import SwiftUI
import TokeniCore

struct CompanionCollectionView: View {
    @ObservedObject var store: UsageStore
    @State private var confirmsNewEgg = false
    @State private var confirmsCompletion = false
    @State private var selectedSpeciesID = CompanionSpeciesID.bytebot
    @State private var showsGrowthBreakdown = true

    private let stages: [CompanionGameStage] = [.hatchling, .junior, .adult]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                self.currentCompanion
                self.energyWallet
                self.rewardWallet
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
                self.store.companionNewEggCost))
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
        .onAppear {
            if let current = self.store.companionState.speciesID {
                self.selectedSpeciesID = current
            } else if let discovered = CompanionSpeciesID.allCases.first(where: {
                self.store.companionState.collection.discoveredSpeciesIDs.contains($0)
            }) {
                self.selectedSpeciesID = discovered
            }
        }
    }

    private var energyWallet: some View {
        GroupBox(AppLocalization.string("companion.energy.title")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    self.metric(
                        AppLocalization.string("companion.energy.balance"),
                        value: "\(self.store.companionState.growthEnergy)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.energy.earnedToday"),
                        value: "+\(self.store.companionState.growthEarnedToday)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.energy.carried"),
                        value: "\(self.store.companionState.growthCarriedToday)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.energy.spentToday"),
                        value: "-\(self.store.companionState.growthSpentToday)")
                }
                .frame(height: 42)

                Divider()

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalization.string(
                            "companion.energy.reflectedToday"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(AppLocalization.format(
                            "companion.energy.tokenTotal",
                            self.store.companionTodayTokens.formatted(.number)))
                            .font(.title3.weight(.semibold))
                    }
                    Spacer()
                    Label(
                        "+\(self.store.companionTodayEnergy)",
                        systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }

                if let required = self.store.companionNextEnergyTokenRequirement {
                    Text(AppLocalization.format(
                        "companion.energy.next",
                        required.formatted(.number)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup(
                    AppLocalization.string("companion.energy.providers"),
                    isExpanded: self.$showsGrowthBreakdown)
                {
                    VStack(spacing: 7) {
                        ForEach(self.store.companionGrowthProviderBreakdown) { provider in
                            HStack(spacing: 8) {
                                ProviderIcon(descriptor: provider.descriptor)
                                Text(provider.descriptor.displayName)
                                Spacer()
                                if let tokens = provider.reflectedTokens {
                                    Text(AppLocalization.format(
                                        "companion.energy.providerTokens",
                                        tokens.formatted(.number)))
                                        .monospacedDigit()
                                } else {
                                    Text(AppLocalization.string(
                                        "companion.energy.providerPending"))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .font(.caption)
                    .padding(.top, 6)
                }

                Text(AppLocalization.string("companion.energy.curve"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var rewardWallet: some View {
        GroupBox(AppLocalization.string("companion.rewards.title")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        AppLocalization.format(
                            "companion.rewards.balance",
                            self.store.companionRewardState.starShards),
                        systemImage: "star.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                    Spacer()
                    Button(self.attendanceButtonTitle) {
                        self.store.claimCompanionAttendance()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(self.store.companionAttendanceStatus != .available)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalization.format(
                            "companion.attendance.week",
                            self.store.companionAttendanceWeekCount,
                            self.store.companionAttendanceWeeklyGoal))
                        ProgressView(
                            value: Double(self.store.companionAttendanceWeekCount),
                            total: Double(self.store.companionAttendanceWeeklyGoal))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalization.format(
                            "companion.attendance.month",
                            self.store.companionAttendanceMonthCount,
                            self.store.companionAttendanceMonthlyGoal))
                        ProgressView(
                            value: Double(self.store.companionAttendanceMonthCount),
                            total: Double(self.store.companionAttendanceMonthlyGoal))
                    }
                }
                .font(.caption)

                if let amount = self.store.companionRewardNoticeAmount {
                    Text(AppLocalization.format(
                        "companion.rewards.received",
                        amount))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else if self.store.companionAttendanceError == .clockRollback {
                    Text(AppLocalization.string(
                        "companion.attendance.clockRollback"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text(AppLocalization.string("companion.rewards.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var attendanceButtonTitle: String {
        switch self.store.companionAttendanceStatus {
        case .available:
            AppLocalization.string("companion.attendance.claim")
        case .claimed:
            AppLocalization.string("companion.attendance.claimed")
        case .clockRollback:
            AppLocalization.string("companion.attendance.unavailable")
        }
    }

    private var currentCompanion: some View {
        HStack(spacing: 18) {
            ByteBotTransitionView(
                speciesID: self.store.companionState.speciesID,
                stage: self.store.companionStage,
                rarity: self.store.companionState.rarity,
                behavior: self.store.companionBehavior,
                dimension: 104,
                animationsEnabled: self.store.companionAnimationsEnabled)

            VStack(alignment: .leading, spacing: 8) {
                Text(self.currentCompanionTitle)
                    .font(.title2.weight(.semibold))
                HStack {
                    Text(AppLocalization.string(
                        "companion.stage.\(self.store.companionStage.rawValue)"))
                    if let rarity = self.store.companionState.rarity {
                        CompanionRarityBadge(rarity: rarity)
                    } else {
                        Text(AppLocalization.string("companion.rarity.unhatched"))
                            .foregroundStyle(.secondary)
                    }
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
                    value: "\(self.store.companionState.collection.unlockedFormCount) / 60")
                Divider()
                self.metric(
                    AppLocalization.string("companion.collection.species"),
                    value: "\(self.store.companionState.collection.discoveredSpeciesIDs.count) / 5")
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
                if self.store.companionState.collection.discoveredSpeciesIDs.count
                    < CompanionSpeciesID.allCases.count
                {
                    Text(AppLocalization.format(
                        "companion.pity.species",
                        max(
                            6 - self.store.companionState.consecutiveDuplicateHatches,
                            1)))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var collectionGrid: some View {
        GroupBox(AppLocalization.string("companion.collection.title")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(CompanionSpeciesID.allCases, id: \.self) { speciesID in
                        self.speciesButton(speciesID)
                    }
                }

                HStack {
                    Text(self.selectedSpeciesName)
                        .font(.headline)
                    if self.isSelectedSpeciesDiscovered {
                        Text(AppLocalization.string(
                            "companion.species.\(self.selectedSpeciesID.rawValue).personality"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(AppLocalization.format(
                            "companion.collection.encounters",
                            self.store.companionState.collection.encounterCount(
                                for: self.selectedSpeciesID)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

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
                                self.formCell(
                                    speciesID: self.selectedSpeciesID,
                                    stage: stage,
                                    rarity: rarity)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func formCell(
        speciesID: CompanionSpeciesID,
        stage: CompanionGameStage,
        rarity: CompanionRarity) -> some View
    {
        let formID = CompanionGameState.formID(
            speciesID: speciesID,
            stage: stage,
            rarity: rarity)
        let record = self.store.companionState.collection.forms.first {
            $0.formID == formID
        }
        VStack(spacing: 2) {
            if let record {
                ByteBotSpriteView(
                    speciesID: record.speciesID,
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

    private func speciesButton(_ speciesID: CompanionSpeciesID) -> some View {
        let discovered = self.store.companionState.collection.discoveredSpeciesIDs
            .contains(speciesID)
        return Button {
            self.selectedSpeciesID = speciesID
        } label: {
            VStack(spacing: 3) {
                if discovered {
                    ByteBotSpriteView(
                        speciesID: speciesID,
                        stage: .hatchling,
                        rarity: .normal,
                        behavior: .idle,
                        dimension: 46,
                        animationsEnabled: false)
                } else {
                    Image(systemName: "questionmark")
                        .font(.title3.bold())
                        .frame(width: 46, height: 46)
                        .foregroundStyle(.tertiary)
                }
                Text(discovered
                    ? AppLocalization.string(
                        "companion.species.\(speciesID.rawValue).name")
                    : "???")
                    .font(.caption2)
            }
            .frame(width: 74, height: 70)
            .background(
                self.selectedSpeciesID == speciesID
                    ? Color.accentColor.opacity(0.16)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var currentCompanionName: String {
        guard let speciesID = self.store.companionState.speciesID else {
            return AppLocalization.string("companion.species.mystery.name")
        }
        return AppLocalization.string(
            "companion.species.\(speciesID.rawValue).name")
    }

    private var currentCompanionTitle: String {
        guard let speciesID = self.store.companionState.speciesID else {
            return self.currentCompanionName
        }
        return AppLocalization.format(
            "companion.collection.generation",
            speciesID.contentGeneration,
            self.currentCompanionName)
    }

    private var isSelectedSpeciesDiscovered: Bool {
        self.store.companionState.collection.discoveredSpeciesIDs
            .contains(self.selectedSpeciesID)
    }

    private var selectedSpeciesName: String {
        guard self.isSelectedSpeciesDiscovered else { return "???" }
        return AppLocalization.string(
            "companion.species.\(self.selectedSpeciesID.rawValue).name")
    }

    @ViewBuilder
    private var journeyActions: some View {
        GroupBox(AppLocalization.string("companion.journey.title")) {
            VStack(alignment: .leading, spacing: 10) {
                if self.store.companionStage == .adult {
                    Text(AppLocalization.string("companion.complete.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(AppLocalization.format(
                        "companion.action.withCost",
                        AppLocalization.string("companion.complete.action"),
                        self.store.companionJourneyCompletionCost))
                    {
                        self.confirmsCompletion = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!self.store.canPerformCompanionAction)
                } else if self.store.companionStage == .egg {
                    Text(AppLocalization.string("companion.hatch.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(AppLocalization.format(
                        "companion.action.withCost",
                        AppLocalization.string("companion.hatch.action"),
                        self.store.companionActionCost ?? 0))
                    {
                        self.store.hatchCompanion()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!self.store.canPerformCompanionAction)
                } else {
                    Text(AppLocalization.string("companion.evolve.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(AppLocalization.format(
                        "companion.action.withCost",
                        AppLocalization.string("companion.evolve.action"),
                        self.store.companionActionCost ?? 0))
                    {
                        self.store.evolveCompanion()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!self.store.canPerformCompanionAction)

                    Divider()
                    Text(AppLocalization.string("companion.newEgg.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(
                        AppLocalization.format(
                            "companion.action.withCost",
                            AppLocalization.string("companion.newEgg.action"),
                            self.store.companionNewEggCost),
                        role: .destructive)
                    {
                        self.confirmsNewEgg = true
                    }
                    .disabled(
                        self.store.companionState.growthEnergy
                            < self.store.companionNewEggCost)
                }

                if self.store.canPerformCompanionAction {
                    Text(AppLocalization.string(self.readyMessageKey))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else if let cost = self.store.companionActionCost {
                    Text(AppLocalization.format(
                        "companion.energy.insufficient",
                        max(cost - self.store.companionState.growthEnergy, 0)))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var readyMessageKey: String {
        switch self.store.companionStage {
        case .egg: "companion.hatch.ready"
        case .hatchling, .junior: "companion.evolve.ready"
        case .adult: "companion.complete.ready"
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
