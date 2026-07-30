import SwiftUI
import TokeniCore

private enum CompanionCollectionSection: String, CaseIterable, Identifiable {
    case home
    case collection
    case lineup
    case rewards

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .collection: "square.grid.3x3.fill"
        case .lineup: "person.3.fill"
        case .rewards: "star.fill"
        }
    }
}

private enum CompanionAcquisitionFilter: String, CaseIterable, Identifiable {
    case all
    case discovered
    case undiscovered

    var id: Self { self }
}

private enum CompanionCosmeticSlotFilter:
    String,
    CaseIterable,
    Identifiable
{
    case all
    case head
    case aura
    case background
    case palette

    var id: Self { self }

    var slot: CompanionCosmeticSlot? {
        switch self {
        case .all: nil
        case .head: .head
        case .aura: .aura
        case .background: .background
        case .palette: .palette
        }
    }
}

private enum CompanionCosmeticOwnershipFilter:
    String,
    CaseIterable,
    Identifiable
{
    case all
    case owned
    case unowned

    var id: Self { self }
}

struct CompanionCollectionView: View {
    @ObservedObject var store: UsageStore
    @State private var selectedSection = CompanionCollectionSection.home
    @State private var confirmsNewEgg = false
    @State private var confirmsCompletion = false
    @State private var selectedSpeciesID = CompanionSpeciesID.bytebot
    @State private var selectedGeneration = 0
    @State private var acquisitionFilter = CompanionAcquisitionFilter.all
    @State private var showsGrowthBreakdown = false
    @State private var showsAdvancedBenefits = false
    @State private var showsIdentityDetails = false
    @State private var showsEnergyDetails = false
    @State private var cosmeticSlotFilter =
        CompanionCosmeticSlotFilter.all
    @State private var cosmeticOwnershipFilter =
        CompanionCosmeticOwnershipFilter.all
    @State private var selectedArchivedGeneration:
        CompletedCompanionGeneration?
    @State private var pendingCosmeticPurchaseID: CompanionCosmeticID?
    @State private var nicknameDraft = ""

    private let stages: [CompanionGameStage] = [.hatchling, .junior, .adult]

