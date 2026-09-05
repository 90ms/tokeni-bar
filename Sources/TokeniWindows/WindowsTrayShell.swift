import Foundation
import TokeniCore
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
        return details.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "\r\n").withCString { value in
            tokeni_windows_tray_update_details(value) != 0
        }
    }

    public func takeRefreshRequest() -> Bool {
        tokeni_windows_tray_take_refresh_request() != 0
    }

    public func takeGrowthTargetRequest() -> UUID? {
        var buffer = [CChar](repeating: 0, count: 64)
        return buffer.withUnsafeMutableBufferPointer { pointer in
            guard tokeni_windows_dashboard_take_pet_request(pointer.baseAddress, 64) != 0,
                  let address = pointer.baseAddress,
                  let value = String(validatingCString: address) else { return nil }
            return UUID(uuidString: value)
        }
    }

    public func takeHatchRequest() -> Bool {
        tokeni_windows_dashboard_take_hatch_request() != 0
    }

    public func updateCompanions(_ state: CompanionGameState?, feedback: String?) {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return }
        tokeni_windows_dashboard_begin_pets()
        var entries: [(UUID, String)] = []
        if let state {
            if state.stage != .egg, let species = state.speciesID {
                entries.append((state.generationID, "\(state.nickname ?? WindowsCompanionNames.species(species)) · \(WindowsLocalization.text("Level", "레벨")) \(state.level)"))
            }
            entries += state.collection.archivedGenerations.map {
                ($0.generationID, "\($0.nickname ?? WindowsCompanionNames.species($0.speciesID)) · \(WindowsLocalization.text("Level", "레벨")) \(CompanionLevelCurve.standard.level(forXP: $0.growthXP))")
            }
        }
        for (id, label) in entries.prefix(128) {
            _ = id.uuidString.withCString { identifier in
                String(label.prefix(100)).withCString { name in
                    tokeni_windows_dashboard_append_pet(identifier, name,
                        state?.resolvedGrowthTargetGenerationID == id ? 1 : 0)
                }
            }
        }
        let summary: String
        if let state {
            let target = state.growthTargetPet
            let progress = target.map { Int(($0.levelProgress * 100).rounded()) } ?? 0
            summary = WindowsLocalization.text("\(entries.count) companions · \(state.eggs.count) unopened eggs", "보유 펫 \(entries.count)마리 · 미개봉 알 \(state.eggs.count)개") + "\r\n\r\n"
                + (target.map { WindowsLocalization.text("Growing: \($0.nickname ?? $0.speciesID.rawValue) · Level \($0.level) · \(progress)% to next level", "성장 중: \($0.nickname ?? $0.speciesID.rawValue) · 레벨 \($0.level) · 다음 레벨까지 \(progress)%") }
                    ?? WindowsLocalization.text("Open an egg to meet your first companion.", "알을 열어 첫 번째 펫을 만나세요."))
                + WindowsLocalization.text("\r\n\r\nGrowth comes from verified cumulative usage. Hiding the desktop companion does not stop growth.", "\r\n\r\n확인된 누적 사용량으로 성장합니다. 데스크톱 펫을 숨겨도 성장은 계속됩니다.")
        } else {
            summary = WindowsLocalization.message("Companion state could not be loaded. Restart Tokeni Bar to retry.")
        }
        summary.withCString { text in
            WindowsLocalization.message(feedback ?? "").withCString { message in
                tokeni_windows_dashboard_commit_pets(text, Int32(state?.eggs.count ?? 0), message)
            }
        }
    }

    public func updateDashboard(_ presentation: WindowsDashboardPresentation) {
        self.stateLock.lock()
        defer { self.stateLock.unlock() }
        guard self.started else { return }
        tokeni_windows_dashboard_begin_usage()
        for row in presentation.rows {
            // Bound UI labels without splitting UTF-8 sequences at the C boundary.
            let cells = row.map { String($0.prefix(100)) }
            _ = cells[0].withCString { name in
                cells[1].withCString { status in
                    cells[2].withCString { remaining in
                        cells[3].withCString { reset in
                            cells[4].withCString { tokens in
                                cells[5].withCString { cost in
                                    tokeni_windows_dashboard_append_usage(name, status, remaining, reset, tokens, cost)
                                }
                            }
                        }
                    }
                }
            }
        }
        presentation.summary.replacingOccurrences(of: "\n", with: "\r\n").withCString { summary in
            presentation.status.withCString { status in
                tokeni_windows_dashboard_commit_usage(summary, status, presentation.refreshing ? 1 : 0)
            }
        }
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
