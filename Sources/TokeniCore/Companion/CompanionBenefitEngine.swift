import Foundation

public struct CompanionBenefitEngine: Sendable {
    public let passiveSlotThresholds: [Int]
    private var calendar: Calendar

    public init(
        passiveSlotThresholds: [Int] = [30, 60, 90, 120],
        calendar: Calendar = .current)
    {
        self.passiveSlotThresholds = passiveSlotThresholds
            .filter { $0 > 0 }
            .sorted()
        self.calendar = calendar
    }

    public func reconcileSlots(
        unlockedFormCount: Int,
        in state: inout CompanionBenefitState)
    {
        let earned = 1 + self.passiveSlotThresholds.count {
            unlockedFormCount >= $0
        }
        let unlockedCount = max(
            state.unlockedPassiveSlotCount,
            min(earned, 5))
        let assignments = Array(
            state.passiveGenerationIDs.prefix(unlockedCount))
        guard unlockedCount != state.unlockedPassiveSlotCount
                || assignments != state.passiveGenerationIDs
        else { return }
        state.unlockedPassiveSlotCount = unlockedCount
        state.passiveGenerationIDs = assignments
        state.updatedAt = .now
    }

    public func assignPassive(
        generationID: UUID?,
        to slot: Int,
        archivedCompanions: [CompletedCompanionGeneration],
        at date: Date = .now,
        in state: inout CompanionBenefitState) throws
    {
        guard slot >= 0, slot < state.unlockedPassiveSlotCount else {
            throw CompanionBenefitError.slotLocked
        }
        while state.passiveGenerationIDs.count < state.unlockedPassiveSlotCount {
            state.passiveGenerationIDs.append(nil)
        }
        guard let generationID else {
            state.passiveGenerationIDs[slot] = nil
            state.updatedAt = date
            return
        }
        guard let companion = archivedCompanions.first(where: {
            $0.generationID == generationID
        }) else {
            throw CompanionBenefitError.archivedCompanionNotFound
        }
        guard CompanionBenefitRegistry.definition(for: companion.speciesID)?
            .activation == .passive
        else {
            throw CompanionBenefitError.passiveCompanionRequired
        }
        guard !state.passiveGenerationIDs.enumerated().contains(where: {
            $0.offset != slot && $0.element == generationID
        }) else {
            throw CompanionBenefitError.duplicateCompanion
        }
        let archivedByID = Dictionary(uniqueKeysWithValues: archivedCompanions.map {
            ($0.generationID, $0)
        })
        guard !state.passiveGenerationIDs.enumerated().contains(where: { entry in
            guard entry.offset != slot,
                  let otherID = entry.element,
                  let other = archivedByID[otherID]
            else { return false }
            return other.speciesID == companion.speciesID
        }) else {
            throw CompanionBenefitError.duplicateSpecies
        }
        state.passiveGenerationIDs[slot] = generationID
        state.updatedAt = date
    }

    public func activePassives(
        archivedCompanions: [CompletedCompanionGeneration],
        state: CompanionBenefitState) -> [CompanionBenefitCompanion]
    {
        let byID = Dictionary(uniqueKeysWithValues: archivedCompanions.map {
            ($0.generationID, $0)
        })
        var species = Set<CompanionSpeciesID>()
        return state.passiveGenerationIDs
            .prefix(state.unlockedPassiveSlotCount)
            .compactMap { $0 }
            .compactMap { byID[$0] }
            .compactMap { generation in
                guard species.insert(generation.speciesID).inserted,
                      CompanionBenefitRegistry.definition(
                        for: generation.speciesID)?.activation == .passive
                else { return nil }
                return CompanionBenefitCompanion(
                    generationID: generation.generationID,
                    speciesID: generation.speciesID,
                    rarity: generation.finalRarity)
            }
    }

    public func actionCostDiscountBasisPoints(
        passives: [CompanionBenefitCompanion]) -> Int
    {
        passives
            .filter { $0.speciesID == .stackfox }
            .map {
                CompanionBenefitRegistry.stackOptimizationBasisPoints(
                    for: $0.rarity)
            }
            .max() ?? 0
    }

    public func luckyCheerBasisPoints(
        passives: [CompanionBenefitCompanion]) -> Int
    {
        passives
            .filter { $0.speciesID == .promptpup }
            .map {
                CompanionBenefitRegistry.luckyCheerBasisPoints(for: $0.rarity)
            }
            .max() ?? 0
    }

    public func rewardAbsorptionBasisPoints(
        passives: [CompanionBenefitCompanion]) -> Int
    {
        passives
            .filter { $0.speciesID == .nullslime }
            .map {
                CompanionBenefitRegistry.rewardAbsorptionBasisPoints(
                    for: $0.rarity)
            }
            .max() ?? 0
    }

