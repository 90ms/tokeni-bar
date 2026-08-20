import Foundation
import TokeniCore

/// Connects user-facing tray service actions to the platform contracts.
///
/// The coordinator persists only small preferences. Notification content is
/// supplied by the caller and is never written to the settings file.
public struct WindowsTrayServiceCoordinator: Sendable {
    public static let launchAtLoginKey = "windows.launchAtLogin"
    public static let notificationsEnabledKey = "windows.notificationsEnabled"

    private let settings: any SettingsStoring
    private let launchAtLogin: WindowsLaunchAtLoginManager
    private let notifications: WindowsNotificationDelivery

    public init(
        executableURL: URL,
        settings: any SettingsStoring,
        notifications: WindowsNotificationDelivery =
            WindowsNotificationDelivery())
    {
        self.settings = settings
        self.launchAtLogin = WindowsLaunchAtLoginManager(
            applicationName: "TokeniBar",
            executableURL: executableURL)
        self.notifications = notifications
    }

    public func isLaunchAtLoginEnabled() async -> Bool {
        await self.launchAtLogin.isEnabled()
    }

    @discardableResult
    public func toggleLaunchAtLogin() async throws -> Bool {
        let nextValue = !(await self.launchAtLogin.isEnabled())
        try await self.launchAtLogin.setEnabled(nextValue)
        self.settings.set(nextValue, forKey: Self.launchAtLoginKey)
        return nextValue
    }

    public func sendTestNotification() async throws {
        try await self.notifications.requestAuthorization()
        try await self.notifications.deliver(AppNotification(
            id: "windows-test-notification",
            title: "Tokeni Bar",
            body: "Windows notifications are connected."))
        self.settings.set(true, forKey: Self.notificationsEnabledKey)
    }
}
