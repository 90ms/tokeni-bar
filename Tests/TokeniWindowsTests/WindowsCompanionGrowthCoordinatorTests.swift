import Foundation
import Testing
import TokeniCore
import TokeniWindows

struct WindowsCompanionGrowthCoordinatorTests {
    @Test
    func failedHatchSavePreservesEggAndSuccessfulRetryPersistsIt() async throws {
        let harness = GrowthHarness(award: GrowthEnergyAward(dateKey: "2026-09-05", energy: 0, createdAt: .now), failNextSave: true)
        let coordinator = Self.coordinator(harness: harness)
        let initial = try await coordinator.load()
        await #expect(throws: GrowthHarness.Failure.save) {
            try await coordinator.openNextEgg()
        }
        #expect(await coordinator.currentState() == initial)
        try await coordinator.openNextEgg()
        let hatched = await coordinator.currentState()
        #expect(hatched?.eggs.count == initial.eggs.count - 1)
        #expect(hatched?.stage != .egg)
        #expect(await harness.saveCount() == 1)
        #expect(await harness.load() == hatched)
    }

    @Test
    func savesCompanionBeforeRemovingAwardFromLedger() async throws {
        let award = GrowthEnergyAward(
            id: UUID(uuidString: "F0AFAF1D-3685-46DA-A9C5-7E4494EEFCF1")!,
            dateKey: "2026-08-21",
            energy: 7,
            createdAt: Date(timeIntervalSince1970: 1_777_000_000))
        let harness = GrowthHarness(award: award)
        let coordinator = Self.coordinator(harness: harness)

        _ = try await coordinator.load()
        let state = try await coordinator.applyPendingAwards()

        #expect(state.growthEnergy == 7)
        #expect(state.appliedGrowthAwardIDs == [award.id])
        #expect(await harness.events() == [.saved, .marked])
        #expect(await harness.pendingAwardIDs().isEmpty)
    }

    @Test
    func tokenOnlyAwardsRemainDurableWithoutAddingGrowthEnergy() async throws {
        let award = GrowthEnergyAward(
            id: UUID(uuidString: "F46CD794-B70F-4239-B71B-B4BA069308E3")!,
            dateKey: "2026-08-21",
            energy: 0,
            verifiedTokens: 100_000,
            createdAt: Date(timeIntervalSince1970: 1_777_000_050))
        let harness = GrowthHarness(award: award)
        let coordinator = Self.coordinator(harness: harness)

        _ = try await coordinator.load()
        let state = try await coordinator.applyPendingAwards()

        #expect(state.growthEnergy == 0)
        #expect(state.appliedGrowthAwardIDs == [award.id])
        #expect(await harness.events() == [.saved, .marked])
        #expect(await harness.pendingAwardIDs().isEmpty)
    }

    @Test
    func failedSaveLeavesAwardPendingAndDoesNotChangeCurrentState() async throws {
        let award = GrowthEnergyAward(
            id: UUID(uuidString: "7D205948-41EE-429E-BCAC-129D939E862B")!,
            dateKey: "2026-08-21",
            energy: 11,
            createdAt: Date(timeIntervalSince1970: 1_777_000_100))
        let harness = GrowthHarness(award: award, failNextSave: true)
        let coordinator = Self.coordinator(harness: harness)

        _ = try await coordinator.load()
        await #expect(throws: GrowthHarness.Failure.save) {
            try await coordinator.applyPendingAwards()
        }

        #expect(await coordinator.currentState()?.growthEnergy == 0)
        #expect(await harness.events().isEmpty)
        #expect(await harness.pendingAwardIDs() == [award.id])

        let retried = try await coordinator.applyPendingAwards()
        #expect(retried.growthEnergy == 11)
        #expect(await harness.events() == [.saved, .marked])
    }

    @Test
    func failedLedgerWriteRetriesWithoutApplyingEnergyTwice() async throws {
        let award = GrowthEnergyAward(
            id: UUID(uuidString: "66DA44D9-810F-4057-BE08-3EC43D39FE17")!,
            dateKey: "2026-08-21",
            energy: 13,
            createdAt: Date(timeIntervalSince1970: 1_777_000_200))
        let harness = GrowthHarness(award: award, failNextMark: true)
        let coordinator = Self.coordinator(harness: harness)

        _ = try await coordinator.load()
        await #expect(throws: GrowthHarness.Failure.mark) {
            try await coordinator.applyPendingAwards()
        }

        #expect(await coordinator.currentState()?.growthEnergy == 13)
        #expect(await harness.events() == [.saved])
        #expect(await harness.pendingAwardIDs() == [award.id])

        let retried = try await coordinator.applyPendingAwards()
        #expect(retried.growthEnergy == 13)
        #expect(retried.appliedGrowthAwardIDs == [award.id])
        #expect(await harness.events() == [.saved, .marked])
        #expect(await harness.saveCount() == 1)
    }

    @Test
    func processesOneRefreshOnceRegardlessOfOverlayVisibility() async throws {
        let award = GrowthEnergyAward(
            dateKey: "2026-08-21",
            energy: 3,
            createdAt: Date(timeIntervalSince1970: 1_777_000_300))
        let harness = GrowthHarness(award: award)
        let coordinator = Self.coordinator(harness: harness)
        let refreshDate = Date(timeIntervalSince1970: 1_777_000_400)

        _ = try await coordinator.load()
        _ = try await coordinator.synchronize(afterRefreshAt: refreshDate)
        _ = try await coordinator.synchronize(afterRefreshAt: refreshDate)

        #expect(await harness.processCount() == 1)
        #expect(await harness.saveCount() == 1)
    }

    private static func coordinator(
        harness: GrowthHarness) -> WindowsCompanionGrowthCoordinator
    {
        WindowsCompanionGrowthCoordinator(
            loadState: { await harness.load() },
            saveState: { state, revision in
                try await harness.save(state, revision: revision)
            },
            processGrowth: { _ in await harness.process() },
            loadLedger: { await harness.ledger() },
            markAwardApplied: { awardID in
                try await harness.mark(awardID)
            })
    }
}

