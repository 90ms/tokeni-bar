import Foundation

public struct ClineUsageProvider: UsageProviding, UsageActivityProviding {
    public let descriptor = ProviderDescriptor(
        id: .cline,
        displayName: "Cline",
        shortName: "Cline",
        systemImage: "terminal.fill",
        capabilities: .init(supportsTokenUsage: true))

    private let roots: [URL]
    private let calendar: Calendar
    private let usageCache = ClineUsageCache()

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        calendar: Calendar = .current,
        roots: [URL]? = nil,
        applicationSupportDirectory: URL? = nil)
    {
        self.calendar = calendar
        self.roots = roots ?? Self.defaultRoots(
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory)
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let startOfDay = self.calendar.startOfDay(for: .now)
        let files = self.usageFiles(modifiedAfter: startOfDay)
        guard !files.isEmpty,
              let usage = await self.usageCache.aggregate(
                files: files,
                since: startOfDay)
        else {
            return .init(
                descriptor: self.descriptor,
                availability: .unavailable,
                source: .localSessionLog,
                detail: "No Cline task was updated today")
        }
        return .init(
            descriptor: self.descriptor,
            availability: .available,
            source: .localSessionLog,
            tokenUsage: usage.tokenUsage,
            costEstimate: usage.costEstimate,
            growthUsageObservation: .daily(
                providerID: .cline,
                dateKey: GrowthLocalDate.key(for: usage.observedAt, calendar: self.calendar),
                totalTokens: usage.tokenUsage.totalTokens,
                observedAt: usage.observedAt),
            detail: "Today across \(usage.taskCount) local Cline tasks",
            updatedAt: usage.observedAt)
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        self.roots.compactMap { root in
            LocalFiles.latestModificationDate(
                below: root,
                modifiedAfter: cutoff,
                matching: { $0.lastPathComponent == "ui_messages.json" })
        }.max()
    }

    private func usageFiles(modifiedAfter startDate: Date) -> [URL] {
        var seen: Set<URL> = []
        return self.roots.flatMap { root in
            LocalFiles.newestFiles(
                below: root,
                named: "ui_messages.json",
                modifiedAfter: startDate,
                limit: 256)
        }.filter { seen.insert($0.standardizedFileURL).inserted }
    }

    private static func defaultRoots(
        homeDirectory: URL,
        applicationSupportDirectory: URL?) -> [URL]
    {
        let applicationSupport = applicationSupportDirectory
            ?? Self.defaultApplicationSupportDirectory(homeDirectory: homeDirectory)
        let extensionPath = "User/globalStorage/saoudrizwan.claude-dev"
        return [
            applicationSupport.appending(path: "Code/\(extensionPath)", directoryHint: .isDirectory),
            applicationSupport.appending(path: "Code - Insiders/\(extensionPath)", directoryHint: .isDirectory),
            applicationSupport.appending(path: "VSCodium/\(extensionPath)", directoryHint: .isDirectory),
            applicationSupport.appending(path: "Cursor/\(extensionPath)", directoryHint: .isDirectory),
            homeDirectory.appending(path: ".cline/data", directoryHint: .isDirectory),
        ]
    }

    private static func defaultApplicationSupportDirectory(homeDirectory: URL) -> URL {
        #if os(Windows)
        // APPDATA is supplied by the platform directory adapter. Keep the
        // provider-specific relative paths below unchanged until they are
        // verified against each Windows editor distribution.
        return DefaultApplicationDirectoriesProvider().directories.applicationSupportDirectory
        #else
        return homeDirectory.appending(
            path: "Library/Application Support",
            directoryHint: .isDirectory)
        #endif
    }
}

struct ClineTodayUsage: Sendable {
    let tokenUsage: TokenUsage
    let costEstimate: TokenCostEstimate?
    let observedAt: Date
    let taskCount: Int
}

actor ClineUsageCache {
    private var signatures: [LocalFileSignature]?
    private var startDate: Date?
    private var result: ClineTodayUsage?
    private var hasResult = false

    func aggregate(files: [URL], since startDate: Date) -> ClineTodayUsage? {
        let nextSignatures = LocalFiles.signatures(for: files)
        if self.signatures == nextSignatures,
           self.startDate == startDate,
           self.hasResult
        {
            return self.result
        }
        let result = ClineLogParser.aggregate(files: files, since: startDate)
        self.signatures = nextSignatures
        self.startDate = startDate
        self.result = result
        self.hasResult = true
        return result
    }
}

