import AppKit
import SwiftUI

struct CompanionCard: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openWindow) private var openWindow
    @State private var confirmsCompletion = false
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ByteBotTransitionView(
                    speciesID: self.store.companionState.speciesID,
                    stage: self.store.companionStage,
                    rarity: self.store.companionState.rarity,
                    behavior: self.store.companionBehavior,
                    cosmeticID: self.store.companionRewardState.selectedCosmeticID,
                    dimension: self.compact ? 50 : 62,
                    animationsEnabled: self.store.companionAnimationsEnabled)

                VStack(alignment: .leading, spacing: 5) {
                    Text(self.companionName)
                        .font(.headline)

                    HStack(spacing: 5) {
                        self.metadataBadge(AppLocalization.string(
                            "companion.stage.\(self.store.companionStage.rawValue)"))
                        if let rarity = self.store.companionState.rarity {
                            self.metadataBadge(AppLocalization.string(
                                "companion.rarity.\(rarity.rawValue)"))
                        }
                    }

                    if !self.compact {
                        Text(self.companionSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 4)

                Button {
                    self.openCompanionCollection()
                } label: {
                    Image(systemName: "square.grid.3x3.fill")
                }
                .buttonStyle(.borderless)
                .help(AppLocalization.string("companion.collection.open"))
                .accessibilityLabel(AppLocalization.string(
                    "companion.collection.open"))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if self.store.companionStage == .adult {
                        Text(AppLocalization.format(
                            "companion.progress.adult",
                            self.store.companionState.bondEnergy,
                            self.store.companionState.growthEnergy))
                    } else if let nextEnergy = self.store.companionNextStageEnergy {
                        Text(AppLocalization.format(
                            "companion.progress",
                            self.store.companionState.growthEnergy,
                            nextEnergy))
                    }

                    Spacer()

                    Text(AppLocalization.format(
                        "companion.today.short",
                        self.store.companionTodayEnergy))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                if self.store.companionStage != .adult {
                    ProgressView(value: self.store.companionStageProgress)
                }
            }

            HStack(spacing: 8) {
                self.primaryActionButton

                Spacer()

                Button {
                    self.store.patCompanion()
                } label: {
                    Image(systemName: "hand.point.up.left.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(AppLocalization.string("companion.pat"))
                .accessibilityLabel(AppLocalization.string("companion.pat"))
            }
        }
        .padding(10)
        .background(
            .quaternary.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 10))
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
            Text(AppLocalization.format(
                "companion.complete.confirm.message",
                self.store.companionJourneyCompletionCost))
        }
        .sheet(item: Binding(
            get: { self.store.companionReveal },
            set: { reveal in
                if reveal == nil {
                    self.store.dismissCompanionReveal()
                }
            }))
        { reveal in
            CompanionHatchRevealView(
                reveal: reveal,
                animationsEnabled: self.store.companionAnimationsEnabled,
                dismiss: self.store.dismissCompanionReveal)
        }
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch self.store.companionStage {
        case .egg:
            Button {
                self.store.hatchCompanion()
            } label: {
                Label(
                    AppLocalization.string("companion.hatch.action"),
                    systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!self.store.canPerformCompanionAction)
        case .hatchling, .junior:
            Button {
                self.store.evolveCompanion()
            } label: {
                Label(
                    AppLocalization.string("companion.evolve.action"),
                    systemImage: "arrow.up.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!self.store.canPerformCompanionAction)
        case .adult:
            Button {
                self.confirmsCompletion = true
            } label: {
                Label(
                    AppLocalization.string("companion.complete.action"),
                    systemImage: "archivebox.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!self.store.canPerformCompanionAction)
        }
    }

    private func metadataBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }

    private func openCompanionCollection() {
        self.openWindow(id: "companion-collection")
        Task { @MainActor in
            await Task.yield()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private var companionName: String {
        guard let speciesID = self.store.companionState.speciesID else {
            return AppLocalization.string("companion.species.mystery.name")
        }
        return AppLocalization.string(
            "companion.species.\(speciesID.rawValue).name")
    }

    private var companionSubtitle: String {
        guard let speciesID = self.store.companionState.speciesID else {
            return AppLocalization.string("companion.species.mystery.personality")
        }
        if self.store.companionBehavior == .idle {
            return AppLocalization.string(
                "companion.species.\(speciesID.rawValue).personality")
        }
        return AppLocalization.string(
            "companion.behavior.\(self.store.companionBehavior.rawValue)")
    }
}
