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
}
