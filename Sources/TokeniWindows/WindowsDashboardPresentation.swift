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
                    return [descriptor.displayName, WindowsLocalization.message("Waiting for data"), "—", "—", "—", "—"]
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
                    return [descriptor.displayName, WindowsLocalization.message(state), "—", "—", "—", "—"]
                }
                let remaining = provider.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—"
                let reset = provider.quotaWindows.compactMap(\.resetsAt).min()
                    .map { WindowsUsageDetailFormatter.relativeReset($0, now: now) } ?? "—"
                return [descriptor.displayName, WindowsLocalization.message(state), remaining, reset,
                    provider.tokenTotal.map(String.init) ?? "—",
                    provider.costUSD.map { String(format: "$%.2f", $0) } ?? "—"]
            }
        if presentation.enabledProviderIDs.isEmpty {
            self.summary = WindowsLocalization.text("Welcome to Tokeni Bar\n\nChoose providers in Settings to start tracking your usage.", "Tokeni Bar에 오신 것을 환영합니다\n\n설정에서 사용할 제공자를 선택하면 사용량을 확인할 수 있습니다.")
        } else if self.rows.isEmpty || presentation.providers.isEmpty {
            self.summary = WindowsLocalization.text("Getting ready\n\nWaiting for your first verified usage refresh.", "준비 중\n\n첫 사용량 갱신을 기다리고 있습니다.")
        } else {
            let available = presentation.providers.filter {
                presentation.enabledProviderIDs.contains($0.id) && $0.availability == .available
            }.count
            self.summary = WindowsLocalization.text("\(available) of \(self.rows.count) providers available\n\nUsage stays local. Missing or outdated values are shown as unavailable.", "제공자 \(self.rows.count)개 중 \(available)개 사용 가능\n\n사용량은 로컬에 보관됩니다. 없거나 오래된 값은 현재 수치로 표시하지 않습니다.")
        }
        if presentation.isRefreshing {
            self.status = WindowsLocalization.message("Refreshing provider usage…")
        } else if let updated = presentation.lastRefresh {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            self.status = WindowsLocalization.text("Last refresh: \(formatter.string(from: updated))", "마지막 갱신: \(formatter.string(from: updated))")
        } else {
            self.status = WindowsLocalization.message("Waiting for first refresh")
        }
    }
}
