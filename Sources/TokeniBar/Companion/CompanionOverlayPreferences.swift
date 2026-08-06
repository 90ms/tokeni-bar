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
        CompanionMutationDecoration.displayDimension(
            for: self.spriteDimension) + 16
    }
}
