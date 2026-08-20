import Foundation

public struct AntigravityUsageProvider: UsageProviding, UsageActivityProviding {
    public let descriptor = ProviderDescriptor(
        id: .antigravity,
        displayName: "Antigravity",
        shortName: "Antigravity",
        systemImage: "sparkles.rectangle.stack",
        capabilities: .init(supportsTokenUsage: true))

    private let roots: [URL]
    private let calendar: Calendar
    private let databaseReader: AntigravityDatabaseReader

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current,
        roots: [URL]? = nil,
        sqliteQueryRunner: any ReadOnlySQLiteQuerying = SystemSQLiteQueryRunner())
    {
        self.calendar = calendar
        self.roots = roots ?? [
            homeDirectory.appending(
                path: ".gemini/antigravity/conversations",
                directoryHint: .isDirectory),
            homeDirectory.appending(
                path: ".gemini/antigravity-cli/conversations",
                directoryHint: .isDirectory),
            homeDirectory.appending(
                path: ".gemini/antigravity-ide/conversations",
                directoryHint: .isDirectory),
        ]
        self.databaseReader = AntigravityDatabaseReader(queryRunner: sqliteQueryRunner)
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let startOfDay = self.calendar.startOfDay(for: .now)
        let databases = self.databaseFiles(modifiedAfter: startOfDay)
        var databaseRows: [AntigravityDatabaseRows] = []
        for database in databases {
            guard let rows = try? await self.databaseReader.readRows(from: database) else {
                continue
            }
            databaseRows.append(AntigravityDatabaseRows(
                sessionID: database.standardizedFileURL.path,
                rows: rows))
        }
        let usage = AntigravityMetadataParser.aggregate(
            databaseRows,
            since: startOfDay)

        guard let usage else {
            return .init(
                descriptor: self.descriptor,
                availability: .unavailable,
                source: .localSessionLog,
                detail: databases.isEmpty
                    ? "No Antigravity conversation database was updated today"
                    : "No timestamped Antigravity token record was available today")
        }

        return .init(
            descriptor: self.descriptor,
            availability: .available,
            source: .localSessionLog,
            tokenUsage: usage.tokenUsage,
            growthUsageObservation: .daily(
                providerID: .antigravity,
                dateKey: GrowthLocalDate.key(for: usage.observedAt, calendar: self.calendar),
                totalTokens: usage.tokenUsage.totalTokens,
                observedAt: usage.observedAt),
            detail: "Today across \(usage.sessionCount) local Antigravity conversations",
            updatedAt: usage.observedAt)
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        self.roots.compactMap { root in
            LocalFiles.latestModificationDate(
                below: root,
                modifiedAfter: cutoff,
                matching: {
                    $0.pathExtension == "db"
                        || $0.lastPathComponent.hasSuffix(".db-wal")
                })
        }.max()
    }

    private func databaseFiles(modifiedAfter startDate: Date) -> [URL] {
        var seen: Set<URL> = []
        return self.roots.flatMap { root in
            let databases = LocalFiles.newestFiles(
                below: root,
                extension: "db",
                modifiedAfter: startDate,
                limit: 128)
            let databasesWithUpdatedWAL = LocalFiles.newestFiles(
                below: root,
                extension: "db-wal",
                modifiedAfter: startDate,
                limit: 128)
                .map { URL(fileURLWithPath: String($0.path.dropLast(4))) }
            return databases + databasesWithUpdatedWAL
        }.filter { seen.insert($0.standardizedFileURL).inserted }
    }
}

struct AntigravityMetadataRow: Decodable {
    let index: Int
    let dataHex: String

    enum CodingKeys: String, CodingKey {
        case index = "idx"
        case dataHex = "data_hex"
    }
}

struct AntigravityDatabaseRows {
    let sessionID: String
    let rows: [AntigravityMetadataRow]
}

struct AntigravityTodayUsage {
    let tokenUsage: TokenUsage
    let observedAt: Date
    let sessionCount: Int
}

