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

        #expect(first.reduce(0) { $0 + $1.amount } == 120)
        #expect(state.starShards == 120)
        #expect(state.rewardedSpeciesIDs == [.bytebot, .cachecat])
        #expect(state.rewardedJourneyCount == 2)
        #expect(state.rewardedFormMilestones == [10])
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
            cosmeticID: .starCrown,
            at: now,
            in: &state)

        #expect(state.starShards == 130)
        #expect(state.unlockedCosmeticIDs == [.starCrown])
        #expect(state.selectedCosmeticID == .starCrown)
        #expect(state.updatedAt == now)
        #expect(throws: CompanionRewardError.cosmeticAlreadyOwned) {
            try engine.purchase(cosmeticID: .starCrown, in: &state)
        }

        try engine.select(cosmeticID: nil, at: now, in: &state)
        #expect(state.selectedCosmeticID == nil)
        try engine.select(cosmeticID: .starCrown, at: now, in: &state)
        #expect(state.selectedCosmeticID == .starCrown)
    }

    @Test("Cosmetics reject insufficient balances and locked selections")
    func cosmeticPurchaseFailures() {
        let engine = CompanionRewardEngine(calendar: self.calendar)
        var state = CompanionRewardState(starShards: 59)

        #expect(throws: CompanionRewardError.insufficientStarShards) {
            try engine.purchase(cosmeticID: .sparkleAura, in: &state)
        }
        #expect(throws: CompanionRewardError.cosmeticNotOwned) {
            try engine.select(cosmeticID: .nightRing, in: &state)
        }
        #expect(state.starShards == 59)
        #expect(state.unlockedCosmeticIDs.isEmpty)
        #expect(state.selectedCosmeticID == nil)
        #expect(state.rewardedRarities.isEmpty)
        #expect(state.rewardedGrowthDateKeys.isEmpty)
        #expect(state.latestRewardedAppVersion == nil)
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
        #expect(state.selectedCosmeticID == nil)
    }

    private func forms(at date: Date) -> [CompanionFormRecord] {
        let combinations: [(CompanionSpeciesID, CompanionGameStage, CompanionRarity)] = [
            (.bytebot, .hatchling, .normal),
            (.bytebot, .hatchling, .rare),
            (.bytebot, .junior, .normal),
            (.bytebot, .junior, .rare),
            (.bytebot, .adult, .normal),
            (.cachecat, .hatchling, .normal),
            (.cachecat, .hatchling, .rare),
            (.cachecat, .junior, .normal),
            (.cachecat, .junior, .rare),
            (.cachecat, .adult, .normal),
        ]
        return combinations.map { combination in
            let (speciesID, stage, rarity) = combination
            return CompanionFormRecord(
                formID: CompanionGameState.formID(
                    speciesID: speciesID,
                    stage: stage,
                    rarity: rarity),
                speciesID: speciesID,
                stage: stage,
                rarity: rarity,
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
