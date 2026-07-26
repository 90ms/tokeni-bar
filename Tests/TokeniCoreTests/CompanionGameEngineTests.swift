import Foundation
import Testing
@testable import TokeniCore

@Suite("Companion game")
struct CompanionGameEngineTests {
    @Test("One award can evolve through every stage in order")
    func evolvesAcrossStages() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let award = GrowthEnergyAward(
            dateKey: "2027-01-15",
            energy: 850,
            createdAt: now)
        let engine = CompanionGameEngine()
        var state = CompanionGameState(
            generationCreatedAt: now,
            updatedAt: now)

        let events = try engine.apply(
            award: award,
            randomValues: [0.80, 0.90, 0.995],
            to: &state)

        #expect(state.stage == .adult)
        #expect(state.rarity == .legendary)
        #expect(state.growthEnergy == 800)
        #expect(state.bondEnergy == 50)
        #expect(events.count == 5)
        #expect(state.collection.forms.contains {
            $0.formID == "bytebot.hatchling.legendary"
                && $0.unlockKind == .lineage
        })
        #expect(state.collection.forms.contains {
            $0.formID == "bytebot.adult.legendary"
                && $0.unlockKind == .encountered
        })
    }

    @Test("The same growth award is idempotent")
    func appliesAwardOnce() throws {
        let award = GrowthEnergyAward(
            dateKey: "2027-01-15",
            energy: 80,
            createdAt: .now)
        let engine = CompanionGameEngine()
        var state = CompanionGameState()

        _ = try engine.apply(award: award, randomValues: [0.5], to: &state)
        let repeated = try engine.apply(award: award, randomValues: [], to: &state)

        #expect(repeated.isEmpty)
        #expect(state.growthEnergy == 80)
        #expect(state.collection.forms.first {
            $0.formID == "bytebot.hatchling.normal"
        }?.encounterCount == 1)
    }

    @Test("Rarity transitions match every published boundary")
    func rarityBoundaries() {
        let engine = CompanionGameEngine()

        #expect(engine.rollRarity(from: .normal, unitValue: 0.7499) == .normal)
        #expect(engine.rollRarity(from: .normal, unitValue: 0.75) == .rare)
        #expect(engine.rollRarity(from: .normal, unitValue: 0.96) == .epic)
        #expect(engine.rollRarity(from: .normal, unitValue: 0.998) == .legendary)
        #expect(engine.rollRarity(from: .rare, unitValue: 0.8599) == .rare)
        #expect(engine.rollRarity(from: .rare, unitValue: 0.86) == .epic)
        #expect(engine.rollRarity(from: .rare, unitValue: 0.99) == .legendary)
        #expect(engine.rollRarity(from: .epic, unitValue: 0.9699) == .epic)
        #expect(engine.rollRarity(from: .epic, unitValue: 0.97) == .legendary)
        #expect(engine.rollRarity(from: .legendary, unitValue: 0) == .legendary)
    }

    @Test("Adult pity guarantees the promised minimum rarity")
    func adultPity() throws {
        let engine = CompanionGameEngine()
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        for (pity, expected) in [
            (CompanionPityState(adultsWithoutRareOrHigher: 2), CompanionRarity.rare),
            (CompanionPityState(adultsWithoutEpicOrHigher: 6), CompanionRarity.epic),
            (CompanionPityState(adultsWithoutLegendary: 15), CompanionRarity.legendary),
        ] {
            var state = CompanionGameState(
                stage: .junior,
                rarity: .normal,
                growthEnergy: 799,
                pity: pity)
            _ = try engine.apply(
                award: GrowthEnergyAward(
                    dateKey: "2027-01-15",
                    energy: 1,
                    createdAt: now),
                randomValues: [0],
                to: &state)
            #expect(state.rarity == expected)
        }
    }

    @Test("Completing adults advances and resets pity independently")
    func completionPity() throws {
        let engine = CompanionGameEngine()
        var state = CompanionGameState(
            stage: .adult,
            rarity: .normal,
            growthEnergy: 800)

        _ = try engine.completeGeneration(in: &state)
        #expect(state.pity.adultsWithoutRareOrHigher == 1)
        #expect(state.pity.adultsWithoutEpicOrHigher == 1)
        #expect(state.pity.adultsWithoutLegendary == 1)
        #expect(state.stage == .egg)
        #expect(state.generationNumber == 2)

        state.stage = .adult
        state.rarity = .epic
        state.growthEnergy = 800
        _ = try engine.completeGeneration(in: &state)
        #expect(state.pity.adultsWithoutRareOrHigher == 0)
        #expect(state.pity.adultsWithoutEpicOrHigher == 0)
        #expect(state.pity.adultsWithoutLegendary == 2)
    }

    @Test("Abandoning preserves collection and pity but resets progress")
    func abandon() {
        let engine = CompanionGameEngine()
        var state = CompanionGameState(
            stage: .junior,
            rarity: .rare,
            growthEnergy: 450,
            pity: CompanionPityState(adultsWithoutEpicOrHigher: 4))
        let originalForms = state.collection.forms.count

        _ = engine.abandonForNewEgg(in: &state)

        #expect(state.stage == .egg)
        #expect(state.rarity == .normal)
        #expect(state.growthEnergy == 0)
        #expect(state.pity.adultsWithoutEpicOrHigher == 4)
        #expect(state.collection.forms.count == originalForms)
        #expect(state.collection.forms.first?.encounterCount == 2)
    }

    @Test("Adult energy becomes bond and is archived on completion")
    func adultBond() throws {
        let engine = CompanionGameEngine()
        var state = CompanionGameState(
            stage: .adult,
            rarity: .rare,
            growthEnergy: 800)
        _ = try engine.apply(
            award: GrowthEnergyAward(
                dateKey: "2027-01-15",
                energy: 120,
                createdAt: .now),
            randomValues: [],
            to: &state)
        #expect(state.bondEnergy == 120)

        _ = try engine.completeGeneration(in: &state)
        #expect(state.collection.highestBondEnergy == 120)
        #expect(state.collection.completedCount(for: .rare) == 1)
        #expect(state.collection.recentCompletedGenerations.last?.bondEnergy == 120)
    }

    @Test("Old companion state is deliberately removed")
    func removesLegacyState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(
            #"{"schemaVersion":1,"companionID":"bytebot","totalXP":120}"#.utf8)
            .write(to: file)

        let state = try await CompanionGameStateStore(fileURL: file).load()

        #expect(state.schemaVersion == 2)
        #expect(state.stage == .egg)
        #expect(state.growthEnergy == 0)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("New game state round-trips without provider or token totals")
    func stateRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        var expected = CompanionGameState(
            stage: .junior,
            rarity: .epic,
            growthEnergy: 420,
            bondEnergy: 17)
        expected.lastActiveAt = Date(timeIntervalSince1970: 1_800_000_000)
        let store = CompanionGameStateStore(fileURL: file)

        try await store.save(expected)
        let loaded = try await store.load()
        let encoded = try String(contentsOf: file, encoding: .utf8)

        #expect(loaded == expected)
        #expect(!encoded.contains("provider"))
        #expect(!encoded.contains("token"))
    }

    @Test("Behavior priority remains celebration warning work sleep idle")
    func behaviorPriority() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var state = CompanionGameState(
            lastActiveAt: now.addingTimeInterval(-700),
            celebrationUntil: now.addingTimeInterval(4))

        #expect(CompanionBehaviorResolver.resolve(
            state: state,
            isWorking: true,
            lowestRemainingQuotaPercent: 2,
            at: now) == .celebrate)
        state.celebrationUntil = nil
        #expect(CompanionBehaviorResolver.resolve(
            state: state,
            isWorking: true,
            lowestRemainingQuotaPercent: 2,
            at: now) == .warning)
        #expect(CompanionBehaviorResolver.resolve(
            state: state,
            isWorking: true,
            lowestRemainingQuotaPercent: 50,
            at: now) == .working)
        #expect(CompanionBehaviorResolver.resolve(
            state: state,
            isWorking: false,
            lowestRemainingQuotaPercent: 50,
            at: now) == .sleep)
    }
}
