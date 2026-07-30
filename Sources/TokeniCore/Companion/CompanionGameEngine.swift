import Foundation

public struct CompanionGameEngine: Sendable {
    public let rules: CompanionGameRules
    private var calendar: Calendar

    public init(
        rules: CompanionGameRules = .standard,
        calendar: Calendar = .current)
    {
        self.rules = rules
        self.calendar = calendar
    }

    public func apply(
        award: GrowthEnergyAward,
        to state: inout CompanionGameState) -> [CompanionGameEvent]
    {
        guard !state.appliedGrowthAwardIDs.contains(award.id) else { return [] }
        self.rollOverEnergyIfNeeded(at: award.createdAt, in: &state)
        state.appliedGrowthAwardIDs.append(award.id)
        state.appliedGrowthAwardIDs = Array(state.appliedGrowthAwardIDs.suffix(256))
        state.updatedAt = award.createdAt
        guard award.energy > 0 else { return [] }

        let availableRoom = max(self.rules.maximumEnergyBalance - state.growthEnergy, 0)
        let credited = min(award.energy, availableRoom)
        state.growthEnergy = Self.saturatedAdd(state.growthEnergy, credited)
        state.growthEarnedToday = Self.saturatedAdd(
            state.growthEarnedToday,
            credited)
        let settlementDateKey = GrowthLocalDate.key(
            for: award.createdAt,
            calendar: self.calendar)
        if award.dateKey != settlementDateKey {
            state.delayedGrowthEarnedToday = Self.saturatedAdd(
                state.delayedGrowthEarnedToday,
                credited)
        }

        var events: [CompanionGameEvent] = []
        if credited > 0 {
            events.append(.energyApplied(credited))
        }
        if state.stage == .adult {
            let previousLevel = CompanionBond.level(for: state.bondEnergy)
            state.bondEnergy = Self.saturatedAdd(state.bondEnergy, award.energy)
            events.append(.bondIncreased(award.energy))
            let newLevel = CompanionBond.level(for: state.bondEnergy)
            if newLevel > previousLevel {
                for level in (previousLevel + 1)...newLevel {
                    self.recordMemory(
                        .bondLevel,
                        bondLevel: level,
                        at: award.createdAt,
                        in: &state)
                }
            }
        }
        return events
    }

    public func hatch(
        speciesUnitValue: Double,
        variantUnitValue: Double,
        personalityUnitValue: Double = 0,
        costDiscountBasisPoints: Int = 0,
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        self.rollOverEnergyIfNeeded(at: now, in: &state)
        guard state.stage == .egg else { throw CompanionGameError.eggRequired }
        let cost = self.discountedCost(
            self.rules.hatchCost,
            basisPoints: costDiscountBasisPoints)
        try self.spend(cost, in: &state)
        return [.energySpent(cost)] + self.revealHatch(
            speciesUnitValue: speciesUnitValue,
            variantUnitValue: variantUnitValue,
            personalityUnitValue: personalityUnitValue,
            at: now,
            in: &state)
    }

    private func revealHatch(
        speciesUnitValue: Double,
        variantUnitValue: Double,
        personalityUnitValue: Double,
        at now: Date,
        in state: inout CompanionGameState) -> [CompanionGameEvent]
    {
        let discoveredSpecies = state.collection.discoveredSpeciesIDs
        let missingSpecies = CompanionSpeciesID.allCases.filter {
            !discoveredSpecies.contains($0)
        }
        let pityApplies = !missingSpecies.isEmpty
            && state.consecutiveDuplicateHatches
                >= self.rules.duplicateSpeciesPityHatches
        let speciesID = self.rollSpecies(
            from: pityApplies ? missingSpecies : CompanionSpeciesID.allCases,
            unitValue: speciesUnitValue)
        let isNewSpecies = !discoveredSpecies.contains(speciesID)
        let variantID = self.rollVariant(
            unitValue: variantUnitValue,
            pity: state.variantPity)
        let rarity = CompanionVariantRegistry.definition(
            for: variantID).assetRarity
        state.speciesID = speciesID
        state.stage = .hatchling
        state.rarity = rarity
        state.variantID = variantID
        state.nickname = nil
        state.personalityID = self.rollPersonality(
            unitValue: personalityUnitValue)
        state.variantPity.standardHatches = variantID == .prismatic
            ? 0
            : Self.saturatedAdd(state.variantPity.standardHatches, 1)
        state.consecutiveDuplicateHatches = isNewSpecies
            ? 0
            : Self.saturatedAdd(state.consecutiveDuplicateHatches, 1)
        state.updatedAt = now
        let unlocked = self.recordHatch(
            rarity: rarity,
            at: now,
            in: &state)
        self.recordMemory(.hatched, at: now, in: &state)
        state.celebrationUntil = now.addingTimeInterval(6)
        return [
            .hatched(
                speciesID: speciesID,
                rarity: rarity,
                isNewSpecies: isNewSpecies,
                unlockedFormIDs: unlocked),
        ]
    }

