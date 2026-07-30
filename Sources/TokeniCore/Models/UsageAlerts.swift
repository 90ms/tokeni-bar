import Foundation

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
}
