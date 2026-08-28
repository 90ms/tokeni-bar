import AppKit
import SwiftUI
import TokeniCore

struct CompanionCard: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openSettings) private var openSettings
    var compact = false

    var body: some View {
        if self.store.companionDataUnavailable {
            self.unavailableCard
        } else {
            self.companionContent
        }
    }

    private var unavailableCard: some View {
        Label(
            AppLocalization.string("companion.data.unavailable"),
            systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                .quaternary.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 10))
    }

    private var companionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if self.store.companionGrowthDataUnavailable {
                Label(
                    AppLocalization.string("companion.growthData.unavailable"),
                    systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 10) {
                ByteBotTransitionView(
                        speciesID: self.store.displayedCompanionSpeciesID,
                        stage: self.store.displayedCompanionStage,
                        rarity: self.store.displayedCompanionRarity,
                        variantID: self.store.displayedCompanionVariantID,
                        behavior: self.store.companionBehavior,
                        mutationID: self.store.displayedCompanionMutationID,
                        cosmeticIDs: self.store.companionRewardState.selectedCosmeticIDs,
                        dimension: self.compact ? 50 : 62,
                        animationsEnabled: self.store.companionAnimationsEnabled,
                        animationIntensity: self.store
                            .companionAnimationIntensity.motionScale,
                        interactionPulse: self.store.companionInteractionPulse,
                        growthPulse: self.store.isShowingArchivedCompanion
                            ? 0
                            : self.store.companionGrowthPulse)

                VStack(alignment: .leading, spacing: 5) {
                    Text(self.companionName)
                        .font(.headline)

                    HStack(spacing: 5) {
                        self.metadataBadge(AppLocalization.format(
                            "companion.level.value",
                            self.store.displayedCompanionLevel))
                        self.metadataBadge(AppLocalization.string(
                            "companion.stage.\(self.store.displayedCompanionStage.rawValue)"))
                        if let variantID =
                            self.store.displayedCompanionVariantID
                        {
                            self.metadataBadge(AppLocalization.string(
                                "companion.variant.\(variantID.rawValue)"))
                        }
                        if let mutationID =
                            self.store.displayedCompanionMutationID
                        {
                            self.metadataBadge(AppLocalization.string(
                                "companion.mutation.\(mutationID.rawValue).name"))
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
                    self.openCompanionSettings()
                } label: {
                    Image(systemName: "square.grid.3x3.fill")
                }
                .buttonStyle(.borderless)
                .help(AppLocalization.string("companion.collection.open"))
                .accessibilityLabel(AppLocalization.string(
                    "companion.collection.open"))
            }

            if let personalityID =
                self.store.displayedCompanionPersonalityID
            {
                HStack {
                    Label(
                        AppLocalization.string(
                            "companion.personality.\(personalityID.rawValue)"),
                        systemImage: "heart.text.square")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if self.store.displayedCompanionLevel
                == CompanionLevelCurve.standard.maximumLevel
            {
                Picker(
                    AppLocalization.string("companion.displayStage.title"),
                    selection: Binding(
                        get: { self.store.displayedCompanionStage },
                        set: { self.store.selectDisplayedCompanionStage($0) }))
                {
                    ForEach(
                        [CompanionGameStage.hatchling, .junior, .adult],
                        id: \.self)
                    { stage in
                        Text(AppLocalization.string(
                            "companion.stage.\(stage.rawValue)"))
                            .tag(stage)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(AppLocalization.string(
                    "companion.displayStage.title"))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if self.store.isShowingArchivedCompanion {
                        Text(AppLocalization.format(
                            "companion.level.value",
                            self.store.displayedCompanionLevel))
                    } else if self.store.companionStage != .egg {
                        Text(self.store.companionLevel
                                == CompanionLevelCurve.standard.maximumLevel
                            ? AppLocalization.string(
                                "companion.level.maximum")
                            : AppLocalization.format(
                                "companion.level.progress",
                                self.store.companionDisplayedGrowthEnergy,
                                self.store.companionDisplayedGrowthEnergyTarget))
                    }

                    Spacer()

                    Text(AppLocalization.format(
                        "companion.today.tokens.short",
                        self.store.companionTodayTokens.formatted(
                            .number.notation(.compactName))))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                if self.store.displayedCompanionStage != .egg
                {
                    if self.store.displayedCompanionLevel
                        == CompanionLevelCurve.standard.maximumLevel
                    {
                        if self.store.displayedCompanionIsGrowthTarget,
                           let remainder = self.store
                            .companionMaxLevelConversionRemainder
                        {
                            ProgressView(
                                value: Double(remainder),
                                total: Double(
                                    CompanionRewardEngine.maxLevelTokenCost))
                                .accessibilityLabel(AppLocalization.string(
                                    "companion.maxLevel.progress.accessibility"))
                                .accessibilityValue(AppLocalization.format(
                                    "companion.maxLevel.conversionProgress",
                                    remainder,
                                    CompanionRewardEngine.maxLevelTokenCost))
                            Text(AppLocalization.format(
                                "companion.maxLevel.conversionProgress",
                                remainder,
                                CompanionRewardEngine.maxLevelTokenCost))
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text(AppLocalization.string(
                                "companion.maxLevel.growthHint"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(AppLocalization.string(
                                "companion.maxLevel.selectGrowthTargetHint"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else if !self.store.isShowingArchivedCompanion {
                        ProgressView(value: self.store.companionStageProgress)
                            .accessibilityLabel(AppLocalization.string(
                                "companion.progress.accessibility.label"))
                            .accessibilityValue(AppLocalization.format(
                                "companion.progress.accessibility.value",
                                self.store.companionDisplayedGrowthEnergy,
                                self.store.companionDisplayedGrowthEnergyTarget))
                        if let evolutionLevel = self.store
                            .companionNextEvolutionLevel
                        {
                            Text(AppLocalization.format(
                                "companion.level.nextEvolution",
                                evolutionLevel))
                                .font(.caption2)
                                .foregroundStyle(
                                    self.store.canPerformCompanionAction
                                        ? Color.green
                                        : Color.secondary)
                        } else {
                            Text(AppLocalization.format(
                                "companion.level.nextReward",
                                self.store.companionNextRecurringRewardLevel,
                                self.store.companionNextRecurringRewardShards))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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
        .sheet(item: Binding(
            get: { self.store.companionHatchBatchReveal },
            set: { reveal in
                if reveal == nil {
                    self.store.dismissCompanionHatchBatchReveal()
                }
            }))
        { batch in
            CompanionHatchBatchRevealView(
                batch: batch,
                animationsEnabled: self.store.companionAnimationsEnabled,
                dismiss: self.store.dismissCompanionHatchBatchReveal)
        }
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if self.store.isShowingArchivedCompanion {
            Button {
                self.store.showcaseArchivedCompanion(nil)
            } label: {
                Label(
                    AppLocalization.string("companion.archive.showCurrent"),
                    systemImage: "arrow.uturn.backward.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
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
                    self.openCompanionSettings()
                } label: {
                    Label(
                        AppLocalization.string("companion.collection.open"),
                        systemImage: "square.grid.3x3.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
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

    private func openCompanionSettings() {
        self.openSettings()
        Task { @MainActor in
            await Task.yield()
            NSApplication.shared.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(
                name: .openCompanionSettings,
                object: nil)
        }
    }

    private var companionName: String {
        if let nickname = self.store.displayedCompanionNickname {
            return nickname
        }
        guard let speciesID = self.store.displayedCompanionSpeciesID else {
            return AppLocalization.string("companion.species.mystery.name")
        }
        return AppLocalization.string(
            "companion.species.\(speciesID.rawValue).name")
    }

    private var companionSubtitle: String {
        guard let speciesID = self.store.displayedCompanionSpeciesID else {
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
