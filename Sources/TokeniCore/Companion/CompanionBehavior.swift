import Foundation

public enum CompanionBehavior: String, Codable, CaseIterable, Hashable, Sendable {
    case idle
    case working
    case warning
    case celebrate
    case sleep
}

public enum CompanionBehaviorResolver {
    public static func resolve(
        state: CompanionGameState,
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
