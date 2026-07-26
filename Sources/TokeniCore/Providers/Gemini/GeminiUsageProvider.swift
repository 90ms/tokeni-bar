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

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.temporaryDirectory = homeDirectory.appending(
            path: ".gemini/tmp",
            directoryHint: .isDirectory)
    }

    public func fetchUsage() async -> ProviderSnapshot {
        for file in self.sessionFiles() {
            guard let usage = GeminiSessionParser.latestUsage(in: file) else { continue }
            let detail = usage.tokenUsage.modelID.map {
                "Latest local Gemini CLI session · \($0)"
            } ?? "Latest local Gemini CLI session"
            return .init(
                descriptor: self.descriptor,
                availability: .available,
                source: .localSessionLog,
                tokenUsage: usage.tokenUsage,
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

struct GeminiParsedUsage {
    let timestamp: Date?
    let tokenUsage: TokenUsage
}

enum GeminiSessionParser {
    static func latestUsage(in file: URL) -> GeminiParsedUsage? {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe),
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
