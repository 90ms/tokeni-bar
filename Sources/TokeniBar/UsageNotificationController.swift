import TokeniCore
import AppKit
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class UsageNotificationController: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter
    private let settings: any SettingsStoring
    private var deliveredIdentifiers: [String]

    private static let enabledKey = "usageNotificationsEnabled"
    private static let deliveredIdentifiersKey = "usageNotificationDeliveredIdentifiers"

    init(
        center: UNUserNotificationCenter = .current(),
        settings: any SettingsStoring = UserDefaultsSettingsStore())
    {
        self.center = center
        self.settings = settings
        self.deliveredIdentifiers = settings.stringArray(
            forKey: Self.deliveredIdentifiersKey) ?? []
        super.init()
        self.center.delegate = self
    }

    var isEnabled: Bool {
        self.settings.bool(forKey: Self.enabledKey)
    }

    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            self.settings.set(false, forKey: Self.enabledKey)
            return false
        }

        do {
            let granted = try await self.center.requestAuthorization(options: [.alert, .sound])
            self.settings.set(granted, forKey: Self.enabledKey)
            return granted
        } catch {
            self.settings.set(false, forKey: Self.enabledKey)
            return false
        }
    }

    func process(
        _ snapshots: [ProviderSnapshot],
        history: [UsageHistoryRecord],
        warningThreshold: Int,
        criticalThreshold: Int,
        preferences: UsageAlertPreferences,
        enabledProviderIDs: Set<ProviderID>)
        -> [String]
    {
        guard self.isEnabled else {
            return [AppLocalization.string(
                "settings.notifications.diagnostics.masterDisabled")]
        }
        let alreadyDelivered = Set(self.deliveredIdentifiers)
        let resetCandidates = preferences.resetEnabled
            ? UsageAlertEvaluator.resetCandidates(
                in: snapshots,
                enabledProviderIDs: enabledProviderIDs)
            : []
        let resettingWindows = Set(resetCandidates.map {
            "\($0.providerID.rawValue).\($0.windowID)"
        })
        let candidates = preferences.lowUsageEnabled
            ? UsageAlertEvaluator.candidates(
                in: snapshots,
                warningThreshold: warningThreshold,
                criticalThreshold: criticalThreshold,
                enabledProviderIDs: enabledProviderIDs)
                .filter {
                    !alreadyDelivered.contains($0.identifier)
                        && !resettingWindows.contains(
                            "\($0.providerID.rawValue).\($0.windowID)")
                }
            : []
        var pending: [PendingAlert] = []
        var diagnostics: [String] = []

        for candidate in candidates {
            var body = AppLocalization.format(
                "notification.usageLow.body",
                candidate.windowLabel,
                Int(candidate.remainingPercent.rounded()))
            if let prediction = UsageAlertEvaluator.depletionPrediction(
                for: candidate,
                history: history),
               prediction.exhaustsBeforeReset
            {
                body += " " + AppLocalization.string(
                    "notification.usageLow.depletionRisk")
            }
            pending.append(PendingAlert(
                identifier: candidate.identifier,
                title: AppLocalization.format(
                    "notification.usageLow.title",
                    candidate.providerName),
                body: body))
        }

        if preferences.resetEnabled {
            for candidate in resetCandidates
                where !alreadyDelivered.contains(candidate.identifier)
            {
                pending.append(PendingAlert(
                    identifier: candidate.identifier,
                    title: AppLocalization.format(
                        "notification.resetSoon.title",
                        candidate.providerName),
                    body: AppLocalization.format(
                        "notification.resetSoon.body",
                        candidate.windowLabel,
                        self.timeRemainingText(candidate.timeRemaining),
                        Int(candidate.remainingPercent.rounded()))))
            }
        }

        if preferences.connectionIssuesEnabled {
            let day = Calendar.current.startOfDay(for: .now)
            let dayKey = Int(day.timeIntervalSince1970)
            for snapshot in snapshots
                where enabledProviderIDs.contains(snapshot.id)
                    && snapshot.availability == .failed
            {
                let identifier =
                    "connection.\(snapshot.id.rawValue).\(dayKey)"
                guard !alreadyDelivered.contains(identifier) else { continue }
                pending.append(PendingAlert(
                    identifier: identifier,
                    title: AppLocalization.format(
                        "notification.connection.title",
                        snapshot.descriptor.displayName),
                    body: AppLocalization.string(
                        "notification.connection.body")))
            }
        }

        if pending.isEmpty {
            diagnostics.append(AppLocalization.string(
                "settings.notifications.diagnostics.noCandidate"))
        } else {
            self.deliver(
                pending,
                quietly: self.isQuietHour(preferences: preferences))
            self.deliveredIdentifiers.append(
                contentsOf: pending.map(\.identifier))
            diagnostics = pending.map {
                AppLocalization.format(
                    "settings.notifications.diagnostics.sent",
                    $0.title)
            }
        }

        for snapshot in snapshots
            where enabledProviderIDs.contains(snapshot.id)
                && snapshot.availability == .available
                && snapshot.descriptor.capabilities.supportsQuotaWindows
                && snapshot.quotaWindows.allSatisfy({ $0.resetsAt == nil })
        {
            diagnostics.append(AppLocalization.format(
                "settings.notifications.diagnostics.noReset",
                snapshot.descriptor.displayName))
        }

        if self.deliveredIdentifiers.count > 200 {
            self.deliveredIdentifiers = Array(self.deliveredIdentifiers.suffix(200))
        }
        self.settings.set(self.deliveredIdentifiers, forKey: Self.deliveredIdentifiersKey)
        return Array(diagnostics.prefix(8))
    }

    private func timeRemainingText(_ interval: TimeInterval) -> String {
        let minutes = max(Int(ceil(interval / 60)), 1)
        if minutes >= 60 {
            let hours = max(Int((Double(minutes) / 60).rounded()), 1)
            return AppLocalization.format("notification.time.hours", hours)
        }
        return AppLocalization.format("notification.time.minutes", minutes)
    }

    func sendTest() {
        let content = UNMutableNotificationContent()
        content.title = AppLocalization.string("notification.test.title")
        content.body = AppLocalization.string("notification.test.body")
        content.sound = .default
        self.center.add(UNNotificationRequest(
            identifier: "usage-notification-test-\(UUID().uuidString)",
            content: content,
            trigger: nil))
    }

    func processBudget(
        spentUSD: Double,
        budgetUSD: Double,
        spentText: String,
        budgetText: String,
        enabled: Bool,
        preferences: UsageAlertPreferences)
    {
        guard self.isEnabled, enabled, budgetUSD > 0 else { return }
        let ratio = spentUSD / budgetUSD
        let components = Calendar.current.dateComponents([.year, .month], from: .now)
        let monthKey = String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
        let alreadyDelivered = Set(self.deliveredIdentifiers)

        for threshold in [50, 80, 100] where ratio * 100 >= Double(threshold) {
            let identifier = "budget-\(monthKey)-\(threshold)"
            guard !alreadyDelivered.contains(identifier) else { continue }
            let content = UNMutableNotificationContent()
            content.title = AppLocalization.format("notification.budget.title", threshold)
            content.body = AppLocalization.format(
                "notification.budget.body",
                spentText,
                budgetText)
            content.sound = self.isQuietHour(preferences: preferences)
                ? nil
                : .default
            content.threadIdentifier = "usage-alerts"
            content.userInfo = ["destination": "notifications"]
            self.center.add(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil))
            self.deliveredIdentifiers.append(identifier)
        }
        self.settings.set(self.deliveredIdentifiers, forKey: Self.deliveredIdentifiersKey)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void)
    {
        completionHandler()
        Task { @MainActor in
            NSApplication.shared.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(
                name: .openNotificationSettings,
                object: nil)
        }
    }

    private func deliver(_ alerts: [PendingAlert], quietly: Bool) {
        guard let first = alerts.first else { return }
        let content = UNMutableNotificationContent()
        if alerts.count == 1 {
            content.title = first.title
            content.body = first.body
        } else {
            content.title = AppLocalization.format(
                "notification.summary.title",
                alerts.count)
            content.body = alerts.prefix(3)
                .map { "• \($0.body)" }
                .joined(separator: "\n")
        }
        content.sound = quietly ? nil : .default
        content.threadIdentifier = "usage-alerts"
        content.userInfo = ["destination": "notifications"]
        self.center.add(UNNotificationRequest(
            identifier: alerts.count == 1
                ? first.identifier
                : "\(first.identifier).summary",
            content: content,
            trigger: nil))
    }

    private func isQuietHour(
        preferences: UsageAlertPreferences,
        date: Date = .now) -> Bool
    {
        guard preferences.quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        let start = min(max(preferences.quietHoursStart, 0), 23)
        let end = min(max(preferences.quietHoursEnd, 0), 23)
        if start == end { return true }
        if start < end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end
    }
}

private struct PendingAlert {
    let identifier: String
    let title: String
    let body: String
}

extension Notification.Name {
    static let openNotificationSettings =
        Notification.Name("openNotificationSettings")
}
