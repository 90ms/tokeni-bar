import Foundation

public protocol UsageProviding: Sendable {
    var descriptor: ProviderDescriptor { get }
    func fetchUsage() async -> ProviderSnapshot
}

public protocol UsageCacheInvalidating: Sendable {
    func invalidateUsageCache() async
}

public protocol UsageAuthorizationProviding: UsageProviding {
    func requestUsageAuthorization() async throws
}

public protocol UsageActivityProviding: Sendable {
    var descriptor: ProviderDescriptor { get }
    func latestActivityDate(since cutoff: Date) -> Date?
}

public enum ProviderActivityState: String, Hashable, Sendable {
    case active
    case idle
    case unknown
}

public struct ProviderActivitySnapshot: Hashable, Sendable {
    public let providerID: ProviderID
    public let state: ProviderActivityState
    public let lastActivityAt: Date?

    public init(
        providerID: ProviderID,
        state: ProviderActivityState,
        lastActivityAt: Date? = nil)
    {
        self.providerID = providerID
        self.state = state
        self.lastActivityAt = lastActivityAt
    }
}

public enum ProviderActivityEvaluator {
    public static func snapshot(
        providerID: ProviderID,
        lastActivityAt: Date?,
        now: Date,
        activeWindow: TimeInterval) -> ProviderActivitySnapshot
    {
        guard let lastActivityAt else {
            return ProviderActivitySnapshot(providerID: providerID, state: .idle)
        }
        let age = now.timeIntervalSince(lastActivityAt)
        let active = age >= -1 && age <= max(activeWindow, 0)
        return ProviderActivitySnapshot(
            providerID: providerID,
            state: active ? .active : .idle,
            lastActivityAt: lastActivityAt)
    }
}

public enum ProviderRegistry {
    public static func defaultProviders(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> [any UsageProviding]
    {
        [
            CodexUsageProvider(homeDirectory: homeDirectory),
            ClaudeUsageProvider(homeDirectory: homeDirectory),
            GrokUsageProvider(homeDirectory: homeDirectory),
            GeminiUsageProvider(homeDirectory: homeDirectory),
            OpenCodeUsageProvider(homeDirectory: homeDirectory),
        ]
    }
}
