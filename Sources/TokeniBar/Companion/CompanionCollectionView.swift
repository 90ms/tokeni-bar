import SwiftUI
import TokeniCore

struct CompanionCollectionView: View {
    @ObservedObject var store: UsageStore
    @State private var confirmsNewEgg = false
    @State private var confirmsCompletion = false

    private let stages: [CompanionGameStage] = [.hatchling, .junior, .adult]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                self.currentCompanion
                self.summary
                self.pity
                self.collectionGrid
                self.journeyActions
            }
            .padding(20)
        }
        .confirmationDialog(
            AppLocalization.string("companion.newEgg.confirm.title"),
            isPresented: self.$confirmsNewEgg,
            titleVisibility: .visible)
        {
            Button(
                AppLocalization.string("companion.newEgg.confirm.action"),
                role: .destructive)
            {
                self.store.abandonCompanionForNewEgg()
            }
            Button(AppLocalization.string("action.cancel"), role: .cancel) {}
        } message: {
            Text(AppLocalization.format(
                "companion.newEgg.confirm.message",
                self.store.companionState.growthEnergy))
        }
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

    private var currentCompanion: some View {
        HStack(spacing: 18) {
            ByteBotSpriteView(
                stage: self.store.companionStage,
                rarity: self.store.companionState.rarity,
                behavior: self.store.companionBehavior,
                dimension: 104,
                animationsEnabled: self.store.companionAnimationsEnabled)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.format(
                    "companion.collection.generation",
                    self.store.companionState.generationNumber))
                    .font(.title2.weight(.semibold))
                HStack {
                    Text(AppLocalization.string(
                        "companion.stage.\(self.store.companionStage.rawValue)"))
                    CompanionRarityBadge(rarity: self.store.companionState.rarity)
                }
                if self.store.companionStage == .adult {
                    Text(AppLocalization.format(
                        "companion.collection.bond",
                        self.store.companionState.bondEnergy))
                        .foregroundStyle(.secondary)
                } else if let next = self.store.companionNextStageEnergy {
                    ProgressView(value: self.store.companionStageProgress)
                        .frame(width: 220)
                    Text(AppLocalization.format(
                        "companion.progress",
                        self.store.companionState.growthEnergy,
                        next))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var summary: some View {
        GroupBox(AppLocalization.string("companion.collection.summary")) {
            HStack {
                self.metric(
                    AppLocalization.string("companion.collection.unlocked"),
                    value: "\(self.store.companionState.collection.unlockedFormCount) / 13")
                Divider()
                self.metric(
                    AppLocalization.string("companion.collection.completed"),
                    value: "\(self.store.companionState.collection.totalCompletedGenerations)")
                Divider()
                self.metric(
                    AppLocalization.string("companion.collection.bestRarity"),
                    value: AppLocalization.string(
                        "companion.rarity.\(self.store.companionState.collection.highestRarity.rawValue)"))
                Divider()
                self.metric(
                    AppLocalization.string("companion.collection.bestBond"),
                    value: "\(self.store.companionState.collection.highestBondEnergy)")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var pity: some View {
        GroupBox(AppLocalization.string("companion.pity.title")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppLocalization.format(
                    "companion.pity.rare",
                    max(3 - self.store.companionState.pity.adultsWithoutRareOrHigher, 1)))
                Text(AppLocalization.format(
                    "companion.pity.epic",
                    max(7 - self.store.companionState.pity.adultsWithoutEpicOrHigher, 1)))
                Text(AppLocalization.format(
                    "companion.pity.legendary",
                    max(16 - self.store.companionState.pity.adultsWithoutLegendary, 1)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var collectionGrid: some View {
        GroupBox(AppLocalization.string("companion.collection.title")) {
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("")
                    ForEach(CompanionRarity.allCases, id: \.self) { rarity in
                        CompanionRarityBadge(rarity: rarity)
                    }
                }
                ForEach(self.stages, id: \.self) { stage in
                    GridRow {
                        Text(AppLocalization.string(
                            "companion.stage.\(stage.rawValue)"))
                            .font(.caption.weight(.semibold))
                            .frame(width: 72, alignment: .leading)
                        ForEach(CompanionRarity.allCases, id: \.self) { rarity in
                            self.formCell(stage: stage, rarity: rarity)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func formCell(
        stage: CompanionGameStage,
        rarity: CompanionRarity) -> some View
    {
        let formID = CompanionGameState.formID(
            speciesID: self.store.companionState.speciesID,
            stage: stage,
            rarity: rarity)
        let record = self.store.companionState.collection.forms.first {
            $0.formID == formID
        }
        VStack(spacing: 2) {
            if let record {
                ByteBotSpriteView(
                    stage: stage,
                    rarity: rarity,
                    behavior: .idle,
                    dimension: 62,
                    animationsEnabled: false)
                Text(AppLocalization.string(
                    record.unlockKind == .encountered
                        ? "companion.collection.encountered"
                        : "companion.collection.lineage"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "questionmark")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 62, height: 62)
                Text(AppLocalization.string("companion.collection.locked"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 76, height: 82)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var journeyActions: some View {
        GroupBox(AppLocalization.string("companion.journey.title")) {
            VStack(alignment: .leading, spacing: 10) {
                if self.store.companionStage == .adult {
                    Text(AppLocalization.string("companion.complete.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(AppLocalization.string("companion.complete.action")) {
                        self.confirmsCompletion = true
                    }
                    .buttonStyle(.borderedProminent)
                } else if self.store.companionStage != .egg {
                    Text(AppLocalization.string("companion.newEgg.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(
                        AppLocalization.string("companion.newEgg.action"),
                        role: .destructive)
                    {
                        self.confirmsNewEgg = true
                    }
                } else {
                    Text(AppLocalization.string("companion.newEgg.egg"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
