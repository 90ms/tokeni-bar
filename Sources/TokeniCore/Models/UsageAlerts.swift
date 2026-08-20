import Foundation

public struct UsageAlertPreferences: Equatable, Sendable {
    public let lowUsageEnabled: Bool
    public let resetEnabled: Bool
    public let connectionIssuesEnabled: Bool
    public let quietHoursEnabled: Bool
    public let quietHoursStart: Int
    public let quietHoursEnd: Int

    public init(
        lowUsageEnabled: Bool,
        resetEnabled: Bool,
        connectionIssuesEnabled: Bool,
        quietHoursEnabled: Bool,
        quietHoursStart: Int,
        quietHoursEnd: Int)
    {
        self.lowUsageEnabled = lowUsageEnabled
        self.resetEnabled = resetEnabled
        self.connectionIssuesEnabled = connectionIssuesEnabled
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
    }
}

public struct UsageAlertCandidate: Hashable, Sendable {
    public let providerID: ProviderID
    public let providerName: String
    public let windowID: String
    public let windowLabel: String
    public let remainingPercent: Double
    public let threshold: Int
    public let resetsAt: Date?

    public var identifier: String {
        let resetKey = self.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "no-reset"
        return [
            self.providerID.rawValue,
            self.windowID,
            String(self.threshold),
            resetKey,
        ].joined(separator: ".")
    }
}

public struct UsageResetAlertCandidate: Hashable, Sendable {
    public let providerID: ProviderID
    public let providerName: String
    public let windowID: String
    public let windowLabel: String
    public let remainingPercent: Double
    public let resetsAt: Date
    public let timeRemaining: TimeInterval

    public var identifier: String {
        [
            "reset",
            self.providerID.rawValue,
            self.windowID,
            String(Int(self.resetsAt.timeIntervalSince1970)),
        ].joined(separator: ".")
    }
}

public struct UsageDepletionPrediction: Hashable, Sendable {
    public let exhaustsBeforeReset: Bool
    public let estimatedExhaustionAt: Date
    public let observedInterval: TimeInterval

    public init(
        exhaustsBeforeReset: Bool,
        estimatedExhaustionAt: Date,
        observedInterval: TimeInterval)
    {
        self.exhaustsBeforeReset = exhaustsBeforeReset
        self.estimatedExhaustionAt = estimatedExhaustionAt
        self.observedInterval = observedInterval
    }
}

public enum UsageAlertEvaluator {
    public static func candidates(
        in snapshots: [ProviderSnapshot],
        warningThreshold: Int = 30,
        criticalThreshold: Int = 10,
        enabledProviderIDs: Set<ProviderID>? = nil) -> [UsageAlertCandidate]
    {
        let thresholds = [criticalThreshold, warningThreshold].sorted()
        return snapshots.flatMap { snapshot -> [UsageAlertCandidate] in
            guard snapshot.availability == .available,
                  enabledProviderIDs?.contains(snapshot.id) != false
            else { return [] }
            return snapshot.quotaWindows.compactMap { window in
                guard window.kind != .context else { return nil }
                guard let threshold = thresholds.first(where: {
                    window.remainingPercent <= Double($0)
                }) else { return nil }
                return UsageAlertCandidate(
                    providerID: snapshot.id,
                    providerName: snapshot.descriptor.displayName,
                    windowID: window.id,
                    windowLabel: window.label,
                    remainingPercent: window.remainingPercent,
                    threshold: threshold,
                    resetsAt: window.resetsAt)
            }
        }
    }

    public static func resetCandidates(
        in snapshots: [ProviderSnapshot],
        now: Date = .now,
        leadTime: TimeInterval = 60 * 60,
        enabledProviderIDs: Set<ProviderID>? = nil) -> [UsageResetAlertCandidate]
    {
        guard leadTime > 0 else { return [] }
        return snapshots.flatMap { snapshot -> [UsageResetAlertCandidate] in
            guard snapshot.availability == .available,
                  enabledProviderIDs?.contains(snapshot.id) != false
            else { return [] }
            return snapshot.quotaWindows.compactMap { window in
                guard window.kind != .context,
                      let resetsAt = window.resetsAt
                else { return nil }
                let timeRemaining = resetsAt.timeIntervalSince(now)
                guard timeRemaining > 0, timeRemaining <= leadTime else {
                    return nil
                }
                return UsageResetAlertCandidate(
                    providerID: snapshot.id,
                    providerName: snapshot.descriptor.displayName,
                    windowID: window.id,
                    windowLabel: window.label,
                    remainingPercent: window.remainingPercent,
                    resetsAt: resetsAt,
                    timeRemaining: timeRemaining)
            }
        }
    }

    public static func depletionPrediction(
        for candidate: UsageAlertCandidate,
        history: [UsageHistoryRecord],
        now: Date = .now,
        minimumObservationInterval: TimeInterval = 15 * 60)
        -> UsageDepletionPrediction?
    {
        guard let resetsAt = candidate.resetsAt, resetsAt > now else {
            return nil
        }
        let matchingHistory = history.filter {
            $0.providerID == candidate.providerID
                && $0.timestamp <= now
                && $0.timestamp >= now.addingTimeInterval(-24 * 60 * 60)
                && $0.windows.contains { $0.id == candidate.windowID }
        }
        guard let last = matchingHistory.last,
              let lastRemaining = last.windows.first(where: {
                  $0.id == candidate.windowID
              })?.remainingPercent
        else { return nil }

        let interval = now.timeIntervalSince(last.timestamp)
        let consumed = lastRemaining - candidate.remainingPercent
        guard interval >= minimumObservationInterval, consumed >= 1 else {
            return nil
        }
        let consumptionPerSecond = consumed / interval
        let secondsToExhaustion =
            max(candidate.remainingPercent, 0) / consumptionPerSecond
        let estimatedExhaustionAt =
            now.addingTimeInterval(secondsToExhaustion)
        return UsageDepletionPrediction(
            exhaustsBeforeReset: estimatedExhaustionAt < resetsAt,
            estimatedExhaustionAt: estimatedExhaustionAt,
            observedInterval: interval)
    }
}
