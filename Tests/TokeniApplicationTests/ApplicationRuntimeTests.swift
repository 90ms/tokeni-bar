@testable import TokeniApplication
import Foundation
import Testing
import TokeniCore

struct ApplicationRuntimeTests {
    @Test
    func refreshesEnabledProvidersAndPublishesSnapshotsAndRefreshDate() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let codex = Self.snapshot(
            id: .codex,
            tokenTotal: 12,
            updatedAt: Self.fixedDate)
        let claude = Self.snapshot(
            id: .claude,
            tokenTotal: 34,
            updatedAt: Self.fixedDate)
        let runtime = Self.runtime(
            providers: [
                TestProvider(snapshot: codex),
                TestProvider(snapshot: claude),
            ],
            directory: directory)

        let refreshed = await runtime.refresh(
            enabledProviderIDs: [.codex],
            now: Self.fixedDate)

        #expect(refreshed.snapshots == [codex])
        #expect(refreshed.lastRefresh == Self.fixedDate)

        let state = await runtime.state()
        #expect(state.snapshots == [codex])
        #expect(state.lastRefresh == Self.fixedDate)
        #expect(state.historyRecords.isEmpty)
    }

    @Test
    func historyOperationsUpdateRuntimeState() async throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = Self.snapshot(
            id: .codex,
            tokenTotal: 12,
            updatedAt: Self.fixedDate)
        let runtime = Self.runtime(
            providers: [TestProvider(snapshot: snapshot)],
            directory: directory)

        let initiallyLoaded = try await runtime.loadHistory()
        #expect(initiallyLoaded.historyRecords.isEmpty)

        _ = await runtime.refresh(
            enabledProviderIDs: [.codex],
            now: Self.fixedDate)
        let recorded = try await runtime.recordHistory(at: Self.fixedDate)

        #expect(recorded.historyRecords.count == 1)
        #expect(recorded.historyRecords[0].providerID == .codex)
        #expect(recorded.historyRecords[0].timestamp == Self.fixedDate)
        #expect((await runtime.state()).historyRecords == recorded.historyRecords)

        let loaded = try await runtime.loadHistory()
        #expect(loaded.historyRecords == recorded.historyRecords)

        let cleared = try await runtime.clearHistory()
        #expect(cleared.historyRecords.isEmpty)
        #expect((await runtime.state()).historyRecords.isEmpty)
    }

    @Test
    func growthOperationsUpdateRuntimeLedgerState() async throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let observation = GrowthUsageObservation.daily(
            providerID: .codex,
            dateKey: GrowthLocalDate.key(for: Self.fixedDate),
            totalTokens: 100_000,
            observedAt: Self.fixedDate)
        let snapshot = Self.snapshot(
            id: .codex,
            growthObservation: observation,
            updatedAt: Self.fixedDate)
        let runtime = Self.runtime(
            providers: [TestProvider(snapshot: snapshot)],
            directory: directory)

        let loaded = try await runtime.loadGrowthLedger()
        #expect(loaded.growthLedgerState == TokenGrowthLedgerState())

        _ = await runtime.refresh(
            enabledProviderIDs: [.codex],
            now: Self.fixedDate)
        let update = try await runtime.processGrowth(at: Self.fixedDate)

        #expect(update.awards.count == 1)
        #expect((await runtime.state()).growthLedgerState == update.state)

        let award = try #require(update.awards.first)
        let marked = try await runtime.markGrowthAwardApplied(award.id)

        #expect(marked.growthLedgerState.pendingAwards.isEmpty)
        #expect((await runtime.state()).growthLedgerState == marked.growthLedgerState)
    }

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    private static func runtime(
        providers: [any UsageProviding],
        directory: URL) -> UsageApplicationRuntime
    {
        let historyStore = UsageHistoryStore(
            fileURL: directory.appending(path: "usage-history.json"),
            minimumRecordInterval: 0)
        let growthStore = TokenGrowthLedgerStore(
            fileURL: directory.appending(path: "growth-ledger.json"))
        return UsageApplicationRuntime(
            providers: providers,
            historyCoordinator: UsageHistoryCoordinator(store: historyStore),
            growthLedgerCoordinator: TokenGrowthLedgerCoordinator(
                store: growthStore,
                engine: TokenGrowthLedgerEngine(
                    formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000))))
    }

    private static func snapshot(
        id: ProviderID,
        tokenTotal: Int64? = nil,
        growthObservation: GrowthUsageObservation? = nil,
        updatedAt: Date) -> ProviderSnapshot
    {
        ProviderSnapshot(
            descriptor: ProviderDescriptor(
                id: id,
                displayName: id.rawValue,
                shortName: id.rawValue,
                systemImage: "circle",
                capabilities: ProviderCapabilities(supportsTokenUsage: tokenTotal != nil)),
            availability: .available,
            source: .localProtocol,
            tokenUsage: tokenTotal.map {
                TokenUsage(label: "Today", totalTokens: $0)
            },
            growthUsageObservation: growthObservation,
            updatedAt: updatedAt)
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
