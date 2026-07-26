import SwiftUI

struct CompanionCard: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openWindow) private var openWindow
    @State private var confirmsCompletion = false
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            ByteBotSpriteView(
                stage: self.store.companionStage,
                rarity: self.store.companionState.rarity,
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
                    Text(AppLocalization.string(
                        "companion.rarity.\(self.store.companionState.rarity.rawValue)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Text(AppLocalization.string(
                    "companion.behavior.\(self.store.companionBehavior.rawValue)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let nextEnergy = self.store.companionNextStageEnergy {
                    ProgressView(value: self.store.companionStageProgress)
                    Text(AppLocalization.format(
                        "companion.progress",
                        self.store.companionState.growthEnergy,
                        nextEnergy))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text(AppLocalization.format(
                        "companion.progress.max",
                        self.store.companionState.bondEnergy))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(AppLocalization.format(
                    "companion.today.short",
                    self.store.companionTodayEnergy))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                self.store.patCompanion()
            } label: {
                Image(systemName: "hand.point.up.left.fill")
            }
            .buttonStyle(.borderless)
            .help(AppLocalization.string("companion.pat"))
            .accessibilityLabel(AppLocalization.string("companion.pat"))

            Button {
                self.openWindow(id: "companion-collection")
            } label: {
                Image(systemName: "square.grid.3x3.fill")
            }
            .buttonStyle(.borderless)
            .help(AppLocalization.string("companion.collection.open"))

            if self.store.companionStage == .adult {
                Button {
                    self.confirmsCompletion = true
                } label: {
                    Image(systemName: "archivebox.fill")
                }
                .buttonStyle(.borderless)
                .help(AppLocalization.string("companion.complete.action"))
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .confirmationDialog(
            AppLocalization.string("companion.complete.confirm.title"),
            isPresented: self.$confirmsCompletion,
            titleVisibility: .visible)
        {
            Button(AppLocalization.string("companion.complete.confirm.action")) {
                self.store.completeCompanionGeneration()
            }
            Button(AppLocalization.string("action.cancel"), role: .cancel) {}
        } message: {
            Text(AppLocalization.string("companion.complete.confirm.message"))
        }
    }
}
