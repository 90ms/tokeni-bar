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

struct CompanionVariantBadge: View {
    let variantID: CompanionVariantID

    var body: some View {
        let definition = CompanionVariantRegistry.definition(
            for: self.variantID)
        Label(
            AppLocalization.string(
                "companion.variant.\(self.variantID.rawValue)"),
            systemImage: definition.isSpecial
                ? "sparkles"
                : "circle.fill")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(self.color.opacity(0.14), in: Capsule())
            .foregroundStyle(self.color)
            .accessibilityLabel(AppLocalization.string(
                "companion.variant.\(self.variantID.rawValue)"))
    }

    private var color: Color {
        if self.variantID == .mutated { return .green }
        if self.variantID == .prismatic { return .pink }
        if self.variantID == .legacyAzure { return .blue }
        if self.variantID == .legacyViolet { return .purple }
        return .secondary
    }
}
