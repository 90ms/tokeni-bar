import TokeniCore
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class UsageNotificationController: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private var deliveredIdentifiers: [String]

    private static let enabledKey = "usageNotificationsEnabled"
    private static let deliveredIdentifiersKey = "usageNotificationDeliveredIdentifiers"

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard)
    {
        self.center = center
        self.defaults = defaults
        self.deliveredIdentifiers = defaults.stringArray(forKey: Self.deliveredIdentifiersKey) ?? []
        super.init()
        self.center.delegate = self
    }

    var isEnabled: Bool {
        self.defaults.bool(forKey: Self.enabledKey)
    }

    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            self.defaults.set(false, forKey: Self.enabledKey)
            return false
        }

        do {
            let granted = try await self.center.requestAuthorization(options: [.alert, .sound])
            self.defaults.set(granted, forKey: Self.enabledKey)
            return granted
        } catch {
            self.defaults.set(false, forKey: Self.enabledKey)
            return false
        }
    }

    func process(
        _ snapshots: [ProviderSnapshot],
        warningThreshold: Int,
        criticalThreshold: Int,
        enabledProviderIDs: Set<ProviderID>)
    {
        guard self.isEnabled else { return }
        let alreadyDelivered = Set(self.deliveredIdentifiers)
        let candidates = UsageAlertEvaluator.candidates(
            in: snapshots,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold,
            enabledProviderIDs: enabledProviderIDs)
            .filter { !alreadyDelivered.contains($0.identifier) }

        for candidate in candidates {
            let content = UNMutableNotificationContent()
            content.title = AppLocalization.format("notification.usageLow.title", candidate.providerName)
            content.body = AppLocalization.format(
                "notification.usageLow.body",
                candidate.windowLabel,
                Int(candidate.remainingPercent.rounded()))
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: candidate.identifier,
                content: content,
                trigger: nil)
            self.center.add(request)
            self.deliveredIdentifiers.append(candidate.identifier)
        }

        if self.deliveredIdentifiers.count > 200 {
            self.deliveredIdentifiers = Array(self.deliveredIdentifiers.suffix(200))
        }
        self.defaults.set(self.deliveredIdentifiers, forKey: Self.deliveredIdentifiersKey)
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
        budgetText: String)
    {
        guard self.isEnabled, budgetUSD > 0 else { return }
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
            content.sound = .default
            self.center.add(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil))
            self.deliveredIdentifiers.append(identifier)
        }
        self.defaults.set(self.deliveredIdentifiers, forKey: Self.deliveredIdentifiersKey)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.banner, .sound])
    }
}
