import Foundation
import Testing
@testable import TokeniCore

struct CompanionEggTests {
    @Test("The shop unlocks eggs from account and collection progress")
    func unlocks() throws {
        let mystery = try #require(
            CompanionEggRegistry.definition(for: .mystery))
        let discovery = try #require(
            CompanionEggRegistry.definition(for: .discovery))

        #expect(!CompanionEggRegistry.isUnlocked(
            mystery,
            highestPetLevel: 4,
            discoveredSpeciesCount: 5))
        #expect(CompanionEggRegistry.isUnlocked(
            mystery,
            highestPetLevel: 5,
            discoveredSpeciesCount: 0))
        #expect(CompanionEggRegistry.isUnlocked(
            discovery,
            highestPetLevel: 1,
            discoveredSpeciesCount: 3))
    }

    @Test("Egg seeds produce stable unit values")
    func stableSeed() {
        let first = CompanionEggRegistry.unitValue(seed: 42, salt: 1)
        let second = CompanionEggRegistry.unitValue(seed: 42, salt: 1)

        #expect(first == second)
        #expect((0..<1).contains(first))
        #expect(
            CompanionEggRegistry.deterministicSeed(for: "species-5")
                == CompanionEggRegistry.deterministicSeed(for: "species-5"))
    }

    @Test("The starter egg hatches for free and becomes the active pet")
    func starterEgg() throws {
        let egg = CompanionEggInstance.starter(seed: 42)
        var state = CompanionGameState(eggs: [egg])
        let engine = CompanionGameEngine()

        let events = try engine.openEgg(egg.id, in: &state)

        #expect(state.stage == .hatchling)
        #expect(state.level == 1)
        #expect(state.eggs.isEmpty)
        #expect(state.speciesID != nil)
        #expect(events.contains {
            if case let .eggOpened(id) = $0 { return id == egg.id }
            return false
        })
    }

    @Test("Special eggs enforce their discovery and variant guarantees")
    func specialEggGuarantees() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let discovered = CompanionSpeciesID.allCases.dropLast().map { speciesID in
            CompanionFormRecord(
                formID: "\(speciesID.rawValue).hatchling.standard",
                speciesID: speciesID,
                stage: .hatchling,
                rarity: .normal,
                variantID: .standard,
                unlockKind: .encountered,
                firstUnlockedAt: now,
                lastEncounteredAt: now,
                encounterCount: 1)
        }
        let egg = CompanionEggInstance(
            definitionID: .discovery,
            seed: 42,
            acquiredAt: now,
            source: .collectionMilestone)
        var state = CompanionGameState(
            collection: CompanionCollection(forms: discovered),
            eggs: [egg])
        let engine = CompanionGameEngine()

        _ = try engine.openEgg(egg.id, at: now, in: &state)

        #expect(state.speciesID == CompanionSpeciesID.allCases.last)

        let prismatic = CompanionEggInstance(
            definitionID: .prismatic,
            seed: 7,
            acquiredAt: now,
            source: .collectionMilestone)
        var prismaticState = CompanionGameState(eggs: [prismatic])
        _ = try engine.openEgg(prismatic.id, at: now, in: &prismaticState)
        #expect(prismaticState.resolvedVariantID == .prismatic)
    }

    @Test("Egg resale is fixed and the starter egg cannot be sold")
    func eggResale() throws {
        let engine = CompanionGameEngine()
        let mystery = CompanionEggInstance(
            definitionID: .mystery,
            seed: 1,
            source: .shop)
        var state = CompanionGameState(
            eggs: [.starter(seed: 2), mystery])

        let value = try engine.sellEgg(mystery.id, in: &state)

        #expect(value == 30)
        #expect(state.eggs.count == 1)
        #expect(throws: CompanionEggError.eggNotSellable) {
            try engine.sellEgg(state.eggs[0].id, in: &state)
        }
    }

    @Test("Opening another egg adds a switchable owned companion")
    func roster() throws {
        let engine = CompanionGameEngine()
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .hatchling,
            rarity: .normal,
            variantID: .standard,
            personalityID: .calm,
            eggs: [])
        let activeID = state.generationID
        let transactionID = UUID()
        _ = try engine.acquireEgg(
            definitionID: .mystery,
            seed: 99,
            source: .shop,
            transactionID: transactionID,
            in: &state)
        _ = try engine.acquireEgg(
            definitionID: .mystery,
            seed: 99,
            source: .shop,
            transactionID: transactionID,
            in: &state)

        #expect(state.eggs.count == 1)
        let eggID = try #require(state.eggs.first?.id)
        _ = try engine.openEgg(eggID, in: &state)
        let inactive = try #require(
            state.collection.archivedGenerations.first)

        _ = try engine.activateArchivedGeneration(
            inactive.generationID,
            in: &state)

        #expect(state.generationID == inactive.generationID)
        #expect(state.activeAcquisitionEggID == .mystery)
        #expect(state.collection.archivedGenerations.contains {
            $0.generationID == activeID
        })
    }

    @Test("Collection milestone eggs reconcile once for existing saves")
    func collectionMilestoneReconciliation() {
        let now = Date(timeIntervalSince1970: 1_000)
        let forms = CompanionSpeciesID.allCases.map { speciesID in
            CompanionFormRecord(
                formID: "\(speciesID.rawValue).hatchling.standard",
                speciesID: speciesID,
                stage: .hatchling,
                rarity: .normal,
                variantID: .standard,
                unlockKind: .encountered,
                firstUnlockedAt: now,
                lastEncounteredAt: now,
                encounterCount: 1)
        }
        var state = CompanionGameState(
            collection: CompanionCollection(forms: forms),
            eggs: [])
        let engine = CompanionGameEngine()

        _ = engine.reconcileEggMilestones(at: now, in: &state)
        _ = engine.reconcileEggMilestones(at: now, in: &state)

        #expect(state.eggs.count == 2)
        #expect(state.eggs.map(\.definitionID).contains(.discovery))
        #expect(state.eggs.map(\.definitionID).contains(.prismatic))
        #expect(state.claimedEggMilestoneIDs == ["species-5", "variants-5"])
        let seeds = state.eggs.map(\.seed)
        var secondState = CompanionGameState(
            collection: CompanionCollection(forms: forms),
            eggs: [])
        _ = engine.reconcileEggMilestones(at: now, in: &secondState)
        #expect(secondState.eggs.map(\.seed) == seeds)
    }

    @Test("Economy journal persists and completes pending transactions")
    func economyJournal() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "transactions.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CompanionEconomyTransactionStore(fileURL: file)
        let transaction = CompanionEconomyTransaction(kind: .purchaseEgg(
            definitionID: .mystery,
            seed: 42,
            price: 90))

        try await store.begin(transaction)
        #expect(try await store.load().pending == [transaction])

        try await store.complete(transaction.id)
        #expect(try await store.load().pending.isEmpty)
    }

    @Test("A purchase can resume after only its currency side was saved")
    func interruptedPurchaseRecovery() throws {
        let transactionID = UUID()
        let rewardEngine = CompanionRewardEngine()
        let gameEngine = CompanionGameEngine()
        var rewards = CompanionRewardState(starShards: 100)
        var companion = CompanionGameState(eggs: [])

        try rewardEngine.spendStarShards(
            90,
            transactionID: transactionID,
            in: &rewards)

        try rewardEngine.spendStarShards(
            90,
            transactionID: transactionID,
            in: &rewards)
        _ = try gameEngine.acquireEgg(
            definitionID: .mystery,
            seed: 42,
            source: .shop,
            transactionID: transactionID,
            in: &companion)
        _ = try gameEngine.acquireEgg(
            definitionID: .mystery,
            seed: 42,
            source: .shop,
            transactionID: transactionID,
            in: &companion)

        #expect(rewards.starShards == 10)
        #expect(companion.eggs.count == 1)
    }
}