    public func evolve(
        unitValue: Double,
        costDiscountBasisPoints: Int = 0,
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        self.rollOverEnergyIfNeeded(at: now, in: &state)
        guard state.stage == .hatchling || state.stage == .junior,
              let nextStage = self.rules.nextStage(after: state.stage)
        else { throw CompanionGameError.evolutionUnavailable }
        guard let rarity = state.rarity,
              state.resolvedVariantID != nil
        else {
            throw CompanionGameError.rarityMissing
        }

        let cost = self.discountedCost(
            self.rules.actionCost(to: nextStage),
            basisPoints: costDiscountBasisPoints)
        try self.spend(cost, in: &state)
        let fromStage = state.stage
        state.stage = nextStage
        state.updatedAt = now
        state.celebrationUntil = now.addingTimeInterval(6)
        let unlocked = self.recordEvolution(
            stage: nextStage,
            rarity: rarity,
            at: now,
            in: &state)
        self.recordMemory(.evolved, at: now, in: &state)
        return [
            .energySpent(cost),
            .evolved(
                fromStage: fromStage,
                toStage: nextStage,
                fromRarity: rarity,
                toRarity: rarity,
                unlockedFormIDs: unlocked),
        ]
    }

    public func completeGeneration(
        speciesUnitValue: Double,
        variantUnitValue: Double,
        personalityUnitValue: Double = 0,
        costDiscountBasisPoints: Int = 0,
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        self.rollOverEnergyIfNeeded(at: now, in: &state)
        guard state.stage == .adult else { throw CompanionGameError.adultRequired }
        guard let rarity = state.rarity,
              let speciesID = state.speciesID
        else {
            throw CompanionGameError.rarityMissing
        }
        let completionCost = self.discountedCost(
            self.rules.journeyCompletionCost,
            basisPoints: costDiscountBasisPoints)
        try self.spend(completionCost, in: &state)

        self.recordMemory(.journeyCompleted, at: now, in: &state)
        let completion = CompletedCompanionGeneration(
            generationID: state.generationID,
            generationNumber: state.generationNumber,
            speciesID: speciesID,
            finalRarity: rarity,
            variantID: state.resolvedVariantID,
            nickname: state.nickname,
            personalityID: state.personalityID,
            bondEnergy: state.bondEnergy,
            completedAt: now)
        self.recordCompletion(completion, in: &state)
        self.startNewEgg(at: now, in: &state)
        let hatchEvents = self.revealHatch(
            speciesUnitValue: speciesUnitValue,
            variantUnitValue: variantUnitValue,
            personalityUnitValue: personalityUnitValue,
            at: now,
            in: &state)
        return [
            .energySpent(completionCost),
            .generationCompleted(completion),
            .newEgg(generationNumber: state.generationNumber),
        ] + hatchEvents
    }

    public func abandonForNewEgg(
        costDiscountBasisPoints: Int = 0,
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        self.rollOverEnergyIfNeeded(at: now, in: &state)
        guard state.stage != .egg else { throw CompanionGameError.eggRequired }
        let cost = self.discountedCost(
            self.rules.newEggCost,
            basisPoints: costDiscountBasisPoints)
        try self.spend(cost, in: &state)
        self.startNewEgg(at: now, in: &state)
        return [
            .energySpent(cost),
            .newEgg(generationNumber: state.generationNumber),
        ]
    }

    public func showcaseArchivedGeneration(
        _ generationID: UUID?,
        at now: Date = .now,
        in state: inout CompanionGameState) throws
    {
        if let generationID,
           !state.collection.archivedGenerations.contains(where: {
               $0.generationID == generationID
           })
        {
            throw CompanionGameError.archivedGenerationNotFound
        }
        state.showcasedGenerationID = generationID
        state.updatedAt = now
    }

    public func rollOverEnergyIfNeeded(
        at now: Date = .now,
        in state: inout CompanionGameState)
    {
        let currentKey = GrowthLocalDate.key(for: now, calendar: self.calendar)
        guard state.growthDateKey < currentKey else { return }

        let elapsedDays = max(
            self.dayDistance(from: state.growthDateKey, to: currentKey),
            1)
        var carried = min(state.growthEnergy, self.rules.maximumEnergyBalance)
        for _ in 0..<elapsedDays {
            carried = Int(
                floor(Double(carried) * self.rules.dailyCarryoverRate))
        }
        state.growthEnergy = min(carried, self.rules.maximumEnergyBalance)
        state.growthDateKey = currentKey
        state.growthCarriedToday = state.growthEnergy
        state.growthEarnedToday = 0
        state.delayedGrowthEarnedToday = 0
        state.growthSpentToday = 0
        state.updatedAt = now
    }

