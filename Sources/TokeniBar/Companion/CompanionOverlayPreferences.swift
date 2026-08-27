import Foundation

enum CompanionOverlaySize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { self.rawValue }

    var localizedName: String {
        AppLocalization.string("settings.companion.overlay.size.\(self.rawValue)")
    }

    var spriteDimension: CGFloat {
        switch self {
        case .small: 64
        case .medium: 96
        case .large: 136
        }
    }

    var panelDimension: CGFloat {
        self.spriteDimension + 16
    }

    var panelSize: CGSize {
        CGSize(width: max(self.panelDimension, 220),
               height: self.panelDimension + 72)
    }
}