enum AntigravityMetadataParser {
    static func aggregate(
        _ databases: [AntigravityDatabaseRows],
        since startDate: Date) -> AntigravityTodayUsage?
    {
        var seenResponses: Set<String> = []
        var sessionIDs: Set<String> = []
        var modelIDs: Set<String> = []
        var input: Int64 = 0
        var output: Int64 = 0
        var reasoning: Int64 = 0
        var total: Int64 = 0
        var observedAt = startDate
        var count = 0

        for database in databases {
            for row in database.rows {
                guard let record = self.parse(row),
                      let timestamp = record.timestamp,
                      timestamp >= startDate,
                      seenResponses.insert(
                          "\(database.sessionID):\(record.responseID)").inserted
                else { continue }
                input = saturatedAdd(input, record.inputTokens)
                output = saturatedAdd(output, record.outputTokens)
                reasoning = saturatedAdd(reasoning, record.reasoningTokens)
                total = saturatedAdd(total, record.totalTokens)
                observedAt = max(observedAt, timestamp)
                sessionIDs.insert(database.sessionID)
                count += 1
                if let modelID = record.modelID { modelIDs.insert(modelID) }
            }
        }

        guard count > 0 else { return nil }
        return AntigravityTodayUsage(
            tokenUsage: TokenUsage(
                label: "Today",
                modelID: modelIDs.count == 1 ? modelIDs.first : nil,
                inputTokens: input,
                outputTokens: output,
                reasoningTokens: reasoning,
                totalTokens: total),
            observedAt: observedAt,
            sessionCount: sessionIDs.count)
    }

    static func parse(_ row: AntigravityMetadataRow) -> Record? {
        guard let data = Data(hexString: row.dataHex) else { return nil }
        let rootFields = ProtoDecoder.fields(in: data)
        guard let chatData = rootFields.firstBytes(number: 1) else { return nil }
        let chatFields = ProtoDecoder.fields(in: chatData)
        guard let usageData = chatFields.firstBytes(number: 4) else { return nil }
        let usageFields = ProtoDecoder.fields(in: usageData)

        let inputTokens = positiveInt64(
            usageFields.firstVarint(number: 2)
                ?? usageFields.firstVarint(number: 1))
        let totalOutput = positiveInt64(usageFields.firstVarint(number: 3))
        var responseOutput = positiveInt64(usageFields.firstVarint(number: 9))
        let reasoning = min(
            positiveInt64(usageFields.firstVarint(number: 10)),
            totalOutput)
        if responseOutput == 0 && reasoning == 0 {
            responseOutput = totalOutput
        } else if saturatedAdd(responseOutput, reasoning) != totalOutput {
            responseOutput = max(totalOutput - reasoning, 0)
        }
        guard inputTokens > 0 || totalOutput > 0 else { return nil }

        let responseID = usageFields.firstText(number: 11)
            .flatMap {
                $0.rangeOfCharacter(from: .whitespacesAndNewlines) == nil ? $0 : nil
            }
            ?? String(row.index)
        let model = chatFields.firstText(number: 19)
            ?? chatFields.firstText(number: 21)
        let timestamp = chatFields.firstBytes(number: 9)
            .flatMap { ProtoDecoder.fields(in: $0).first(number: 4) }
            .flatMap(Self.timestamp)
        return Record(
            responseID: responseID,
            modelID: model?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            timestamp: timestamp,
            inputTokens: inputTokens,
            outputTokens: responseOutput,
            reasoningTokens: reasoning,
            totalTokens: saturatedAdd(inputTokens, totalOutput))
    }

    private static func timestamp(_ field: ProtoField) -> Date? {
        if let text = field.text, let date = TimestampParser.parse(text) {
            return date
        }
        if let bytes = field.bytes {
            let fields = ProtoDecoder.fields(in: bytes)
            if let seconds = fields.firstVarint(number: 1) {
                let nanos = fields.firstVarint(number: 2) ?? 0
                return Date(
                    timeIntervalSince1970: TimeInterval(seconds)
                        + TimeInterval(nanos) / 1_000_000_000)
            }
        }
        if let value = field.varint {
            let raw = TimeInterval(value)
            return Date(timeIntervalSince1970: raw > 1_000_000_000_000 ? raw / 1_000 : raw)
        }
        return nil
    }

    private static func positiveInt64(_ value: UInt64?) -> Int64 {
        guard let value, value <= UInt64(Int64.max) else { return 0 }
        return max(Int64(value), 0)
    }

