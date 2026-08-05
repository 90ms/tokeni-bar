import Foundation
import Testing
@testable import TokeniCore

@Suite("Companion rewards")
struct CompanionRewardEngineTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test("Daily attendance and weekly milestones are awarded once")
    func weeklyAttendance() throws {
        let engine = CompanionRewardEngine(calendar: self.calendar)
        let start = try #require(self.date("2027-01-04T12:00:00Z"))
        var state = CompanionRewardState()
        var total = 0

        for offset in 0..<7 {
            let date = try #require(self.calendar.date(
                byAdding: .day,
                value: offset,
                to: start))
            let grants = try engine.checkIn(at: date, in: &state)
            total += grants.reduce(0) { $0 + $1.amount }
        }

        #expect(total == 130)
        #expect(state.starShards == 130)
        #expect(engine.attendanceCountThisWeek(
            at: start,
            in: state) == 7)
        let finalDate = try #require(self.calendar.date(
            byAdding: .day,
            value: 6,
            to: start))
        #expect(engine.attendanceStatus(
            at: finalDate,
            in: state) == .claimed)
        #expect(throws: CompanionRewardError.alreadyClaimed) {
            try engine.checkIn(at: finalDate, in: &state)
        }
    }

    @Test("Twenty monthly check-ins include the monthly reward")
    func monthlyAttendance() throws {
        let engine = CompanionRewardEngine(calendar: self.calendar)
        let start = try #require(self.date("2027-03-01T12:00:00Z"))
        var state = CompanionRewardState()
        var finalGrants: [CompanionRewardGrant] = []

        for offset in 0..<20 {
            let date = try #require(self.calendar.date(
                byAdding: .day,
                value: offset,
                to: start))
            finalGrants = try engine.checkIn(at: date, in: &state)
        }

        #expect(engine.attendanceCountThisMonth(
            at: start,
            in: state) == 20)
        #expect(finalGrants.contains {
            $0.reason == .monthlyAttendance(days: 20) && $0.amount == 50
        })
    }

    @Test("A date rollback cannot create another attendance claim")
    func clockRollback() throws {
        let engine = CompanionRewardEngine(calendar: self.calendar)
        let later = try #require(self.date("2027-01-06T12:00:00Z"))
        let earlier = try #require(self.date("2027-01-05T12:00:00Z"))
        var state = CompanionRewardState()

        _ = try engine.checkIn(at: later, in: &state)

        #expect(engine.attendanceStatus(
            at: earlier,
            in: state) == .clockRollback)
        #expect(throws: CompanionRewardError.clockRollback) {
            try engine.checkIn(at: earlier, in: &state)
        }
        #expect(state.attendanceRecords.count == 1)
        #expect(state.starShards == 10)
    }

    @Test("Collection and journey rewards reconcile idempotently")
    func collectionRewards() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let forms = self.forms(at: now)
        let collection = CompanionCollection(
            forms: forms,
            totalCompletedGenerations: 2)
        let engine = CompanionRewardEngine(calendar: self.calendar)
        var state = CompanionRewardState()

        let first = engine.reconcile(
            collection: collection,
            at: now,
            in: &state)
        let repeated = engine.reconcile(
            collection: collection,
            at: now,
            in: &state)

        #expect(first.reduce(0) { $0 + $1.amount } == 220)
        #expect(state.starShards == 220)
        #expect(state.rewardedSpeciesIDs == Set(CompanionSpeciesID.allCases))
        #expect(state.rewardedVariantIDs == [.prismatic])
        #expect(state.rewardedJourneyCount == 2)
        #expect(state.rewardedFormMilestones == [5])
        #expect(repeated.isEmpty)
    }

    @Test("Mutation discoveries grant shards once")
    func mutationRewards() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let mutation = CompanionMutationRecord(
            speciesID: .bytebot,
            mutationID: .neon,
            firstDiscoveredAt: now,
            lastSynthesizedAt: now)
        let collection = CompanionCollection(mutations: [mutation])
        let engine = CompanionRewardEngine(calendar: self.calendar)
        var state = CompanionRewardState()

        let first = engine.reconcile(
            collection: collection,
            at: now,
            in: &state)
        let repeated = engine.reconcile(
            collection: collection,
            at: now,
            in: &state)

        #expect(first == [CompanionRewardGrant(
            amount: 30,
            reason: .mutationDiscovered(
                speciesID: .bytebot,
                mutationID: .neon))])
        #expect(state.starShards == 30)
        #expect(state.rewardedMutationKeys == [mutation.id])
        #expect(repeated.isEmpty)
    }

    @Test("Verified growth and stable release gifts are awarded once")
    func recurringRewards() throws {
        let engine = CompanionRewardEngine(calendar: self.calendar)
        let firstDay = try #require(self.date("2027-01-04T12:00:00Z"))
        let secondDay = try #require(self.date("2027-01-05T12:00:00Z"))
        var state = CompanionRewardState()

        #expect(engine.rewardVerifiedGrowth(
            energy: 1,
            at: firstDay,
            in: &state)?.amount == 5)
        #expect(engine.rewardVerifiedGrowth(
            energy: 100,
            at: firstDay,
            in: &state) == nil)
        #expect(engine.rewardVerifiedGrowth(
            energy: 1,
            at: secondDay,
            in: &state)?.amount == 5)

        #expect(engine.claimReleaseGift(
            appVersion: "1.2.0",
            at: firstDay,
            in: &state)?.amount == 20)
        #expect(engine.claimReleaseGift(
            appVersion: "1.2.0",
            at: secondDay,
            in: &state) == nil)
        #expect(engine.claimReleaseGift(
            appVersion: "1.1.0",
            at: secondDay,
            in: &state) == nil)
        #expect(engine.claimReleaseGift(
            appVersion: "1.3.0-beta.1",
            at: secondDay,
            in: &state) == nil)
        #expect(engine.claimReleaseGift(
            appVersion: "1.3.0",
            at: secondDay,
            in: &state)?.amount == 20)
        #expect(state.starShards == 50)
    }

    @Test("Cosmetics spend shards once and can be equipped")
    func cosmeticPurchase() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let engine = CompanionRewardEngine(calendar: self.calendar)
        var state = CompanionRewardState(starShards: 250)

        try engine.purchase(
            cosmeticID: .terminalNight,
            at: now,
            in: &state)

        #expect(state.starShards == 90)
        #expect(state.unlockedCosmeticIDs == [.terminalNight])
        #expect(state.selectedCosmeticIDs == [.terminalNight])
        #expect(state.updatedAt == now)
        #expect(throws: CompanionRewardError.cosmeticAlreadyOwned) {
            try engine.purchase(cosmeticID: .terminalNight, in: &state)
        }

        engine.unequip(slot: .background, at: now, in: &state)
        #expect(state.selectedCosmeticIDs.isEmpty)
        try engine.select(cosmeticID: .terminalNight, at: now, in: &state)
        #expect(state.selectedCosmeticIDs == [.terminalNight])

        state.starShards = 500
        try engine.purchase(cosmeticID: .sparkleAura, at: now, in: &state)
        #expect(state.selectedCosmeticIDs == [.terminalNight, .sparkleAura])
        try engine.purchase(cosmeticID: .pixelHearts, at: now, in: &state)
        #expect(state.selectedCosmeticIDs == [.terminalNight, .pixelHearts])
        try engine.purchase(cosmeticID: .azurePalette, at: now, in: &state)
        #expect(state.selectedCosmeticIDs == [
            .terminalNight,
            .pixelHearts,
            .azurePalette,
        ])
        try engine.purchase(cosmeticID: .violetPalette, at: now, in: &state)
        #expect(state.selectedCosmeticIDs == [
            .terminalNight,
            .pixelHearts,
            .violetPalette,
        ])
    }

    @Test("Cosmetics reject insufficient balances and locked selections")
    func cosmeticPurchaseFailures() {
        let engine = CompanionRewardEngine(calendar: self.calendar)
        var state = CompanionRewardState(starShards: 59)

        #expect(throws: CompanionRewardError.insufficientStarShards) {
            try engine.purchase(cosmeticID: .sparkleAura, in: &state)
        }
        #expect(throws: CompanionRewardError.cosmeticNotOwned) {
            try engine.select(cosmeticID: .sparkleAura, in: &state)
        }
        #expect(state.starShards == 59)
        #expect(state.unlockedCosmeticIDs.isEmpty)
        #expect(state.selectedCosmeticIDs.isEmpty)
        #expect(state.rewardedRarities.isEmpty)
        #expect(state.rewardedVariantIDs.isEmpty)
        #expect(state.rewardedGrowthDateKeys.isEmpty)
        #expect(state.latestRewardedAppVersion == nil)
    }

    @Test("Removed cosmetics are absent and legacy night rings are discarded")
    func removedNightRing() throws {
        let engine = CompanionRewardEngine()
        #expect(!engine.cosmetics.contains { $0.id == .nightRing })

        var state = CompanionRewardState(
            unlockedCosmeticIDs: [.nightRing],
            selectedCosmeticIDs: [.nightRing])
        #expect(state.unlockedCosmeticIDs.isEmpty)
        #expect(state.selectedCosmeticIDs.isEmpty)
        #expect(throws: CompanionRewardError.unknownCosmetic) {
            try engine.purchase(cosmeticID: .nightRing, in: &state)
        }
    }

    @Test("Bond milestones grant each booster and cosmetic once")
    func bondMilestones() {
        let engine = CompanionRewardEngine(calendar: self.calendar)
        let generationID = UUID()
        var state = CompanionRewardState()

        engine.reconcileBondMilestones(
            generationID: generationID,
            bondEnergy: 800,
            in: &state)
        engine.reconcileBondMilestones(
            generationID: generationID,
            bondEnergy: 800,
            in: &state)

        #expect(state.energyBoosterInventory[.double30Minutes] == 1)
        #expect(state.energyBoosterInventory[.triple20Minutes] == 1)
        #expect(state.energyBoosterInventory[.quintuple10Minutes] == 1)
        #expect(state.unlockedCosmeticIDs.contains(.fireflyAura))
        #expect(state.unlockedCosmeticIDs.contains(.orbitAura))
        #expect(state.rewardedBondMilestoneIDs.count == 4)
    }

    @Test("Energy boosters are consumed once and expire")
    func energyBoosterActivation() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let engine = CompanionRewardEngine(calendar: self.calendar)
        var state = CompanionRewardState(starShards: 150)

        try engine.purchaseEnergyBooster(
            .triple20Minutes,
            at: now,
            in: &state)

        try engine.activateEnergyBooster(
            .triple20Minutes,
            at: now,
            in: &state)

        #expect(state.energyBoosterInventory[.triple20Minutes] == 0)
        #expect(state.starShards == 0)
        #expect(engine.energyMultiplier(at: now, in: state) == 3)
        #expect(engine.energyMultiplier(
            at: now.addingTimeInterval(20 * 60),
            in: state) == 1)
        #expect(throws: CompanionRewardError.energyBoosterAlreadyActive) {
            try engine.activateEnergyBooster(
                .triple20Minutes,
                at: now.addingTimeInterval(1),
                in: &state)
        }
    }

    @Test("Reward state persists without companion or provider data")
    func persistence() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "rewards.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CompanionRewardStateStore(fileURL: file)
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let state = CompanionRewardState(
            starShards: 42,
            rewardedSpeciesIDs: [.bytebot],
            rewardedJourneyCount: 1,
            updatedAt: updatedAt)

        try await store.save(state)
        let loaded = try await store.load()

        #expect(loaded == state)
        let text = try #require(String(data: Data(contentsOf: file), encoding: .utf8))
        #expect(!text.contains("provider"))
        #expect(!text.contains("token"))
        #expect(!text.contains("prompt"))
    }

    @Test("Version one reward state migrates without losing shards")
    func legacyPersistence() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "rewards.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let legacy = """
        {
          "schemaVersion" : 1,
          "starShards" : 175,
          "attendanceRecords" : [],
          "awardedMilestoneIDs" : [],
          "rewardedSpeciesIDs" : [],
          "rewardedJourneyCount" : 0,
          "rewardedFormMilestones" : [],
          "updatedAt" : "2027-01-15T08:00:00Z"
        }
        """
        try Data(legacy.utf8).write(to: file)

        let state = try await CompanionRewardStateStore(fileURL: file).load()

        #expect(state.schemaVersion == CompanionRewardState.currentSchemaVersion)
        #expect(state.starShards == 175)
        #expect(state.unlockedCosmeticIDs.isEmpty)
        #expect(state.selectedCosmeticIDs.isEmpty)
    }

    @Test("Single equipped cosmetic migrates into its slot")
    func legacyCosmeticSelection() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let file = directory.appending(path: "rewards.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let legacy = """
        {
          "schemaVersion" : 3,
          "starShards" : 55,
          "attendanceRecords" : [],
          "awardedMilestoneIDs" : [],
          "rewardedSpeciesIDs" : [],
          "rewardedJourneyCount" : 0,
          "rewardedFormMilestones" : [],
          "unlockedCosmeticIDs" : ["sparkleAura"],
          "selectedCosmeticID" : "sparkleAura",
          "updatedAt" : "2027-01-15T08:00:00Z"
        }
        """
        try Data(legacy.utf8).write(to: file)

        let state = try await CompanionRewardStateStore(fileURL: file).load()

        #expect(state.unlockedCosmeticIDs == [.sparkleAura])
        #expect(state.selectedCosmeticIDs == [.sparkleAura])
    }

    @Test("Level milestones replace bond rewards without duplicate grants")
    func levelMilestones() {
        let engine = CompanionRewardEngine()
        let generationID = UUID()
        var state = CompanionRewardState()

        engine.reconcileLevelMilestones(
            generationID: generationID,
            level: 25,
            in: &state)
        engine.reconcileLevelMilestones(
            generationID: generationID,
            level: 25,
            in: &state)

        #expect(state.energyBoosterInventory[.double30Minutes] == 1)
        #expect(state.energyBoosterInventory[.triple20Minutes] == 1)
        #expect(state.energyBoosterInventory[.quintuple10Minutes] == 1)
        #expect(state.unlockedCosmeticIDs.contains(.fireflyAura))
        #expect(state.unlockedCosmeticIDs.contains(.orbitAura))
    }

    @Test("Levels 30 and above grant recurring shards once per ten levels")
    func recurringLevelMilestones() {
        let engine = CompanionRewardEngine()
        let generationID = UUID()
        var state = CompanionRewardState()

        engine.reconcileLevelMilestones(
            generationID: generationID,
            level: 49,
            in: &state)
        engine.reconcileLevelMilestones(
            generationID: generationID,
            level: 50,
            in: &state)
        engine.reconcileLevelMilestones(
            generationID: generationID,
            level: 50,
            in: &state)

        #expect(state.starShards == 30)
        #expect(CompanionRewardEngine.nextRecurringRewardLevel(after: 29) == 30)
        #expect(CompanionRewardEngine.nextRecurringRewardLevel(after: 30) == 40)
        #expect(CompanionRewardEngine.nextRecurringRewardLevel(after: 49) == 50)
    }

    @Test("Imported pets skip historical rewards but earn future milestones")
    func importedLevelBaseline() {
        let engine = CompanionRewardEngine()
        let generationID = UUID()
        var state = CompanionRewardState()

        engine.suppressImportedLevelBackfill(
            generationID: generationID,
            level: 35,
            in: &state)
        engine.reconcileLevelMilestones(
            generationID: generationID,
            level: 35,
            in: &state)
        #expect(state.starShards == 0)
        #expect(state.energyBoosterInventory.isEmpty)

        engine.reconcileLevelMilestones(
            generationID: generationID,
            level: 40,
            in: &state)
        #expect(state.starShards == 10)
    }

    @Test("Egg shop shard transactions are idempotent")
    func eggTransactions() throws {
        let engine = CompanionRewardEngine()
        let purchaseID = UUID()
        let saleID = UUID()
        var state = CompanionRewardState(starShards: 100)

        try engine.spendStarShards(
            90,
            transactionID: purchaseID,
            in: &state)
        try engine.spendStarShards(
            90,
            transactionID: purchaseID,
            in: &state)
        engine.grantStarShards(30, transactionID: saleID, in: &state)
        engine.grantStarShards(30, transactionID: saleID, in: &state)

        #expect(state.starShards == 40)
    }

    private func forms(at date: Date) -> [CompanionFormRecord] {
        let combinations: [(CompanionSpeciesID, CompanionVariantID)] = [
            (.bytebot, .standard),
            (.bytebot, .prismatic),
            (.cachecat, .standard),
            (.stackfox, .standard),
            (.promptpup, .standard),
            (.nullslime, .standard),
        ]
        return combinations.map { combination in
            let (speciesID, variantID) = combination
            let rarity = CompanionVariantRegistry.definition(
                for: variantID).assetRarity
            return CompanionFormRecord(
                formID: CompanionGameState.variantFormID(
                    speciesID: speciesID,
                    stage: .adult,
                    variantID: variantID),
                speciesID: speciesID,
                stage: .adult,
                rarity: rarity,
                variantID: variantID,
                unlockKind: .encountered,
                firstUnlockedAt: date,
                lastEncounteredAt: date,
                encounterCount: 1)
        }
    }

    private func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
