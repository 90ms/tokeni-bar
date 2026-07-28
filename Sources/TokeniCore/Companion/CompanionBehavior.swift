import Foundation

public enum CompanionBehavior: String, Codable, CaseIterable, Hashable, Sendable {
    case idle
    case working
    case waiting
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
        waitingFor: TimeInterval = 2 * 60,
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
        if let lastActiveAt = state.lastActiveAt {
            let inactiveFor = now.timeIntervalSince(lastActiveAt)
            if inactiveFor >= max(sleepAfter, 0) {
                return .sleep
            }
            if inactiveFor >= 0, inactiveFor < max(waitingFor, 0) {
                return .waiting
            }
        }
        return .idle
    }
}
