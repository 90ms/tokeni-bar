import AppKit
import SwiftUI

struct CompanionCard: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openWindow) private var openWindow
    @State private var confirmsCompletion = false
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            ByteBotTransitionView(
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
                    if let rarity = self.store.companionState.rarity {
                        Text(AppLocalization.string(
                            "companion.rarity.\(rarity.rawValue)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Text(AppLocalization.string(
                    "companion.behavior.\(self.store.companionBehavior.rawValue)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if self.store.companionStage == .adult {
                    Text(AppLocalization.format(
                        "companion.progress.adult",
                        self.store.companionState.bondEnergy,
                        self.store.companionState.growthEnergy))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else if let nextEnergy = self.store.companionNextStageEnergy {
                    ProgressView(value: self.store.companionStageProgress)
                    Text(AppLocalization.format(
                        "companion.progress",
                        self.store.companionState.growthEnergy,
                        nextEnergy))
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
                Task { @MainActor in
                    await Task.yield()
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            } label: {
                Image(systemName: "square.grid.3x3.fill")
            }
            .buttonStyle(.borderless)
            .help(AppLocalization.string("companion.collection.open"))

            switch self.store.companionStage {
            case .egg:
                Button {
                    self.store.hatchCompanion()
                } label: {
                    Image(systemName: "sparkles")
                }
                .buttonStyle(.borderless)
                .disabled(!self.store.canPerformCompanionAction)
                .help(AppLocalization.string("companion.hatch.action"))
            case .hatchling, .junior:
                Button {
                    self.store.evolveCompanion()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!self.store.canPerformCompanionAction)
                .help(AppLocalization.string("companion.evolve.action"))
            case .adult:
                Button {
                    self.confirmsCompletion = true
                } label: {
                    Image(systemName: "archivebox.fill")
                }
                .buttonStyle(.borderless)
                .disabled(!self.store.canPerformCompanionAction)
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
