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

struct CompanionCollectionView: View {
    @ObservedObject var store: UsageStore
    @State private var selectedSection = CompanionCollectionSection.home
    @State private var confirmsNewEgg = false
    @State private var confirmsCompletion = false
    @State private var selectedSpeciesID = CompanionSpeciesID.bytebot
    @State private var selectedGeneration = 0
    @State private var acquisitionFilter = CompanionAcquisitionFilter.all
    @State private var showsGrowthBreakdown = false
    @State private var showsGuarantees = false
    @State private var pendingCosmeticPurchaseID: CompanionCosmeticID?

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
        .confirmationDialog(
            AppLocalization.string("companion.cosmetic.confirm.title"),
            isPresented: Binding(
                get: { self.pendingCosmeticPurchaseID != nil },
                set: { presented in
                    if !presented {
                        self.pendingCosmeticPurchaseID = nil
                    }
                }),
            titleVisibility: .visible)
        {
            if let cosmetic = self.pendingCosmeticPurchase {
                Button(AppLocalization.format(
                    "companion.cosmetic.confirm.action",
                    cosmetic.cost))
                {
                    self.store.purchaseCompanionCosmetic(cosmetic.id)
                    self.pendingCosmeticPurchaseID = nil
                }
            }
            Button(AppLocalization.string("action.cancel"), role: .cancel) {
                self.pendingCosmeticPurchaseID = nil
            }
        } message: {
            if let cosmetic = self.pendingCosmeticPurchase {
                Text(AppLocalization.format(
                    "companion.cosmetic.confirm.message",
                    self.cosmeticName(cosmetic.id),
                    cosmetic.cost))
            }
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
            switch self.selectedSection {
            case .home:
                self.currentCompanion
                self.appliedEffectsSummary
                self.journeyActions
                self.energyWallet
            case .collection:
                self.summary
                self.pity
                self.collectionGrid
            case .lineup:
                self.companionBenefits
                self.companionArchive
            case .rewards:
                self.rewardWallet
            }
        }
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

                Text(AppLocalization.string("companion.rewards.sources"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.string("companion.cosmetic.shop"))
                        .font(.subheadline.weight(.semibold))
                    Text(AppLocalization.string("companion.cosmetic.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 8),
                        count: 3),
                    spacing: 8)
                {
                    ForEach(self.store.companionCosmetics) { cosmetic in
                        self.cosmeticCard(cosmetic)
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

                Divider()

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

    private var pendingCosmeticPurchase: CompanionCosmetic? {
        guard let pendingCosmeticPurchaseID else { return nil }
        return self.store.companionCosmetics.first {
            $0.id == pendingCosmeticPurchaseID
        }
    }

    private func cosmeticCard(_ cosmetic: CompanionCosmetic) -> some View {
        let isOwned = self.store.companionRewardState.unlockedCosmeticIDs
            .contains(cosmetic.id)
        let isSelected = self.store.companionRewardState.selectedCosmeticIDs
            .contains(cosmetic.id)
        let canAfford = self.store.companionRewardState.starShards >= cosmetic.cost

        return VStack(spacing: 7) {
            CompanionCosmeticDecoration(
                cosmeticID: cosmetic.id,
                dimension: 54,
                animationsEnabled: self.store.companionAnimationsEnabled)
                .saturation(isOwned ? 1 : 0.25)
                .opacity(isOwned ? 1 : 0.72)
                .frame(height: 54)
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
            .disabled(!isOwned && !canAfford)
        }
        .frame(maxWidth: .infinity)
        .padding(9)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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
                : "companion.cosmetic.insufficient")
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
                    interactionPulse: self.store.companionInteractionPulse,
                    growthPulse: self.store.companionGrowthPulse)

                VStack(alignment: .leading, spacing: 8) {
                    Text(self.displayedCompanionTitle)
                        .font(.title2.weight(.semibold))
                    HStack {
                        Text(AppLocalization.string(
                            "companion.stage.\(self.store.displayedCompanionStage.rawValue)"))
                        if let rarity = self.store.displayedCompanionRarity {
                            CompanionRarityBadge(rarity: rarity)
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
                            self.store.companionState.growthEnergy,
                            next))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    CompanionTraitSummaryView(
                        store: self.store,
                        showsValue: false)
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
                    if let rarity = self.store.companionState.rarity {
                        CompanionRarityBadge(rarity: rarity)
                    } else {
                        Text(AppLocalization.string("companion.rarity.unhatched"))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(AppLocalization.format(
                        "companion.energy.balanceValue",
                        self.store.companionState.growthEnergy))
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

    private var summary: some View {
        GroupBox(AppLocalization.string("companion.collection.summary")) {
            HStack {
                    self.metric(
                        AppLocalization.string("companion.collection.unlocked"),
                    value: "\(self.store.companionState.collection.unlockedFormCount) / \(CompanionSpeciesID.totalRegisteredFormCount)")
                Divider()
                self.metric(
                    AppLocalization.string("companion.collection.species"),
                    value: "\(self.store.companionState.collection.discoveredSpeciesIDs.count) / \(CompanionSpeciesID.allCases.count)")
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
        DisclosureGroup(
            AppLocalization.string("companion.pity.title"),
            isExpanded: self.$showsGuarantees)
        {
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
            .padding(.top, 8)
        }
        .padding(12)
        .background(
            Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 9))
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

                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            Text("")
                            ForEach(self.filteredRarities, id: \.self) {
                                rarity in
                                CompanionRarityBadge(rarity: rarity)
                            }
                        }
                        ForEach(self.stages, id: \.self) { stage in
                            GridRow {
                                Text(AppLocalization.string(
                                    "companion.stage.\(stage.rawValue)"))
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 72, alignment: .leading)
                                ForEach(self.filteredRarities, id: \.self) {
                                    rarity in
                                    self.formCell(
                                        speciesID: self.selectedSpeciesID,
                                        stage: stage,
                                        rarity: rarity)
                                }
                            }
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
        guard let speciesID = self.store.displayedCompanionSpeciesID else {
            return self.displayedCompanionName
        }
        return AppLocalization.format(
            "companion.collection.generation",
            speciesID.contentGeneration,
            self.displayedCompanionName)
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
        let passiveSlot = self.store.companionPassiveSlot(
            for: generation.generationID)
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
                    Text(AppLocalization.string(
                        "companion.species.\(generation.speciesID.rawValue).name"))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        CompanionRarityBadge(rarity: generation.finalRarity)
                        if isShowcased {
                            Text(AppLocalization.string(
                                "companion.archive.status.together"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.green)
                        } else if let passiveSlot {
                            Text(AppLocalization.format(
                                "companion.archive.status.passiveSlot",
                                passiveSlot + 1))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(AppLocalization.format(
                        "companion.archive.bond",
                        generation.bondEnergy))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let definition = CompanionBenefitRegistry.definition(
                for: generation.speciesID)
            {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(CompanionBenefitPresentation.name(definition.id))
                            .font(.caption2.weight(.semibold))
                        Text(CompanionBenefitPresentation.mode(
                            definition.activation))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(self.benefitValue(
                        definition.id,
                        rarity: generation.finalRarity))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
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

                if CompanionBenefitRegistry.definition(
                    for: generation.speciesID)?.activation == .passive
                {
                    self.archivePassiveMenu(
                        generation,
                        assignedSlot: passiveSlot)
                }

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
