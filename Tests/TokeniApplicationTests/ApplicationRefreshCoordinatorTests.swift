@testable import TokeniApplication
import Foundation
import Testing
import TokeniCore

struct ApplicationRefreshCoordinatorTests {
    @Test
    func refreshesOnlyEnabledProvidersInCatalogOrder() async {
        let first = TestProvider(snapshot: Self.snapshot(id: .codex))
        let second = TestProvider(snapshot: Self.snapshot(id: .claude))
        let disabled = TestProvider(snapshot: Self.snapshot(id: .grok))
        let coordinator = UsageRefreshCoordinator(
            providers: [first, second, disabled])

        let result = await coordinator.refresh(
            enabledProviderIDs: [.claude, .codex],
            now: Self.fixedDate)

        #expect(result.snapshots.map(\.id) == [.codex, .claude])
        #expect(result.refreshedAt == Self.fixedDate)
    }

    @Test
    func preservesUnavailableAndStaleProviderResults() async {
        let stale = TestProvider(
            snapshot: Self.snapshot(id: .codex, availability: .stale))
        let unavailable = TestProvider(
            snapshot: Self.snapshot(id: .claude, availability: .unavailable))
        let coordinator = UsageRefreshCoordinator(providers: [stale, unavailable])

        let result = await coordinator.refresh(
            enabledProviderIDs: [.codex, .claude])

        #expect(result.snapshots.map(\.availability) == [.stale, .unavailable])
    }

    @Test
    func invalidatesActiveCachesBeforeRefreshingWhenForced() async {
        let provider = RecordingProvider(snapshot: Self.snapshot(id: .codex))
        let coordinator = UsageRefreshCoordinator(providers: [provider])

        _ = await coordinator.refresh(
            enabledProviderIDs: [.codex],
            forceProviderReload: true)

        #expect(await provider.invalidationCount() == 1)
        #expect(await provider.fetchCount() == 1)
    }

    @Test
    func forcedRefreshSkipsFetchAndInvalidationWithNoActiveProviders() async {
        let provider = RecordingProvider(snapshot: Self.snapshot(id: .codex))
        let coordinator = UsageRefreshCoordinator(providers: [provider])

        let result = await coordinator.refresh(
            enabledProviderIDs: [],
            forceProviderReload: true,
            now: Self.fixedDate)

        #expect(result.snapshots.isEmpty)
        #expect(result.refreshedAt == Self.fixedDate)
        #expect(await provider.invalidationCount() == 0)
        #expect(await provider.fetchCount() == 0)
    }

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static func snapshot(
        id: ProviderID,
        availability: ProviderAvailability = .available) -> ProviderSnapshot
    {
        ProviderSnapshot(
            descriptor: ProviderDescriptor(
                id: id,
                displayName: id.rawValue,
                shortName: id.rawValue,
                systemImage: "circle",
                capabilities: .init()),
            availability: availability,
            source: .localProtocol,
            updatedAt: Self.fixedDate)
    }
}

private struct TestProvider: UsageProviding {
    let descriptor: ProviderDescriptor
    let snapshot: ProviderSnapshot

    init(snapshot: ProviderSnapshot) {
        self.descriptor = snapshot.descriptor
        self.snapshot = snapshot
    }

    func fetchUsage() async -> ProviderSnapshot {
        self.snapshot
    }
}

private actor RecordingProvider: UsageProviding, UsageCacheInvalidating {
    nonisolated let descriptor: ProviderDescriptor
    private let snapshot: ProviderSnapshot
    private var invalidations = 0
    private var fetches = 0

    init(snapshot: ProviderSnapshot) {
        self.descriptor = snapshot.descriptor
        self.snapshot = snapshot
    }

    func fetchUsage() async -> ProviderSnapshot {
        self.fetches += 1
        return self.snapshot
    }

    func invalidateUsageCache() async {
        self.invalidations += 1
    }

    func invalidationCount() -> Int {
        self.invalidations
    }

    func fetchCount() -> Int {
        self.fetches
    }
}
