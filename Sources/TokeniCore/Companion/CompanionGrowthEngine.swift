import Foundation

public struct CompanionGrowthEngine: Sendable {
    public let rules: CompanionGrowthRules
    private var calendar: Calendar

    public init(
        rules: CompanionGrowthRules = .standard,
        calendar: Calendar = .current)
    {
        self.rules = rules
        self.calendar = calendar
    }

    public func stage(for state: CompanionState) -> CompanionStage {
        self.rules.stage(for: state.totalXP)
    }

    public func recordActivity(
        isActive: Bool,
        at now: Date = .now,
        in state: inout CompanionState) -> CompanionGrowthEvent
    {
        self.rollDailyCounterIfNeeded(at: now, in: &state)
        guard isActive else { return .none }

        let currentMinute = self.startOfMinute(for: now)
        if state.lastActiveAt.map({ currentMinute > self.startOfMinute(for: $0) }) ?? true {
            state.lastActiveAt = now
            state.updatedAt = now
        }
        guard state.lastAwardedMinute.map({ currentMinute > $0 }) ?? true,
              state.dailyXP < self.rules.dailyXPCap
        else {
            return .none
        }

        let previousStage = self.stage(for: state)
        state.totalXP += 1
        state.dailyXP += 1
        state.lastAwardedMinute = currentMinute
        let currentStage = self.stage(for: state)

        if previousStage != currentStage {
            return .stageChanged(from: previousStage, to: currentStage)
        }
        return .xpAwarded(totalXP: state.totalXP, dailyXP: state.dailyXP)
    }

    public func pat(
        at now: Date = .now,
        celebrationDuration: TimeInterval = 4,
        in state: inout CompanionState)
    {
        state.lastPattedAt = now
        state.celebrationUntil = now.addingTimeInterval(max(celebrationDuration, 0))
        state.updatedAt = now
    }

    private func rollDailyCounterIfNeeded(
        at date: Date,
        in state: inout CompanionState)
    {
        let dateKey = self.dateKey(for: date)
        guard state.dailyXPDate != dateKey else { return }
        state.dailyXPDate = dateKey
        state.dailyXP = 0
    }

    private func startOfMinute(for date: Date) -> Date {
        let components = self.calendar.dateComponents(
            [.era, .year, .month, .day, .hour, .minute],
            from: date)
        return self.calendar.date(from: components) ?? date
    }

    private func dateKey(for date: Date) -> String {
        let components = self.calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0)
    }
}

public enum CompanionBehaviorResolver {
    public static func resolve(
        state: CompanionState,
        isWorking: Bool,
        lowestRemainingQuotaPercent: Double?,
        at now: Date = .now,
        warningThreshold: Double = 10,
        sleepAfter: TimeInterval = 10 * 60) -> CompanionBehavior
    {
        if state.celebrationUntil.map({ $0 > now }) == true {
            return .celebrate
        }
        if lowestRemainingQuotaPercent.map({ $0 <= warningThreshold }) == true {
            return .warning
        }
        if isWorking {
            return .working
        }
        if let lastActiveAt = state.lastActiveAt,
           now.timeIntervalSince(lastActiveAt) >= max(sleepAfter, 0)
        {
            return .sleep
        }
        return .idle
    }
}