    public func actionCost(
        for stage: CompanionGameStage,
        costDiscountBasisPoints: Int = 0) -> Int?
    {
        let baseCost: Int? = switch stage {
        case .egg:
            self.rules.hatchCost
        case .hatchling, .junior:
            self.rules.nextActionCost(after: stage)
        case .adult:
            self.rules.journeyCompletionCost
        }
        return baseCost.map {
            self.discountedCost($0, basisPoints: costDiscountBasisPoints)
        }
    }

    public func canPerformAction(
        for state: CompanionGameState,
        costDiscountBasisPoints: Int = 0) -> Bool
    {
        self.actionCost(
            for: state.stage,
            costDiscountBasisPoints: costDiscountBasisPoints).map {
            state.availableGrowthEnergy >= $0
        } ?? false
    }

    public func discountedCost(_ baseCost: Int, basisPoints: Int) -> Int {
        guard baseCost > 0 else { return 0 }
        let multiplier = max(10_000 - min(max(basisPoints, 0), 9_999), 1)
        let product = baseCost.multipliedReportingOverflow(by: multiplier)
        guard !product.overflow else { return baseCost }
        let quotient = product.partialValue / 10_000
        let roundedUp = quotient + (product.partialValue % 10_000 == 0 ? 0 : 1)
        return max(roundedUp, 1)
    }

    public func pat(
        at now: Date = .now,
        celebrationDuration: TimeInterval = 4,
        in state: inout CompanionGameState)
    {
        if !state.memories.contains(where: {
            $0.generationID == state.generationID && $0.kind == .firstPat
        }) {
            self.recordMemory(.firstPat, at: now, in: &state)
        }
        state.lastPattedAt = now
        state.celebrationUntil = now.addingTimeInterval(max(celebrationDuration, 0))
        state.updatedAt = now
    }

    public func recordActivity(
        isActive: Bool,
        at now: Date = .now,
        in state: inout CompanionGameState)
    {
        guard isActive else { return }
        state.lastActiveAt = now
        state.updatedAt = now
    }

    public func rollSpecies(
        from candidates: [CompanionSpeciesID] = CompanionSpeciesID.allCases,
        unitValue requestedValue: Double) -> CompanionSpeciesID
    {
        let available = candidates.isEmpty
            ? CompanionSpeciesID.allCases
            : candidates
        let value = min(max(requestedValue, 0), 0.999_999_999_999)
        let index = min(Int(floor(value * Double(available.count))), available.count - 1)
        return available[index]
    }

    public func rollVariant(
        unitValue requestedValue: Double,
        pity: CompanionVariantPityState = CompanionVariantPityState())
        -> CompanionVariantID
    {
        if pity.standardHatches >= self.rules.prismaticPityHatches - 1 {
            return .prismatic
        }
        let value = min(max(requestedValue, 0), 0.999_999_999_999)
        return value >= 1 - self.rules.prismaticChance ? .prismatic : .standard
    }

    public func rollPersonality(
        unitValue requestedValue: Double) -> CompanionPersonalityID
    {
        let personalities = CompanionPersonalityRegistry.allIDs
        let value = min(max(requestedValue, 0), 0.999_999_999_999)
        let index = min(
            Int(floor(value * Double(personalities.count))),
            personalities.count - 1)
        return personalities[index]
    }

    public func rename(
        _ requestedName: String?,
        at now: Date = .now,
        in state: inout CompanionGameState)
    {
        let trimmed = requestedName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        state.nickname = trimmed.map { String($0.prefix(24)) }
            .flatMap { $0.isEmpty ? nil : $0 }
        state.updatedAt = now
    }

    private func spend(
        _ amount: Int,
        in state: inout CompanionGameState) throws
    {
        guard state.availableGrowthEnergy >= amount else {
            throw CompanionGameError.insufficientEnergy(
                required: amount,
                available: state.availableGrowthEnergy)
        }
        let reserveSpent = min(state.migrationEnergyReserve, amount)
        state.migrationEnergyReserve -= reserveSpent
        state.growthEnergy -= amount - reserveSpent
        state.growthSpentToday = Self.saturatedAdd(
            state.growthSpentToday,
            amount)
    }

    private func recordHatch(
        rarity: CompanionRarity,
        at date: Date,
        in state: inout CompanionGameState) -> [String]
    {
        guard let speciesID = state.speciesID else { return [] }
        guard self.unlock(
            stage: .hatchling,
            rarity: rarity,
            kind: .encountered,
            at: date,
            in: &state)
        else { return [] }
        return [self.formID(
            speciesID: speciesID,
            stage: .hatchling,
            rarity: rarity,
            variantID: state.resolvedVariantID)]
    }

