import Foundation
import Testing
@testable import TokeniCore

@Suite("Companion game")
struct CompanionGameEngineTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test("Energy never hatches or evolves a companion automatically")
    func energyDoesNotAutoEvolve() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let award = GrowthEnergyAward(
            dateKey: "2027-01-15",
            energy: 850,
            createdAt: now)
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthDateKey: "2027-01-15",
            generationCreatedAt: now,
            updatedAt: now)

        let events = engine.apply(award: award, to: &state)

        #expect(state.stage == .egg)
        #expect(state.rarity == nil)
        #expect(state.growthEnergy == 320)
        #expect(events == [.energyApplied(320)])
    }

    @Test("The same growth award is idempotent")
    func appliesAwardOnce() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let award = GrowthEnergyAward(
            dateKey: "2027-01-15",
            energy: 80,
            createdAt: now)
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(growthDateKey: "2027-01-15")

        _ = engine.apply(award: award, to: &state)
        let repeated = engine.apply(award: award, to: &state)

        #expect(repeated.isEmpty)
        #expect(state.growthEnergy == 80)
        #expect(state.growthEarnedToday == 80)
    }

    @Test("Hatching is manual, spends energy, and reveals the first rarity")
    func manualHatch() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthEnergy: 80,
            growthDateKey: "2027-01-15")

        let events = try engine.hatch(
            speciesUnitValue: 0,
            rarityUnitValue: 0.80,
            at: now,
            in: &state)

        #expect(state.stage == .hatchling)
        #expect(state.rarity == .rare)
        #expect(state.growthEnergy == 20)
        #expect(state.growthSpentToday == 60)
        #expect(events.contains {
            if case .hatched(
                speciesID: .bytebot,
                rarity: .rare,
                isNewSpecies: true,
                unlockedFormIDs: _) = $0
            {
                return true
            }
            return false
        })
        #expect(state.collection.forms.contains {
            $0.formID == "bytebot.hatchling.rare"
                && $0.unlockKind == .encountered
        })
    }

    @Test("Every species occupies an equal hatch interval")
    func equalSpeciesIntervals() {
        let engine = CompanionGameEngine(calendar: self.calendar)

        #expect(engine.rollSpecies(unitValue: 0) == .bytebot)
        #expect(engine.rollSpecies(unitValue: 0.20) == .cachecat)
        #expect(engine.rollSpecies(unitValue: 0.40) == .stackfox)
        #expect(engine.rollSpecies(unitValue: 0.60) == .promptpup)
        #expect(engine.rollSpecies(unitValue: 0.80) == .nullslime)
        #expect(engine.rollSpecies(unitValue: 1) == .nullslime)
    }

    @Test("Five duplicate hatches guarantee a missing species next")
    func missingSpeciesPity() throws {
        let engine = CompanionGameEngine(calendar: self.calendar)
        let encounteredByteBot = CompanionFormRecord(
            formID: "bytebot.hatchling.normal",
            speciesID: .bytebot,
            stage: .hatchling,
            rarity: .normal,
            unlockKind: .encountered,
            firstUnlockedAt: .now,
            lastEncounteredAt: .now,
            encounterCount: 6)
        var state = CompanionGameState(
            growthEnergy: 60,
            growthDateKey: GrowthLocalDate.key(
                for: .now,
                calendar: self.calendar),
            collection: CompanionCollection(forms: [encounteredByteBot]),
            consecutiveDuplicateHatches: 5)

        let events = try engine.hatch(
            speciesUnitValue: 0,
            rarityUnitValue: 0,
            in: &state)

        #expect(state.speciesID == .cachecat)
        #expect(state.consecutiveDuplicateHatches == 0)
        #expect(events.contains {
            if case .hatched(
                speciesID: .cachecat,
                rarity: .normal,
                isNewSpecies: true,
                unlockedFormIDs: _) = $0
            {
                return true
            }
            return false
        })
    }

    @Test("Evolution waits for a click and rarity never decreases")
    func manualEvolution() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .hatchling,
            rarity: .rare,
            growthEnergy: 260,
            growthDateKey: "2027-01-15")

        _ = try engine.evolve(unitValue: 0.10, at: now, in: &state)
        #expect(state.stage == .junior)
        #expect(state.speciesID == .bytebot)
        #expect(state.rarity == .rare)
        #expect(state.growthEnergy == 160)

        _ = try engine.evolve(unitValue: 0.90, at: now, in: &state)
        #expect(state.stage == .adult)
        #expect(state.speciesID == .bytebot)
        #expect(state.rarity == .epic)
        #expect(state.growthEnergy == 0)
        #expect(state.growthSpentToday == 260)
    }

    @Test("Insufficient energy leaves the egg unchanged")
    func insufficientEnergy() {
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthEnergy: 59,
            growthDateKey: GrowthLocalDate.key(
                for: .now,
                calendar: self.calendar))
        let original = state

        #expect(throws: CompanionGameError.insufficientEnergy(
            required: 60,
            available: 59))
        {
            try engine.hatch(
                speciesUnitValue: 0,
                rarityUnitValue: 0,
                in: &state)
        }
        #expect(state == original)
    }

    @Test("Daily rollover carries twenty percent for every elapsed day")
    func dailyCarryover() throws {
        let first = try #require(self.date("2027-01-15T12:00:00Z"))
        let third = try #require(self.date("2027-01-17T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthEnergy: 300,
            growthDateKey: "2027-01-15",
            growthEarnedToday: 300,
            generationCreatedAt: first)

        engine.rollOverEnergyIfNeeded(at: third, in: &state)

        #expect(state.growthEnergy == 12)
        #expect(state.growthCarriedToday == 12)
        #expect(state.growthEarnedToday == 0)
        #expect(state.growthSpentToday == 0)
        #expect(state.growthDateKey == "2027-01-17")
    }

    @Test("Energy balance never exceeds the two-day cap")
    func energyCap() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthEnergy: 300,
            growthDateKey: "2027-01-15")

        _ = engine.apply(
            award: GrowthEnergyAward(
                dateKey: "2027-01-15",
                energy: 100,
                createdAt: now),
            to: &state)

        #expect(state.growthEnergy == 320)
        #expect(state.growthEarnedToday == 20)
    }

    @Test("Adult pity guarantees the promised minimum rarity")
    func adultPity() throws {
        let engine = CompanionGameEngine(calendar: self.calendar)
        let dateKey = GrowthLocalDate.key(for: .now, calendar: self.calendar)

        for (pity, expected) in [
            (CompanionPityState(adultsWithoutRareOrHigher: 2), CompanionRarity.rare),
            (CompanionPityState(adultsWithoutEpicOrHigher: 6), CompanionRarity.epic),
            (CompanionPityState(adultsWithoutLegendary: 15), CompanionRarity.legendary),
        ] {
            var state = CompanionGameState(
                speciesID: .bytebot,
                stage: .junior,
                rarity: .normal,
                growthEnergy: 160,
                growthDateKey: dateKey,
                pity: pity)
            _ = try engine.evolve(unitValue: 0, in: &state)
            #expect(state.rarity == expected)
        }
    }

    @Test("Completing an adult spends egg and hatch energy, then hatches again")
    func completion() throws {
        let engine = CompanionGameEngine(calendar: self.calendar)
        let dateKey = GrowthLocalDate.key(for: .now, calendar: self.calendar)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .adult,
            rarity: .normal,
            growthEnergy: 120,
            growthDateKey: dateKey)

        let events = try engine.completeGeneration(
            speciesUnitValue: 0.25,
            rarityUnitValue: 0,
            in: &state)

        #expect(state.stage == .hatchling)
        #expect(state.speciesID == .cachecat)
        #expect(state.rarity == .normal)
        #expect(state.generationNumber == 2)
        #expect(state.growthEnergy == 20)
        #expect(state.growthSpentToday == 100)
        #expect(state.pity.adultsWithoutRareOrHigher == 1)
        #expect(state.collection.completedCount(for: .normal) == 1)
        #expect(engine.actionCost(for: .adult) == 100)
        #expect(events.contains(.energySpent(100)))
        #expect(events.contains {
            if case .hatched(
                speciesID: .cachecat,
                rarity: .normal,
                isNewSpecies: true,
                unlockedFormIDs: _) = $0
            {
                return true
            }
            return false
        })
    }

    @Test("Every currently bundled pet belongs to asset generation one")
    func currentSpeciesAreGenerationOne() {
        #expect(CompanionSpeciesID.allCases.allSatisfy {
            $0.contentGeneration == 1
        })
        #expect(CompanionSpeciesID.latestContentGeneration == 1)
    }

    @Test("Restarting spends energy but preserves collection and pity")
    func abandon() throws {
        let engine = CompanionGameEngine(calendar: self.calendar)
        let dateKey = GrowthLocalDate.key(for: .now, calendar: self.calendar)
        let form = CompanionFormRecord(
            formID: "bytebot.hatchling.rare",
            stage: .hatchling,
            rarity: .rare,
            unlockKind: .encountered,
            firstUnlockedAt: .now,
            lastEncounteredAt: .now,
            encounterCount: 1)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .junior,
            rarity: .rare,
            growthEnergy: 75,
            growthDateKey: dateKey,
            collection: CompanionCollection(forms: [form]),
            pity: CompanionPityState(adultsWithoutEpicOrHigher: 4))

        _ = try engine.abandonForNewEgg(in: &state)

        #expect(state.stage == .egg)
        #expect(state.rarity == nil)
        #expect(state.growthEnergy == 35)
        #expect(state.pity.adultsWithoutEpicOrHigher == 4)
        #expect(state.collection.forms == [form])
    }

    @Test("Adult energy becomes bond while also filling action energy")
    func adultBond() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .adult,
            rarity: .rare,
            growthDateKey: "2027-01-15")

        _ = engine.apply(
            award: GrowthEnergyAward(
                dateKey: "2027-01-15",
                energy: 120,
                createdAt: now),
            to: &state)

        #expect(state.bondEnergy == 120)
        #expect(state.growthEnergy == 120)
    }

    @Test("Version three state migrates without discarding the companion")
    func migratesVersionThreeState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let current = CompanionGameState(
            speciesID: .bytebot,
            stage: .junior,
            rarity: .epic,
            growthEnergy: 320,
            growthDateKey: "2027-01-15",
            generationCreatedAt: timestamp,
            updatedAt: timestamp)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(current)
        let versionThree = try #require(
            String(data: encoded, encoding: .utf8)?
                .replacingOccurrences(
                    of: #""schemaVersion":4"#,
                    with: #""schemaVersion":3"#)
                .data(using: .utf8))
        try versionThree.write(to: file)

        let state = try await CompanionGameStateStore(fileURL: file).load()

        #expect(state.schemaVersion == 4)
        #expect(state.speciesID == .bytebot)
        #expect(state.stage == .junior)
        #expect(state.rarity == .epic)
        #expect(state.growthEnergy == 320)
    }

    @Test("Unsupported old companion state is deliberately removed")
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

        #expect(state.schemaVersion == 4)
        #expect(state.stage == .egg)
        #expect(state.speciesID == nil)
        #expect(state.rarity == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("New game state round-trips without provider or token totals")
    func stateRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        var expected = CompanionGameState(
            speciesID: .bytebot,
            stage: .junior,
            rarity: .epic,
            growthEnergy: 120,
            growthDateKey: "2027-01-15",
            growthEarnedToday: 100,
            growthCarriedToday: 20,
            growthSpentToday: 40,
            bondEnergy: 17,
            generationCreatedAt: timestamp,
            updatedAt: timestamp)
        expected.lastActiveAt = timestamp
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

    @Test("Rejects graded eggs and ungraded evolved companions")
    func rejectsInvalidState() {
        let gradedEgg = CompanionGameState(rarity: .normal)
        #expect(!gradedEgg.isValid())

        let ungradedAdult = CompanionGameState(stage: .adult)
        #expect(!ungradedAdult.isValid())
    }

    @Test("Published rarity transitions produce the expected adult distribution")
    func finalRarityDistribution() {
        let engine = CompanionGameEngine(calendar: self.calendar)
        var generator = SplitMix64(state: 0x746f_6b65_6e69)
        var counts = [CompanionRarity: Int]()
        let samples = 200_000

        for _ in 0..<samples {
            var rarity = CompanionRarity.normal
            for _ in 0..<3 {
                rarity = engine.rollRarity(
                    from: rarity,
                    unitValue: generator.nextUnit())
            }
            counts[rarity, default: 0] += 1
        }

        let expected: [CompanionRarity: Double] = [
            .normal: 0.42188,
            .rare: 0.40889,
            .epic: 0.15521,
            .legendary: 0.01403,
        ]
        for (rarity, probability) in expected {
            let actual = Double(counts[rarity, default: 0]) / Double(samples)
            #expect(abs(actual - probability) < 0.006)
        }
    }

    private func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}

private struct SplitMix64 {
    var state: UInt64

    mutating func nextUnit() -> Double {
        self.state &+= 0x9E37_79B9_7F4A_7C15
        var value = self.state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value >> 11) / Double(1 << 53)
    }
}
