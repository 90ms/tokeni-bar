import SwiftUI
import TokeniCore

private enum CompanionCollectionSection: String, CaseIterable, Identifiable {
    case pets
    case eggs
    case rewards

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .pets: "pawprint.fill"
        case .eggs: "shippingbox.fill"
        case .rewards: "star.fill"
        }
    }
}

private enum CompanionCosmeticSlotFilter:
    String,
    CaseIterable,
    Identifiable
{
    case all
    case aura
    case background
    case frame
    case scene
    case sidekick

    var id: Self { self }

    var slot: CompanionCosmeticSlot? {
        switch self {
        case .all: nil
        case .aura: .aura
        case .background: .background
        case .frame: .frame
        case .scene: .scene
        case .sidekick: .sidekick
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

private struct CompanionCollectionEntrySelection: Identifiable {
    let speciesID: CompanionSpeciesID
    let variantID: CompanionVariantID

    var id: String { "\(self.speciesID.rawValue).\(self.variantID.rawValue)" }
}

struct CompanionCollectionView: View {
    @ObservedObject var store: UsageStore
    @State private var selectedSection = CompanionCollectionSection.pets
    @State private var selectedSpeciesID = CompanionSpeciesID.bytebot
    @State private var selectedOwnedSpeciesID: CompanionSpeciesID?
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
    @State private var selectedCollectionEntry:
        CompanionCollectionEntrySelection?
    @State private var collectionPreviewBehavior = CompanionBehavior.idle
    @State private var collectionSpeechMessageKey: String?
    @State private var pendingCosmeticPurchaseID: CompanionCosmeticID?
    @State private var pendingEggSale: CompanionEggInstance?
    @State private var pendingPetSale: CompletedCompanionGeneration?
    @State private var pendingBoosterReplacement: CompanionEnergyBoosterID?
    @State private var nicknameDraft = ""

    private let stages: [CompanionGameStage] = [.hatchling, .junior, .adult]

    var body: some View {
        if self.store.companionDataUnavailable {
            ContentUnavailableView(
                AppLocalization.string("companion.data.unavailable.title"),
                systemImage: "externaldrive.badge.exclamationmark",
                description: Text(AppLocalization.string(
                    "companion.data.unavailable.description")))
        } else {
            self.collectionContent
        }
    }

    private var collectionContent: some View {
        VStack(spacing: 0) {
            if self.store.companionGrowthDataUnavailable {
                Label(
                    AppLocalization.string("companion.growthData.unavailable"),
                    systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 10)
            }
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
        .sheet(item: self.$selectedCollectionEntry) { selection in
            self.collectionEntryDetail(selection)
        }
        .alert(item: self.$pendingEggSale) { egg in
            Alert(
                title: Text(AppLocalization.string(
                    "companion.sale.confirm.title")),
                message: Text(AppLocalization.string(
                    "companion.sale.egg.confirm")),
                primaryButton: .destructive(Text(AppLocalization.string(
                    "companion.sale.confirm.action"))) {
                        self.store.sellCompanionEgg(egg.id)
                    },
                secondaryButton: .cancel())
        }
        .alert(item: self.$pendingPetSale) { companion in
            Alert(
                title: Text(AppLocalization.string(
                    "companion.sale.confirm.title")),
                message: Text(AppLocalization.string(
                    "companion.sale.pet.confirm")),
                primaryButton: .destructive(Text(AppLocalization.string(
                    "companion.sale.confirm.action"))) {
                        self.store.sellCompanion(companion.generationID)
                    },
                secondaryButton: .cancel())
        }
        .confirmationDialog(
            AppLocalization.string("companion.booster.replace.title"),
            isPresented: Binding(
                get: { self.pendingBoosterReplacement != nil },
                set: { shown in
                    if !shown { self.pendingBoosterReplacement = nil }
                }),
            titleVisibility: .visible)
        {
            Button(
                AppLocalization.string("companion.booster.replace.action"),
                role: .destructive)
            {
                if let boosterID = self.pendingBoosterReplacement {
                    self.store.activateCompanionEnergyBooster(boosterID)
                }
                self.pendingBoosterReplacement = nil
            }
            Button(AppLocalization.string("action.cancel"), role: .cancel) {}
        } message: {
            Text(AppLocalization.string("companion.booster.replace.message"))
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
        .sheet(item: Binding(
            get: { self.store.companionMutationReveal },
            set: { reveal in
                if reveal == nil {
                    self.store.dismissCompanionMutationReveal()
                }
            }))
        { reveal in
            CompanionMutationRevealView(
                reveal: reveal,
                animationsEnabled: self.store.companionAnimationsEnabled,
                dismiss: self.store.dismissCompanionMutationReveal)
        }
        .onAppear {
            if let current = self.store.companionState.speciesID {
                self.selectedSpeciesID = current
            } else if let discovered = CompanionSpeciesRegistry.gameSpeciesIDs
                .first(where: {
                    self.store.companionState.collection.discoveredSpeciesIDs
                        .contains($0)
                })
            {
                self.selectedSpeciesID = discovered
            }
            self.nicknameDraft = self.store.companionState.nickname ?? ""
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch self.selectedSection {
            case .pets:
                self.petContent
            case .eggs:
                self.eggVault
            case .rewards:
                self.rewardWallet
            }
        }
    }

    @ViewBuilder
    private var petContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            self.currentCompanion
            self.homeDetails
            self.summary
            self.pity
            self.collectionGrid
            self.companionArchive
        }
    }

    private var eggVault: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.string("companion.eggs.title"))
                        .font(.title2.bold())
                    Text(AppLocalization.string("companion.eggs.description"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(AppLocalization.string("companion.eggs.hatchingCost"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(AppLocalization.format(
                    "companion.rewards.balance",
                    self.store.companionRewardState.starShards))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let message = self.store.companionEconomyErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            GroupBox(AppLocalization.string("companion.eggs.inventory")) {
                VStack(alignment: .leading, spacing: 10) {
                    if self.store.companionState.eggs.isEmpty {
                        Text(AppLocalization.string("companion.eggs.empty"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(CompanionEggRegistry.definitions.filter {
                            definition in
                            self.store.companionState.eggs.contains {
                                $0.definitionID == definition.id
                            }
                        }) { definition in
                            let count = self.store.companionState.eggs.filter {
                                $0.definitionID == definition.id
                            }.count
                            HStack {
                                Label(
                                    "\(AppLocalization.string("companion.egg.\(definition.id.rawValue)")) × \(count)",
                                    systemImage: "circle.hexagongrid.fill")
                                Spacer()
                                Button(AppLocalization.format(
                                    "companion.eggs.hatchCount", 1)) {
                                    self.store.openCompanionEggs(
                                        definitionID: definition.id,
                                        quantity: 1)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(self.store
                                    .companionEconomyTransactionInFlight)
                                if count >= 10 {
                                    Button(AppLocalization.format(
                                        "companion.eggs.hatchCount", 10)) {
                                        self.store.openCompanionEggs(
                                            definitionID: definition.id,
                                            quantity: 10)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(self.store
                                        .companionEconomyTransactionInFlight)
                                }
                                if definition.isSellable,
                                   let egg = self.store.companionState.eggs
                                    .first(where: {
                                        $0.definitionID == definition.id
                                    })
                                {
                                    Button(AppLocalization.format(
                                        "companion.eggs.sellValue",
                                        definition.resaleValue))
                                    {
                                        self.pendingEggSale = egg
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(self.store
                                        .companionEconomyTransactionInFlight)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(AppLocalization.string("companion.eggs.shop")) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(CompanionEggRegistry.definitions.filter {
                        $0.price != nil
                    }) { definition in
                        let unlocked = CompanionEggRegistry.isUnlocked(
                            definition,
                            highestPetLevel:
                                self.store.companionState.highestPetLevel,
                            discoveredSpeciesCount: self.store.companionState
                                .collection.discoveredSpeciesIDs.count)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppLocalization.string(
                                    "companion.egg.\(definition.id.rawValue)"))
                                Text(self.eggRequirementText(definition))
                                    .font(.caption)
                                    .foregroundStyle(
                                        unlocked ? Color.secondary : Color.orange)
                                Text(self.eggOutcomeText(definition))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                Button(AppLocalization.format(
                                    "companion.eggs.buyCount",
                                    1,
                                    definition.price ?? 0)) {
                                    self.store.purchaseCompanionEgg(
                                        definition.id,
                                        quantity: 1)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    !unlocked
                                        || self.store
                                            .companionEconomyTransactionInFlight
                                        || self.store.companionRewardState.starShards
                                            < (definition.price ?? 0))
                                Button(AppLocalization.format(
                                    "companion.eggs.buyCount",
                                    10,
                                    (definition.price ?? 0) * 10)) {
                                    self.store.purchaseCompanionEgg(
                                        definition.id,
                                        quantity: 10)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    !unlocked
                                        || self.store
                                            .companionEconomyTransactionInFlight
                                        || self.store.companionRewardState.starShards
                                            < (definition.price ?? 0) * 10)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func eggRequirementText(
        _ definition: CompanionEggDefinition) -> String
    {
        switch definition.unlockRequirement {
        case let .highestPetLevel(level):
            AppLocalization.format("companion.eggs.requirement.level", level)
        case let .discoveredSpecies(count):
            AppLocalization.format("companion.eggs.requirement.species", count)
        case .starterOnly, .milestoneOnly:
            AppLocalization.string("companion.eggs.locked")
        }
    }

    private func eggOutcomeText(
        _ definition: CompanionEggDefinition) -> String
    {
        if definition.guaranteesPrismatic {
            return AppLocalization.string(
                "companion.eggs.outcome.prismatic")
        }

        if definition.id == .discovery {
            return AppLocalization.string("companion.eggs.outcome.starlight")
        }

        let key = definition.prefersUndiscoveredSpecies
            ? "companion.eggs.outcome.discovery"
            : "companion.eggs.outcome.mystery"
        return AppLocalization.format(
            key,
            self.store.companionPrismaticChancePercent,
            self.store.companionPrismaticPityHatches)
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
                        AppLocalization.string("companion.level.title"),
                        value: "\(self.store.companionLevel)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.level.xp"),
                        value: "\(self.store.companionState.growthXP)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.energy.earnedToday"),
                        value: "+\(self.store.companionState.growthEarnedToday)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.level.next"),
                        value: "\(self.store.companionNextLevelXP)")
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

                if self.store.companionUpdateRewardAvailable {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "gift.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppLocalization.format(
                                "companion.updateReward.title",
                                self.store.currentAppVersion))
                                .font(.subheadline.weight(.semibold))
                            Text(AppLocalization.format(
                                "companion.updateReward.description",
                                self.store.companionUpdateRewardAmount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(AppLocalization.format(
                            "companion.updateReward.claim",
                            self.store.companionUpdateRewardAmount))
                        {
                            self.store.claimCompanionUpdateReward()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(12)
                    .background(
                        Color.yellow.opacity(0.1),
                        in: RoundedRectangle(
                            cornerRadius: TokeniLayout.cornerRadius))
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
                            .accessibilityLabel(AppLocalization.string(
                                "companion.attendance.week.accessibility"))
                            .accessibilityValue(AppLocalization.format(
                                "companion.progress.accessibility.value",
                                self.store.companionAttendanceWeekCount,
                                self.store.companionAttendanceWeeklyGoal))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalization.format(
                            "companion.attendance.month",
                            self.store.companionAttendanceMonthCount,
                            self.store.companionAttendanceMonthlyGoal))
                        ProgressView(
                            value: Double(self.store.companionAttendanceMonthCount),
                            total: Double(self.store.companionAttendanceMonthlyGoal))
                            .accessibilityLabel(AppLocalization.string(
                                "companion.attendance.month.accessibility"))
                            .accessibilityValue(AppLocalization.format(
                                "companion.progress.accessibility.value",
                                self.store.companionAttendanceMonthCount,
                                self.store.companionAttendanceMonthlyGoal))
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

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalization.string("companion.booster.title"))
                        .font(.subheadline.weight(.semibold))
                    if let active = self.store.companionActiveEnergyBooster {
                        Text(AppLocalization.format(
                            "companion.booster.active",
                            active.id.multiplier,
                            active.expiresAt.formatted(
                                date: .omitted,
                                time: .shortened)))
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    HStack(spacing: 8) {
                        ForEach(CompanionEnergyBoosterID.allCases, id: \.self) {
                            boosterID in
                            let count = self.store.companionRewardState
                                .energyBoosterInventory[boosterID, default: 0]
                            Button {
                                if count > 0 {
                                    if let active = self.store
                                        .companionActiveEnergyBooster,
                                       active.id != boosterID
                                    {
                                        self.pendingBoosterReplacement = boosterID
                                    } else {
                                        self.store.activateCompanionEnergyBooster(
                                            boosterID)
                                    }
                                } else {
                                    self.store.purchaseCompanionEnergyBooster(
                                        boosterID)
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("×\(boosterID.multiplier)")
                                        .font(.caption.weight(.bold))
                                    Text(count > 0
                                        ? AppLocalization.format(
                                            "companion.booster.count",
                                            count)
                                        : AppLocalization.format(
                                            "companion.booster.price",
                                            boosterID.cost))
                                        .font(.caption2)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(
                                count == 0
                                        && self.store.companionRewardState
                                            .starShards < boosterID.cost)
                        }
                    }
                    Text(AppLocalization.string(
                        "companion.booster.levelDescription"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

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
                                variantID: self.store.displayedCompanionVariantID,
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
                    let displayDimension: CGFloat = 48
                    ByteBotSpriteView(
                        speciesID: generation.speciesID,
                        stage: generation.stage,
                        rarity: generation.finalRarity,
                        variantID: generation.variantID,
                        behavior: .idle,
                        dimension: 38,
                        animationsEnabled: false)
                    .frame(
                        width: displayDimension,
                        height: displayDimension)
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
                        if let mutationID = generation.mutationID {
                            Text(AppLocalization.string(
                                "companion.mutation.\(mutationID.rawValue).name"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
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
                rarity: self.store.displayedCompanionRarity,
                variantID: self.store.displayedCompanionVariantID,
                    behavior: .idle,
                    mutationID: self.store.displayedCompanionMutationID,
                    cosmeticIDs: cosmeticIDs,
                dimension: 104,
                animationsEnabled: self.store.companionAnimationsEnabled,
                animationIntensity: self.store
                    .companionAnimationIntensity.motionScale)
        }
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
                        .companionAnimationIntensity.motionScale,
                    isBackground: cosmetic.id.slot == .background)
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
                .foregroundStyle(.secondary)
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
                case .all: return true
                case .owned: return owned
                case .unowned: return !owned
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
                    variantID: self.store.displayedCompanionVariantID,
                    behavior: self.store.companionBehavior,
                    mutationID: self.store.displayedCompanionMutationID,
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
                        Text(AppLocalization.format(
                            "companion.level.value",
                            self.store.displayedCompanionLevel))
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
                            "companion.level.value",
                            self.store.displayedCompanionLevel))
                            .foregroundStyle(.secondary)
                    } else if self.store.companionStage != .egg {
                        ProgressView(value: self.store.companionStageProgress)
                            .frame(width: 220)
                            .accessibilityLabel(AppLocalization.string(
                                "companion.progress.accessibility.label"))
                            .accessibilityValue(AppLocalization.format(
                                "companion.progress.accessibility.value",
                                self.store.companionDisplayedGrowthEnergy,
                                self.store.companionDisplayedGrowthEnergyTarget))
                        Text(AppLocalization.format(
                            "companion.level.progress",
                            self.store.companionDisplayedGrowthEnergy,
                            self.store.companionDisplayedGrowthEnergyTarget))
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
                            "companion.header.growingPet"),
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
                        "companion.level.value",
                        self.store.companionLevel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Divider()
                HStack {
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
                        .disabled(!self.store.canPerformCompanionAction)
                        if let level = self.store.companionNextEvolutionLevel {
                            Text(AppLocalization.format(
                                "companion.level.nextEvolution",
                                level))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    case .adult:
                        Button {
                            self.selectedSection = .eggs
                        } label: {
                            Label(
                                AppLocalization.string("companion.eggs.open"),
                                systemImage: "shippingbox.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        if self.store.companionLevel
                            == CompanionLevelCurve.standard.maximumLevel
                        {
                            VStack(alignment: .leading, spacing: 2) {
                                if self.store.activeCompanionIsGrowthTarget,
                                   let remainder = self.store
                                    .companionMaxLevelConversionRemainder
                                {
                                    Text(AppLocalization.format(
                                        "companion.maxLevel.conversionProgress",
                                        remainder,
                                        CompanionRewardEngine
                                            .maxLevelTokenCost))
                                    Text(AppLocalization.string(
                                        "companion.maxLevel.growthHint"))
                                } else {
                                    Text(AppLocalization.string(
                                        "companion.maxLevel.selectGrowthTargetHint"))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            Text(AppLocalization.format(
                                "companion.level.nextReward",
                                self.store.companionNextRecurringRewardLevel,
                                self.store.companionNextRecurringRewardShards))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
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
                            "companion.level.title"),
                        value: "\(self.store.displayedCompanionLevel)")
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
            VStack(spacing: 10) {
                HStack {
                    self.metric(
                        AppLocalization.string("companion.collection.unlocked"),
                        value: "\(self.store.companionState.collection.discoveredCollectionEntryCount) / \(CompanionSpeciesID.totalCollectionEntryCount)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.collection.species"),
                        value: "\(self.store.companionState.collection.discoveredSpeciesIDs.count) / \(CompanionSpeciesRegistry.gameSpeciesIDs.count)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.collection.mutations"),
                        value: "\(self.mutatedSpeciesCount) / \(CompanionSpeciesRegistry.gameSpeciesIDs.count)")
                }
                Divider()
                HStack {
                    self.metric(
                        AppLocalization.string("companion.collection.prismatic"),
                        value: "\(self.prismaticSpeciesCount) / \(CompanionSpeciesRegistry.gameSpeciesIDs.count)")
                    Divider()
                    self.metric(
                        AppLocalization.string("companion.memories.title"),
                        value: "\(self.store.companionState.memories.count)")
                }
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
            < CompanionSpeciesRegistry.gameSpeciesIDs.count
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
                ForEach(self.registeredGenerations, id: \.self) { generation in
                    self.generationCollectionSection(generation)
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
            .padding(.vertical, 8)
        }
    }

    private func generationCollectionSection(_ generation: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.format(
                "companion.collection.generation.section",
                generation))
                .font(.subheadline.weight(.semibold))

            if generation == 2 {
                self.generationTwoBanner
            }

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 74, maximum: 90),
                        spacing: 8),
                ],
                spacing: 8)
            {
                ForEach(self.speciesIDs(inContentGeneration: generation), id: \.self) {
                    speciesID in
                    self.speciesButton(speciesID)
                }
            }
        }
        .padding(10)
        .background(
            Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 9))
    }

    private var generationTwoBanner: some View {
        let generationTwoSpecies = Set(
            CompanionSpeciesID.species(inContentGeneration: 2))
        let discoveredCount = self.store.companionState.collection
            .discoveredSpeciesIDs
            .intersection(generationTwoSpecies)
            .count
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(AppLocalization.string(
                    "companion.collection.generation2.title"))
                    .font(.caption.weight(.bold))
                Text(AppLocalization.string(
                    "companion.collection.generation2.description"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(AppLocalization.format(
                    "companion.collection.generation2.progress",
                    discoveredCount,
                    generationTwoSpecies.count))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            Color.accentColor.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 9))
    }

    private var mutationLab: some View {
        GroupBox(AppLocalization.string("companion.mutation.title")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(AppLocalization.string("companion.mutation.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(AppLocalization.string("companion.mutation.pity"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                HStack {
                    Label(
                        AppLocalization.format(
                            "companion.mutation.progress",
                            self.store.companionState.collection
                                .discoveredMutationCount,
                            CompanionSpeciesID.totalCollectibleMutationCount),
                        systemImage: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(AppLocalization.format(
                        "companion.mutation.syntheses",
                        self.store.companionState.collection
                            .mutationSynthesisCount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let message = self.store.companionMutationErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8)
                {
                    ForEach(CompanionSpeciesRegistry.gameSpeciesIDs, id: \.self) {
                        speciesID in
                        self.mutationSpeciesCard(speciesID)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func mutationSpeciesCard(
        _ speciesID: CompanionSpeciesID) -> some View
    {
        let records = self.store.companionState.collection.mutations.filter {
            $0.speciesID == speciesID
        }
        let sourceCount = self.store.companionMutationSources(for: speciesID).count
        let canSynthesize = sourceCount >= CompanionMutationRegistry.synthesisSourceCount
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Text(AppLocalization.string(
                    "companion.species.\(speciesID.rawValue).name"))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(records.count)/\(CompanionMutationRegistry.allIDs.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                ],
                spacing: 4)
            {
                ForEach(CompanionMutationRegistry.allIDs, id: \.rawValue) {
                    mutationID in
                    let discovered = records.contains {
                        $0.mutationID == mutationID
                    }
                    HStack(spacing: 3) {
                        if discovered {
                            ByteBotSpriteView(
                                speciesID: speciesID,
                                stage: .hatchling,
                                rarity: .normal,
                                variantID: .mutated,
                                behavior: .idle,
                                dimension: 22,
                                animationsEnabled: false)
                                .frame(width: 25, height: 25)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(width: 25, height: 25)
                        }
                        Text(self.mutationName(mutationID))
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(discovered ? .primary : .tertiary)
                    }
                }
            }

            Text(AppLocalization.format(
                "companion.mutation.duplicates",
                sourceCount))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                self.store.synthesizeCompanionMutation(for: speciesID)
            } label: {
                Label(
                    AppLocalization.string(
                        canSynthesize
                            ? "companion.mutation.synthesize"
                            : "companion.mutation.needSources"),
                    systemImage: "wand.and.stars")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canSynthesize || self.store.companionCelebration != nil)
        }
        .padding(9)
        .background(
            .quaternary.opacity(0.45),
            in: RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    private var mutationLoadout: some View {
        if !self.store.isShowingArchivedCompanion,
           self.store.companionStage != .egg,
           let speciesID = self.store.companionState.speciesID
        {
            let records = self.store.companionState.collection.mutations.filter {
                $0.speciesID == speciesID
            }
            if !records.isEmpty {
                GroupBox(AppLocalization.string("companion.mutation.equip.title")) {
                    HStack {
                        Label(
                            AppLocalization.string("companion.mutation.equip"),
                            systemImage: "wand.and.stars")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Menu {
                            Button {
                                self.store.equipCompanionMutation(nil)
                            } label: {
                                Label(
                                    AppLocalization.string(
                                        "companion.mutation.none"),
                                    systemImage: "circle.slash")
                            }
                            Divider()
                            ForEach(records) { record in
                                Button {
                                    self.store.equipCompanionMutation(
                                        record.mutationID)
                                } label: {
                                    Label(
                                        self.mutationName(record.mutationID),
                                        systemImage: self.mutationIcon(
                                            record.mutationID))
                                }
                            }
                        } label: {
                            Label(
                                self.store.companionState.activeMutationID.map {
                                    self.mutationName($0)
                                } ?? AppLocalization.string(
                                    "companion.mutation.none"),
                                systemImage: "chevron.up.chevron.down")
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
            }
        }
    }

    private func mutationName(_ mutationID: CompanionMutationID) -> String {
        AppLocalization.string(
            "companion.mutation.\(mutationID.rawValue).name")
    }

    private func mutationIcon(_ mutationID: CompanionMutationID) -> String {
        switch mutationID.rawValue {
        case "neon": "bolt.fill"
        case "shadow": "moon.fill"
        case "crystal": "diamond.fill"
        case "glitch": "rectangle.split.3x1"
        case "aurora": "rainbow"
        default: "wand.and.stars"
        }
    }

    private var registeredGenerations: [Int] {
        Array(Set(CompanionSpeciesRegistry.gameSpeciesIDs.map(\.contentGeneration)))
            .sorted()
    }

    private func speciesIDs(inContentGeneration generation: Int) -> [CompanionSpeciesID] {
        CompanionSpeciesRegistry.gameSpeciesIDs.filter {
            $0.contentGeneration == generation
        }
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

        Button {
            self.collectionPreviewBehavior = .idle
            self.selectedCollectionEntry = CompanionCollectionEntrySelection(
                speciesID: speciesID,
                variantID: variantID)
        } label: {
            VStack(spacing: 6) {
                CompanionVariantBadge(variantID: variantID)
                if let record {
                    ByteBotSpriteView(
                        speciesID: record.speciesID,
                        stage: record.stage,
                        rarity: record.rarity,
                        variantID: variantID,
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
        }
        .buttonStyle(.plain)
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
        CompanionSpeciesRegistry.gameSpeciesIDs.count { speciesID in
            self.store.companionState.collection
                .discoveredCollectibleVariantKeys
                .contains("\(speciesID.rawValue).prismatic")
        }
    }

    private var mutatedSpeciesCount: Int {
        CompanionSpeciesRegistry.gameSpeciesIDs.count { speciesID in
            self.store.companionState.collection
                .discoveredCollectibleVariantKeys
                .contains("\(speciesID.rawValue).mutated")
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

                if !self.store.companionState.collection.archivedGenerations.isEmpty {
                    self.archiveFilters
                }

                if self.store.companionState.collection.archivedGenerations.isEmpty {
                    Text(AppLocalization.string("companion.archive.empty"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else if self.filteredArchivedGenerations.isEmpty {
                    ContentUnavailableView(
                        AppLocalization.string(
                            "companion.archive.filter.empty"),
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(AppLocalization.string(
                            "companion.archive.filter.emptyDescription")))
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 8),
                            count: 2),
                        spacing: 8)
                    {
                        ForEach(self.filteredArchivedGenerations) { generation in
                            self.archivedCompanionCard(generation)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var archiveFilters: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Label(
                    AppLocalization.string(
                        "companion.archive.filter.title"),
                    systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                Spacer()
                Picker(
                    AppLocalization.string(
                        "companion.archive.filter.title"),
                    selection: self.$selectedOwnedSpeciesID)
                {
                    Text(AppLocalization.string(
                        "companion.archive.filter.all"))
                        .tag(CompanionSpeciesID?.none)
                    ForEach(CompanionSpeciesRegistry.gameSpeciesIDs, id: \.self) {
                        speciesID in
                        Text(AppLocalization.string(
                            "companion.species.\(speciesID.rawValue).name"))
                            .tag(CompanionSpeciesID?.some(speciesID))
                    }
                }
                .pickerStyle(.menu)
            }

            Text(AppLocalization.format(
                "companion.archive.filter.count",
                self.filteredArchivedGenerations.count,
                self.store.companionState.collection.archivedGenerations.count))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var filteredArchivedGenerations: [CompletedCompanionGeneration] {
        self.store.companionState.collection.archivedGenerations.filter {
            guard let selectedOwnedSpeciesID = self.selectedOwnedSpeciesID
            else { return true }
            return $0.speciesID == selectedOwnedSpeciesID
        }.sorted { lhs, rhs in
            let lhsIsMaximum = CompanionLevelCurve.standard.level(
                forXP: lhs.growthXP)
                == CompanionLevelCurve.standard.maximumLevel
            let rhsIsMaximum = CompanionLevelCurve.standard.level(
                forXP: rhs.growthXP)
                == CompanionLevelCurve.standard.maximumLevel
            if lhsIsMaximum != rhsIsMaximum {
                return !lhsIsMaximum
            }
            return lhs.completedAt > rhs.completedAt
        }
    }

    private func archivedCompanionCard(
        _ generation: CompletedCompanionGeneration) -> some View
    {
        let isShowcased = self.store.companionState.showcasedGenerationID
            == generation.generationID
        let isGrowthTarget = self.store.companionState
            .resolvedGrowthTargetGenerationID == generation.generationID
        let variantID = generation.variantID
            ?? CompanionVariantRegistry.migrated(
                from: generation.finalRarity)
        let displayDimension: CGFloat = 64
        let level = CompanionLevelCurve.standard.level(
            forXP: generation.growthXP)
        let isMaximumLevel = level
            == CompanionLevelCurve.standard.maximumLevel
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ByteBotSpriteView(
                    speciesID: generation.speciesID,
                    stage: generation.stage,
                    rarity: generation.finalRarity,
                    variantID: generation.variantID,
                    behavior: .idle,
                    dimension: 52,
                    animationsEnabled: false)
                .frame(
                    width: displayDimension,
                    height: displayDimension)
                VStack(alignment: .leading, spacing: 4) {
                    Text(generation.nickname ?? AppLocalization.string(
                        "companion.species.\(generation.speciesID.rawValue).name"))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Label(
                        AppLocalization.string(
                            isMaximumLevel
                                ? "companion.archive.status.maximum"
                                : "companion.archive.status.growing"),
                        systemImage: isMaximumLevel
                            ? "checkmark.seal.fill"
                            : "arrow.up.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(
                            isMaximumLevel ? Color.orange : Color.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (isMaximumLevel ? Color.orange : Color.green)
                                .opacity(0.12),
                            in: Capsule())
                    HStack(spacing: 5) {
                        CompanionVariantBadge(variantID: variantID)
                        if let mutationID = generation.mutationID {
                            Text(AppLocalization.string(
                                "companion.mutation.\(mutationID.rawValue).name"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        if isShowcased {
                            Text(AppLocalization.string(
                                "companion.archive.status.together"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                        if isGrowthTarget {
                            Text(AppLocalization.string(
                                "companion.growthTarget.current"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(AppLocalization.format(
                        "companion.archive.identity",
                        level,
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

            if isMaximumLevel {
                if isGrowthTarget {
                    let remainder = self.store.companionRewardState
                        .maxLevelConversionRemainders[
                            generation.generationID,
                            default: 0]
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
                } else {
                    Text(AppLocalization.string(
                        "companion.maxLevel.selectGrowthTargetHint"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
                    self.store.selectCompanionGrowthTarget(
                        generation.generationID)
                } label: {
                    Image(systemName: isGrowthTarget ? "scope" : "target")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isGrowthTarget)
                .help(AppLocalization.string(
                    isGrowthTarget
                        ? "companion.growthTarget.current"
                        : "companion.growthTarget.select"))

                Button {
                    self.store.activateCompanion(generation.generationID)
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(AppLocalization.string("companion.archive.activate"))

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
                : isMaximumLevel
                    ? Color.orange.opacity(0.10)
                    : Color.green.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isMaximumLevel
                        ? Color.orange.opacity(0.45)
                        : Color.green.opacity(0.5),
                    lineWidth: isMaximumLevel ? 1 : 1.5))
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
        let displayDimension: CGFloat = 136

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                ByteBotSpriteView(
                    speciesID: generation.speciesID,
                    stage: generation.stage,
                    rarity: generation.finalRarity,
                    variantID: generation.variantID,
                    behavior: .idle,
                    dimension: 112,
                    animationsEnabled: false)
                .frame(
                    width: displayDimension,
                    height: displayDimension)

                VStack(alignment: .leading, spacing: 7) {
                    Text(generation.nickname ?? AppLocalization.string(
                        "companion.species."
                            + generation.speciesID.rawValue
                            + ".name"))
                        .font(.title2.weight(.semibold))
                    CompanionVariantBadge(variantID: variantID)
                    if let mutationID = generation.mutationID {
                        Label(
                            AppLocalization.string(
                                "companion.mutation.\(mutationID.rawValue).name"),
                            systemImage: "wand.and.stars")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
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
                        "companion.level.title"),
                    value: String(CompanionLevelCurve.standard.level(
                        forXP: generation.growthXP)),
                    systemImage: "arrow.up.circle.fill",
                    tint: .pink)
                TokeniMetricTile(
                    title: AppLocalization.string(
                        "companion.level.xp"),
                    value: generation.growthXP.formatted(),
                    systemImage: "sparkles",
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
                Button(
                    AppLocalization.format(
                        "companion.archive.sellValue",
                        generation.variantID == .prismatic ? 60 : 30),
                    role: .destructive)
                {
                    self.pendingPetSale = generation
                    self.selectedArchivedGeneration = nil
                }
                Spacer()
                Button {
                    self.store.activateCompanion(generation.generationID)
                    self.selectedArchivedGeneration = nil
                } label: {
                    Label(
                        AppLocalization.string("companion.archive.activate"),
                        systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
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

    private func collectionEntryDetail(
        _ selection: CompanionCollectionEntrySelection) -> some View
    {
        let records = self.store.companionState.collection.forms.filter {
            $0.speciesID == selection.speciesID
                && ($0.variantID
                    ?? CompanionVariantRegistry.migrated(from: $0.rarity))
                    == selection.variantID
        }
        let record = self.stages.reversed().compactMap { stage in
            records.first { $0.stage == stage }
        }.first
        let activeMatches = self.store.companionState.speciesID
                == selection.speciesID
            && self.store.companionState.resolvedVariantID
                == selection.variantID
        let archived = self.store.companionState.collection
            .archivedGenerations.first {
                $0.speciesID == selection.speciesID
                    && ($0.variantID
                        ?? CompanionVariantRegistry.migrated(
                            from: $0.finalRarity)) == selection.variantID
            }
        let ownedID = activeMatches
            ? self.store.companionState.generationID
            : archived?.generationID
        let ownedXP = activeMatches
            ? self.store.companionState.growthXP
            : archived?.growthXP
        let ownedLevel = ownedXP.map {
            CompanionLevelCurve.standard.level(forXP: $0)
        }
        let commonBehaviors: [CompanionBehavior] = [
            .idle, .working, .waiting, .warning, .celebrate, .sleep,
        ]
        let specialAction = CompanionSpecialActionRegistry.action(
            for: selection.speciesID,
            variantID: selection.variantID)
        let behaviors = commonBehaviors
            + (record != nil ? specialAction.map { [$0.behavior] } ?? [] : [])

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                if let record {
                    ByteBotSpriteView(
                        speciesID: selection.speciesID,
                        stage: record.stage,
                        rarity: record.rarity,
                        variantID: selection.variantID,
                        behavior: self.collectionPreviewBehavior,
                        dimension: 144,
                        animationsEnabled: self.store.companionAnimationsEnabled)
                } else {
                    Image(systemName: "questionmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 144, height: 144)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalization.string(
                        "companion.species.\(selection.speciesID.rawValue).name"))
                        .font(.title2.weight(.semibold))
                    CompanionVariantBadge(variantID: selection.variantID)
                    Text(AppLocalization.string(
                        record == nil
                            ? "companion.collection.locked"
                            : "companion.collection.encountered"))
                        .foregroundStyle(
                            record == nil ? Color.secondary : Color.green)
                    if let ownedLevel {
                        Label(
                            AppLocalization.format(
                                "companion.level.value",
                                ownedLevel),
                            systemImage: ownedLevel
                                == CompanionLevelCurve.standard.maximumLevel
                                ? "checkmark.seal.fill"
                                : "arrow.up.circle.fill")
                    }
                }
            }

            if ownedLevel == CompanionLevelCurve.standard.maximumLevel {
                Button {
                    self.collectionSpeechMessageKey = (1...7)
                        .map { "companion.maxLevel.message.\($0)" }
                        .filter { $0 != self.collectionSpeechMessageKey }
                        .randomElement()
                } label: {
                    Label(
                        AppLocalization.string(
                            "companion.maxLevel.action"),
                        systemImage: "bubble.left.fill")
                }
                .buttonStyle(.bordered)
                if let collectionSpeechMessageKey {
                    Text(AppLocalization.string(collectionSpeechMessageKey))
                        .font(.callout)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            .quaternary,
                            in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if record != nil {
                Text(AppLocalization.string("companion.actions.preview"))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 7) {
                        ForEach(behaviors, id: \.self) { behavior in
                            Button {
                                self.collectionPreviewBehavior = behavior
                            } label: {
                                Text(self.actionName(
                                    behavior,
                                    specialAction: specialAction))
                            }
                            .buttonStyle(.bordered)
                            .tint(
                                self.collectionPreviewBehavior == behavior
                                    ? Color.accentColor
                                    : Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                }

                Text(AppLocalization.format(
                    "companion.collection.journeyStages",
                    Set(records.map(\.stage)).count,
                    self.stages.count))
                    .font(.subheadline)
                HStack {
                    ForEach(self.stages, id: \.self) { stage in
                        Label(
                            AppLocalization.string(
                                "companion.stage.\(stage.rawValue)"),
                            systemImage: records.contains { $0.stage == stage }
                                ? "checkmark.circle.fill"
                                : "circle")
                            .foregroundStyle(
                                records.contains { $0.stage == stage }
                                    ? Color.green
                                    : Color.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()
            HStack {
                Button(AppLocalization.string("action.done")) {
                    self.collectionSpeechMessageKey = nil
                    self.selectedCollectionEntry = nil
                }
                Spacer()
                if let ownedID {
                    Button {
                        self.store.selectCompanionGrowthTarget(ownedID)
                        self.selectedCollectionEntry = nil
                    } label: {
                        Label(
                            AppLocalization.string(
                                "companion.growthTarget.select"),
                            systemImage: "scope")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(22)
        .frame(width: 520, height: 520)
    }

    private func actionName(
        _ behavior: CompanionBehavior,
        specialAction: CompanionSpecialActionDefinition?) -> String
    {
        if behavior == .signature, let specialAction {
            return AppLocalization.string(
                "companion.specialAction.\(specialAction.id.rawValue)")
        }
        return AppLocalization.string(
            "companion.behavior.\(behavior.rawValue)")
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
