import Foundation

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case iconOnly
    case lowestRemaining
    case monthlyCost
    case selectedProvider

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
