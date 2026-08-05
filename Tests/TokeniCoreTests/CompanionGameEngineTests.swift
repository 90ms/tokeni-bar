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
        #expect(state.growthEnergy == 850)
        #expect(events == [.energyApplied(850)])
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

    @Test("Hatching is manual, spends energy, and reveals a stable variant")
    func manualHatch() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthEnergy: 800,
            growthDateKey: "2027-01-15")

        let events = try engine.hatch(
            speciesUnitValue: 0,
            variantUnitValue: 0.99,
            personalityUnitValue: 0.5,
            at: now,
            in: &state)

        #expect(state.stage == .hatchling)
        #expect(state.rarity == .legendary)
        #expect(state.variantID == .prismatic)
        #expect(state.personalityID == .playful)
        #expect(state.memories.map(\.kind) == [.hatched])
        #expect(state.growthEnergy == 300)
        #expect(state.growthSpentToday == 500)
        #expect(events.contains {
            if case .hatched(
                speciesID: .bytebot,
                rarity: .legendary,
                isNewSpecies: true,
                unlockedFormIDs: _) = $0
            {
                return true
            }
            return false
        })
        #expect(state.collection.forms.contains {
            $0.formID == "bytebot.hatchling.prismatic"
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
            growthEnergy: 500,
            growthDateKey: GrowthLocalDate.key(
                for: .now,
                calendar: self.calendar),
            collection: CompanionCollection(forms: [encounteredByteBot]),
            consecutiveDuplicateHatches: 5)

        let events = try engine.hatch(
            speciesUnitValue: 0,
            variantUnitValue: 0,
            in: &state)

        #expect(state.speciesID == .cachecat)
        #expect(state.variantID == .standard)
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

    @Test("Evolution waits for a click and keeps the hatch variant")
    func manualEvolution() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .hatchling,
            rarity: .rare,
            variantID: .legacyAzure,
            growthEnergy: 2_200,
            growthDateKey: "2027-01-15")

        _ = try engine.evolve(unitValue: 0.10, at: now, in: &state)
        #expect(state.stage == .junior)
        #expect(state.speciesID == .bytebot)
        #expect(state.rarity == .rare)
        #expect(state.variantID == .legacyAzure)
        #expect(state.growthEnergy == 2_200)

        _ = try engine.evolve(unitValue: 0.90, at: now, in: &state)
        #expect(state.stage == .adult)
        #expect(state.speciesID == .bytebot)
        #expect(state.rarity == .rare)
        #expect(state.variantID == .legacyAzure)
        #expect(state.growthEnergy == 2_200)
        #expect(state.growthSpentToday == 0)
        #expect(state.collection.forms.map(\.formID).sorted() == [
            "bytebot.adult.legacy-azure",
            "bytebot.junior.legacy-azure",
        ])
        #expect(!state.collection.forms.contains {
            $0.variantID != .legacyAzure
        })
    }

    @Test("Evolution requires its configured level and never spends XP")
    func levelGatedEvolution() throws {
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .hatchling,
            rarity: .normal,
            variantID: .standard,
            personalityID: .calm,
            growthXP: 17,
            growthDateKey: "2027-01-15")

        #expect(throws: CompanionGameError.evolutionLevelRequired(
            required: 10,
            current: 9))
        {
            try engine.evolve(unitValue: 0, in: &state)
        }

        state.growthXP = 18
        _ = try engine.evolve(unitValue: 0, in: &state)
        #expect(state.stage == .junior)
        #expect(state.growthXP == 18)
    }

    @Test("Insufficient energy leaves the egg unchanged")
    func insufficientEnergy() {
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthEnergy: 499,
            growthDateKey: GrowthLocalDate.key(
                for: .now,
                calendar: self.calendar))
        let original = state

        #expect(throws: CompanionGameError.insufficientEnergy(
            required: 500,
            available: 499))
        {
            try engine.hatch(
                speciesUnitValue: 0,
                variantUnitValue: 0,
                in: &state)
        }
        #expect(state == original)
    }

    @Test("Daily rollover preserves unspent energy across elapsed days")
    func dailyCarryover() throws {
        let first = try #require(self.date("2027-01-15T12:00:00Z"))
        let third = try #require(self.date("2027-01-17T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthEnergy: 300,
            growthDateKey: "2027-01-15",
            growthEarnedToday: 300,
            delayedGrowthEarnedToday: 100,
            generationCreatedAt: first)

        engine.rollOverEnergyIfNeeded(at: third, in: &state)

        #expect(state.growthEnergy == 300)
        #expect(state.growthCarriedToday == 300)
        #expect(state.growthEarnedToday == 0)
        #expect(state.delayedGrowthEarnedToday == 0)
        #expect(state.growthSpentToday == 0)
        #expect(state.growthDateKey == "2027-01-17")
    }

    @Test("A delayed usage award is added to the confirmation day's energy")
    func delayedUsageAwardSettlesToday() throws {
        let confirmedAt = try #require(self.date("2027-01-16T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthEnergy: 100,
            growthDateKey: "2027-01-15",
            growthEarnedToday: 100)
        let award = GrowthEnergyAward(
            dateKey: "2027-01-15",
            energy: 50,
            createdAt: confirmedAt)

        _ = engine.apply(award: award, to: &state)

        #expect(state.growthDateKey == "2027-01-16")
        #expect(state.growthCarriedToday == 100)
        #expect(state.growthEarnedToday == 50)
        #expect(state.delayedGrowthEarnedToday == 50)
        #expect(state.growthEnergy == 150)
    }

    @Test("Energy balance never exceeds the safety cap")
    func energyCap() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            growthEnergy: 99_950,
            growthDateKey: "2027-01-15")

        _ = engine.apply(
            award: GrowthEnergyAward(
                dateKey: "2027-01-15",
                energy: 100,
                createdAt: now),
            to: &state)

        #expect(state.growthEnergy == 100_000)
        #expect(state.growthEarnedToday == 50)
    }

    @Test("Prismatic variants use a single transparent guarantee")
    func prismaticPity() {
        let engine = CompanionGameEngine(calendar: self.calendar)

        #expect(engine.rollVariant(unitValue: 0.91) == .standard)
        #expect(engine.rollVariant(unitValue: 0.92) == .prismatic)
        #expect(engine.rollVariant(
            unitValue: 0,
            pity: CompanionVariantPityState(standardHatches: 11))
            == .prismatic)
    }

    @Test("Completing an adult spends egg and hatch energy, then hatches again")
    func completion() throws {
        let engine = CompanionGameEngine(calendar: self.calendar)
        let dateKey = GrowthLocalDate.key(for: .now, calendar: self.calendar)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .adult,
            rarity: .normal,
            growthEnergy: 900,
            growthDateKey: dateKey)

        let events = try engine.completeGeneration(
            speciesUnitValue: 0.25,
            variantUnitValue: 0,
            in: &state)

        #expect(state.stage == .hatchling)
        #expect(state.speciesID == .cachecat)
        #expect(state.rarity == .normal)
        #expect(state.variantID == .standard)
        #expect(state.generationNumber == 2)
        #expect(state.growthEnergy == 100)
        #expect(state.growthSpentToday == 800)
        #expect(state.variantPity.standardHatches == 1)
        #expect(state.collection.completedCount(for: .normal) == 1)
        #expect(state.collection.archivedGenerations.count == 1)
        #expect(engine.actionCost(for: .adult) == nil)
        #expect(events.contains(.energySpent(800)))
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

    @Test("Completed pets remain archived and can be showcased")
    func archivedCompanions() throws {
        let engine = CompanionGameEngine(calendar: self.calendar)
        let dateKey = GrowthLocalDate.key(for: .now, calendar: self.calendar)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .adult,
            rarity: .normal,
            growthEnergy: 800,
            growthDateKey: dateKey)

        for index in 0..<25 {
            state.speciesID = .bytebot
            state.stage = .adult
            state.rarity = index == 24 ? .legendary : .normal
            state.growthEnergy = 800
            _ = try engine.completeGeneration(
                speciesUnitValue: 0,
                variantUnitValue: 0,
                in: &state)
        }

        #expect(state.collection.archivedGenerations.count == 25)
        let first = try #require(state.collection.archivedGenerations.first)
        try engine.showcaseArchivedGeneration(first.generationID, in: &state)
        #expect(state.showcasedGeneration == first)

        try engine.showcaseArchivedGeneration(nil, in: &state)
        #expect(state.showcasedGeneration == nil)
        #expect(throws: CompanionGameError.archivedGenerationNotFound) {
            try engine.showcaseArchivedGeneration(UUID(), in: &state)
        }
    }

    @Test("Three same-species duplicates synthesize a visual mutation")
    func mutationSynthesis() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        let duplicates = (0..<3).map { index in
            CompletedCompanionGeneration(
                generationID: UUID(),
                generationNumber: index + 1,
                speciesID: .bytebot,
                finalRarity: .normal,
                variantID: .standard,
                bondEnergy: 0,
                growthXP: 0,
                stage: .adult,
                completedAt: now)
        }
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .adult,
            rarity: .normal,
            variantID: .standard,
            personalityID: .calm,
            collection: CompanionCollection(
                recentCompletedGenerations: duplicates))

        let events = try engine.synthesizeMutation(
            sourceGenerationIDs: duplicates.map(\.generationID),
            mutationUnitValue: 0,
            at: now,
            in: &state)

        let mutationPet = try #require(
            state.collection.archivedGenerations.first(where: {
                $0.mutationID == .neon
            }))
        #expect(state.collection.archivedGenerations.count == 1)
        #expect(mutationPet.speciesID == .bytebot)
        #expect(mutationPet.finalRarity == .normal)
        #expect(mutationPet.variantID == .standard)
        #expect(mutationPet.stage == .hatchling)
        #expect(state.collection.mutationSynthesisCount == 1)
        #expect(state.collection.mutations.map(\.mutationID) == [.neon])
        #expect(events.contains {
            if case .mutationSynthesized(
                speciesID: .bytebot,
                mutationID: .neon,
                consumedGenerationIDs: _,
                createdGeneration: _,
                isNewMutation: true) = $0
            {
                return true
            }
            return false
        })

        try engine.equipMutation(.neon, at: now, in: &state)
        #expect(state.activeMutationID == .neon)
        #expect(state.isValid())

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(
            CompanionGameState.self,
            from: data)
        #expect(decoded.collection.mutations == state.collection.mutations)
        #expect(decoded.collection.archivedGenerations == state.collection.archivedGenerations)
        #expect(decoded.activeMutationID == .neon)

        try engine.activateArchivedGeneration(
            mutationPet.generationID,
            at: now,
            in: &state)
        #expect(state.generationID == mutationPet.generationID)
        #expect(state.activeMutationID == .neon)
        #expect(state.stage == .hatchling)
        #expect(state.isValid())
    }

    @Test("Mutation synthesis protects prismatic and mutated companions")
    func mutationSourcesMustBeStandardAndUnmutated() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        let standardOne = CompletedCompanionGeneration(
            generationID: UUID(),
            generationNumber: 1,
            speciesID: .bytebot,
            finalRarity: .normal,
            variantID: .standard,
            bondEnergy: 0,
            completedAt: now)
        let standardTwo = CompletedCompanionGeneration(
            generationID: UUID(),
            generationNumber: 2,
            speciesID: .bytebot,
            finalRarity: .normal,
            variantID: .standard,
            bondEnergy: 0,
            completedAt: now)
        let prismatic = CompletedCompanionGeneration(
            generationID: UUID(),
            generationNumber: 3,
            speciesID: .bytebot,
            finalRarity: .legendary,
            variantID: .prismatic,
            bondEnergy: 0,
            completedAt: now)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .hatchling,
            rarity: .normal,
            variantID: .standard,
            personalityID: .calm,
            collection: CompanionCollection(
                recentCompletedGenerations: [
                    standardOne,
                    standardTwo,
                    prismatic,
                ]))
        let original = state

        #expect(throws: CompanionMutationError.sourceNotEligible) {
            try engine.synthesizeMutation(
                sourceGenerationIDs: [
                    standardOne.generationID,
                    standardTwo.generationID,
                    prismatic.generationID,
                ],
                mutationUnitValue: 0,
                in: &state)
        }
        #expect(state == original)

        let mutated = CompletedCompanionGeneration(
            generationID: UUID(),
            generationNumber: 4,
            speciesID: .bytebot,
            finalRarity: .normal,
            variantID: .standard,
            mutationID: .neon,
            bondEnergy: 0,
            completedAt: now)
        state.collection.recentCompletedGenerations = [
            standardOne,
            standardTwo,
            mutated,
        ]
        state.collection.mutations = [CompanionMutationRecord(
            speciesID: .bytebot,
            mutationID: .neon,
            firstDiscoveredAt: now,
            lastSynthesizedAt: now)]
        let stateWithMutation = state

        #expect(throws: CompanionMutationError.sourceNotEligible) {
            try engine.synthesizeMutation(
                sourceGenerationIDs: [
                    standardOne.generationID,
                    standardTwo.generationID,
                    mutated.generationID,
                ],
                mutationUnitValue: 0,
                in: &state)
        }
        #expect(state == stateWithMutation)
    }

    @Test("Every currently bundled pet belongs to asset generation one")
    func currentSpeciesAreGenerationOne() {
        #expect(CompanionSpeciesID.allCases.allSatisfy {
            $0.contentGeneration == 1
        })
        #expect(CompanionSpeciesID.latestContentGeneration == 1)
    }

    @Test("Restarting spends energy but preserves collection and variant pity")
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
            growthEnergy: 375,
            growthDateKey: dateKey,
            collection: CompanionCollection(forms: [form]),
            variantPity: CompanionVariantPityState(standardHatches: 4))

        _ = try engine.abandonForNewEgg(in: &state)

        #expect(state.stage == .egg)
        #expect(state.rarity == nil)
        #expect(state.growthEnergy == 75)
        #expect(state.variantPity.standardHatches == 4)
        #expect(state.collection.forms == [form])
    }

    @Test("Adult growth continues as unbounded level XP")
    func adultGrowth() throws {
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

        #expect(state.growthXP == 186)
        #expect(state.growthEnergy == 0)
        #expect(state.bondEnergy == 0)
        #expect(state.memories.compactMap(\.bondLevel).isEmpty)
    }

    @Test("Boosted awards increase level XP without a second bond track")
    func boostedEnergyUsesLevelXP() {
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            speciesID: .bytebot,
            stage: .adult,
            rarity: .normal,
            variantID: .standard,
            personalityID: .calm)
        let award = GrowthEnergyAward(
            dateKey: state.growthDateKey,
            energy: 50,
            createdAt: .now)

        _ = engine.apply(award: award, bondEnergy: 10, to: &state)

        #expect(state.growthEnergy == 0)
        #expect(state.growthXP == 116)
        #expect(state.bondEnergy == 0)
    }

    @Test("Names and content-free memories make journeys individual")
    func identityAndMemories() throws {
        let now = try #require(self.date("2027-01-15T12:00:00Z"))
        let engine = CompanionGameEngine(calendar: self.calendar)
        var state = CompanionGameState(
            speciesID: .cachecat,
            stage: .adult,
            rarity: .normal,
            variantID: .standard,
            personalityID: .curious,
            growthEnergy: 800,
            growthDateKey: "2027-01-15")

        engine.rename("  Moka  ", at: now, in: &state)
        engine.pat(at: now, in: &state)
        engine.pat(at: now, in: &state)
        _ = try engine.completeGeneration(
            speciesUnitValue: 0,
            variantUnitValue: 0,
            personalityUnitValue: 0.9,
            at: now,
            in: &state)

        let archived = try #require(
            state.collection.archivedGenerations.first)
        #expect(archived.nickname == "Moka")
        #expect(archived.personalityID == .curious)
        #expect(state.memories.count {
            $0.generationID == archived.generationID
                && $0.kind == .firstPat
        } == 1)
        #expect(state.memories.contains {
            $0.generationID == archived.generationID
                && $0.kind == .journeyCompleted
        })
        #expect(state.personalityID == .brave)
        #expect(state.nickname == nil)
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
                    of: #""schemaVersion":10"#,
                    with: #""schemaVersion":3"#)
                .data(using: .utf8))
        try versionThree.write(to: file)

        let state = try await CompanionGameStateStore(fileURL: file).load()

        #expect(state.schemaVersion == 10)
        #expect(state.speciesID == .bytebot)
        #expect(state.stage == .junior)
        #expect(state.rarity == .epic)
        #expect(state.growthEnergy == 0)
        #expect(state.level >= 10)
    }

    @Test("Version eight adults migrate into unbounded level progress")
    func migratesVersionEightProgress() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let current = CompanionGameState(
            speciesID: .bytebot,
            stage: .adult,
            rarity: .normal,
            variantID: .standard,
            personalityID: .calm,
            growthEnergy: 40,
            bondEnergy: 20)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(current)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["schemaVersion"] = 8
        object.removeValue(forKey: "growthXP")
        object.removeValue(forKey: "eggs")
        object.removeValue(forKey: "highestPetLevel")
        object.removeValue(forKey: "claimedEggMilestoneIDs")
        object.removeValue(forKey: "processedEggTransactionIDs")
        try JSONSerialization.data(withJSONObject: object).write(to: file)

        let state = try await CompanionGameStateStore(fileURL: file).load()

        #expect(state.schemaVersion == 10)
        #expect(state.stage == .adult)
        #expect(state.level >= 25)
        #expect(state.growthXP >= 106)
        #expect(state.growthEnergy == 0)
        #expect(state.legacyMigratedGenerationIDs.contains(state.generationID))
        #expect(state.eggs.contains { $0.source == .migrationGift })
    }

    @Test("Version five rarity migrates to a non-ranked visual variant")
    func migratesVersionFiveVariant() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let current = CompanionGameState(
            speciesID: .cachecat,
            stage: .adult,
            rarity: .epic,
            growthEnergy: 320,
            growthDateKey: "2027-01-15",
            generationCreatedAt: timestamp,
            updatedAt: timestamp)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(current)
        let versionFive = try #require(
            String(data: encoded, encoding: .utf8)?
                .replacingOccurrences(
                    of: #""schemaVersion":10"#,
                    with: #""schemaVersion":5"#)
                .data(using: .utf8))
        try versionFive.write(to: file)

        let state = try await CompanionGameStateStore(fileURL: file).load()

        #expect(state.schemaVersion == 10)
        #expect(state.speciesID == .cachecat)
        #expect(state.variantID == .legacyViolet)
        #expect(state.rarity == .epic)
    }

    @Test("Version six variant state gains an empty private memory album")
    func migratesVersionSixMemories() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let current = CompanionGameState(
            speciesID: .stackfox,
            stage: .junior,
            rarity: .legendary,
            variantID: .prismatic,
            personalityID: .brave,
            growthDateKey: "2027-01-15",
            generationCreatedAt: timestamp,
            updatedAt: timestamp)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(current)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["schemaVersion"] = 6
        object.removeValue(forKey: "nickname")
        object.removeValue(forKey: "personalityID")
        object.removeValue(forKey: "memories")
        try JSONSerialization.data(withJSONObject: object).write(to: file)

        let state = try await CompanionGameStateStore(fileURL: file).load()

        #expect(state.schemaVersion == 10)
        #expect(state.variantID == .prismatic)
        #expect(state.personalityID == .calm)
        #expect(state.memories.isEmpty)
    }

    @Test("Version four lineage forms are removed during migration")
    func migratesVersionFourLineageForms() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let encountered = CompanionFormRecord(
            formID: "bytebot.adult.rare",
            stage: .adult,
            rarity: .rare,
            unlockKind: .encountered,
            firstUnlockedAt: timestamp,
            lastEncounteredAt: timestamp,
            encounterCount: 1)
        let lineage = CompanionFormRecord(
            formID: "bytebot.hatchling.rare",
            stage: .hatchling,
            rarity: .rare,
            unlockKind: .lineage,
            firstUnlockedAt: timestamp,
            lastEncounteredAt: nil,
            encounterCount: 0)
        let current = CompanionGameState(
            speciesID: .bytebot,
            stage: .adult,
            rarity: .rare,
            collection: CompanionCollection(forms: [encountered, lineage]),
            generationCreatedAt: timestamp,
            updatedAt: timestamp)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(current)
        let versionFour = try #require(
            String(data: encoded, encoding: .utf8)?
                .replacingOccurrences(
                    of: #""schemaVersion":10"#,
                    with: #""schemaVersion":4"#)
                .data(using: .utf8))
        try versionFour.write(to: file)

        let state = try await CompanionGameStateStore(fileURL: file).load()

        #expect(state.schemaVersion == 10)
        #expect(state.collection.forms == [encountered])
        #expect(state.delayedGrowthEarnedToday == 0)
    }

    @Test("Unsupported old companion state is quarantined")
    func quarantinesLegacyState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(
            #"{"schemaVersion":1,"companionID":"bytebot","totalXP":120}"#.utf8)
            .write(to: file)

        var loadFailed = false
        do {
            _ = try await CompanionGameStateStore(fileURL: file).load()
        } catch {
            loadFailed = true
        }

        #expect(loadFailed)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        let quarantinedFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil)
        #expect(quarantinedFiles.contains {
            $0.lastPathComponent.hasPrefix("companion-state.corrupt-")
                && $0.pathExtension == "json"
        })
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
            variantID: .legacyViolet,
            personalityID: .dreamy,
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

    @Test("A mutation backup restores missing prismatic archived pets")
    func recoversPrismaticCompanionFromMutationBackup() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "companion-state.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let prismatic = CompletedCompanionGeneration(
            generationID: UUID(),
            generationNumber: 2,
            speciesID: .bytebot,
            finalRarity: .legendary,
            variantID: .prismatic,
            bondEnergy: 0,
            stage: .hatchling,
            completedAt: timestamp)
        let mutationRecord = CompanionMutationRecord(
            speciesID: .bytebot,
            mutationID: .neon,
            firstDiscoveredAt: timestamp,
            lastSynthesizedAt: timestamp)
        let mutationPet = CompletedCompanionGeneration(
            generationID: UUID(),
            generationNumber: 4,
            speciesID: .bytebot,
            finalRarity: .normal,
            variantID: .standard,
            mutationID: .neon,
            personalityID: .calm,
            bondEnergy: 0,
            stage: .hatchling,
            completedAt: timestamp)
        let beforeMutation = CompanionGameState(
            speciesID: .bytebot,
            stage: .hatchling,
            rarity: .normal,
            variantID: .standard,
            personalityID: .calm,
            collection: CompanionCollection(
                recentCompletedGenerations: [prismatic]),
            updatedAt: timestamp)
        let afterMutation = CompanionGameState(
            speciesID: .bytebot,
            stage: .hatchling,
            rarity: .normal,
            variantID: .standard,
            personalityID: .calm,
            collection: CompanionCollection(
                mutations: [mutationRecord],
                mutationSynthesisCount: 1,
                recentCompletedGenerations: [mutationPet]),
            updatedAt: timestamp.addingTimeInterval(60))
        let store = CompanionGameStateStore(fileURL: file)

        try await store.save(beforeMutation)
        try await store.save(afterMutation)
        let loaded = try await store.load()

        #expect(loaded.collection.archivedGenerations.contains {
            $0.generationID == prismatic.generationID
        })
        #expect(loaded.collection.archivedGenerations.contains {
            $0.generationID == mutationPet.generationID
        })
        #expect(loaded.collection.mutationSynthesisCount == 1)
        #expect(loaded.isValid())
    }

    @Test("Behavior priority remains celebration warning work waiting sleep idle")
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
        state.lastActiveAt = now.addingTimeInterval(-30)
        #expect(CompanionBehaviorResolver.resolve(
            state: state,
            isWorking: false,
            lowestRemainingQuotaPercent: 50,
            at: now) == .waiting)
        state.lastActiveAt = now.addingTimeInterval(-300)
        #expect(CompanionBehaviorResolver.resolve(
            state: state,
            isWorking: false,
            lowestRemainingQuotaPercent: 50,
            at: now) == .idle)
        state.lastActiveAt = now.addingTimeInterval(-700)
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

    @Test("Published variant roll produces the expected prismatic frequency")
    func variantDistribution() {
        let engine = CompanionGameEngine(calendar: self.calendar)
        var generator = SplitMix64(state: 0x746f_6b65_6e69)
        var prismaticCount = 0
        let samples = 200_000

        for _ in 0..<samples {
            if engine.rollVariant(unitValue: generator.nextUnit()) == .prismatic {
                prismaticCount += 1
            }
        }

        let actual = Double(prismaticCount) / Double(samples)
        #expect(abs(actual - 0.08) < 0.004)
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
