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
    func externalRuntimeRefreshRunsBeforeQueuedSessionRefresh() async {
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
        let runtime = Self.runtime(
            providers: providers,
            historyStore: historyStore,
            growthStore: TokenGrowthLedgerStore(
                fileURL: directory.appending(path: "growth.json")))
        let session = UsageApplicationSession(
            providers: providers,
            runtime: runtime,
            enabledProviderIDs: [.claude])

        let externalRefresh = Task {
            await runtime.refresh(
                enabledProviderIDs: [.codex],
                now: oldDate)
        }
        let oldStarted = await Self.waitForFetchStart(oldProvider)
        if !oldStarted {
            await oldProvider.complete()
            await newProvider.complete()
        }

        let sessionRefresh = Task {
            await session.refresh(
                forceProviderReload: true,
                now: newDate)
        }
        let sessionQueued = await Self.waitForQueuedOperationCount(
            1,
            in: runtime)

        await oldProvider.complete()
        let externalState = await externalRefresh.value
        let newStarted = await Self.waitForFetchStart(newProvider)
        #expect(externalState.snapshots == [oldSnapshot])
        #expect(externalState.lastRefresh == oldDate)
        #expect(externalState.historyRecords.isEmpty)

        await newProvider.complete()
        await sessionRefresh.value

        let runtimeState = await runtime.state()
        let sessionState = await session.state()
        let persistedHistory = try? await historyStore.records()
        #expect(oldStarted)
        #expect(sessionQueued)
        #expect(newStarted)
        #expect(runtimeState.snapshots == [newSnapshot])
        #expect(runtimeState.lastRefresh == newDate)
        #expect(runtimeState.historyRecords.map(\.providerID) == [.claude])
        #expect(sessionState.applicationState == runtimeState)
        #expect(sessionState.enabledProviderIDs == [.claude])
        #expect(persistedHistory?.map(\.providerID) == [.claude])
        #expect(!sessionState.isRefreshing)
    }

    @Test
    func cancellingQueuedRefreshPreservesActiveRefreshResult() async {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let activeSnapshot = Self.snapshot(
            id: .codex,
            tokenTotal: 12,
            updatedAt: Self.fixedDate)
        let queuedSnapshot = Self.snapshot(
            id: .claude,
            tokenTotal: 34,
            updatedAt: Self.fixedDate.addingTimeInterval(60))
        let activeProvider = DelayedProvider(snapshot: activeSnapshot)
        let queuedProvider = CountingProvider(snapshot: queuedSnapshot)
        let providers: [any UsageProviding] = [
            activeProvider,
            queuedProvider,
        ]
        let runtime = Self.runtime(
            providers: providers,
            historyStore: UsageHistoryStore(
                fileURL: directory.appending(path: "history.json"),
                minimumRecordInterval: 0),
            growthStore: TokenGrowthLedgerStore(
                fileURL: directory.appending(path: "growth.json")))

        let activeRefresh = Task {
            await runtime.refresh(
                enabledProviderIDs: [.codex],
                now: Self.fixedDate)
        }
        let activeStarted = await Self.waitForFetchStart(activeProvider)
        if !activeStarted {
            await activeProvider.complete()
        }
        let queuedRefresh = Task {
            await runtime.refresh(
                enabledProviderIDs: [.claude],
                now: Self.fixedDate.addingTimeInterval(60))
        }
        let queued = await Self.waitForQueuedOperationCount(1, in: runtime)

        queuedRefresh.cancel()
        let cancelledState = await queuedRefresh.value
        #expect(cancelledState.snapshots.isEmpty)
        #expect(await queuedProvider.fetchCount() == 0)

        await activeProvider.complete()
        let activeState = await activeRefresh.value
        let finalState = await runtime.state()
        #expect(activeStarted)
        #expect(queued)
        #expect(activeState.snapshots == [activeSnapshot])
        #expect(finalState == activeState)
        #expect(await queuedProvider.fetchCount() == 0)
    }

    @Test
    func newerSessionRefreshQueuesWhileHistoryWriteIsInFlight() async {
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
        let oldSession = UsageApplicationSession(
            providers: providers,
            runtime: runtime,
            enabledProviderIDs: [.codex])
        let newSession = UsageApplicationSession(
            providers: providers,
            runtime: runtime,
            enabledProviderIDs: [.claude])

        let oldRefresh = Task {
            await oldSession.refresh(now: oldDate)
        }
        let historyStarted = await Self.waitForSignal {
            await history.waitUntilFirstRecordStarts()
        }

        let newRefresh = Task {
            await newSession.refresh(now: newDate)
        }
        let newerQueued = await Self.waitForQueuedOperationCount(
            1,
            in: runtime)

        await history.releaseFirstRecord()
        await oldRefresh.value
        await newRefresh.value

        let state = await runtime.state()
        let persistedHistory = await history.persistedRecords()
        let oldSessionState = await oldSession.state()
        let newSessionState = await newSession.state()
        #expect(historyStarted)
        #expect(newerQueued)
        #expect(state.snapshots == [newSnapshot])
        #expect(state.lastRefresh == newDate)
        #expect(state.historyRecords.map(\.providerID) == [
            .codex,
            .claude,
        ])
        #expect(persistedHistory.map(\.providerID) == [.codex, .claude])
        #expect(!oldSessionState.isRefreshing)
        #expect(!newSessionState.isRefreshing)
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
        await Self.waitForSignal {
            await provider.waitUntilFetchStarts()
        }
    }

    private static func waitForQueuedOperationCount(
        _ count: Int,
        in runtime: UsageApplicationRuntime) async -> Bool
    {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while clock.now < deadline {
            if await runtime.queuedOperationCount() == count {
                return true
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return false
    }

    private static func waitForSignal(
        _ operation: @escaping @Sendable () async -> Void) async -> Bool
    {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await operation()
                return true
            }
            group.addTask {
                do {
                    try await Task.sleep(for: .seconds(2))
                    return false
                } catch {
                    return false
                }
            }
            let signalled = await group.next() ?? false
            group.cancelAll()
            return signalled
        }
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
    private let gate = AsyncTestGate()

    init(snapshot: ProviderSnapshot) {
        self.descriptor = snapshot.descriptor
        self.snapshot = snapshot
    }

    func fetchUsage() async -> ProviderSnapshot {
        await self.gate.enterAndWait()
        return self.snapshot
    }

    func waitUntilFetchStarts() async {
        await self.gate.waitUntilEntered()
    }

    func complete() async {
        await self.gate.release()
    }
}