    struct Record {
        let responseID: String
        let modelID: String?
        let timestamp: Date?
        let inputTokens: Int64
        let outputTokens: Int64
        let reasoningTokens: Int64
        let totalTokens: Int64
    }
}

struct AntigravityDatabaseReader: Sendable {
    private static let metadataQuery = """
        SELECT idx, hex(data) AS data_hex FROM gen_metadata ORDER BY idx;
        """

    private let queryRunner: any ReadOnlySQLiteQuerying

    init(queryRunner: any ReadOnlySQLiteQuerying) {
        self.queryRunner = queryRunner
    }

    func readRows(from databaseURL: URL) async throws -> [AntigravityMetadataRow] {
        guard let values = try? databaseURL.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
            values.isRegularFile == true,
            values.isSymbolicLink != true
        else { throw AntigravityDatabaseError.invalidFile }

        let data = try await self.queryRunner.queryJSON(
            databaseURL: databaseURL,
            sql: Self.metadataQuery)
        return try JSONDecoder().decode([AntigravityMetadataRow].self, from: data)
    }
}

private enum AntigravityDatabaseError: Error {
    case invalidFile
}

private struct ProtoField {
    let number: Int
    let wireType: Int
    let varint: UInt64?
    let bytes: Data?

    var text: String? {
        guard let bytes,
              let value = String(data: bytes, encoding: .utf8),
              !value.isEmpty,
              !value.unicodeScalars.contains(where: {
                  ($0.value < 0x20 && $0.value != 0x09 && $0.value != 0x0A && $0.value != 0x0D)
                      || $0.value == 0x7F
              })
        else { return nil }
        return value
    }
}

private enum ProtoDecoder {
    static func fields(in data: Data) -> [ProtoField] {
        var fields: [ProtoField] = []
        var offset = 0
        while offset < data.count {
            guard let key = self.varint(in: data, offset: &offset) else { break }
            let number = Int(key >> 3)
            let wireType = Int(key & 0x07)
            guard number > 0 else { break }
            switch wireType {
            case 0:
                guard let value = self.varint(in: data, offset: &offset) else { return fields }
                fields.append(ProtoField(number: number, wireType: wireType, varint: value, bytes: nil))
            case 1:
                guard offset + 8 <= data.count else { return fields }
                fields.append(ProtoField(
                    number: number,
                    wireType: wireType,
                    varint: nil,
                    bytes: data.subdata(in: offset ..< offset + 8)))
                offset += 8
            case 2:
                guard let length = self.varint(in: data, offset: &offset),
                      length <= UInt64(Int.max),
                      offset + Int(length) <= data.count
                else { return fields }
                fields.append(ProtoField(
                    number: number,
                    wireType: wireType,
                    varint: nil,
                    bytes: data.subdata(in: offset ..< offset + Int(length))))
                offset += Int(length)
            case 5:
                guard offset + 4 <= data.count else { return fields }
                fields.append(ProtoField(
                    number: number,
                    wireType: wireType,
                    varint: nil,
                    bytes: data.subdata(in: offset ..< offset + 4)))
                offset += 4
            default:
                return fields
            }
        }
        return fields
    }

    private static func varint(in data: Data, offset: inout Int) -> UInt64? {
        var result: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard offset < data.count else { return nil }
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
        }
        return nil
    }
}

private extension Array where Element == ProtoField {
    func first(number: Int) -> ProtoField? {
        self.first { $0.number == number }
    }

    func firstBytes(number: Int) -> Data? {
        self.first(number: number)?.bytes
    }

    func firstVarint(number: Int) -> UInt64? {
        self.first(number: number)?.varint
    }

    func firstText(number: Int) -> String? {
        self.first(number: number)?.text
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2) else { return nil }
        self.init(capacity: hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(String(hexString[index ..< next]), radix: 16) else {
                return nil
            }
            self.append(byte)
            index = next
        }
    }
}

private extension String {
    var nilIfEmpty: String? { self.isEmpty ? nil : self }
}

private func saturatedAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    let result = lhs.addingReportingOverflow(max(rhs, 0))
    return result.overflow ? .max : result.partialValue
}
