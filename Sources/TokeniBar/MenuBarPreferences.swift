import Foundation

enum CompanionAnimationIntensity: String, CaseIterable, Identifiable {
    case off
    case gentle
    case full

    var id: Self { self }

    var isEnabled: Bool { self != .off }

    var motionScale: Double {
        switch self {
        case .off: 0
        case .gentle: 0.5
        case .full: 1
        }
    }

    var localizedName: String {
        AppLocalization.string(
            "settings.companion.animationIntensity.\(self.rawValue)")
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case iconOnly
    case lowestRemaining
    case monthlyCost
    case selectedProvider
    case tokeni

    var id: String { self.rawValue }

    var localizedName: String {
        AppLocalization.string("settings.menuBar.mode.\(self.rawValue)")
    }
}

enum ClaudeMenuBarQuota: String, CaseIterable, Identifiable {
    case fiveHour
    case weekly
    case fable

    var id: String { self.rawValue }

    var windowID: String {
        switch self {
        case .fiveHour: "five-hour"
        case .weekly: "seven-day"
        case .fable: "scoped-weekly-fable"
        }
    }

    var localizedName: String {
        AppLocalization.string("settings.menuBar.claudeQuota.\(self.rawValue)")
    }
}