private actor ControlledHistoryCoordinator: UsageHistoryCoordinating {
    private var records: [UsageHistoryRecord] = []
    private var recordCount = 0
    private let firstRecordGate = AsyncTestGate()

    func load() async throws -> [UsageHistoryRecord] {
        self.records
    }

    func record(
        _ snapshots: [ProviderSnapshot],
        at timestamp: Date) async throws -> [UsageHistoryRecord]
    {
        self.recordCount += 1
        if self.recordCount == 1 {
            await self.firstRecordGate.enterAndWait()
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

    func waitUntilFirstRecordStarts() async {
        await self.firstRecordGate.waitUntilEntered()
    }

    func releaseFirstRecord() async {
        await self.firstRecordGate.release()
    }

    func persistedRecords() -> [UsageHistoryRecord] {
        self.records
    }
}

private actor AsyncTestGate {
    private var entered = false
    private var released = false
    private var entryWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var releaseWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    func enterAndWait() async {
        if !self.entered {
            self.entered = true
            let waiters = Array(self.entryWaiters.values)
            self.entryWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
        guard !self.released, !Task.isCancelled else { return }

        let waiterID = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if self.released || Task.isCancelled {
                    continuation.resume()
                } else {
                    self.releaseWaiters[waiterID] = continuation
                }
            }
        } onCancel: {
            Task { await self.cancelReleaseWaiter(waiterID) }
        }
    }

    func waitUntilEntered() async {
        guard !self.entered, !Task.isCancelled else { return }

        let waiterID = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if self.entered || Task.isCancelled {
                    continuation.resume()
                } else {
                    self.entryWaiters[waiterID] = continuation
                }
            }
        } onCancel: {
            Task { await self.cancelEntryWaiter(waiterID) }
        }
    }

    func release() {
        guard !self.released else { return }
        self.released = true
        let waiters = Array(self.releaseWaiters.values)
        self.releaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func cancelEntryWaiter(_ waiterID: UUID) {
        guard let waiter = self.entryWaiters.removeValue(forKey: waiterID) else {
            return
        }
        waiter.resume()
    }

    private func cancelReleaseWaiter(_ waiterID: UUID) {
        guard let waiter = self.releaseWaiters.removeValue(forKey: waiterID) else {
            return
        }
        waiter.resume()
    }
}