    private func recordEvolution(
        stage: CompanionGameStage,
        rarity: CompanionRarity,
        at date: Date,
        in state: inout CompanionGameState) -> [String]
    {
        guard let speciesID = state.speciesID else { return [] }
        guard self.unlock(
            stage: stage,
            rarity: rarity,
            kind: .encountered,
            at: date,
            in: &state)
        else { return [] }
        return [self.formID(
            speciesID: speciesID,
            stage: stage,
            rarity: rarity,
            variantID: state.resolvedVariantID)]
    }

    @discardableResult
    private func unlock(
        stage: CompanionGameStage,
        rarity: CompanionRarity,
        kind: CompanionFormUnlockKind,
        at date: Date,
        in state: inout CompanionGameState) -> Bool
    {
        guard let speciesID = state.speciesID else { return false }
        let variantID = state.resolvedVariantID
        let currentFormID = self.formID(
            speciesID: speciesID,
            stage: stage,
            rarity: rarity,
            variantID: variantID)
        if let index = state.collection.forms.firstIndex(where: {
            $0.formID == currentFormID
        }) {
            if kind == .encountered {
                state.collection.forms[index].unlockKind = .encountered
                state.collection.forms[index].lastEncounteredAt = date
                state.collection.forms[index].encounterCount += 1
            }
            return false
        }
        state.collection.forms.append(CompanionFormRecord(
            formID: currentFormID,
            speciesID: speciesID,
            stage: stage,
            rarity: rarity,
            variantID: variantID,
            unlockKind: kind,
            firstUnlockedAt: date,
            lastEncounteredAt: kind == .encountered ? date : nil,
            encounterCount: kind == .encountered ? 1 : 0))
        return true
    }

    private func formID(
        speciesID: CompanionSpeciesID,
        stage: CompanionGameStage,
        rarity: CompanionRarity,
        variantID: CompanionVariantID?) -> String
    {
        variantID.map {
            CompanionGameState.variantFormID(
                speciesID: speciesID,
                stage: stage,
                variantID: $0)
        } ?? CompanionGameState.formID(
            speciesID: speciesID,
            stage: stage,
            rarity: rarity)
    }

    private func recordCompletion(
        _ completion: CompletedCompanionGeneration,
        in state: inout CompanionGameState)
    {
        state.collection.totalCompletedGenerations += 1
        state.collection.completedByRarity[completion.finalRarity.rawValue, default: 0] += 1
        state.collection.highestRarity = CompanionRarity.max(
            state.collection.highestRarity,
            completion.finalRarity)
        state.collection.highestBondEnergy = max(
            state.collection.highestBondEnergy,
            completion.bondEnergy)
        state.collection.recentCompletedGenerations.append(completion)

        state.pity.adultsWithoutRareOrHigher = completion.finalRarity.rank >= 1
            ? 0
            : state.pity.adultsWithoutRareOrHigher + 1
        state.pity.adultsWithoutEpicOrHigher = completion.finalRarity.rank >= 2
            ? 0
            : state.pity.adultsWithoutEpicOrHigher + 1
        state.pity.adultsWithoutLegendary = completion.finalRarity == .legendary
            ? 0
            : state.pity.adultsWithoutLegendary + 1
    }

    private func startNewEgg(
        at now: Date,
        in state: inout CompanionGameState)
    {
        state.generationID = UUID()
        state.generationNumber += 1
        state.speciesID = nil
        state.stage = .egg
        state.rarity = nil
        state.variantID = nil
        state.nickname = nil
        state.personalityID = nil
        state.bondEnergy = 0
        state.lastPattedAt = nil
        state.celebrationUntil = nil
        state.showcasedGenerationID = nil
        state.generationCreatedAt = now
        state.updatedAt = now
    }

    private func recordMemory(
        _ kind: CompanionMemoryKind,
        bondLevel: Int? = nil,
        at date: Date,
        in state: inout CompanionGameState)
    {
        state.memories.append(CompanionMemoryRecord(
            generationID: state.generationID,
            kind: kind,
            stage: state.stage,
            bondLevel: bondLevel,
            occurredAt: date))
        state.memories = Array(state.memories.suffix(400))
    }

    private func dayDistance(from startKey: String, to endKey: String) -> Int {
        guard let start = self.date(from: startKey),
              let end = self.date(from: endKey)
        else { return 1 }
        return self.calendar.dateComponents([.day], from: start, to: end).day ?? 1
    }

    private func date(from key: String) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }
        var components = DateComponents()
        components.calendar = self.calendar
        components.timeZone = self.calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return self.calendar.date(from: components)
    }

    private static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }
}
