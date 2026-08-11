import Foundation
import Testing
@testable import TokeniCore

@Suite("Companion benefits")
struct CompanionBenefitEngineTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test("Every registered species owns one benefit")
    func registryCoverage() {
        #expect(
            Set(CompanionBenefitRegistry.definitions.map(\.speciesID))
                == Set(CompanionSpeciesID.allCases))
        #expect(
            Set(CompanionBenefitRegistry.definitions.map(\.id)).count
                == CompanionBenefitRegistry.definitions.count)
        #expect(CompanionSpeciesID.totalRegisteredFormCount == 75)
        #expect(CompanionSpeciesID.totalCollectibleVariantCount == 15)
    }

    @Test("Passive slots unlock permanently at collection thresholds")
    func slotThresholds() {
        let engine = CompanionBenefitEngine(calendar: self.calendar)
        var state = CompanionBenefitState()

        #expect(engine.unlockedSlotCount(for: 0) == 1)
        #expect(engine.unlockedSlotCount(for: 29) == 1)
        #expect(engine.unlockedSlotCount(for: 30) == 2)
        #expect(engine.unlockedSlotCount(for: 60) == 3)
        #expect(engine.unlockedSlotCount(for: 90) == 4)
        #expect(engine.unlockedSlotCount(for: 120) == 5)

        engine.reconcileSlots(unlockedFormCount: 60, in: &state)
        engine.reconcileSlots(unlockedFormCount: 10, in: &state)
        #expect(state.unlockedPassiveSlotCount == 3)
    }

    @Test("Passive assignment requires archived passive pets and unique species")
    func passiveAssignmentValidation() throws {
        let engine = CompanionBenefitEngine(calendar: self.calendar)
        let stackOne = self.archived(.stackfox, rarity: .rare, number: 1)
        let stackTwo = self.archived(.stackfox, rarity: .epic, number: 2)
        let prompt = self.archived(.promptpup, rarity: .normal, number: 3)
        let active = self.archived(.bytebot, rarity: .legendary, number: 4)
        let archived = [stackOne, stackTwo, prompt, active]
        var state = CompanionBenefitState(unlockedPassiveSlotCount: 3)

        try engine.assignPassive(
            generationID: stackOne.generationID,
            to: 0,
            archivedCompanions: archived,
            in: &state)
        try engine.assignPassive(
            generationID: prompt.generationID,
            to: 1,
            archivedCompanions: archived,
            in: &state)

        #expect(throws: CompanionBenefitError.duplicateSpecies) {
            try engine.assignPassive(
                generationID: stackTwo.generationID,
                to: 2,
                archivedCompanions: archived,
                in: &state)
        }
        #expect(throws: CompanionBenefitError.passiveCompanionRequired) {
            try engine.assignPassive(
                generationID: active.generationID,
                to: 2,
                archivedCompanions: archived,
                in: &state)
        }
        #expect(engine.activePassives(
            archivedCompanions: archived,
            state: state).count == 2)
    }

    @Test("ByteBot converts verified base energy once and respects its daily cap")
    func tokenOptimization() {
        let engine = CompanionBenefitEngine(calendar: self.calendar)
        let generationID = UUID()
        let companion = CompanionBenefitCompanion(
            generationID: generationID,
            speciesID: .bytebot,
            rarity: .rare)
        let awardID = UUID()
        var state = CompanionBenefitState(dailyDateKey: "2027-01-15")
        let now = self.date("2027-01-15T12:00:00Z")

        engine.processVerifiedBaseEnergy(
            62,
            sourceAwardID: awardID,
            activeCompanion: companion,
            at: now,
            in: &state)
        engine.processVerifiedBaseEnergy(
            62,
            sourceAwardID: awardID,
            activeCompanion: companion,
            at: now,
            in: &state)

        #expect(state.tokenOptimizationGrantedToday == 15)
        #expect(state.pendingEnergyBonuses.map(\.amount) == [15])
        #expect(state.progress.first?.baseEnergyRemainder == 2)
        #expect(state.processedGrowthAwardIDs == [awardID])
    }

    @Test("CacheCat grants only time spent together and rejects clock rollback")
    func starlightCache() {
        let engine = CompanionBenefitEngine(calendar: self.calendar)
        let companion = CompanionBenefitCompanion(
            generationID: UUID(),
            speciesID: .cachecat,
            rarity: .legendary)
        let start = self.date("2027-01-15T00:00:00Z")
        let fourHours = self.date("2027-01-15T04:00:00Z")
        let rollback = self.date("2027-01-15T03:00:00Z")
        var state = CompanionBenefitState(dailyDateKey: "2027-01-15")

        #expect(engine.settleActiveTime(
            activeCompanion: companion,
            at: start,
            in: &state) == 0)
        #expect(engine.settleActiveTime(
            activeCompanion: companion,
            at: fourHours,
            in: &state) == 1)
        #expect(engine.settleActiveTime(
            activeCompanion: companion,
            at: rollback,
            in: &state) == 0)
        #expect(state.starlightCacheGrantedToday == 1)
        #expect(state.latestObservedAt == fourHours)
    }

    @Test("Reward absorption carries fractional Star Shards without recursion")
    func rewardAbsorption() {
        let engine = CompanionBenefitEngine(calendar: self.calendar)
        let eligible = [
            CompanionRewardGrant(
                amount: 3,
                reason: .collectionForms(10)),
        ]
        let ineligible = [
            CompanionRewardGrant(
                amount: 100,
                reason: .benefit(.rewardAbsorption)),
        ]
        var state = CompanionBenefitState()

        #expect(engine.rewardAbsorptionBonus(
            for: eligible,
            basisPoints: 1_500,
            in: &state) == 0)
        #expect(state.rewardBonusRemainderBasisPoints == 4_500)
        #expect(engine.rewardAbsorptionBonus(
            for: eligible,
            basisPoints: 1_500,
            in: &state) == 0)
        #expect(engine.rewardAbsorptionBonus(
            for: eligible,
            basisPoints: 1_500,
            in: &state) == 1)
        #expect(engine.rewardAbsorptionBonus(
            for: ineligible,
            basisPoints: 1_500,
            in: &state) == 0)
    }

    @Test("Legacy cost discount rounds up without changing a visual variant")
    func actionBenefits() throws {
        let engine = CompanionGameEngine(calendar: self.calendar)
        var discounted = CompanionGameState(
            growthEnergy: 440,
            growthDateKey: "2027-01-15")

        _ = try engine.hatch(
            speciesUnitValue: 0,
            variantUnitValue: 0,
            costDiscountBasisPoints: 1_200,
            at: self.date("2027-01-15T12:00:00Z"),
            in: &discounted)
        #expect(discounted.growthSpentToday == 440)

        var cheered = CompanionGameState(
            growthEnergy: 500,
            growthDateKey: "2027-01-15")
        _ = try engine.hatch(
            speciesUnitValue: 0,
            variantUnitValue: 0,
            at: self.date("2027-01-15T12:00:00Z"),
            in: &cheered)
        #expect(cheered.rarity == .normal)
        #expect(cheered.variantID == .standard)
    }

    @Test("Benefit state persists only companion-safe progress")
    func privateStatePersistence() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "companion-benefits.json")
        let store = CompanionBenefitStateStore(fileURL: fileURL)
        let generationID = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let state = CompanionBenefitState(
            progress: [CompanionBenefitProgress(
                generationID: generationID,
                baseEnergyRemainder: 2)],
            updatedAt: timestamp)

        try await store.save(state)
        let data = try Data(contentsOf: fileURL)
        let text = try #require(String(data: data, encoding: .utf8))
        let loaded = try await store.load()

        #expect(!text.localizedCaseInsensitiveContains("provider"))
        #expect(!text.localizedCaseInsensitiveContains("tokenTotal"))
        #expect(loaded == state)
        try? FileManager.default.removeItem(at: directory)
    }

    private func archived(
        _ speciesID: CompanionSpeciesID,
        rarity: CompanionRarity,
        number: Int) -> CompletedCompanionGeneration
    {
        CompletedCompanionGeneration(
            generationID: UUID(),
            generationNumber: number,
            speciesID: speciesID,
            finalRarity: rarity,
            bondEnergy: 0,
            completedAt: Date(timeIntervalSince1970: 1_800_000_000))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
