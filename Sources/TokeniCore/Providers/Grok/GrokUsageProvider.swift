import Foundation

public struct GrokUsageProvider: UsageProviding, UsageActivityProviding {
    public let descriptor = ProviderDescriptor(
        id: .grok,
        displayName: "Grok",
        shortName: "Grok",
        systemImage: "xmark",
        iconAssetName: "grok",
        capabilities: .init(
            supportsQuotaWindows: true,
            supportsTokenUsage: true))

    private let sessionsDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.sessionsDirectory = homeDirectory.appending(path: ".grok/sessions", directoryHint: .isDirectory)
    }

    public func fetchUsage() async -> ProviderSnapshot {
        guard let file = LocalFiles.newestFiles(
            below: self.sessionsDirectory,
            named: "signals.json",
            limit: 1).first,
            let data = try? Data(contentsOf: file),
            let signals = try? JSONDecoder().decode(GrokSignals.self, from: data)
        else {
            return .init(
                descriptor: self.descriptor,
                availability: .unavailable,
                source: .localSessionLog,
                detail: "No Grok session signals were found")
        }

        let contextUsed = signals.contextTokensUsed ?? 0
        let contextPercent = signals.contextWindowUsage ?? {
            guard let window = signals.contextWindowTokens, window > 0 else { return 0 }
            return Double(contextUsed) / Double(window) * 100
        }()

        return .init(
            descriptor: self.descriptor,
            availability: .available,
            source: .localSessionLog,
            quotaWindows: [
                QuotaWindow(
                    id: "context",
                    kind: .context,
                    label: "Context",
                    usedPercent: contextPercent),
            ],
            tokenUsage: TokenUsage(
                label: "Current context",
                totalTokens: contextUsed),
            detail: signals.primaryModelID.map { "Latest local session · \($0)" } ?? "Latest local Grok session")
    }

    public func latestActivityDate(since cutoff: Date) -> Date? {
        LocalFiles.latestModificationDate(
            below: self.sessionsDirectory,
            modifiedAfter: cutoff,
            matching: { $0.lastPathComponent == "signals.json" })
    }
}

private struct GrokSignals: Decodable {
    let contextTokensUsed: Int64?
    let contextWindowTokens: Int64?
    let contextWindowUsage: Double?
    let totalTokensBeforeCompaction: Int64?
    let primaryModelID: String?

    enum CodingKeys: String, CodingKey {
        case contextTokensUsed
        case contextWindowTokens
        case contextWindowUsage
        case totalTokensBeforeCompaction
        case primaryModelID = "primaryModelId"
    }
}
