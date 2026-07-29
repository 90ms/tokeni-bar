import SwiftUI
import TokeniCore

struct CompanionTraitSummaryView: View {
    @ObservedObject var store: UsageStore
    var compact = false

    var body: some View {
        if let companion = self.store.activeBenefitCompanion,
           let definition = self.store.displayedCompanionBenefitDefinition
        {
            VStack(alignment: .leading, spacing: self.compact ? 3 : 5) {
                HStack(spacing: 6) {
                    Label(
                        AppLocalization.string("companion.benefit.unique"),
                        systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                    Text(CompanionBenefitPresentation.mode(
                        definition.activation))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                    Spacer()
                    Text(self.statusText(
                        definition: definition,
                        generationID: companion.generationID))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(self.statusColor(definition))
                }

                Text(CompanionBenefitPresentation.name(definition.id))
                    .font(self.compact
                        ? .caption.weight(.semibold)
                        : .subheadline.weight(.semibold))

                Text(CompanionBenefitPresentation.value(
                    definition.id,
                    rarity: companion.rarity))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(self.compact ? 1 : 2)
            }
            .padding(self.compact ? 7 : 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.accentColor.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine)
        }
    }

    private func statusText(
        definition: CompanionBenefitDefinition,
        generationID: UUID) -> String
    {
        switch definition.activation {
        case .active:
            return AppLocalization.string(
                "companion.benefit.status.activeTogether")
        case .passive:
            if let slot = self.store.companionPassiveSlot(
                for: generationID)
            {
                return AppLocalization.format(
                    "companion.benefit.status.passiveSlot",
                    slot + 1)
            }
            return AppLocalization.string(
                self.store.isShowingArchivedCompanion
                    ? "companion.benefit.status.notAssigned"
                    : "companion.benefit.status.completeRequired")
        }
    }

    private func statusColor(
        _ definition: CompanionBenefitDefinition) -> Color
    {
        if definition.activation == .active {
            return .green
        }
        guard let generationID = self.store.activeBenefitCompanion?
            .generationID
        else { return .secondary }
        return self.store.companionPassiveSlot(for: generationID) == nil
            ? .secondary
            : .green
    }
}
