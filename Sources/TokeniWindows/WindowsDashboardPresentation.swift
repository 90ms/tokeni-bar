import Foundation
import TokeniApplication
import TokeniCore

/// Display-only values. Availability gates every numeric field, including stale costs.
public struct WindowsDashboardPresentation: Equatable, Sendable {
    public let rows: [[String]]
    public let summary: String
    public let status: String
    public let refreshing: Bool

    public init(_ presentation: UsageApplicationPresentation, now: Date = .now) {
        self.refreshing = presentation.isRefreshing
        self.rows = presentation.providerDescriptors
            .filter { presentation.enabledProviderIDs.contains($0.id) }
            .map { descriptor in
                guard let provider = presentation.providers.first(where: { $0.id == descriptor.id }) else {
                    return [descriptor.displayName, "Waiting for data", "—", "—", "—", "—"]
                }
                let state: String
                switch provider.availability {
                case .available: state = "Connected"
                case .loading: state = "Refreshing"
                case .stale: state = "Stale · refresh needed"
                case .unavailable: state = "Unavailable"
                case .failed: state = "Refresh failed"
                }
                guard provider.availability == .available else {
                    return [descriptor.displayName, state, "—", "—", "—", "—"]
                }
                let remaining = provider.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—"
                let reset = provider.quotaWindows.compactMap(\.resetsAt).min()
                    .map { WindowsUsageDetailFormatter.relativeReset($0, now: now) } ?? "—"
                return [descriptor.displayName, state, remaining, reset,
                    provider.tokenTotal.map(String.init) ?? "—",
                    provider.costUSD.map { String(format: "$%.2f", $0) } ?? "—"]
            }
        if presentation.enabledProviderIDs.isEmpty {
            self.summary = "Welcome to Tokeni Bar\n\nChoose providers in Settings to start tracking your usage."
        } else if self.rows.isEmpty || presentation.providers.isEmpty {
            self.summary = "Getting ready\n\nWaiting for your first verified usage refresh."
        } else {
            let available = presentation.providers.filter {
                presentation.enabledProviderIDs.contains($0.id) && $0.availability == .available
            }.count
            self.summary = "\(available) of \(self.rows.count) providers available\n\n"
                + "Usage stays local. Missing or outdated values are shown as unavailable."
        }
        if presentation.isRefreshing {
            self.status = "Refreshing provider usage…"
        } else if let updated = presentation.lastRefresh {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            self.status = "Last refresh: \(formatter.string(from: updated))"
        } else {
            self.status = "Waiting for first refresh"
        }
    }
}
