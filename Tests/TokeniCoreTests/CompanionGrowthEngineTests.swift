import Foundation
import Testing
@testable import TokeniCore

@Suite("Companion growth")
struct CompanionGrowthEngineTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test("Awards at most one XP per active minute")
    func awardsUniqueActiveMinutes() throws {
        let engine = CompanionGrowthEngine(calendar: self.calendar)
        let first = try #require(self.date("2026-07-26T10:00:05Z"))
        var state = CompanionState(createdAt: first, updatedAt: first)

        let firstEvent = engine.recordActivity(isActive: true, at: first, in: &state)
        let duplicateEvent = engine.recordActivity(
            isActive: true,
            at: first.addingTimeInterval(40),
            in: &state)
        let nextEvent = engine.recordActivity(
            isActive: true,
            at: first.addingTimeInterval(60),
            in: &state)

        #expect(firstEvent == .xpAwarded(totalXP: 1, dailyXP: 1))
        #expect(duplicateEvent == .none)
        #expect(nextEvent == .xpAwarded(totalXP: 2, dailyXP: 2))
        #expect(state.totalXP == 2)
    }

    @Test("Does not backfill XP after the app was not running")
    func doesNotBackfill() throws {
        let engine = CompanionGrowthEngine(calendar: self.calendar)
        let first = try #require(self.date("2026-07-26T10:00:00Z"))
        var state = CompanionState()

        _ = engine.recordActivity(isActive: true, at: first, in: &state)
        _ = engine.recordActivity(
            isActive: true,
            at: first.addingTimeInterval(60 * 60),
            in: &state)

        #expect(state.totalXP == 2)
    }

    @Test("Applies the daily XP cap and resets it on a new day")
    func capsDailyXP() throws {
        let rules = CompanionGrowthRules(
            dailyXPCap: 3,
            hatchXP: 15,
            babyXP: 120,
            adultXP: 360)
        let engine = CompanionGrowthEngine(rules: rules, calendar: self.calendar)
        let first = try #require(self.date("2026-07-26T10:00:00Z"))
        var state = CompanionState()

        for minute in 0..<5 {
            _ = engine.recordActivity(
                isActive: true,
                at: first.addingTimeInterval(TimeInterval(minute * 60)),
                in: &state)
        }
        #expect(state.totalXP == 3)
        #expect(state.dailyXP == 3)

        let nextDay = try #require(self.date("2026-07-27T10:00:00Z"))
        _ = engine.recordActivity(isActive: true, at: nextDay, in: &state)
        #expect(state.totalXP == 4)
        #expect(state.dailyXP == 1)
    }

    @Test("Emits stage changes at configured thresholds")
    func changesStages() throws {
        let rules = CompanionGrowthRules(
            dailyXPCap: 90,
            hatchXP: 2,
            babyXP: 3,
            adultXP: 4)
        let engine = CompanionGrowthEngine(rules: rules, calendar: self.calendar)
        let first = try #require(self.date("2026-07-26T10:00:00Z"))
        var state = CompanionState()

        _ = engine.recordActivity(isActive: true, at: first, in: &state)
        let hatch = engine.recordActivity(
            isActive: true,
            at: first.addingTimeInterval(60),
            in: &state)
        let baby = engine.recordActivity(
            isActive: true,
            at: first.addingTimeInterval(120),
            in: &state)
        let adult = engine.recordActivity(
            isActive: true,
            at: first.addingTimeInterval(180),
            in: &state)

        #expect(hatch == .stageChanged(from: .egg, to: .hatchling))
        #expect(baby == .stageChanged(from: .hatchling, to: .baby))
        #expect(adult == .stageChanged(from: .baby, to: .adult))
    }

    @Test("Behavior follows celebration, warning, work, and sleep priority")
    func resolvesBehaviorPriority() throws {
        let now = try #require(self.date("2026-07-26T10:00:00Z"))
        var state = CompanionState(
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

    private func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