    var body: some View {
        VStack(spacing: 0) {
            Picker(
                AppLocalization.string("companion.section.title"),
                selection: self.$selectedSection)
            {
                ForEach(CompanionCollectionSection.allCases) { section in
                    Label(
                        AppLocalization.string(
                            "companion.section.\(section.rawValue)"),
                        systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                self.sectionContent
                    .padding(20)
            }
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
        .sheet(
            isPresented: Binding(
                get: { self.pendingCosmeticPurchaseID != nil },
                set: { presented in
                    if !presented {
                        self.pendingCosmeticPurchaseID = nil
                    }
                }))
        {
            if let cosmetic = self.pendingCosmeticPurchase {
                self.cosmeticPurchasePreview(cosmetic)
            }
        }
        .sheet(item: self.$selectedArchivedGeneration) { generation in
            self.archivedCompanionDetail(generation)
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
            self.nicknameDraft = self.store.companionState.nickname ?? ""
            self.ensureSelectedSpeciesVisible()
        }
        .onChange(of: self.selectedGeneration) { _, _ in
            self.ensureSelectedSpeciesVisible()
        }
        .onChange(of: self.acquisitionFilter) { _, _ in
            self.ensureSelectedSpeciesVisible()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if self.store.companionMigrationQuote != nil
                || self.store.companionMigrationReceipt != nil
            {
                CompanionMigrationCard(store: self.store)
            }

            switch self.selectedSection {
            case .home:
                self.currentCompanion
                self.journeyActions
                self.homeDetails
            case .collection:
                self.summary
                self.pity
                self.collectionGrid
            case .lineup:
                self.companionArchive
            case .rewards:
                self.rewardWallet
            }
        }
    }

    private var homeDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(
                AppLocalization.string("companion.identity.title"),
                isExpanded: self.$showsIdentityDetails)
            {
                self.companionIdentity
                    .padding(.top, 8)
            }
            DisclosureGroup(
                AppLocalization.string("companion.energy.title"),
                isExpanded: self.$showsEnergyDetails)
            {
                self.energyWallet
                    .padding(.top, 8)
            }
        }
        .padding(TokeniLayout.cardPadding)
        .background(
            .quaternary.opacity(0.38),
            in: RoundedRectangle(cornerRadius: TokeniLayout.cornerRadius))
    }

    private var appliedEffectsSummary: some View {
        GroupBox(AppLocalization.string(
            "companion.benefit.appliedEffects.title"))
        {
            VStack(alignment: .leading, spacing: 8) {
                if let companion = self.store.activeBenefitCompanion,
                   let definition =
                       self.store.activeCompanionBenefitDefinition
                {
                    self.appliedEffectRow(
                        companion: companion,
                        definition: definition,
                        source: AppLocalization.string(
                            "companion.benefit.source.together"),
                        systemImage: "figure.walk")
                }

                ForEach(self.store.companionActivePassives, id: \.generationID) {
                    companion in
                    if let definition = CompanionBenefitRegistry.definition(
                        for: companion.speciesID)
                    {
                        self.appliedEffectRow(
                            companion: companion,
                            definition: definition,
                            source: self.passiveSource(
                                generationID: companion.generationID),
                            systemImage: "square.stack.3d.up.fill")
                    }
                }

                if self.store.activeCompanionBenefitDefinition == nil,
                   self.store.companionActivePassives.isEmpty
                {
                    Text(AppLocalization.string(
                        "companion.benefit.appliedEffects.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func appliedEffectRow(
        companion: CompanionBenefitCompanion,
        definition: CompanionBenefitDefinition,
        source: String,
        systemImage: String) -> some View
    {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(CompanionBenefitPresentation.name(definition.id))
                        .font(.caption.weight(.semibold))
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(CompanionBenefitPresentation.value(
                    definition.id,
                    rarity: companion.rarity))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if definition.activation == .active {
                    Text(self.benefitProgress(
                        definition.id,
                        rarity: companion.rarity))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            CompanionRarityBadge(rarity: companion.rarity)
        }
        .accessibilityElement(children: .combine)
    }

    private func passiveSource(generationID: UUID) -> String {
        guard let slot = self.store.companionPassiveSlot(
            for: generationID)
        else {
            return AppLocalization.string(
                "companion.benefit.mode.passive")
        }
        return AppLocalization.format(
            "companion.benefit.source.passiveSlot",
            slot + 1)
    }

    private var energyWallet: some View {
        GroupBox(AppLocalization.string("companion.energy.title")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    self.metric(
                        AppLocalization.string("companion.energy.balance"),
                        value: "\(self.store.companionState.availableGrowthEnergy)")
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
                        "+\(self.store.companionTodayEnergyTarget)",
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

                if self.store.companionState.delayedGrowthEarnedToday > 0 {
                    Label(
                        AppLocalization.format(
                            "companion.energy.delayedSettlement",
                            self.store.companionState.delayedGrowthEarnedToday),
                        systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let tokens = provider.reflectedTokens {
                                        Text(AppLocalization.format(
                                            "companion.energy.providerTokens",
                                            tokens.formatted(.number)))
                                            .monospacedDigit()
                                        if let usageDateKey = provider.usageDateKey {
                                            Text(usageDateKey)
                                                .foregroundStyle(.secondary)
                                        }
                                        if provider.wasSettledToday {
                                            Text(AppLocalization.string(
                                                "companion.energy.settledToday"))
                                                .foregroundStyle(.orange)
                                        } else if provider.isTodayPending {
                                            Text(AppLocalization.string(
                                                "companion.energy.todayPending"))
                                                .foregroundStyle(.secondary)
                                        }
                                    } else if let issue = provider.accountIssue {
                                        Text(AppLocalization.string(
                                            "usage.accountTokens.issue.\(issue.rawValue)"))
                                            .foregroundStyle(.orange)
                                    } else {
                                        Text(AppLocalization.string(
                                            "companion.energy.providerPending"))
                                            .foregroundStyle(.secondary)
                                    }
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
                    Label(
                        AppLocalization.string(
                            self.store.companionAttendanceStatus == .claimed
                                ? "companion.attendance.automaticComplete"
                                : "companion.attendance.automaticPending"),
                        systemImage: self.store.companionAttendanceStatus == .claimed
                            ? "checkmark.circle.fill"
                            : "clock")
                        .font(.caption)
                        .foregroundStyle(
                            self.store.companionAttendanceStatus == .claimed
                                ? Color.green
                                : Color.secondary)
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
                    Text(AppLocalization.string(
                        "companion.rewards.description.simplified"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(AppLocalization.string(
                    "companion.rewards.sources.simplified"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.string("companion.cosmetic.shop"))
                        .font(.subheadline.weight(.semibold))
                    Text(AppLocalization.string("companion.cosmetic.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AppLocalization.string(
                        "companion.cosmetic.earning"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                VStack(spacing: 8) {
                    Picker(
                        AppLocalization.string(
                            "companion.cosmetic.filter.slot"),
                        selection: self.$cosmeticSlotFilter)
                    {
                        ForEach(CompanionCosmeticSlotFilter.allCases) {
                            filter in
                            Text(AppLocalization.string(
                                "companion.cosmetic.filter.slot."
                                    + filter.rawValue))
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Picker(
                        AppLocalization.string(
                            "companion.cosmetic.filter.ownership"),
                        selection: self.$cosmeticOwnershipFilter)
                    {
                        ForEach(
                            CompanionCosmeticOwnershipFilter.allCases)
                        { filter in
                            Text(AppLocalization.string(
                                "companion.cosmetic.filter.ownership."
                                    + filter.rawValue))
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if self.filteredCosmetics.isEmpty {
                    ContentUnavailableView(
                        AppLocalization.string(
                            "companion.cosmetic.filter.empty"),
                        systemImage: "paintpalette")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 8),
                            count: 3),
                        spacing: 8)
                    {
                        ForEach(self.filteredCosmetics) { cosmetic in
                            self.cosmeticCard(cosmetic)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var companionBenefits: some View {
        GroupBox(AppLocalization.string("companion.benefit.title")) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        AppLocalization.string("companion.benefit.active.title"),
                        systemImage: "figure.walk")
                        .font(.subheadline.weight(.semibold))

                    if let companion = self.store.activeBenefitCompanion,
                       let definition =
                           self.store.activeCompanionBenefitDefinition
                    {
                        HStack(alignment: .top, spacing: 10) {
                            ByteBotSpriteView(
                                speciesID: companion.speciesID,
                                stage: self.store.displayedCompanionStage,
                                rarity: companion.rarity,
                                behavior: .idle,
                                dimension: 50,
                                animationsEnabled: false)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(CompanionBenefitPresentation.name(
                                    definition.id))
                                    .font(.caption.weight(.semibold))
                                Text(self.benefitValue(
                                    definition.id,
                                    rarity: companion.rarity))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(self.benefitProgress(
                                    definition.id,
                                    rarity: companion.rarity))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            CompanionRarityBadge(rarity: companion.rarity)
                        }
                    } else if self.store.activeBenefitCompanion != nil {
                        Text(AppLocalization.string(
                            "companion.benefit.active.passiveSpecies"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(AppLocalization.string(
                            "companion.benefit.active.empty"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                DisclosureGroup(
                    AppLocalization.string(
                        "companion.benefit.passive.advanced"),
                    isExpanded: self.$showsAdvancedBenefits)
                {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(
                                AppLocalization.string(
                                    "companion.benefit.passive.title"),
                                systemImage: "square.stack.3d.up.fill")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(AppLocalization.format(
                                "companion.benefit.passive.count",
                                self.store.companionUnlockedPassiveSlotCount,
                                5))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(0..<5, id: \.self) { slot in
                            self.passiveSlot(slot)
                        }

                        if let error = self.store.companionBenefitError {
                            Label(
                                self.passiveErrorText(error),
                                systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if let threshold =
                            self.store.companionNextPassiveSlotThreshold
                        {
                            Text(AppLocalization.format(
                                "companion.benefit.passive.next",
                                threshold,
                                self.store.companionState.collection
                                    .unlockedFormCount))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func passiveSlot(_ slot: Int) -> some View {
        if slot >= self.store.companionUnlockedPassiveSlotCount {
            HStack {
                Label(
                    AppLocalization.format(
                        "companion.benefit.passive.slot",
                        slot + 1),
                    systemImage: "lock.fill")
                Spacer()
                Group {
                    if let threshold =
                        self.store.companionPassiveUnlockThreshold(for: slot)
                    {
                        Text(AppLocalization.format(
                            "companion.benefit.passive.lockedProgress",
                            self.store.companionState.collection
                                .unlockedFormCount,
                            threshold))
                    } else {
                        Text(AppLocalization.string(
                            "companion.benefit.passive.locked"))
                    }
                }
                .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .padding(8)
            .background(
                Color.secondary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 7))
        } else {
            HStack(spacing: 10) {
                Text("\(slot + 1)")
                    .font(.caption2.weight(.bold))
                    .frame(width: 22, height: 22)
                    .background(
                        Color.accentColor.opacity(0.15),
                        in: Circle())

                if let generation =
                    self.store.companionPassiveAssignments[slot],
                   let definition = CompanionBenefitRegistry.definition(
                       for: generation.speciesID)
                {
                    ByteBotSpriteView(
                        speciesID: generation.speciesID,
                        stage: .adult,
                        rarity: generation.finalRarity,
                        behavior: .idle,
                        dimension: 38,
                        animationsEnabled: false)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(CompanionBenefitPresentation.speciesName(
                                generation.speciesID))
                                .font(.caption.weight(.semibold))
                            CompanionRarityBadge(
                                rarity: generation.finalRarity)
                        }
                        Text(CompanionBenefitPresentation.name(
                            definition.id))
                            .font(.caption2.weight(.semibold))
                        Text(CompanionBenefitPresentation.value(
                            definition.id,
                            rarity: generation.finalRarity))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppLocalization.format(
                            "companion.benefit.passive.slot",
                            slot + 1))
                            .font(.caption.weight(.semibold))
                        Text(AppLocalization.string(
                            "companion.benefit.passive.empty"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 6)

                if self.store.companionPassiveAssignments[slot] != nil {
                    Text(AppLocalization.string(
                        "companion.benefit.status.applied"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }

                Menu {
                    ForEach(self.store.companionPassiveCandidates) { generation in
                        Button {
                            self.store.setPassiveCompanion(
                                generation.generationID,
                                slot: slot)
                        } label: {
                            Text(self.passiveCandidateTitle(
                                generation,
                                slot: slot))
                        }
                        .disabled(self.passiveCandidateIsUsedElsewhere(
                            generation,
                            slot: slot))
                    }

                    if !self.store.companionPassiveCandidates.isEmpty {
                        Divider()
                    }

                    Button(AppLocalization.string(
                        "companion.benefit.passive.remove"))
                    {
                        self.store.setPassiveCompanion(nil, slot: slot)
                    }
                    .disabled(
                        self.store.companionPassiveAssignments[slot] == nil)
                } label: {
                    Text(AppLocalization.string(
                        self.store.companionPassiveAssignments[slot] == nil
                            ? "companion.benefit.passive.choose"
                            : "companion.benefit.passive.change"))
                }
                .menuStyle(.button)
                .controlSize(.small)
            }
            .padding(8)
            .background(
                Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private func passiveCandidateTitle(
        _ generation: CompletedCompanionGeneration,
        slot: Int) -> String
    {
        let species = CompanionBenefitPresentation.speciesName(
            generation.speciesID)
        let rarity = CompanionBenefitPresentation.rarityName(
            generation.finalRarity)
        let benefit = CompanionBenefitRegistry.definition(
            for: generation.speciesID).map {
            CompanionBenefitPresentation.name($0.id)
        } ?? ""
        let suffix = self.passiveCandidateIsUsedElsewhere(
            generation,
            slot: slot)
            ? AppLocalization.string("companion.benefit.passive.inUse")
            : ""
        return [species, rarity, benefit, suffix]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func passiveCandidateIsUsedElsewhere(
        _ generation: CompletedCompanionGeneration,
        slot: Int) -> Bool
    {
        self.store.companionPassiveAssignments.enumerated().contains {
            $0.offset != slot
                && $0.element?.speciesID == generation.speciesID
        }
    }

    private func passiveErrorText(
        _ error: CompanionBenefitError) -> String
    {
        let key: String = switch error {
        case .slotLocked:
            "companion.benefit.error.slotLocked"
        case .archivedCompanionNotFound:
            "companion.benefit.error.notFound"
        case .passiveCompanionRequired:
            "companion.benefit.error.passiveRequired"
        case .duplicateCompanion:
            "companion.benefit.error.duplicateCompanion"
        case .duplicateSpecies:
            "companion.benefit.error.duplicateSpecies"
        }
        return AppLocalization.string(key)
    }

    private func benefitValue(
        _ id: CompanionBenefitID,
        rarity: CompanionRarity) -> String
    {
        CompanionBenefitPresentation.value(id, rarity: rarity)
    }

    private func benefitProgress(
        _ id: CompanionBenefitID,
        rarity: CompanionRarity) -> String
    {
        switch id {
        case .tokenOptimization:
            let tier = CompanionBenefitRegistry.tokenOptimization(for: rarity)
            return AppLocalization.format(
                "companion.benefit.tokenOptimization.progress",
                self.store.activeCompanionBenefitProgress?
                    .baseEnergyRemainder ?? 0,
                tier.requiredBaseEnergy,
                self.store.companionBenefitState
                    .tokenOptimizationGrantedToday,
                tier.dailyCap)
        case .starlightCache:
            let tier = CompanionBenefitRegistry.starlightCache(for: rarity)
            let elapsed = self.store.activeCompanionBenefitProgress?
                .activeSeconds ?? 0
            return AppLocalization.format(
                "companion.benefit.starlightCache.progress",
                Int(elapsed / 3_600),
                Int(tier.interval / 3_600),
                self.store.companionBenefitState
                    .starlightCacheGrantedToday,
                tier.dailyCap)
        case .stackOptimization, .luckyCheer, .rewardAbsorption:
            return ""
        }
    }

    private var pendingCosmeticPurchase: CompanionCosmetic? {
        guard let pendingCosmeticPurchaseID else { return nil }
        return self.store.companionCosmetics.first {
            $0.id == pendingCosmeticPurchaseID
        }
    }

    private func cosmeticPurchasePreview(
        _ cosmetic: CompanionCosmetic) -> some View
    {
        let current = self.store.companionRewardState.selectedCosmeticIDs
        let preview = Set(current.filter {
            $0.slot != cosmetic.id.slot
        }).union([cosmetic.id])
        return VStack(spacing: 16) {
            Text(AppLocalization.string("companion.cosmetic.preview.title"))
                .font(.headline)

            HStack(spacing: 34) {
                self.cosmeticPreviewPet(
                    title: AppLocalization.string(
                        "companion.cosmetic.preview.current"),
                    cosmeticIDs: current)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                self.cosmeticPreviewPet(
                    title: AppLocalization.string(
                        "companion.cosmetic.preview.new"),
                    cosmeticIDs: preview)
            }

            Text(AppLocalization.format(
                "companion.cosmetic.confirm.message",
                self.cosmeticName(cosmetic.id),
                cosmetic.cost))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(AppLocalization.string("action.cancel")) {
                    self.pendingCosmeticPurchaseID = nil
                }
                Spacer()
                Button(AppLocalization.format(
                    "companion.cosmetic.confirm.action",
                    cosmetic.cost))
                {
                    self.store.purchaseCompanionCosmetic(cosmetic.id)
                    self.pendingCosmeticPurchaseID = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    self.store.companionRewardState.starShards
                        < cosmetic.cost)
            }
        }
        .padding(22)
        .frame(width: 430)
    }

    private func cosmeticPreviewPet(
        title: String,
        cosmeticIDs: Set<CompanionCosmeticID>) -> some View
    {
        VStack(spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
            ByteBotTransitionView(
                speciesID: self.store.displayedCompanionSpeciesID,
                stage: self.store.displayedCompanionStage,
                rarity: self.previewRarity(for: cosmeticIDs),
                behavior: .idle,
                cosmeticIDs: cosmeticIDs,
                dimension: 104,
                animationsEnabled: self.store.companionAnimationsEnabled,
                animationIntensity: self.store
                    .companionAnimationIntensity.motionScale)
        }
    }

    private func previewRarity(
        for cosmeticIDs: Set<CompanionCosmeticID>) -> CompanionRarity?
    {
        if cosmeticIDs.contains(.azurePalette) { return .rare }
        if cosmeticIDs.contains(.violetPalette) { return .epic }
        let variantID = self.store.displayedCompanionVariantID
        return variantID.map {
            CompanionVariantRegistry.definition(for: $0).assetRarity
        } ?? self.store.displayedCompanionRarity
    }

    private func cosmeticCard(_ cosmetic: CompanionCosmetic) -> some View {
        let isOwned = self.store.companionRewardState.unlockedCosmeticIDs
            .contains(cosmetic.id)
        let isSelected = self.store.companionRewardState.selectedCosmeticIDs
            .contains(cosmetic.id)
        let canAfford = self.store.companionRewardState.starShards >= cosmetic.cost

        return VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                CompanionCosmeticDecoration(
                    cosmeticID: cosmetic.id,
                    dimension: 54,
                    animationsEnabled: self.store.companionAnimationsEnabled,
                    motionIntensity: self.store
                        .companionAnimationIntensity.motionScale)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .help(AppLocalization.string(
                            "companion.cosmetic.equipped"))
                        .accessibilityLabel(AppLocalization.string(
                            "companion.cosmetic.equipped"))
                } else if isOwned {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)
                        .help(AppLocalization.string(
                            "companion.cosmetic.owned"))
                        .accessibilityLabel(AppLocalization.string(
                            "companion.cosmetic.owned"))
                }
            }
            Text(self.cosmeticName(cosmetic.id))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(self.cosmeticSlotName(cosmetic.id.slot))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(AppLocalization.format(
                "companion.cosmetic.price",
                cosmetic.cost))
                .font(.caption2)
                .foregroundStyle(
                    canAfford || isOwned ? Color.secondary : Color.orange)
            if !isOwned, !canAfford {
                Text(AppLocalization.format(
                    "companion.cosmetic.missing",
                    cosmetic.cost
                        - self.store.companionRewardState.starShards))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Button(self.cosmeticActionTitle(
                isOwned: isOwned,
                isSelected: isSelected,
                canAfford: canAfford))
            {
                if isSelected {
                    self.store.unequipCompanionCosmetic(slot: cosmetic.id.slot)
                } else if isOwned {
                    self.store.selectCompanionCosmetic(cosmetic.id)
                } else {
                    self.pendingCosmeticPurchaseID = cosmetic.id
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(9)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isOwned {
                self.pendingCosmeticPurchaseID = cosmetic.id
            }
        }
    }

    private func cosmeticName(_ cosmeticID: CompanionCosmeticID) -> String {
        AppLocalization.string("companion.cosmetic.\(cosmeticID.rawValue)")
    }

    private func cosmeticSlotName(_ slot: CompanionCosmeticSlot) -> String {
        AppLocalization.string("companion.cosmetic.slot.\(slot.rawValue)")
    }

    private func cosmeticActionTitle(
        isOwned: Bool,
        isSelected: Bool,
        canAfford: Bool) -> String
    {
        if isSelected {
            return AppLocalization.string("companion.cosmetic.remove")
        }
        if isOwned {
            return AppLocalization.string("companion.cosmetic.equip")
        }
        return AppLocalization.string(
            canAfford
                ? "companion.cosmetic.buy"
                : "companion.cosmetic.preview")
    }

    private var filteredCosmetics: [CompanionCosmetic] {
        self.store.companionCosmetics
            .filter { cosmetic in
                guard let slot = self.cosmeticSlotFilter.slot else {
                    return true
                }
                return cosmetic.id.slot == slot
            }
            .filter { cosmetic in
                let owned = self.store.companionRewardState
                    .unlockedCosmeticIDs.contains(cosmetic.id)
                switch self.cosmeticOwnershipFilter {
                case .all: true
                case .owned: owned
                case .unowned: !owned
                }
            }
            .sorted { lhs, rhs in
                let lhsOwned = self.store.companionRewardState
                    .unlockedCosmeticIDs.contains(lhs.id)
                let rhsOwned = self.store.companionRewardState
                    .unlockedCosmeticIDs.contains(rhs.id)
                if lhsOwned != rhsOwned {
                    return lhsOwned
                }
                if lhs.cost != rhs.cost {
                    return lhs.cost < rhs.cost
                }
                return lhs.id.rawValue < rhs.id.rawValue
            }
    }

    private var currentCompanion: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                AppLocalization.string(
                    self.store.isShowingArchivedCompanion
                        ? "companion.header.together"
                        : "companion.header.growing"),
                systemImage: self.store.isShowingArchivedCompanion
                    ? "figure.2"
                    : "leaf.fill")
                .font(.headline)

            HStack(spacing: 18) {
                ByteBotTransitionView(
                    speciesID: self.store.displayedCompanionSpeciesID,
                    stage: self.store.displayedCompanionStage,
                    rarity: self.store.displayedCompanionRarity,
                    behavior: self.store.companionBehavior,
                    cosmeticIDs: self.store.companionRewardState.selectedCosmeticIDs,
                    dimension: 104,
                    animationsEnabled: self.store.companionAnimationsEnabled,
                    animationIntensity: self.store
                        .companionAnimationIntensity.motionScale,
                    interactionPulse: self.store.companionInteractionPulse,
                    growthPulse: self.store.companionGrowthPulse)

                VStack(alignment: .leading, spacing: 8) {
                    Text(self.displayedCompanionTitle)
                        .font(.title2.weight(.semibold))
                    HStack {
                        Text(AppLocalization.string(
                            "companion.stage.\(self.store.displayedCompanionStage.rawValue)"))
                        if let variantID =
                            self.store.displayedCompanionVariantID
                        {
                            CompanionVariantBadge(variantID: variantID)
                        } else {
                            Text(AppLocalization.string("companion.rarity.unhatched"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if self.store.isShowingArchivedCompanion {
                        Text(AppLocalization.format(
                            "companion.archive.showcasedSummary",
                            self.store.displayedCompanionBondEnergy))
                            .foregroundStyle(.secondary)
                    } else if self.store.companionStage == .adult {
                        Text(AppLocalization.format(
                            "companion.collection.bond",
                            self.store.companionState.bondEnergy))
                            .foregroundStyle(.secondary)
                    } else if let next = self.store.companionNextStageEnergy {
                        ProgressView(value: self.store.companionStageProgress)
                            .frame(width: 220)
                        Text(AppLocalization.format(
                            "companion.progress",
                            self.store.companionState.availableGrowthEnergy,
                            next))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let personalityID =
                        self.store.displayedCompanionPersonalityID
                    {
                        Text(AppLocalization.string(
                            "companion.personality.\(personalityID.rawValue)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if self.store.isShowingArchivedCompanion {
                Divider()
                HStack(spacing: 8) {
                    Label(
                        AppLocalization.string(
                            "companion.header.growingJourney"),
                        systemImage: "leaf.fill")
                        .font(.caption.weight(.semibold))
                    Text(self.growingCompanionName)
                        .font(.caption)
                    Text(AppLocalization.string(
                        "companion.stage.\(self.store.companionStage.rawValue)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let variantID =
                        self.store.companionState.resolvedVariantID
                    {
                        CompanionVariantBadge(variantID: variantID)
                    } else {
                        Text(AppLocalization.string("companion.rarity.unhatched"))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(AppLocalization.format(
                        "companion.energy.balanceValue",
                        self.store.companionState.availableGrowthEnergy))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 11))
    }

    private var companionIdentity: some View {
        GroupBox(AppLocalization.string("companion.identity.title")) {
            VStack(alignment: .leading, spacing: 10) {
                if !self.store.isShowingArchivedCompanion,
                   self.store.companionStage != .egg
                {
                    HStack {
                        TextField(
                            AppLocalization.string(
                                "companion.identity.name.placeholder"),
                            text: self.$nicknameDraft)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                self.store.renameCompanion(
                                    self.nicknameDraft)
                            }
                        Button(AppLocalization.string(
                            "companion.identity.name.save"))
                        {
                            self.store.renameCompanion(
                                self.nicknameDraft)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack {
                    self.metric(
                        AppLocalization.string(
                            "companion.identity.personality"),
                        value: self.personalityName)
                    Divider()
                    self.metric(
                        AppLocalization.string(
                            "companion.identity.bondLevel"),
                        value: "\(self.store.displayedCompanionBondLevel)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.memories.title"),
                        value: "\(self.displayedMemoryCount)")
                }
                .frame(height: 42)

                Text(AppLocalization.string(
                    "companion.identity.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !self.displayedMemories.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(
                            self.displayedMemories.suffix(4).reversed()))
                        { memory in
                            HStack(spacing: 8) {
                                Image(systemName: self.memoryIcon(memory.kind))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 18)
                                Text(self.memoryText(memory))
                                    .font(.caption)
                                Spacer()
                                Text(memory.occurredAt.formatted(
                                    date: .abbreviated,
                                    time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var summary: some View {
        GroupBox(AppLocalization.string("companion.collection.summary")) {
            HStack {
                    self.metric(
                        AppLocalization.string("companion.collection.unlocked"),
                    value: "\(self.store.companionState.collection.discoveredCollectibleVariantCount) / \(CompanionSpeciesID.totalCollectibleVariantCount)")
                Divider()
                self.metric(
                    AppLocalization.string("companion.collection.species"),
                    value: "\(self.store.companionState.collection.discoveredSpeciesIDs.count) / \(CompanionSpeciesID.allCases.count)")
                Divider()
                self.metric(
                    AppLocalization.string("companion.collection.prismatic"),
                    value: "\(self.prismaticSpeciesCount) / \(CompanionSpeciesID.allCases.count)")
                Divider()
                self.metric(
                    AppLocalization.string("companion.memories.title"),
                    value: "\(self.store.companionState.memories.count)")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var pity: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppLocalization.string("companion.pity.next"))
                    .font(.caption.weight(.semibold))
                Text(self.nearestGuaranteeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 9))
    }

    private var nearestGuaranteeText: String {
        var guarantees: [(remaining: Int, key: String)] = [
            (
                max(
                    self.store.companionPrismaticPityHatches
                        - self.store.companionState.variantPity.standardHatches,
                    1),
                "companion.pity.prismatic"),
        ]
        if self.store.companionState.collection.discoveredSpeciesIDs.count
            < CompanionSpeciesID.allCases.count
        {
            guarantees.append((
                max(
                    6 - self.store.companionState.consecutiveDuplicateHatches,
                    1),
                "companion.pity.species"))
        }
        let nearest = guarantees.min {
            $0.remaining < $1.remaining
        } ?? (1, "companion.pity.prismatic")
        return AppLocalization.format(nearest.key, nearest.remaining)
    }

    private var collectionGrid: some View {
        GroupBox(AppLocalization.string("companion.collection.title")) {
            VStack(alignment: .leading, spacing: 12) {
                self.collectionFilters

                if self.filteredSpeciesIDs.isEmpty {
                    ContentUnavailableView(
                        AppLocalization.string(
                            "companion.collection.filter.empty"),
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(AppLocalization.string(
                            "companion.collection.filter.emptyDescription")))
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(minimum: 74, maximum: 90),
                                spacing: 8),
                        ],
                        spacing: 8)
                    {
                        ForEach(self.filteredSpeciesIDs, id: \.self) {
                            speciesID in
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

                    HStack(alignment: .top, spacing: 12) {
                        ForEach(
                            CompanionVariantRegistry.collectibleIDs,
                            id: \.self)
                        { variantID in
                            self.variantCell(
                                speciesID: self.selectedSpeciesID,
                                variantID: variantID)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var collectionFilters: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                AppLocalization.string("companion.collection.filter.title"),
                systemImage: "line.3.horizontal.decrease.circle")
                .font(.caption.weight(.semibold))

            HStack(spacing: 8) {
                if self.registeredGenerations.count > 1 {
                    Picker(
                        AppLocalization.string(
                            "companion.collection.filter.generation"),
                        selection: self.$selectedGeneration)
                    {
                        Text(AppLocalization.string(
                            "companion.collection.filter.all"))
                            .tag(0)
                        ForEach(self.registeredGenerations, id: \.self) {
                            generation in
                            Text(AppLocalization.format(
                                "companion.collection.filter.generationValue",
                                generation))
                                .tag(generation)
                        }
                    }
                }

                Picker(
                    AppLocalization.string(
                        "companion.collection.filter.acquisition"),
                    selection: self.$acquisitionFilter)
                {
                    ForEach(CompanionAcquisitionFilter.allCases) { filter in
                        Text(AppLocalization.string(
                            "companion.collection.filter.acquisition.\(filter.rawValue)"))
                            .tag(filter)
                    }
                }
            }
            .labelsHidden()
        }
    }

    private var registeredGenerations: [Int] {
        Array(Set(CompanionSpeciesID.allCases.map(\.contentGeneration)))
            .sorted()
    }

    private var filteredSpeciesIDs: [CompanionSpeciesID] {
        CompanionSpeciesID.allCases.filter { speciesID in
            let matchesGeneration = self.selectedGeneration == 0
                || speciesID.contentGeneration == self.selectedGeneration
            let isDiscovered = self.store.companionState.collection
                .discoveredSpeciesIDs.contains(speciesID)
            let matchesAcquisition = switch self.acquisitionFilter {
            case .all: true
            case .discovered: isDiscovered
            case .undiscovered: !isDiscovered
            }
            return matchesGeneration
                && matchesAcquisition
        }
    }

    private var filteredRarities: [CompanionRarity] {
        CompanionRarity.allCases
    }

    private func ensureSelectedSpeciesVisible() {
        guard !self.filteredSpeciesIDs.contains(self.selectedSpeciesID),
              let first = self.filteredSpeciesIDs.first
        else { return }
        self.selectedSpeciesID = first
    }

    @ViewBuilder
    private func variantCell(
        speciesID: CompanionSpeciesID,
        variantID: CompanionVariantID) -> some View
    {
        let records = self.store.companionState.collection.forms.filter {
            $0.speciesID == speciesID
                && ($0.variantID
                    ?? CompanionVariantRegistry.migrated(from: $0.rarity))
                    == variantID
        }
        let record = self.stages.reversed().compactMap { stage in
            records.first { $0.stage == stage }
        }.first

        VStack(spacing: 6) {
            CompanionVariantBadge(variantID: variantID)
            if let record {
                ByteBotSpriteView(
                    speciesID: record.speciesID,
                    stage: record.stage,
                    rarity: record.rarity,
                    behavior: .idle,
                    dimension: 76,
                    animationsEnabled: false)
                Text(AppLocalization.format(
                    "companion.collection.journeyStages",
                    Set(records.map(\.stage)).count,
                    self.stages.count))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "questionmark")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 76, height: 76)
                Text(AppLocalization.string(
                    "companion.collection.locked"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118)
        .background(
            .quaternary.opacity(0.45),
            in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
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
                Text(AppLocalization.string("companion.collection.encountered"))
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

    private var displayedCompanionName: String {
        guard let speciesID = self.store.displayedCompanionSpeciesID else {
            return AppLocalization.string("companion.species.mystery.name")
        }
        return AppLocalization.string(
            "companion.species.\(speciesID.rawValue).name")
    }

    private var displayedCompanionTitle: String {
        if let nickname = self.store.displayedCompanionNickname {
            return nickname
        }
        guard let speciesID = self.store.displayedCompanionSpeciesID else {
            return self.displayedCompanionName
        }
        return AppLocalization.format(
            "companion.collection.generation",
            speciesID.contentGeneration,
            self.displayedCompanionName)
    }

    private var personalityName: String {
        guard let personalityID =
            self.store.displayedCompanionPersonalityID
        else {
            return AppLocalization.string(
                "companion.identity.notAvailable")
        }
        return AppLocalization.string(
            "companion.personality.\(personalityID.rawValue)")
    }

    private var displayedMemoryCount: Int {
        self.displayedMemories.count
    }

    private var displayedMemories: [CompanionMemoryRecord] {
        let generationID = self.store.showcasedCompanion?.generationID
            ?? self.store.companionState.generationID
        return self.store.companionState.memories
            .filter { $0.generationID == generationID }
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    private func memoryIcon(_ kind: CompanionMemoryKind) -> String {
        switch kind {
        case .hatched: "sparkles"
        case .evolved: "arrow.up.circle.fill"
        case .firstPat: "hand.point.up.left.fill"
        case .bondLevel: "heart.fill"
        case .journeyCompleted: "book.closed.fill"
        }
    }

    private func memoryText(_ memory: CompanionMemoryRecord) -> String {
        if memory.kind == .bondLevel, let level = memory.bondLevel {
            return AppLocalization.format(
                "companion.memory.bondLevel",
                level)
        }
        return AppLocalization.string(
            "companion.memory.\(memory.kind.rawValue)")
    }

    private var prismaticSpeciesCount: Int {
        CompanionSpeciesID.allCases.count { speciesID in
            self.store.companionState.collection
                .discoveredCollectibleVariantKeys
                .contains("\(speciesID.rawValue).prismatic")
        }
    }

    private var growingCompanionName: String {
        guard let speciesID = self.store.companionState.speciesID else {
            return AppLocalization.string("companion.species.mystery.name")
        }
        return AppLocalization.string(
            "companion.species.\(speciesID.rawValue).name")
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

    private var companionArchive: some View {
        GroupBox(AppLocalization.string("companion.archive.title")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(AppLocalization.string("companion.archive.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if self.store.companionState.collection.archivedGenerations.isEmpty {
                    Text(AppLocalization.string("companion.archive.empty"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 8),
                            count: 2),
                        spacing: 8)
                    {
                        ForEach(Array(
                            self.store.companionState.collection
                                .archivedGenerations.reversed()))
                        { generation in
                            self.archivedCompanionCard(generation)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func archivedCompanionCard(
        _ generation: CompletedCompanionGeneration) -> some View
    {
        let isShowcased = self.store.companionState.showcasedGenerationID
            == generation.generationID
        let variantID = generation.variantID
            ?? CompanionVariantRegistry.migrated(
                from: generation.finalRarity)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ByteBotSpriteView(
                    speciesID: generation.speciesID,
                    stage: .adult,
                    rarity: generation.finalRarity,
                    behavior: .idle,
                    dimension: 52,
                    animationsEnabled: false)
                VStack(alignment: .leading, spacing: 4) {
                    Text(generation.nickname ?? AppLocalization.string(
                        "companion.species.\(generation.speciesID.rawValue).name"))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        CompanionVariantBadge(variantID: variantID)
                        if isShowcased {
                            Text(AppLocalization.string(
                                "companion.archive.status.together"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                    }
                    Text(AppLocalization.format(
                        "companion.archive.identity",
                        CompanionBond.level(for: generation.bondEnergy),
                        self.memoryCount(for: generation.generationID)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let personalityID = generation.personalityID {
                Text(AppLocalization.string(
                    "companion.personality.\(personalityID.rawValue)"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(AppLocalization.format(
                    "companion.archive.record",
                    generation.generationNumber,
                    generation.completedAt.formatted(
                        date: .abbreviated,
                        time: .omitted)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer(minLength: 4)

                Button {
                    self.selectedArchivedGeneration = generation
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(AppLocalization.string(
                    "companion.archive.details"))
                .accessibilityLabel(AppLocalization.string(
                    "companion.archive.details"))

                Button {
                    self.store.showcaseArchivedCompanion(
                        isShowcased ? nil : generation.generationID)
                } label: {
                    Label(
                        AppLocalization.string(
                            isShowcased
                                ? "companion.archive.putAway"
                                : "companion.archive.showcase"),
                        systemImage: isShowcased
                            ? "archivebox"
                            : "figure.2")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            isShowcased
                ? Color.accentColor.opacity(0.14)
                : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8))
    }

    private func archivedCompanionDetail(
        _ generation: CompletedCompanionGeneration) -> some View
    {
        let memories = self.store.companionState.memories
            .filter { $0.generationID == generation.generationID }
            .sorted { $0.occurredAt > $1.occurredAt }
        let variantID = generation.variantID
            ?? CompanionVariantRegistry.migrated(
                from: generation.finalRarity)
        let isShowcased = self.store.companionState.showcasedGenerationID
            == generation.generationID

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                ByteBotSpriteView(
                    speciesID: generation.speciesID,
                    stage: .adult,
                    rarity: generation.finalRarity,
                    behavior: .idle,
                    dimension: 112,
                    animationsEnabled: false)

                VStack(alignment: .leading, spacing: 7) {
                    Text(generation.nickname ?? AppLocalization.string(
                        "companion.species."
                            + generation.speciesID.rawValue
                            + ".name"))
                        .font(.title2.weight(.semibold))
                    CompanionVariantBadge(variantID: variantID)
                    if let personalityID = generation.personalityID {
                        Label(
                            AppLocalization.string(
                                "companion.personality."
                                    + personalityID.rawValue),
                            systemImage: "heart.text.square")
                            .foregroundStyle(.secondary)
                    }
                    Text(AppLocalization.format(
                        "companion.archive.record",
                        generation.generationNumber,
                        generation.completedAt.formatted(
                            date: .abbreviated,
                            time: .omitted)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                TokeniMetricTile(
                    title: AppLocalization.string(
                        "companion.identity.bondLevel"),
                    value: "\(CompanionBond.level(
                        for: generation.bondEnergy))",
                    systemImage: "heart.fill",
                    tint: .pink)
                TokeniMetricTile(
                    title: AppLocalization.string(
                        "companion.archive.bondEnergy"),
                    value: generation.bondEnergy.formatted(),
                    systemImage: "bolt.heart.fill",
                    tint: .orange)
                TokeniMetricTile(
                    title: AppLocalization.string(
                        "companion.memories.title"),
                    value: memories.count.formatted(),
                    systemImage: "book.closed.fill",
                    tint: .accentColor)
            }

            Text(AppLocalization.string("companion.memories.title"))
                .font(.headline)

            if memories.isEmpty {
                ContentUnavailableView(
                    AppLocalization.string(
                        "companion.archive.memories.empty"),
                    systemImage: "book.closed")
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        ForEach(memories) { memory in
                            HStack(spacing: 9) {
                                Image(systemName: self.memoryIcon(
                                    memory.kind))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(self.memoryText(memory))
                                        .font(.caption.weight(.semibold))
                                    Text(AppLocalization.string(
                                        "companion.stage."
                                            + memory.stage.rawValue))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(memory.occurredAt.formatted(
                                    date: .abbreviated,
                                    time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(
                                .quaternary.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }

            HStack {
                Button(AppLocalization.string("action.done")) {
                    self.selectedArchivedGeneration = nil
                }
                Spacer()
                Button {
                    self.store.showcaseArchivedCompanion(
                        isShowcased ? nil : generation.generationID)
                    self.selectedArchivedGeneration = nil
                } label: {
                    Label(
                        AppLocalization.string(
                            isShowcased
                                ? "companion.archive.putAway"
                                : "companion.archive.showcase"),
                        systemImage: isShowcased
                            ? "archivebox"
                            : "figure.2")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 480, height: 560)
    }

    private func memoryCount(for generationID: UUID) -> Int {
        self.store.companionState.memories.count {
            $0.generationID == generationID
        }
    }

    private func archivePassiveMenu(
        _ generation: CompletedCompanionGeneration,
        assignedSlot: Int?) -> some View
    {
        Menu {
            ForEach(
                0..<self.store.companionUnlockedPassiveSlotCount,
                id: \.self)
            { slot in
                Button {
                    self.store.setPassiveCompanion(
                        generation.generationID,
                        slot: slot)
                } label: {
                    Label(
                        AppLocalization.format(
                            assignedSlot == slot
                                ? "companion.archive.passive.assigned"
                                : "companion.archive.passive.assign",
                            slot + 1),
                        systemImage: assignedSlot == slot
                            ? "checkmark"
                            : "square.stack.3d.up")
                }
                .disabled(self.passiveCandidateIsUsedElsewhere(
                    generation,
                    slot: slot))
            }

            if let assignedSlot {
                Divider()
                Button(role: .destructive) {
                    self.store.setPassiveCompanion(nil, slot: assignedSlot)
                } label: {
                    Label(
                        AppLocalization.string(
                            "companion.archive.passive.remove"),
                        systemImage: "minus.circle")
                }
            }
        } label: {
            Label(
                AppLocalization.string(
                    assignedSlot == nil
                        ? "companion.archive.passive.choose"
                        : "companion.archive.passive.change"),
                systemImage: "square.stack.3d.up.fill")
        }
        .menuStyle(.button)
        .controlSize(.small)
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
                        self.store.companionState.availableGrowthEnergy
                            < self.store.companionNewEggCost)
                }

                if self.store.canPerformCompanionAction {
                    Text(AppLocalization.string(self.readyMessageKey))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else if let cost = self.store.companionActionCost {
                    Text(AppLocalization.format(
                        "companion.energy.insufficient",
                        max(
                            cost - self.store.companionState.availableGrowthEnergy,
                            0)))
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
