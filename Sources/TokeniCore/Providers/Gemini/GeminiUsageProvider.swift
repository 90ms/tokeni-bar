import Foundation

public struct GeminiUsageProvider: UsageProviding, UsageActivityProviding {
    public let descriptor = ProviderDescriptor(
        id: .gemini,
        displayName: "Gemini CLI",
        shortName: "Gemini",
        systemImage: "diamond.fill",
        iconAssetName: "gemini",
        capabilities: .init(supportsTokenUsage: true))

    private let temporaryDirectory: URL
    private let usageCache = GeminiUsageCache()

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.init(
            temporaryDirectory: homeDirectory.appending(
                path: ".gemini/tmp",
                directoryHint: .isDirectory))
    }

    public init(temporaryDirectory: URL) {
        self.temporaryDirectory = temporaryDirectory
    }

    public func fetchUsage() async -> ProviderSnapshot {
        let files = self.sessionFiles()
        if let cached = await self.usageCache.latestUsage(files: files) {
            let file = cached.file
            let usage = cached.usage
            let detail = usage.tokenUsage.modelID.map {
                "Latest local Gemini CLI session · \($0)"
            } ?? "Latest local Gemini CLI session"
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: .localSessionLog,
                tokenUsage: usage.tokenUsage,
                growthUsageObservation: GrowthUsageObservation(
                    providerID: .gemini,
                    scope: .session,
                    scopeID: file.deletingPathExtension().lastPathComponent,
                    totalTokens: usage.tokenUsage.totalTokens,
                    observedAt: usage.timestamp ?? .now),
                detail: detail,
                updatedAt: usage.timestamp ?? .now)
        }

        return .init(
            descriptor: self.descriptor,
            availability: .unavailable,
            source: .localSessionLog,
            detail: "No Gemini CLI session usage was found in ~/.gemini/tmp")
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        LocalFiles.latestModificationDate(
            below: self.temporaryDirectory,
            modifiedAfter: cutoff,
            matching: { url in
                url.pathExtension == "json"
                    && url.lastPathComponent.hasPrefix("session-")
                    && url.deletingLastPathComponent().lastPathComponent == "chats"
            })
    }

    private func sessionFiles() -> [URL] {
        LocalFiles.newestFiles(
            below: self.temporaryDirectory,
            extension: "json",
            limit: 256)
            .filter {
                $0.lastPathComponent.hasPrefix("session-")
                    && $0.deletingLastPathComponent().lastPathComponent == "chats"
            }
    }
}

struct GeminiParsedUsage: Sendable {
    let timestamp: Date?
    let tokenUsage: TokenUsage
}

struct GeminiCachedUsage: Sendable {
    let file: URL
    let usage: GeminiParsedUsage
}

actor GeminiUsageCache {
    private var signatures: [LocalFileSignature]?
    private var result: GeminiCachedUsage?
    private var hasResult = false

    func latestUsage(files: [URL]) -> GeminiCachedUsage? {
        let nextSignatures = LocalFiles.signatures(for: files)
        if self.signatures == nextSignatures, self.hasResult {
            return self.result
        }
        let result = files.lazy.compactMap { file in
            GeminiSessionParser.latestUsage(in: file).map {
                GeminiCachedUsage(file: file, usage: $0)
            }
        }.first
        self.signatures = nextSignatures
        self.result = result
        self.hasResult = true
        return result
    }
}

enum GeminiSessionParser {
    static func latestUsage(in file: URL) -> GeminiParsedUsage? {
        guard let data = LocalFiles.data(in: file),
              let session = try? JSONDecoder().decode(GeminiSession.self, from: data)
        else { return nil }

        let records = session.messages.compactMap { message -> UsageRecord? in
            guard message.type == "gemini",
                  let tokens = message.tokens,
                  let total = tokens.total,
                  total >= 0
            else { return nil }
            return UsageRecord(message: message, tokens: tokens, total: total)
        }
        guard !records.isEmpty else { return nil }

        let modelIDs = Set(records.compactMap(\.modelID))
        guard let total = sum(records.map(\.total)) else { return nil }
        let input = sumIfComplete(records.map(\.uncachedInput))
        let cached = sumIfComplete(records.map(\.cached))
        let output = sumIfComplete(records.map(\.output))
        let thoughts = sumIfComplete(records.map(\.thoughts))

        return GeminiParsedUsage(
            timestamp: records.reversed().compactMap(\.timestamp).first
                ?? TimestampParser.parse(session.lastUpdated),
            tokenUsage: TokenUsage(
                label: "Latest session",
                modelID: modelIDs.count == 1 ? modelIDs.first : nil,
                inputTokens: input,
                cachedInputTokens: cached,
                outputTokens: output,
                reasoningTokens: thoughts,
                totalTokens: total))
    }

    private static func sumIfComplete(_ values: [Int64?]) -> Int64? {
        guard values.allSatisfy({ $0 != nil }) else { return nil }
        return self.sum(values.compactMap { $0 })
    }

    private static func sum(_ values: [Int64]) -> Int64? {
        var result: Int64 = 0
        for value in values {
            let addition = result.addingReportingOverflow(value)
            guard !addition.overflow else { return nil }
            result = addition.partialValue
        }
        return result
    }

    private struct UsageRecord {
        let modelID: String?
        let timestamp: Date?
        let uncachedInput: Int64?
        let cached: Int64?
        let output: Int64?
        let thoughts: Int64?
        let total: Int64

        init(message: GeminiSession.Message, tokens: GeminiSession.Tokens, total: Int64) {
            let modelID = message.model?.trimmingCharacters(in: .whitespacesAndNewlines)
            let cached = tokens.cached.map { max($0, 0) }
            self.modelID = modelID?.isEmpty == false ? modelID : nil
            self.timestamp = TimestampParser.parse(message.timestamp)
            self.cached = cached
            self.uncachedInput = tokens.input.map { max($0 - (cached ?? 0), 0) }
            self.output = tokens.output.map { max($0, 0) }
            self.thoughts = tokens.thoughts.map { max($0, 0) }
            self.total = total
        }
    }
}

private struct GeminiSession: Decodable {
    let lastUpdated: String?
    let messages: [Message]

    struct Message: Decodable {
        let type: String?
        let model: String?
        let timestamp: String?
        let tokens: Tokens?
    }

    struct Tokens: Decodable {
        let input: Int64?
        let output: Int64?
        let cached: Int64?
        let thoughts: Int64?
        let total: Int64?
    }
}
