import Foundation

public struct OpenCodeUsageProvider: UsageProviding, UsageActivityProviding {
    public let descriptor = ProviderDescriptor(
        id: .openCode,
        displayName: "OpenCode",
        shortName: "OpenCode",
        systemImage: "terminal",
        iconAssetName: "opencode",
        capabilities: .init(supportsTokenUsage: true))

    private let dataDirectory: URL
    private let databaseReader: OpenCodeDatabaseReader

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.dataDirectory = homeDirectory.appending(
            path: ".local/share/opencode",
            directoryHint: .isDirectory)
        self.databaseReader = OpenCodeDatabaseReader()
    }

    public func fetchUsage() async -> ProviderSnapshot {
        guard let databaseURL = self.latestDatabaseURL() else {
            return .init(
                descriptor: self.descriptor,
                availability: .unavailable,
                source: .localSessionLog,
                detail: "No OpenCode usage database was found")
        }

        guard let aggregate = try? self.databaseReader.readAggregate(from: databaseURL) else {
            return .init(
                descriptor: self.descriptor,
                availability: .failed,
                source: .localSessionLog,
                detail: "OpenCode usage database could not be read")
        }

        let usage = aggregate.tokenUsage
        return .init(
            descriptor: self.descriptor,
            availability: .available,
            source: .localSessionLog,
            tokenUsage: usage,
            costEstimate: TokenCostEstimate(
                label: usage.label,
                amountUSD: max(aggregate.costUSD, 0),
                modelIDs: []),
            detail: "All-time local sessions · \(aggregate.sessionCount) sessions")
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: self.dataDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles])
        else { return nil }

        return entries.compactMap { url -> Date? in
            let name = url.lastPathComponent
            let isDatabase = name == "opencode.db"
                || (name.hasPrefix("opencode-") && name.hasSuffix(".db"))
            let isWriteAheadLog = name == "opencode.db-wal"
                || (name.hasPrefix("opencode-") && name.hasSuffix(".db-wal"))
            guard isDatabase || isWriteAheadLog,
                  let values = try? url.resourceValues(
                      forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt >= cutoff
            else { return nil }
            return modifiedAt
        }.max()
    }

    private func latestDatabaseURL() -> URL? {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: self.dataDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles])
        else { return nil }

        return entries.compactMap { url -> (URL, Date)? in
            let name = url.lastPathComponent
            guard name == "opencode.db"
                    || (name.hasPrefix("opencode-") && url.pathExtension == "db"),
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true
            else { return nil }
            let walURL = URL(fileURLWithPath: url.path + "-wal")
            let walModifiedAt = try? walURL.resourceValues(
                forKeys: [.contentModificationDateKey]).contentModificationDate
            return (url, max(
                values.contentModificationDate ?? .distantPast,
                walModifiedAt ?? .distantPast))
        }
        .max { $0.1 < $1.1 }?
        .0
    }
}

struct OpenCodeUsageAggregate: Decodable, Sendable {
    let sessionCount: Int
    let costUSD: Double
    let inputTokens: Int64
    let outputTokens: Int64
    let reasoningTokens: Int64
    let cacheReadTokens: Int64
    let cacheWriteTokens: Int64

    var tokenUsage: TokenUsage {
        let input = max(self.inputTokens, 0)
        let output = max(self.outputTokens, 0)
        let reasoning = max(self.reasoningTokens, 0)
        let cacheRead = max(self.cacheReadTokens, 0)
        let cacheWrite = max(self.cacheWriteTokens, 0)
        return TokenUsage(
            label: "All-time local",
            inputTokens: input,
            cacheCreationInputTokens: cacheWrite,
            cachedInputTokens: cacheRead,
            outputTokens: output,
            reasoningTokens: reasoning,
            totalTokens: input + output + reasoning + cacheRead + cacheWrite)
    }

    enum CodingKeys: String, CodingKey {
        case sessionCount = "session_count"
        case costUSD = "cost_usd"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case reasoningTokens = "reasoning_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cacheWriteTokens = "cache_write_tokens"
    }
}

enum OpenCodeUsageParser {
    static func decode(_ data: Data) throws -> OpenCodeUsageAggregate {
        let rows = try JSONDecoder().decode([OpenCodeUsageAggregate].self, from: data)
        guard let aggregate = rows.first else {
            throw OpenCodeDatabaseError.invalidAggregate
        }
        return aggregate
    }
}

private struct OpenCodeDatabaseReader: Sendable {
    private static let aggregateQuery = """
        SELECT
          COUNT(*) AS session_count,
          COALESCE(SUM(cost), 0.0) AS cost_usd,
          COALESCE(SUM(tokens_input), 0) AS input_tokens,
          COALESCE(SUM(tokens_output), 0) AS output_tokens,
          COALESCE(SUM(tokens_reasoning), 0) AS reasoning_tokens,
          COALESCE(SUM(tokens_cache_read), 0) AS cache_read_tokens,
          COALESCE(SUM(tokens_cache_write), 0) AS cache_write_tokens
        FROM session;
        """

    func readAggregate(from databaseURL: URL) throws -> OpenCodeUsageAggregate {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-batch",
            "-init",
            "/dev/null",
            "-readonly",
            "-json",
            databaseURL.path,
            Self.aggregateQuery,
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw OpenCodeDatabaseError.queryFailed
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw OpenCodeDatabaseError.queryFailed
        }

        return try OpenCodeUsageParser.decode(output.fileHandleForReading.readDataToEndOfFile())
    }
}

private enum OpenCodeDatabaseError: Error {
    case invalidAggregate
    case queryFailed
}
