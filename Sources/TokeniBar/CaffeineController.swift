import Combine
import Foundation
import TokeniCore

@MainActor
protocol SleepPreventing: AnyObject {
    func begin(preventsDisplaySleep: Bool) -> NSObjectProtocol
    func end(_ activity: NSObjectProtocol)
}

@MainActor
final class ProcessInfoSleepPreventer: SleepPreventing {
    func begin(preventsDisplaySleep: Bool) -> NSObjectProtocol {
        var options: ProcessInfo.ActivityOptions = [.idleSystemSleepDisabled]
        if preventsDisplaySleep {
            options.insert(.idleDisplaySleepDisabled)
        }
        return ProcessInfo.processInfo.beginActivity(
            options: options,
            reason: "Tokeni Bar Caffeine")
    }

    func end(_ activity: NSObjectProtocol) {
        ProcessInfo.processInfo.endActivity(activity)
    }
}

@MainActor
final class CaffeineController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var preventsDisplaySleep: Bool

    private static let preventsDisplaySleepKey =
        "caffeinePreventsDisplaySleep"

    private let sleepPreventer: any SleepPreventing
    private let settings: any SettingsStoring
    private var activity: NSObjectProtocol?

    init(
        sleepPreventer: any SleepPreventing = ProcessInfoSleepPreventer(),
        settings: any SettingsStoring = UserDefaultsSettingsStore())
    {
        self.sleepPreventer = sleepPreventer
        self.settings = settings
        self.preventsDisplaySleep = settings.bool(
            forKey: Self.preventsDisplaySleepKey)
    }

    func toggle() {
        self.setEnabled(!self.isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != self.isEnabled else { return }
        if enabled {
            self.activity = self.sleepPreventer.begin(
                preventsDisplaySleep: self.preventsDisplaySleep)
            self.isEnabled = true
        } else {
            self.stopActivity()
        }
    }

    func setPreventsDisplaySleep(_ enabled: Bool) {
        guard enabled != self.preventsDisplaySleep else { return }
        self.preventsDisplaySleep = enabled
        self.settings.set(enabled, forKey: Self.preventsDisplaySleepKey)
        guard self.isEnabled else { return }

        self.stopActivity()
        self.activity = self.sleepPreventer.begin(preventsDisplaySleep: enabled)
        self.isEnabled = true
    }

    private func stopActivity() {
        if let activity = self.activity {
            self.sleepPreventer.end(activity)
        }
        self.activity = nil
        self.isEnabled = false
    }
}