    public func processVerifiedBaseEnergy(
        _ energy: Int,
        sourceAwardID: UUID,
        activeCompanion: CompanionBenefitCompanion?,
        at date: Date = .now,
        in state: inout CompanionBenefitState)
    {
        guard !state.processedGrowthAwardIDs.contains(sourceAwardID) else { return }
        self.rollOverDailyCountersIfNeeded(at: date, in: &state)
        state.processedGrowthAwardIDs.append(sourceAwardID)
        state.processedGrowthAwardIDs = Array(
            state.processedGrowthAwardIDs.suffix(512))
        guard energy > 0,
              let activeCompanion,
              activeCompanion.speciesID == .bytebot
        else {
            state.updatedAt = date
            return
        }

        let tier = CompanionBenefitRegistry.tokenOptimization(
            for: activeCompanion.rarity)
        let index = self.progressIndex(
            for: activeCompanion.generationID,
            in: &state)
        let total = Self.saturatedAdd(
            state.progress[index].baseEnergyRemainder,
            energy)
        let possible = total / tier.requiredBaseEnergy
        let available = max(
            tier.dailyCap - state.tokenOptimizationGrantedToday,
            0)
        let granted = min(possible, available)
        state.progress[index].baseEnergyRemainder =
            total % tier.requiredBaseEnergy
        state.tokenOptimizationGrantedToday += granted
        if granted > 0 {
            state.pendingEnergyBonuses.append(CompanionPendingEnergyBonus(
                sourceAwardID: sourceAwardID,
                amount: granted,
                createdAt: date))
        }
        state.updatedAt = date
    }

    public func markEnergyBonusApplied(
        _ bonusID: UUID,
        at date: Date = .now,
        in state: inout CompanionBenefitState)
    {
        state.pendingEnergyBonuses.removeAll { $0.id == bonusID }
        state.updatedAt = date
    }

    public func settleActiveTime(
        activeCompanion: CompanionBenefitCompanion?,
        at date: Date = .now,
        in state: inout CompanionBenefitState) -> Int
    {
        self.rollOverDailyCountersIfNeeded(at: date, in: &state)
        if let latest = state.latestObservedAt, date < latest {
            return 0
        }
        defer {
            state.activeGenerationID = activeCompanion?.generationID
            state.lastTimeEvaluationAt = date
            state.latestObservedAt = max(state.latestObservedAt ?? date, date)
            state.updatedAt = date
        }
        guard let activeCompanion,
              activeCompanion.speciesID == .cachecat
        else { return 0 }
        guard state.activeGenerationID == activeCompanion.generationID,
              let previous = state.lastTimeEvaluationAt,
              date >= previous
        else { return 0 }

        let tier = CompanionBenefitRegistry.starlightCache(
            for: activeCompanion.rarity)
        let elapsed = min(date.timeIntervalSince(previous), tier.interval)
        let index = self.progressIndex(
            for: activeCompanion.generationID,
            in: &state)
        state.progress[index].activeSeconds += max(elapsed, 0)
        let possible = Int(
            state.progress[index].activeSeconds / tier.interval)
        let available = max(
            tier.dailyCap - state.starlightCacheGrantedToday,
            0)
        let granted = min(possible, available)
        state.progress[index].activeSeconds.formTruncatingRemainder(
            dividingBy: tier.interval)
        state.starlightCacheGrantedToday += granted
        return granted
    }

    public func rewardAbsorptionBonus(
        for grants: [CompanionRewardGrant],
        basisPoints: Int,
        at date: Date = .now,
        in state: inout CompanionBenefitState) -> Int
    {
        guard basisPoints > 0 else { return 0 }
        let eligible = grants
            .filter { $0.reason.isEligibleForRewardAbsorption }
            .reduce(0) { Self.saturatedAdd($0, $1.amount) }
        guard eligible > 0 else { return 0 }
        let raw = Self.saturatedAdd(
            state.rewardBonusRemainderBasisPoints,
            Self.saturatedMultiply(eligible, min(basisPoints, 10_000)))
        let bonus = raw / 10_000
        state.rewardBonusRemainderBasisPoints = raw % 10_000
        state.updatedAt = date
        return bonus
    }

    public func unlockedSlotCount(for unlockedFormCount: Int) -> Int {
        min(
            1 + self.passiveSlotThresholds.count { unlockedFormCount >= $0 },
            5)
    }

    private func rollOverDailyCountersIfNeeded(
        at date: Date,
        in state: inout CompanionBenefitState)
    {
        let dateKey = GrowthLocalDate.key(for: date, calendar: self.calendar)
        guard state.dailyDateKey < dateKey else { return }
        state.dailyDateKey = dateKey
        state.tokenOptimizationGrantedToday = 0
        state.starlightCacheGrantedToday = 0
    }

    private func progressIndex(
        for generationID: UUID,
        in state: inout CompanionBenefitState) -> Int
    {
        if let index = state.progress.firstIndex(where: {
            $0.generationID == generationID
        }) {
            return index
        }
        state.progress.append(CompanionBenefitProgress(
            generationID: generationID))
        return state.progress.count - 1
    }

    private static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }

    private static func saturatedMultiply(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? .max : result.partialValue
    }
}

extension CompanionRewardReason {
    var isEligibleForRewardAbsorption: Bool {
        switch self {
        case .speciesDiscovered, .rarityDiscovered, .journeysCompleted,
             .collectionForms:
            true
        case .dailyAttendance, .weeklyAttendance, .monthlyAttendance,
             .verifiedGrowth, .releaseGift, .benefit:
            false
        }
    }
}
