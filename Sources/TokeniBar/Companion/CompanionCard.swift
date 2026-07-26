import SwiftUI

struct CompanionCard: View {
    @ObservedObject var store: UsageStore
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            ByteBotSpriteView(
                stage: self.store.companionStage,
                behavior: self.store.companionBehavior,
                dimension: self.compact ? 58 : 72,
                animationsEnabled: self.store.companionAnimationsEnabled)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(AppLocalization.string("companion.name"))
                        .font(.headline)
                    Text(AppLocalization.string(
                        "companion.stage.\(self.store.companionStage.rawValue)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Text(AppLocalization.string(
                    "companion.behavior.\(self.store.companionBehavior.rawValue)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let nextXP = self.store.companionNextStageXP {
                    ProgressView(value: self.store.companionStageProgress)
                    Text(AppLocalization.format(
                        "companion.progress",
                        self.store.companionState.totalXP,
                        nextXP))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text(AppLocalization.format(
                        "companion.progress.max",
                        self.store.companionState.totalXP))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Button {
                self.store.patCompanion()
            } label: {
                Image(systemName: "hand.point.up.left.fill")
            }
            .buttonStyle(.borderless)
            .help(AppLocalization.string("companion.pat"))
            .accessibilityLabel(AppLocalization.string("companion.pat"))
        }
        .padding(8)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
    }
}
