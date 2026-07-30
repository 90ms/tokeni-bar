import Foundation
import Testing
@testable import TokeniCore

@Suite("Companion asset reset migration")
struct CompanionAssetResetMigrationTests {
    @Test("Quote refunds owned pets and cosmetics at registered value")
    func quote() {
        let completed = CompanionCollection(totalCompletedGenerations: 3)
        let companion = CompanionGameState(
            speciesID: .bytebot,
            stage: .junior,
            rarity: .rare,
            variantID: .legacyAzure,
            personalityID: .calm,
            growthEnergy: 250,
            migrationEnergyReserve: 100,
            collection: completed)
        let rewards = CompanionRewardState(
            starShards: 80,
            unlockedCosmeticIDs: [.sparkleAura, .starCrown])

        let quote = CompanionAssetResetEngine().quote(
            companion: companion,
            rewards: rewards)

        #expect(quote.currentPetEnergyRefund == 1_300)
        #expect(quote.completedPetCount == 3)
        #expect(quote.completedPetEnergyRefund == 8_100)
        #expect(quote.collectionDiscoveryCount == 0)
        #expect(quote.existingAvailableGrowthEnergy == 350)
        #expect(quote.petEnergyRefund == 9_400)
        #expect(quote.cosmeticStarShardRefund == 180)
        #expect(
            quote.cosmeticRefunds.map(\.cosmeticID)
                == [.sparkleAura, .starCrown])
        #expect(quote.resultingGrowthEnergy == 9_750)
        #expect(quote.resultingStarShards == 260)
        #expect(quote.requiresConfirmation)
    }

    @Test("Prepared reset preserves balances and private accounting")
    func preparedTargets() throws {
        let awardID = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let collection = CompanionCollection(totalCompletedGenerations: 1)
        let companion = CompanionGameState(
            speciesID: .cachecat,
            stage: .adult,
            rarity: .legendary,
            variantID: .prismatic,
            nickname: "Moka",
            personalityID: .curious,
            growthEnergy: 900,
            growthDateKey: "2027-01-15",
            growthEarnedToday: 20,
            growthCarriedToday: 880,
            collection: collection,
            appliedGrowthAwardIDs: [awardID])
        let rewards = CompanionRewardState(
            starShards: 40,
            attendanceRecords: [
                CompanionAttendanceRecord(
                    dateKey: "2027-01-15",
                    weekKey: "2027-W03",
                    monthKey: "2027-01",
                    claimedAt: date),
            ],
            rewardedSpeciesIDs: [.cachecat],
            unlockedCosmeticIDs: [.nightRing],
            selectedCosmeticIDs: [.nightRing],
            latestObservedDateKey: "2027-01-15")

        let journal = CompanionAssetResetEngine().prepare(
            companion: companion,
            rewards: rewards,
            benefits: CompanionBenefitState(),
            at: date)
        let target = journal.targetCompanionState
        let targetRewards = journal.targetRewardState

        #expect(journal.status == .prepared)
        #expect(target.stage == .egg)
        #expect(target.collection.totalCompletedGenerations == 0)
        #expect(target.growthEnergy == 900)
        #expect(target.migrationEnergyReserve == 5_400)
        #expect(target.availableGrowthEnergy == 6_300)
        #expect(target.appliedGrowthAwardIDs == [awardID])
        #expect(targetRewards.starShards == 240)
        #expect(targetRewards.unlockedCosmeticIDs.isEmpty)
        #expect(targetRewards.selectedCosmeticIDs.isEmpty)
        #expect(targetRewards.rewardedSpeciesIDs.isEmpty)
        #expect(targetRewards.attendanceRecords.count == 1)
        #expect(target.isValid())
        #expect(targetRewards.isValid())
    }

    @Test("Migration journal round-trips as a recovery backup")
    func journalPersistence() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-migrations.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let engine = CompanionAssetResetEngine()
        let journal = engine.prepare(
            companion: CompanionGameState(),
            rewards: CompanionRewardState(),
            benefits: CompanionBenefitState())
        let store = CompanionAssetResetStore(fileURL: file)

        try await store.save(journal)
        let loaded = try await store.load(migrationID: journal.migrationID)
        let restored = try #require(loaded)

        #expect(restored == journal)
        #expect(restored.sourceCompanionState == journal.sourceCompanionState)
        #expect(restored.targetCompanionState == journal.targetCompanionState)

        let futureID = CompanionMigrationID(rawValue: "future-reset")
        let future = CompanionAssetResetEngine(migrationID: futureID).prepare(
            companion: CompanionGameState(),
            rewards: CompanionRewardState(),
            benefits: CompanionBenefitState())
        try await store.save(future)
        let originalReloaded = try await store.load(
            migrationID: journal.migrationID)
        let futureReloaded = try await store.load(migrationID: futureID)

        #expect(originalReloaded == journal)
        #expect(futureReloaded == future)
    }
}
