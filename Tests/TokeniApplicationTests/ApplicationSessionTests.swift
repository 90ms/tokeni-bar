@testable import TokeniApplication
import Foundation
import Testing
import TokeniCore

struct ApplicationSessionTests {
    @Test
    func defaultsToEveryKnownProviderWhenPersistedSelectionIsMissing() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = JSONFileSettingsStore(
            fileURL: directory.appending(path: "settings.json"))
        let providers = Self.preferenceProviders()
        let session = UsageApplicationSession(
            providers: providers,
            providerPreferences: ProviderPreferenceCoordinator(
                settings: settings))

        let state = await session.state()

        #expect(state.enabledProviderIDs == [.codex, .claude])
        #expect(!settings.containsValue(forKey: "enabledProviderIDs"))
    }

    @Test
    func restoresPersistedProviderSelectionAndFiltersUnknownProviders() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = JSONFileSettingsStore(
            fileURL: directory.appending(path: "settings.json"))
        settings.set(
            [ProviderID.codex.rawValue, "removed-provider"],
            forKey: "enabledProviderIDs")
        let session = UsageApplicationSession(
            providers: Self.preferenceProviders(),
            providerPreferences: ProviderPreferenceCoordinator(
                settings: settings))

        let state = await session.state()

        #expect(state.enabledProviderIDs == [.codex])
    }

    @Test
    func explicitSelectionWinsAndSettersPersistTheCurrentSessionState() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "settings.json")
        let settings = JSONFileSettingsStore(fileURL: fileURL)
        settings.set(
            [ProviderID.claude.rawValue],
            forKey: "enabledProviderIDs")
        let providers = Self.preferenceProviders()
        let session = UsageApplicationSession(
            providers: providers,
            enabledProviderIDs: [.codex],
            providerPreferences: ProviderPreferenceCoordinator(
                settings: settings))

        await session.setEnabled(false, for: .codex)
        var state = await session.state()
        #expect(state.enabledProviderIDs.isEmpty)
        #expect(settings.stringArray(forKey: "enabledProviderIDs")?.isEmpty == true)

        await session.setEnabled(true, for: .claude)
        state = await session.state()
        #expect(state.enabledProviderIDs == [.claude])

        let reloaded = UsageApplicationSession(
            providers: providers,
            providerPreferences: ProviderPreferenceCoordinator(
                settings: JSONFileSettingsStore(fileURL: fileURL)))
        #expect((await reloaded.state()).enabledProviderIDs == [.claude])
    }

    @Test
    func setEnabledProviderIDsFiltersAndPersistsDeterministically() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = JSONFileSettingsStore(
            fileURL: directory.appending(path: "settings.json"))
        let session = UsageApplicationSession(
            providers: Self.preferenceProviders(),
            providerPreferences: ProviderPreferenceCoordinator(
                settings: settings))

        await session.setEnabledProviderIDs([
            .codex,
            .claude,
            ProviderID(rawValue: "removed-provider"),
        ])

        let state = await session.state()
        #expect(state.enabledProviderIDs == [.codex, .claude])
        #expect(settings.stringArray(forKey: "enabledProviderIDs") == [
            ProviderID.claude.rawValue,
            ProviderID.codex.rawValue,
        ])
    }

    @Test
    func persistsAndRestoresAllProvidersDisabledWithoutFetching() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let settingsURL = directory.appending(path: "settings.json")
        let settings = JSONFileSettingsStore(fileURL: settingsURL)
        let codex = CountingProvider(snapshot: Self.snapshot(
            id: .codex,
            updatedAt: Self.fixedDate))
        let claude = CountingProvider(snapshot: Self.snapshot(
            id: .claude,
            updatedAt: Self.fixedDate))
        let providers: [any UsageProviding] = [codex, claude]
        let session = UsageApplicationSession(
            providers: providers,
            runtime: Self.runtime(
                providers: providers,
                historyStore: UsageHistoryStore(
                    fileURL: directory.appending(path: "history.json"),
                    minimumRecordInterval: 0),
                growthStore: TokenGrowthLedgerStore(
                    fileURL: directory.appending(path: "growth.json"))),
            providerPreferences: ProviderPreferenceCoordinator(
                settings: settings))

        await session.setEnabledProviderIDs([])
        await session.refresh(
            forceProviderReload: true,
            now: Self.fixedDate)

        var state = await session.state()
        #expect(state.enabledProviderIDs.isEmpty)
        #expect(state.applicationState.snapshots.isEmpty)
        #expect(settings.stringArray(forKey: "enabledProviderIDs")?.isEmpty == true)
        #expect(await codex.fetchCount() == 0)
        #expect(await claude.fetchCount() == 0)

        let restored = UsageApplicationSession(
            providers: providers,
            runtime: Self.runtime(
                providers: providers,
                historyStore: UsageHistoryStore(
                    fileURL: directory.appending(path: "restored-history.json"),
                    minimumRecordInterval: 0),
                growthStore: TokenGrowthLedgerStore(
                    fileURL: directory.appending(path: "restored-growth.json"))),
            providerPreferences: ProviderPreferenceCoordinator(
                settings: JSONFileSettingsStore(fileURL: settingsURL)))

        state = await restored.state()
        #expect(state.enabledProviderIDs.isEmpty)

        await restored.refresh(
            forceProviderReload: true,
            now: Self.fixedDate.addingTimeInterval(1))

        state = await restored.state()
        #expect(state.applicationState.snapshots.isEmpty)
        #expect(await codex.fetchCount() == 0)
        #expect(await claude.fetchCount() == 0)
    }

    @Test
    func ignoresUnknownProviderToggleWithoutChangingStateOrPreferences() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = JSONFileSettingsStore(
            fileURL: directory.appending(path: "settings.json"))
        settings.set(
            [ProviderID.codex.rawValue],
            forKey: "enabledProviderIDs")
        let session = UsageApplicationSession(
            providers: Self.preferenceProviders(),
            providerPreferences: ProviderPreferenceCoordinator(
                settings: settings))
        let unknownProvider = ProviderID(rawValue: "removed-provider")
        let stateBefore = await session.state()
        let storedBefore = settings.stringArray(forKey: "enabledProviderIDs")

        await session.setEnabled(true, for: unknownProvider)
        await session.setEnabled(false, for: unknownProvider)

        let stateAfter = await session.state()
        #expect(stateAfter == stateBefore)
        #expect(settings.stringArray(forKey: "enabledProviderIDs") == storedBefore)
    }

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
    func queuedNewerRefreshPreventsOlderCommitAndHistoryWrite() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let oldDate = Self.fixedDate
        let newDate = oldDate.addingTimeInterval(60)
        let oldSnapshot = Self.snapshot(
            id: .codex,
            tokenTotal: 12,
            updatedAt: oldDate)
        let newSnapshot = Self.snapshot(
            id: .claude,
            tokenTotal: 34,
            updatedAt: newDate)
        let oldProvider = DelayedProvider(snapshot: oldSnapshot)
        let newProvider = DelayedProvider(snapshot: newSnapshot)
        let providers: [any UsageProviding] = [
            oldProvider,
            newProvider,
        ]
        let historyStore = UsageHistoryStore(
            fileURL: directory.appending(path: "history.json"),
            minimumRecordInterval: 0)
        let session = UsageApplicationSession(
            providers: providers,
            runtime: Self.runtime(
                providers: providers,
                historyStore: historyStore,
                growthStore: TokenGrowthLedgerStore(
                    fileURL: directory.appending(path: "growth.json"))),
            enabledProviderIDs: [.codex])

        let oldRefresh = Task {
            await session.refresh(now: oldDate)
        }
        let oldStarted = await Self.waitForFetchStart(oldProvider)

        await session.setEnabledProviderIDs([.claude])
        let newRefresh = Task {
            await session.refresh(
                forceProviderReload: true,
                now: newDate)
        }
        let newerQueued = await Self.waitForRefreshOperationCount(
            2,
            in: session)

        await oldProvider.complete()
        await oldRefresh.value
        let newStarted = await Self.waitForFetchStart(newProvider)

        let stateAfterOldRefresh = await session.state()
        let historyAfterOldRefresh = try? await historyStore.records()
        #expect(stateAfterOldRefresh.applicationState.snapshots.isEmpty)
        #expect(stateAfterOldRefresh.applicationState.lastRefresh == nil)
        #expect(historyAfterOldRefresh?.isEmpty == true)

        await newProvider.complete()
        await newRefresh.value

        let state = await session.state()
        let persistedHistory = try? await historyStore.records()
        #expect(oldStarted)
        #expect(newerQueued)
        #expect(newStarted)
        #expect(state.enabledProviderIDs == [.claude])
        #expect(state.applicationState.snapshots == [newSnapshot])
        #expect(state.applicationState.lastRefresh == newDate)
        #expect(state.applicationState.historyRecords.map(\.providerID) == [
            .claude,
        ])
        #expect(persistedHistory?.map(\.providerID) == [.claude])
        #expect(!state.isRefreshing)
    }

    @Test
    func refreshArrivingDuringHistoryWriteRunsAfterThatWrite() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let oldDate = Self.fixedDate
        let newDate = oldDate.addingTimeInterval(60)
        let oldSnapshot = Self.snapshot(
            id: .codex,
            tokenTotal: 12,
            updatedAt: oldDate)
        let newSnapshot = Self.snapshot(
            id: .claude,
            tokenTotal: 34,
            updatedAt: newDate)
        let history = ControlledHistoryCoordinator()
        let providers: [any UsageProviding] = [
            TestProvider(snapshot: oldSnapshot),
            TestProvider(snapshot: newSnapshot),
        ]
        let runtime = UsageApplicationRuntime(
            providers: providers,
            historyCoordinator: history,
            growthLedgerCoordinator: TokenGrowthLedgerCoordinator(
                store: TokenGrowthLedgerStore(
                    fileURL: directory.appending(path: "growth.json")),
                engine: Self.growthEngine))
        let session = UsageApplicationSession(
            providers: providers,
            runtime: runtime,
            enabledProviderIDs: [.codex])

        let oldRefresh = Task {
            await session.refresh(now: oldDate)
        }
        let historyStarted = await Self.waitForHistoryStart(history)

        await session.setEnabledProviderIDs([.claude])
        let newRefresh = Task {
            await session.refresh(now: newDate)
        }
        let newerQueued = await Self.waitForRefreshOperationCount(
            2,
            in: session)

        await history.completeFirstRecord()
        await oldRefresh.value
        await newRefresh.value

        let state = await session.state()
        let persistedHistory = await history.persistedRecords()
        #expect(historyStarted)
        #expect(newerQueued)
        #expect(state.applicationState.snapshots == [newSnapshot])
        #expect(state.applicationState.lastRefresh == newDate)
        #expect(state.applicationState.historyRecords.map(\.providerID) == [
            .codex,
            .claude,
        ])
        #expect(persistedHistory.map(\.providerID) == [.codex, .claude])
        #expect(!state.isRefreshing)
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

    private static func preferenceProviders() -> [any UsageProviding] {
        [
            TestProvider(snapshot: Self.snapshot(
                id: .codex,
                updatedAt: Self.fixedDate)),
            TestProvider(snapshot: Self.snapshot(
                id: .claude,
                updatedAt: Self.fixedDate)),
        ]
    }

    private static func waitForFetchStart(
        _ provider: DelayedProvider) async -> Bool
    {
        for _ in 0..<1_000 {
            if await provider.hasFetchStarted() { return true }
            await Task.yield()
        }
        return false
    }

    private static func waitForHistoryStart(
        _ history: ControlledHistoryCoordinator) async -> Bool
    {
        for _ in 0..<1_000 {
            if await history.hasRecordStarted() { return true }
            await Task.yield()
        }
        return false
    }

    private static func waitForRefreshOperationCount(
        _ count: Int,
        in session: UsageApplicationSession) async -> Bool
    {
        for _ in 0..<1_000 {
            if await session.activeRefreshOperationCount() == count {
                return true
            }
            await Task.yield()
        }
        return false
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

private actor DelayedProvider: UsageProviding {
    nonisolated let descriptor: ProviderDescriptor
    private let snapshot: ProviderSnapshot
    private var didStart = false
    private var isCompleted = false
    private var fetchContinuation: CheckedContinuation<ProviderSnapshot, Never>?

    init(snapshot: ProviderSnapshot) {
        self.descriptor = snapshot.descriptor
        self.snapshot = snapshot
    }

    func fetchUsage() async -> ProviderSnapshot {
        self.didStart = true
        guard !self.isCompleted else { return self.snapshot }
        return await withCheckedContinuation { continuation in
            self.fetchContinuation = continuation
        }
    }

    func hasFetchStarted() -> Bool {
        self.didStart
    }

    func complete() {
        guard !self.isCompleted else { return }
        self.isCompleted = true
        guard let continuation = self.fetchContinuation else { return }
        self.fetchContinuation = nil
        continuation.resume(returning: self.snapshot)
    }
}

private actor ControlledHistoryCoordinator: UsageHistoryCoordinating {
    private var records: [UsageHistoryRecord] = []
    private var recordCount = 0
    private var firstRecordReleased = false
    private var firstRecordContinuation: CheckedContinuation<Void, Never>?

    func load() async throws -> [UsageHistoryRecord] {
        self.records
    }

    func record(
        _ snapshots: [ProviderSnapshot],
        at timestamp: Date) async throws -> [UsageHistoryRecord]
    {
        self.recordCount += 1
        if self.recordCount == 1, !self.firstRecordReleased {
            await withCheckedContinuation { continuation in
                self.firstRecordContinuation = continuation
            }
        }
        for snapshot in snapshots where snapshot.availability == .available {
            self.records.append(UsageHistoryRecord(
                timestamp: timestamp,
                providerID: snapshot.id,
                providerName: snapshot.descriptor.displayName,
                windows: snapshot.quotaWindows.map {
                    UsageHistoryRecord.WindowSample(
                        id: $0.id,
                        label: $0.label,
                        remainingPercent: $0.remainingPercent)
                },
                tokenTotal: snapshot.tokenUsage?.totalTokens,
                costUSD: snapshot.costEstimate?.amountUSD))
        }
        return self.records
    }

    func clear() async throws -> [UsageHistoryRecord] {
        self.records = []
        return self.records
    }

    func hasRecordStarted() -> Bool {
        self.recordCount > 0
    }

    func completeFirstRecord() {
        guard !self.firstRecordReleased else { return }
        self.firstRecordReleased = true
        guard let continuation = self.firstRecordContinuation else { return }
        self.firstRecordContinuation = nil
        continuation.resume()
    }

    func persistedRecords() -> [UsageHistoryRecord] {
        self.records
    }
}