enum ClineLogParser {
    static func aggregate(files: [URL], since startDate: Date) -> ClineTodayUsage? {
        let decoder = JSONDecoder()
        var seenRecords: Set<String> = []
        var taskIDs: Set<String> = []
        var input: Int64 = 0
        var cached: Int64 = 0
        var cacheCreation: Int64 = 0
        var output: Int64 = 0
        var amountUSD = 0.0
        var allRecordsPriced = true
        var recordCount = 0
        var observedAt = startDate

        for file in files {
            guard let data = LocalFiles.data(in: file),
                  let messages = try? decoder.decode([Message].self, from: data)
            else { continue }
            let taskID = file.deletingLastPathComponent().lastPathComponent
            for (index, message) in messages.enumerated() {
                guard message.type == "say",
                      message.say == "api_req_started",
                      let timestamp = message.date,
                      timestamp >= startDate,
                      let text = message.text,
                      let payload = try? decoder.decode(UsagePayload.self, from: Data(text.utf8))
                else { continue }
                let key = "\(file.standardizedFileURL.path):\(message.ts ?? 0):\(index)"
                guard seenRecords.insert(key).inserted else { continue }
                let tokensIn = max(payload.tokensIn ?? 0, 0)
                let tokensOut = max(payload.tokensOut ?? 0, 0)
                let cacheReads = max(payload.cacheReads ?? 0, 0)
                let cacheWrites = max(payload.cacheWrites ?? 0, 0)
                guard tokensIn > 0 || tokensOut > 0 || cacheReads > 0 || cacheWrites > 0
                else { continue }
                input = saturatedAdd(input, tokensIn)
                output = saturatedAdd(output, tokensOut)
                cached = saturatedAdd(cached, cacheReads)
                cacheCreation = saturatedAdd(cacheCreation, cacheWrites)
                observedAt = max(observedAt, timestamp)
                taskIDs.insert(taskID)
                recordCount += 1
                if let cost = payload.cost, cost.isFinite, cost >= 0 {
                    amountUSD += cost
                } else {
                    allRecordsPriced = false
                }
            }
        }

        guard recordCount > 0 else { return nil }
        let total = [input, output, cached, cacheCreation].reduce(0, saturatedAdd)
        let tokenUsage = TokenUsage(
            label: "Today",
            inputTokens: input,
            cacheCreationInputTokens: cacheCreation,
            cachedInputTokens: cached,
            outputTokens: output,
            totalTokens: total)
        let cost = allRecordsPriced && amountUSD.isFinite
            ? TokenCostEstimate(
                label: "Today · provider recorded",
                amountUSD: amountUSD,
                modelIDs: [])
            : nil
        return ClineTodayUsage(
            tokenUsage: tokenUsage,
            costEstimate: cost,
            observedAt: observedAt,
            taskCount: taskIDs.count)
    }

    private static func saturatedAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(max(rhs, 0))
        return result.overflow ? .max : result.partialValue
    }

    private struct Message: Decodable {
        let type: String?
        let say: String?
        let text: String?
        let ts: Int64?

        enum CodingKeys: String, CodingKey {
            case type, say, text, ts
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try? container.decode(String.self, forKey: .type)
            self.say = try? container.decode(String.self, forKey: .say)
            self.text = try? container.decode(String.self, forKey: .text)
            if let integer = try? container.decode(Int64.self, forKey: .ts) {
                self.ts = integer
            } else if let number = try? container.decode(Double.self, forKey: .ts),
                      number.isFinite,
                      number >= Double(Int64.min),
                      number < Double(Int64.max)
            {
                self.ts = Int64(number)
            } else if let string = try? container.decode(String.self, forKey: .ts) {
                self.ts = Int64(string)
            } else {
                self.ts = nil
            }
        }

        var date: Date? {
            guard let ts, ts > 0 else { return nil }
            let divisor = ts > 1_000_000_000_000 ? 1_000.0 : 1.0
            return Date(timeIntervalSince1970: TimeInterval(ts) / divisor)
        }
    }

    private struct UsagePayload: Decodable {
        let tokensIn: Int64?
        let tokensOut: Int64?
        let cacheReads: Int64?
        let cacheWrites: Int64?
        let cost: Double?
    }
}
