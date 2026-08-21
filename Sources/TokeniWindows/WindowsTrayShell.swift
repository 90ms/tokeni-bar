import Foundation
import TokeniWindowsNative

/// A small Swift boundary around the Win32 notification-area lifecycle.
///
/// The native API and its handles stay inside the Windows target. Higher layers
/// only deal with strings and integer success/failure results.
public final class WindowsTrayShell: @unchecked Sendable {
    private let applicationName: String
    private let initialTooltip: String
    private let stateLock = NSLock()
    private var started = false

    public init(
        applicationName: String = "Tokeni Bar",
        tooltip: String = "Tokeni Bar")
    {
        self.applicationName = applicationName
        self.initialTooltip = tooltip
    }

    @discardableResult
    public func start() -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard !self.started else { return true }
        let result = self.applicationName.withCString { applicationName in
            self.initialTooltip.withCString { tooltip in
                tokeni_windows_tray_start(applicationName, tooltip)
            }
        }
        self.started = result != 0
        return self.started
    }

    @discardableResult
    public func updateTooltip(_ tooltip: String) -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return false }
        return tooltip.withCString { value in
            tokeni_windows_tray_update_tooltip(value) != 0
        }
    }

    @discardableResult
    public func updateDetails(_ details: String) -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return false }
        return details.withCString { value in
            tokeni_windows_tray_update_details(value) != 0
        }
    }

    public func takeRefreshRequest() -> Bool {
        tokeni_windows_tray_take_refresh_request() != 0
    }

    @discardableResult
    public func updateProviderOptions(
        _ options: [WindowsProviderSelectionOption]) -> Bool
    {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started,
              options.count
                <= WindowsProviderSelectionFormatter.maximumProviderCount,
              tokeni_windows_tray_begin_provider_options() != 0
        else {
            return false
        }

        for option in options {
            let appended = option.providerID.rawValue.withCString { providerID in
                option.displayName.withCString { displayName in
                    tokeni_windows_tray_append_provider_option(
                        providerID,
                        displayName,
                        option.enabled ? 1 : 0) != 0
                }
            }
            guard appended else { return false }
        }
        return tokeni_windows_tray_commit_provider_options() != 0
    }

    public func takeProviderToggleRequest()
        -> WindowsProviderSelectionToggle?
    {
        var providerID = [CChar](
            repeating: 0,
            count: WindowsProviderSelectionFormatter
                .maximumProviderIDByteCount + 1)
        var enabled: Int32 = 0
        let result = providerID.withUnsafeMutableBufferPointer { buffer in
            tokeni_windows_tray_take_provider_toggle_request(
                buffer.baseAddress,
                Int32(buffer.count),
                &enabled)
        }
        let rawProviderID = providerID.withUnsafeBufferPointer { buffer in
            buffer.baseAddress.flatMap { String(validatingCString: $0) }
        }
        guard result != 0, let rawProviderID else {
            return nil
        }
        return WindowsProviderSelectionToggle(
            rawProviderID: rawProviderID,
            enabled: enabled != 0)
    }

    @discardableResult
    public func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return false }
        tokeni_windows_tray_set_launch_at_login_enabled(enabled ? 1 : 0)
        return true
    }

    public func takeLaunchAtLoginRequest() -> Bool {
        tokeni_windows_tray_take_launch_at_login_request() != 0
    }

    public func takeTestNotificationRequest() -> Bool {
        tokeni_windows_tray_take_test_notification_request() != 0
    }

    @discardableResult
    public func setCompanionEnabled(_ enabled: Bool) -> Bool {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return false }
        tokeni_windows_tray_set_companion_enabled(enabled ? 1 : 0)
        return true
    }

    public func takeCompanionToggleRequest() -> Bool {
        tokeni_windows_tray_take_companion_toggle_request() != 0
    }

    @discardableResult
    public func run() -> Int32 {
        self.stateLock.lock()
        let started = self.started
        self.stateLock.unlock()
        guard started else { return -1 }
        let result = tokeni_windows_tray_run()
        self.stateLock.lock()
        self.started = false
        self.stateLock.unlock()
        return result
    }

    public func stop() {
        self.stateLock.lock()
        let started = self.started
        self.stateLock.unlock()
        guard started else { return }
        tokeni_windows_tray_stop()
    }
}