private actor GrowthHarness {
    enum Event: Equatable, Sendable {
        case saved
        case marked
    }

    enum Failure: Error, Equatable {
        case save
        case mark
    }

    private var state = CompanionGameState()
    private var ledgerState: TokenGrowthLedgerState
    private var recordedEvents: [Event] = []
    private var shouldFailNextSave: Bool
    private var shouldFailNextMark: Bool
    private var recordedSaveCount = 0
    private var recordedProcessCount = 0

    init(
        award: GrowthEnergyAward,
        failNextSave: Bool = false,
        failNextMark: Bool = false)
    {
        self.ledgerState = TokenGrowthLedgerState(pendingAwards: [award])
        self.shouldFailNextSave = failNextSave
        self.shouldFailNextMark = failNextMark
    }

    func load() -> CompanionGameState {
        self.state
    }

    func save(_ state: CompanionGameState, revision: UInt64) throws {
        _ = revision
        if self.shouldFailNextSave {
            self.shouldFailNextSave = false
            throw Failure.save
        }
        self.state = state
        self.recordedSaveCount += 1
        self.recordedEvents.append(.saved)
    }

    func process() {
        self.recordedProcessCount += 1
    }

    func ledger() -> TokenGrowthLedgerState {
        self.ledgerState
    }

    func mark(_ awardID: GrowthEnergyAward.ID) throws {
        if self.shouldFailNextMark {
            self.shouldFailNextMark = false
            throw Failure.mark
        }
        self.ledgerState.pendingAwards.removeAll { $0.id == awardID }
        self.recordedEvents.append(.marked)
    }

    func events() -> [Event] {
        self.recordedEvents
    }

    func pendingAwardIDs() -> [GrowthEnergyAward.ID] {
        self.ledgerState.pendingAwards.map(\.id)
    }

    func saveCount() -> Int {
        self.recordedSaveCount
    }

    func processCount() -> Int {
        self.recordedProcessCount
    }
}
