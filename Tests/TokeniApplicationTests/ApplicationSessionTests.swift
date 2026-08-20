@testable import TokeniApplication
import Foundation
import Testing
import TokeniCore

struct ApplicationSessionTests {
    @Test
    func bootstrapsPersistedHistoryAndGrowthState() async throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let date = Self.fixedDate
        let observation = GrowthUsageObservation.daily(
            providerID: .codex,
            dateKey: GrowthLocalDate.key(for: date),
            totalTokens: 100_000,
            observedAt: date)
        let snapshot = Self.snapshot(
            id: .codex,
            tokenTotal: 12,
            growthObservation: observation,
            updatedAt: date)

        let historyStore = UsageHistoryStore(
            fileURL: directory.appending(path: "usage-history.json"),
            minimumRecordInterval: 0)
        try await historyStore.record([snapshot], at: date)
        let expectedHistory = try await historyStore.records()

        let growthStore = TokenGrowthLedgerStore(
            fileURL: directory.appending(path: "growth-ledger.json"))
        let persistedGrowth = TokenGrowthLedgerCoordinator(
            store: growthStore,
            engine: Self.growthEngine)
        _ = try await persistedGrowth.load()
        let expectedGrowth = (try await persistedGrowth.process(
            observations: [observation],
            at: date)).state

        let runtime = Self.runtime(
            providers: [TestProvider(snapshot: snapshot)],
            historyStore: historyStore,
            growthStore: growthStore)
        let session = UsageApplicationSession(
            providers: [TestProvider(snapshot: snapshot)],
            runtime: runtime)

        try await session.bootstrap()

        let state = await session.state()
        #expect(state.applicationState.historyRecords == expectedHistory)
        #expect(state.applicationState.growthLedgerState == expectedGrowth)
        #expect(state.providerDescriptors == [snapshot.descriptor])
        #expect(state.enabledProviderIDs == [.codex])
        #expect(!state.isRefreshing)
    }

    @Test
    func refreshesEnabledProvidersAndRecordsHistory() async {
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
        let codexProvider = CountingProvider(snapshot: codex)
        let claudeProvider = CountingProvider(snapshot: claude)
        let providers: [any UsageProviding] = [codexProvider, claudeProvider]
        let runtime = Self.runtime(
            providers: providers,
            historyStore: UsageHistoryStore(
                fileURL: directory.appending(path: "history.json"),
                minimumRecordInterval: 0),
            growthStore: TokenGrowthLedgerStore(
                fileURL: directory.appending(path: "growth.json")))
        let session = UsageApplicationSession(
            providers: providers,
            runtime: runtime,
            enabledProviderIDs: [.codex])

        await session.refresh(now: Self.fixedDate)

        var state = await session.state()
        #expect(state.applicationState.snapshots == [codex])
        #expect(state.applicationState.historyRecords.map(\.providerID) == [.codex])
        #expect(state.enabledProviderIDs == [.codex])
        #expect(!state.isRefreshing)
        #expect(await codexProvider.fetchCount() == 1)
        #expect(await claudeProvider.fetchCount() == 0)

        await session.setEnabled(false, for: .codex)
        await session.setEnabled(true, for: .claude)
        await session.refresh(now: Self.fixedDate.addingTimeInterval(1))

        state = await session.state()
        #expect(state.applicationState.snapshots == [claude])
        #expect(state.applicationState.historyRecords.map(\.providerID) == [.codex, .claude])
        #expect(state.enabledProviderIDs == [.claude])
        #expect(await codexProvider.fetchCount() == 1)
        #expect(await claudeProvider.fetchCount() == 1)
    }

    @Test
    func processesAndMarksGrowthThroughSessionState() async throws {
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
        let provider = TestProvider(snapshot: snapshot)
        let runtime = Self.runtime(
            providers: [provider],
            historyStore: UsageHistoryStore(
                fileURL: directory.appending(path: "history.json"),
                minimumRecordInterval: 0),
            growthStore: TokenGrowthLedgerStore(
                fileURL: directory.appending(path: "growth.json")))
        let session = UsageApplicationSession(
            providers: [provider],
            runtime: runtime)

        try await session.bootstrap()
        await session.refresh(now: Self.fixedDate)
        try await session.processGrowth(at: Self.fixedDate)

        var state = await session.state()
        let award = try #require(state.applicationState.growthLedgerState.pendingAwards.first)
        #expect(state.applicationState.growthLedgerState.pendingAwards.count == 1)

        try await session.markGrowthAwardApplied(award.id)

        state = await session.state()
        #expect(state.applicationState.growthLedgerState.pendingAwards.isEmpty)
    }

    @Test
    func startsOnlyOneRefreshLoopAndStopsIt() async throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let provider = CountingProvider(
            snapshot: Self.snapshot(
                id: .codex,
                tokenTotal: 12,
                updatedAt: Self.fixedDate))
        let runtime = Self.runtime(
            providers: [provider],
            historyStore: UsageHistoryStore(
                fileURL: directory.appending(path: "history.json"),
                minimumRecordInterval: 0),
            growthStore: TokenGrowthLedgerStore(
                fileURL: directory.appending(path: "growth.json")))
        let session = UsageApplicationSession(
            providers: [provider],
            runtime: runtime)

        await session.start(refreshInterval: .seconds(1))
        await session.start(refreshInterval: .milliseconds(1))

        for _ in 0..<20 {
            if await provider.fetchCount() > 0 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let runningCount = await provider.fetchCount()
        #expect(runningCount == 1)

        await session.stop()
        try await Task.sleep(for: .milliseconds(30))

        #expect(await provider.fetchCount() == runningCount)
        let stoppedState = await session.state()
        #expect(!stoppedState.isRefreshing)
    }

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private static let growthEngine = TokenGrowthLedgerEngine(
        formula: TokenGrowthEnergyFormula(tokensPerEnergy: 25_000))

    private static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    private static func runtime(
        providers: [any UsageProviding],
        historyStore: UsageHistoryStore,
        growthStore: TokenGrowthLedgerStore) -> UsageApplicationRuntime
    {
        UsageApplicationRuntime(
            providers: providers,
            historyCoordinator: UsageHistoryCoordinator(store: historyStore),
            growthLedgerCoordinator: TokenGrowthLedgerCoordinator(
                store: growthStore,
                engine: Self.growthEngine))
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
                capabilities: ProviderCapabilities(
                    supportsTokenUsage: tokenTotal != nil)),
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

private actor CountingProvider: UsageProviding {
    nonisolated let descriptor: ProviderDescriptor
    private let snapshot: ProviderSnapshot
    private var fetches = 0

    init(snapshot: ProviderSnapshot) {
        self.descriptor = snapshot.descriptor
        self.snapshot = snapshot
    }

    func fetchUsage() async -> ProviderSnapshot {
        self.fetches += 1
        return self.snapshot
    }

    func fetchCount() -> Int {
        self.fetches
    }
}
