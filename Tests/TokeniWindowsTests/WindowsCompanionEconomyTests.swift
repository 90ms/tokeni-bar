import Foundation
import Testing
import TokeniCore
import TokeniWindows

struct WindowsCompanionEconomyTests {
    @Test func persistedGrowthAwardRecoversItsRewardWithoutPayingTwice() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let rewards = CompanionRewardStateStore(fileURL: directory.appending(path: "reward.json"))
        let award = GrowthEnergyAward(dateKey: "2026-09-05", energy: 7, createdAt: .now)
        let persisted = CompanionGameState(growthEnergy: 7, appliedGrowthAwardIDs: [award.id])
        let coordinator = WindowsCompanionGrowthCoordinator(loadState: { persisted }, saveState: { _, _ in },
            processGrowth: { _ in }, loadLedger: { TokenGrowthLedgerState(pendingAwards: [award]) }, markAwardApplied: { _ in }, rewardStore: rewards)
        _ = try await coordinator.load()
        _ = try await coordinator.applyPendingAwards()
        #expect(await coordinator.currentRewards()?.starShards == CompanionRewardRules.standard.dailyVerifiedGrowth)
        _ = try await coordinator.applyPendingAwards()
        #expect(await coordinator.currentRewards()?.starShards == CompanionRewardRules.standard.dailyVerifiedGrowth)
        #expect(await coordinator.currentState()?.growthEnergy == 7)
    }

    @Test func purchaseRecoveryChargesOnceAndRestoresTheSameEgg() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateStore = CompanionGameStateStore(fileURL: directory.appending(path: "pet.json"))
        let rewardStore = CompanionRewardStateStore(fileURL: directory.appending(path: "reward.json"))
        let journal = CompanionEconomyTransactionStore(fileURL: directory.appending(path: "journal.json"))
        var state = CompanionGameState()
        let transaction = CompanionEconomyTransaction(kind: .purchaseEgg(definitionID: .mystery, seed: 42, price: 90))
        // Simulate a crash between the companion save and the reward save.
        _ = try CompanionGameEngine().acquireEgg(definitionID: .mystery, seed: 42, source: .shop,
            transactionID: transaction.id, at: transaction.createdAt, in: &state)
        try await stateStore.save(state)
        try await rewardStore.save(CompanionRewardState(starShards: 300))
        try await journal.begin(transaction)
        let coordinator = WindowsCompanionGrowthCoordinator(loadState: { try await stateStore.load() },
            saveState: { state, revision in try await stateStore.save(state, revision: revision) },
            processGrowth: { _ in }, loadLedger: { TokenGrowthLedgerState() }, markAwardApplied: { _ in },
            rewardStore: rewardStore, journalStore: journal)
        let recovered = try await coordinator.load()
        #expect(recovered.eggs.count == state.eggs.count)
        #expect(await coordinator.currentRewards()?.starShards == 210)
        #expect(try await journal.load().pending.isEmpty)
        _ = try await coordinator.load()
        #expect(await coordinator.currentRewards()?.starShards == 210)
    }

    @Test func attendanceCannotBeClaimedTwiceAndNamesPersist() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CompanionGameStateStore(fileURL: directory.appending(path: "pet.json"))
        let rewards = CompanionRewardStateStore(fileURL: directory.appending(path: "reward.json"))
        let coordinator = WindowsCompanionGrowthCoordinator(loadState: { try await store.load() },
            saveState: { state, revision in try await store.save(state, revision: revision) },
            processGrowth: { _ in }, loadLedger: { TokenGrowthLedgerState() }, markAwardApplied: { _ in }, rewardStore: rewards)
        let initial = try await coordinator.load()
        try await coordinator.perform(.checkIn)
        let balance = await coordinator.currentRewards()?.starShards
        await #expect(throws: CompanionRewardError.alreadyClaimed) { try await coordinator.perform(.checkIn) }
        #expect(await coordinator.currentRewards()?.starShards == balance)
        await #expect(throws: WindowsCompanionGrowthError.invalidState) {
            try await coordinator.perform(.rename(initial.generationID, "Eggs cannot have nicknames"))
        }
        try await coordinator.openNextEgg()
        let hatched = try #require(await coordinator.currentState())
        try await coordinator.perform(.rename(hatched.generationID, "  작은 친구  "))
        #expect(try await store.load().nickname == "작은 친구")
    }
}
