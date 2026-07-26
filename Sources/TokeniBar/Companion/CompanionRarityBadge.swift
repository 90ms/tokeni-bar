import SwiftUI
import TokeniCore

struct CompanionRarityBadge: View {
    let rarity: CompanionRarity

    var body: some View {
        Label(
            AppLocalization.string("companion.rarity.\(self.rarity.rawValue)"),
            systemImage: self.systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(self.color.opacity(0.14), in: Capsule())
            .foregroundStyle(self.color)
            .accessibilityLabel(AppLocalization.string(
                "companion.rarity.\(self.rarity.rawValue)"))
    }

    private var systemImage: String {
        switch self.rarity {
        case .normal: "circle.fill"
        case .rare: "diamond.fill"
        case .epic: "seal.fill"
        case .legendary: "crown.fill"
        }
    }

    private var color: Color {
        switch self.rarity {
        case .normal: .secondary
        case .rare: .blue
        case .epic: .purple
        case .legendary: .orange
        }
    }
}
