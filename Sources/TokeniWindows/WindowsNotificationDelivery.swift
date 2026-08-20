import Foundation
import TokeniCore
import TokeniWindowsNative

public enum WindowsNotificationDeliveryError: Error, Equatable, Sendable {
    case trayNotStarted
    case deliveryFailed
}

/// Delivers non-blocking notification-area balloons through the running tray
/// icon. Windows manages notification permission in the shell, so requesting
/// authorization only verifies that the tray boundary is available.
public struct WindowsNotificationDelivery: NotificationDelivering, Sendable {
    public init() {}

    public func requestAuthorization() async throws {
        guard tokeni_windows_tray_is_started() != 0 else {
            throw WindowsNotificationDeliveryError.trayNotStarted
        }
    }

    public func deliver(_ notification: AppNotification) async throws {
        guard tokeni_windows_tray_is_started() != 0 else {
            throw WindowsNotificationDeliveryError.trayNotStarted
        }

        let delivered = notification.title.withCString { title in
            notification.body.withCString { body in
                tokeni_windows_tray_notify(title, body) != 0
            }
        }
        guard delivered else {
            throw tokeni_windows_tray_is_started() == 0
                ? WindowsNotificationDeliveryError.trayNotStarted
                : WindowsNotificationDeliveryError.deliveryFailed
        }
    }
}
