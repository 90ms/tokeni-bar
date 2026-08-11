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
        bondEnergy: Int? = nil,
        to state: inout CompanionGameState) -> [CompanionGameEvent]
    {
        guard !state.appliedGrowthAwardIDs.contains(award.id) else { return [] }
        self.rollOverEnergyIfNeeded(at: award.createdAt, in: &state)
        state.appliedGrowthAwardIDs.append(award.id)
        state.appliedGrowthAwardIDs = Array(state.appliedGrowthAwardIDs.suffix(256))
        state.updatedAt = award.createdAt
        guard award.energy > 0 else { return [] }

        let targetID = state.resolvedGrowthTargetGenerationID
        let previousLevel = state.growthTargetLevel
        let credited: Int
        if state.stage == .egg {
            let availableRoom = max(
                self.rules.maximumEnergyBalance - state.growthEnergy,
                0)
            credited = min(award.energy, availableRoom)
            state.growthEnergy = Self.saturatedAdd(
                state.growthEnergy,
                credited)
        } else if targetID == state.generationID {
            let availableRoom = max(
                CompanionLevelCurve.standard.maximumXP - state.growthXP,
                0)
            credited = min(award.energy, availableRoom)
            state.growthXP = Self.saturatedAdd(state.growthXP, credited)
            state.highestPetLevel = max(state.highestPetLevel, state.level)
        } else if let targetID,
                  let index = state.collection.recentCompletedGenerations
                    .firstIndex(where: { $0.generationID == targetID })
        {
            let availableRoom = max(
                CompanionLevelCurve.standard.maximumXP
                    - state.collection.recentCompletedGenerations[index].growthXP,
                0)
            credited = min(award.energy, availableRoom)
            state.collection.recentCompletedGenerations[index].growthXP =
                Self.saturatedAdd(
                    state.collection.recentCompletedGenerations[index].growthXP,
                    credited)
            state.highestPetLevel = max(
                state.highestPetLevel,
                state.growthTargetLevel)
        } else {
            credited = 0
        }
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
        if state.growthTargetLevel > previousLevel, let targetID {
            events.append(.levelIncreased(
                generationID: targetID,
                from: previousLevel,
                to: state.growthTargetLevel))
        }
        return events
    }

    public func selectGrowthTarget(
        _ generationID: UUID,
        at now: Date = .now,
        in state: inout CompanionGameState) throws
    {
        let isActive = state.stage != .egg && generationID == state.generationID
        let archived = state.collection.archivedGenerations.first {
            $0.generationID == generationID
        }
        guard isActive || archived != nil else {
            throw CompanionGameError.archivedGenerationNotFound
        }
        let xp = isActive ? state.growthXP : archived?.growthXP ?? 0
        guard CompanionLevelCurve.standard.level(forXP: xp)
                < CompanionLevelCurve.standard.maximumLevel
        else { throw CompanionGameError.maximumLevelReached }
        state.growthTargetGenerationID = generationID
        state.updatedAt = now
    }

    @available(*, deprecated, message: "Use openEgg(_:at:in:) for free egg hatching.")
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
        guard let egg = state.eggs.first,
              let definition = CompanionEggRegistry.definition(
                for: egg.definitionID)
        else { throw CompanionGameError.eggNotFound }
        let cost = self.discountedCost(
            self.rules.hatchCost,
            basisPoints: costDiscountBasisPoints)
        try self.spend(cost, in: &state)
        state.eggs.removeFirst()
        let events = self.revealHatch(
            speciesUnitValue: speciesUnitValue,
            variantUnitValue: variantUnitValue,
            personalityUnitValue: personalityUnitValue,
            eggDefinition: definition,
            at: now,
            in: &state)
        state.highestPetLevel = max(state.highestPetLevel, state.level)
        return [.energySpent(cost)]
            + events
            + self.reconcileEggMilestones(at: now, in: &state)
    }

    private func revealHatch(
        speciesUnitValue: Double,
        variantUnitValue: Double,
        personalityUnitValue: Double,
        eggDefinition: CompanionEggDefinition? = nil,
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
        let eggPrefersMissing = eggDefinition?.prefersUndiscoveredSpecies == true
            && !missingSpecies.isEmpty
        let speciesID = self.rollSpecies(
            from: pityApplies || eggPrefersMissing
                ? missingSpecies
                : CompanionSpeciesID.allCases,
            unitValue: speciesUnitValue)
        let isNewSpecies = !discoveredSpecies.contains(speciesID)
        let variantID: CompanionVariantID = eggDefinition?.guaranteesPrismatic == true
            ? .prismatic
            : self.rollVariant(
                unitValue: variantUnitValue,
                pity: state.variantPity,
                prismaticChanceBonus:
                    eggDefinition?.prismaticChanceBonus ?? 0,
                mutationChanceBonus:
                    eggDefinition?.mutationChanceBonus ?? 0)
        let rarity = CompanionVariantRegistry.definition(
            for: variantID).assetRarity
        state.speciesID = speciesID
        state.stage = .hatchling
        state.rarity = rarity
        state.variantID = variantID
        state.activeMutationID = nil
        state.nickname = nil
        state.personalityID = self.rollPersonality(
            unitValue: personalityUnitValue)
        state.activeAcquisitionEggID = eggDefinition?.id
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
              let evolution = CompanionEvolutionRegistry.next(after: state.stage)
        else { throw CompanionGameError.evolutionUnavailable }
        guard let rarity = state.rarity,
              state.resolvedVariantID != nil
        else {
            throw CompanionGameError.rarityMissing
        }

        guard state.level >= evolution.requiredLevel else {
            throw CompanionGameError.evolutionLevelRequired(
                required: evolution.requiredLevel,
                current: state.level)
        }
        let nextStage = evolution.stage
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
            .evolved(
                fromStage: fromStage,
                toStage: nextStage,
                fromRarity: rarity,
                toRarity: rarity,
                unlockedFormIDs: unlocked),
        ]
    }

    @available(*, deprecated, message: "Owned pets no longer have a completion reset.")
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
            mutationID: state.activeMutationID,
            nickname: state.nickname,
            personalityID: state.personalityID,
            bondEnergy: state.bondEnergy,
            growthXP: state.growthXP,
            stage: state.stage,
            acquisitionEggID: state.activeAcquisitionEggID,
            createdAt: state.generationCreatedAt,
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

    @available(*, deprecated, message: "Acquire and open an egg without replacing the active pet.")
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

    @discardableResult
    public func acquireEgg(
        definitionID: CompanionEggDefinitionID,
        seed: UInt64,
        source: CompanionEggSource,
        transactionID: UUID = UUID(),
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        guard !state.processedEggTransactionIDs.contains(transactionID)
        else { return [] }
        guard CompanionEggRegistry.definition(for: definitionID) != nil
        else { throw CompanionEggError.definitionNotFound }
        state.eggs.append(CompanionEggInstance(
            definitionID: definitionID,
            seed: seed,
            acquiredAt: now,
            source: source))
        state.processedEggTransactionIDs.append(transactionID)
        state.processedEggTransactionIDs = Array(
            state.processedEggTransactionIDs.suffix(512))
        state.updatedAt = now
        return [.eggAcquired(definitionID)]
    }

    @discardableResult
    public func sellEgg(
        _ eggID: UUID,
        transactionID: UUID = UUID(),
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> Int
    {
        if state.processedEggTransactionIDs.contains(transactionID) {
            return 0
        }
        guard let index = state.eggs.firstIndex(where: { $0.id == eggID })
        else { throw CompanionEggError.eggNotFound }
        guard let definition = CompanionEggRegistry.definition(
            for: state.eggs[index].definitionID)
        else { throw CompanionEggError.definitionNotFound }
        guard definition.isSellable else {
            throw CompanionEggError.eggNotSellable
        }
        state.eggs.remove(at: index)
        state.processedEggTransactionIDs.append(transactionID)
        state.processedEggTransactionIDs = Array(
            state.processedEggTransactionIDs.suffix(512))
        state.updatedAt = now
        return definition.resaleValue
    }

    @discardableResult
    public func openEgg(
        _ eggID: UUID,
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        guard let index = state.eggs.firstIndex(where: { $0.id == eggID })
        else { throw CompanionEggError.eggNotFound }
        let egg = state.eggs[index]
        guard let definition = CompanionEggRegistry.definition(
            for: egg.definitionID)
        else { throw CompanionEggError.definitionNotFound }
        let speciesValue = CompanionEggRegistry.unitValue(
            seed: egg.seed,
            salt: 1)
        let variantValue = CompanionEggRegistry.unitValue(
            seed: egg.seed,
            salt: 2)
        let personalityValue = CompanionEggRegistry.unitValue(
            seed: egg.seed,
            salt: 3)
        state.eggs.remove(at: index)

        let events: [CompanionGameEvent]
        if state.stage == .egg {
            let bankedXP = state.growthEnergy
            state.growthEnergy = 0
            events = self.revealHatch(
                speciesUnitValue: speciesValue,
                variantUnitValue: variantValue,
                personalityUnitValue: personalityValue,
                eggDefinition: definition,
                at: now,
                in: &state)
            state.growthXP = CompanionLevelCurve.standard.clampedXP(
                Self.saturatedAdd(state.growthXP, bankedXP))
            state.highestPetLevel = max(state.highestPetLevel, state.level)
        } else {
            events = self.revealInactiveCompanion(
                egg: egg,
                definition: definition,
                speciesUnitValue: speciesValue,
                variantUnitValue: variantValue,
                personalityUnitValue: personalityValue,
                at: now,
                in: &state)
        }
        let milestoneEvents = self.reconcileEggMilestones(at: now, in: &state)
        state.updatedAt = now
        return [.eggOpened(eggID)] + events + milestoneEvents
    }

    public func activateArchivedGeneration(
        _ generationID: UUID,
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        guard state.stage != .egg,
              let selectedIndex = state.collection.recentCompletedGenerations
                .firstIndex(where: { $0.generationID == generationID }),
              let activeSpeciesID = state.speciesID,
              let activeRarity = state.rarity
        else { throw CompanionGameError.archivedGenerationNotFound }

        let selected = state.collection.recentCompletedGenerations.remove(
            at: selectedIndex)
        let active = CompletedCompanionGeneration(
            generationID: state.generationID,
            generationNumber: state.generationNumber,
            speciesID: activeSpeciesID,
            finalRarity: activeRarity,
            variantID: state.resolvedVariantID,
            mutationID: state.activeMutationID,
            nickname: state.nickname,
            personalityID: state.personalityID,
            bondEnergy: state.bondEnergy,
            growthXP: state.growthXP,
            stage: state.stage,
            acquisitionEggID: state.activeAcquisitionEggID,
            createdAt: state.generationCreatedAt,
            completedAt: now)
        state.collection.recentCompletedGenerations.append(active)

        state.generationID = selected.generationID
        state.generationNumber = selected.generationNumber
        state.speciesID = selected.speciesID
        state.stage = selected.stage
        state.rarity = selected.finalRarity
        state.variantID = selected.variantID
        state.activeMutationID = selected.mutationID
        state.nickname = selected.nickname
        state.personalityID = selected.personalityID ?? .calm
        state.activeAcquisitionEggID = selected.acquisitionEggID
        state.bondEnergy = selected.bondEnergy
        state.growthXP = selected.growthXP
        state.highestPetLevel = max(state.highestPetLevel, state.level)
        state.generationCreatedAt = selected.createdAt
        state.lastPattedAt = nil
        state.showcasedGenerationID = nil
        state.updatedAt = now
        return [.activeCompanionChanged(generationID)]
    }

    @discardableResult
    public func synthesizeMutation(
        sourceGenerationIDs: [UUID],
        mutationUnitValue: Double,
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        guard sourceGenerationIDs.count
                == CompanionMutationRegistry.synthesisSourceCount,
              Set(sourceGenerationIDs).count == sourceGenerationIDs.count
        else { throw CompanionMutationError.requiresThreeSources }

        guard !sourceGenerationIDs.contains(state.generationID) else {
            throw CompanionMutationError.sourceIsActive
        }
        let sources = try sourceGenerationIDs.map { generationID in
            guard let generation = state.collection.archivedGenerations.first(
                where: { $0.generationID == generationID })
            else { throw CompanionMutationError.sourceNotFound(generationID) }
            return generation
        }
        guard let speciesID = sources.first?.speciesID,
              sources.allSatisfy({ $0.speciesID == speciesID })
        else { throw CompanionMutationError.sourceSpeciesMismatch }
        guard sources.allSatisfy(CompanionMutationRegistry.isEligibleSource)
        else { throw CompanionMutationError.sourceNotEligible }

        let nextSynthesisCount = Self.saturatedAdd(
            state.collection.mutationSynthesisCount,
            1)
        let discovered = Set(
            state.collection.mutations
                .filter { $0.speciesID == speciesID }
                .map(\.mutationID))
        let missing = CompanionMutationRegistry.allIDs.filter {
            !discovered.contains($0)
        }
        let guaranteesNewMutation = !missing.isEmpty
            && nextSynthesisCount % CompanionMutationRegistry.pitySynthesisCount == 0
        let mutationID = CompanionMutationRegistry.roll(
            from: guaranteesNewMutation
                ? missing
                : CompanionMutationRegistry.allIDs,
            unitValue: mutationUnitValue)

        let highestGenerationNumber = state.collection.archivedGenerations
            .map(\.generationNumber)
            .max() ?? 0
        let mutationGenerationNumber = Self.saturatedAdd(
            max(state.generationNumber, highestGenerationNumber),
            1)
        let createdGeneration = CompletedCompanionGeneration(
            generationID: UUID(),
            generationNumber: mutationGenerationNumber,
            speciesID: speciesID,
            finalRarity: .normal,
            variantID: .standard,
            mutationID: mutationID,
            personalityID: .calm,
            bondEnergy: 0,
            growthXP: 0,
            stage: .hatchling,
            createdAt: now,
            completedAt: now)

        let sourceIDSet = Set(sourceGenerationIDs)
        state.collection.recentCompletedGenerations.removeAll {
            sourceIDSet.contains($0.generationID)
        }
        if let showcasedGenerationID = state.showcasedGenerationID,
           sourceIDSet.contains(showcasedGenerationID)
        {
            state.showcasedGenerationID = nil
        }
        state.collection.mutationSynthesisCount = nextSynthesisCount
        if let index = state.collection.mutations.firstIndex(where: {
            $0.speciesID == speciesID && $0.mutationID == mutationID
        }) {
            state.collection.mutations[index].lastSynthesizedAt = now
            state.collection.mutations[index].synthesisCount = Self.saturatedAdd(
                state.collection.mutations[index].synthesisCount,
                1)
        } else {
            state.collection.mutations.append(CompanionMutationRecord(
                speciesID: speciesID,
                mutationID: mutationID,
                firstDiscoveredAt: now,
                lastSynthesizedAt: now))
        }
        state.collection.recentCompletedGenerations.append(createdGeneration)
        state.updatedAt = now
        return [.mutationSynthesized(
            speciesID: speciesID,
            mutationID: mutationID,
            consumedGenerationIDs: sourceGenerationIDs,
            createdGeneration: createdGeneration,
            isNewMutation: !discovered.contains(mutationID))]
    }

    public func equipMutation(
        _ mutationID: CompanionMutationID?,
        at now: Date = .now,
        in state: inout CompanionGameState) throws
    {
        guard let mutationID else {
            state.activeMutationID = nil
            state.updatedAt = now
            return
        }
        guard let speciesID = state.speciesID,
              state.stage != .egg,
              state.collection.mutationRecord(
                  for: speciesID,
                  mutationID: mutationID) != nil
        else { throw CompanionMutationError.mutationNotDiscovered }
        state.activeMutationID = mutationID
        state.updatedAt = now
    }

    @discardableResult
    public func sellArchivedGeneration(
        _ generationID: UUID,
        transactionID: UUID = UUID(),
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> Int
    {
        if state.processedEggTransactionIDs.contains(transactionID) {
            return 0
        }
        guard let index = state.collection.recentCompletedGenerations
            .firstIndex(where: { $0.generationID == generationID })
        else { throw CompanionGameError.archivedGenerationNotFound }
        guard state.stage != .egg
                || state.collection.recentCompletedGenerations.count > 1
        else { throw CompanionEggError.lastPetCannotBeSold }
        let companion = state.collection.recentCompletedGenerations.remove(at: index)
        if state.growthTargetGenerationID == generationID {
            state.growthTargetGenerationID = state.level
                    < CompanionLevelCurve.standard.maximumLevel
                ? state.generationID
                : state.collection.recentCompletedGenerations.first(where: {
                    CompanionLevelCurve.standard.level(forXP: $0.growthXP)
                        < CompanionLevelCurve.standard.maximumLevel
                })?.generationID
        }
        if state.showcasedGenerationID == generationID {
            state.showcasedGenerationID = nil
        }
        state.processedEggTransactionIDs.append(transactionID)
        state.processedEggTransactionIDs = Array(
            state.processedEggTransactionIDs.suffix(512))
        state.updatedAt = now
        return companion.variantID == .prismatic ? 60 : 30
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

    @available(*, deprecated, message: "Level evolution and egg opening do not spend Growth XP.")
    public func actionCost(
        for stage: CompanionGameStage,
        costDiscountBasisPoints: Int = 0) -> Int?
    {
        nil
    }

    public func canPerformAction(
        for state: CompanionGameState,
        costDiscountBasisPoints: Int = 0) -> Bool
    {
        switch state.stage {
        case .egg:
            !state.eggs.isEmpty
        case .hatchling, .junior:
            state.canEvolve
        case .adult:
            false
        }
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
        pity: CompanionVariantPityState = CompanionVariantPityState(),
        prismaticChanceBonus: Double = 0,
        mutationChanceBonus: Double = 0)
        -> CompanionVariantID
    {
        let value = min(max(requestedValue, 0), 0.999_999_999_999)
        let mutationChance = min(
            self.rules.mutationChance + max(mutationChanceBonus, 0),
            1)
        let prismaticChance = min(
            self.rules.prismaticChance + max(prismaticChanceBonus, 0),
            max(1 - mutationChance, 0))
        if value >= 1 - mutationChance {
            return .mutated
        }
        if pity.standardHatches >= self.rules.prismaticPityHatches - 1 {
            return .prismatic
        }
        return value >= 1
            - mutationChance
            - prismaticChance
            ? .prismatic
            : .standard
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
        state.growthEnergy -= amount
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

    private func revealInactiveCompanion(
        egg: CompanionEggInstance,
        definition: CompanionEggDefinition,
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
        let prefersMissing = definition.prefersUndiscoveredSpecies
            && !missingSpecies.isEmpty
        let speciesID = self.rollSpecies(
            from: pityApplies || prefersMissing
                ? missingSpecies
                : CompanionSpeciesID.allCases,
            unitValue: speciesUnitValue)
        let isNewSpecies = !discoveredSpecies.contains(speciesID)
        let variantID: CompanionVariantID = definition.guaranteesPrismatic
            ? .prismatic
            : self.rollVariant(
                unitValue: variantUnitValue,
                pity: state.variantPity,
                prismaticChanceBonus: definition.prismaticChanceBonus,
                mutationChanceBonus: definition.mutationChanceBonus)
        let rarity = CompanionVariantRegistry.definition(
            for: variantID).assetRarity
        let personality = self.rollPersonality(unitValue: personalityUnitValue)
        let generationID = UUID()
        let generationNumber = Self.saturatedAdd(
            max(
                state.generationNumber,
                state.collection.recentCompletedGenerations
                    .map(\.generationNumber).max() ?? 0),
            1)

        state.variantPity.standardHatches = variantID == .prismatic
            ? 0
            : Self.saturatedAdd(state.variantPity.standardHatches, 1)
        state.consecutiveDuplicateHatches = isNewSpecies
            ? 0
            : Self.saturatedAdd(state.consecutiveDuplicateHatches, 1)
        let unlocked = self.recordEncounter(
            speciesID: speciesID,
            stage: .hatchling,
            rarity: rarity,
            variantID: variantID,
            at: now,
            in: &state)
        if let duplicateID = self.duplicateGenerationID(
            speciesID: speciesID,
            variantID: variantID,
            in: state)
        {
            let creditedXP = self.creditDuplicateXP(
                to: duplicateID,
                in: &state)
            return [
                .hatched(
                    speciesID: speciesID,
                    rarity: rarity,
                    isNewSpecies: isNewSpecies,
                    unlockedFormIDs: unlocked),
                .duplicateConverted(
                    generationID: duplicateID,
                    creditedXP: creditedXP),
            ]
        }
        state.collection.recentCompletedGenerations.append(
            CompletedCompanionGeneration(
                generationID: generationID,
                generationNumber: generationNumber,
                speciesID: speciesID,
                finalRarity: rarity,
                variantID: variantID,
                personalityID: personality,
                bondEnergy: 0,
                growthXP: 0,
                stage: .hatchling,
                acquisitionEggID: egg.definitionID,
                createdAt: now,
                completedAt: now))
        state.memories.append(CompanionMemoryRecord(
            generationID: generationID,
            kind: .hatched,
            stage: .hatchling,
            occurredAt: now))
        state.memories = CompanionMemoryPolicy.pruned(state.memories)
        return [
            .hatched(
                speciesID: speciesID,
                rarity: rarity,
                isNewSpecies: isNewSpecies,
                unlockedFormIDs: unlocked),
        ]
    }

    private func duplicateGenerationID(
        speciesID: CompanionSpeciesID,
        variantID: CompanionVariantID,
        in state: CompanionGameState) -> UUID?
    {
        if state.speciesID == speciesID,
           state.resolvedVariantID == variantID
        {
            return state.generationID
        }
        return state.collection.archivedGenerations.first { generation in
            generation.speciesID == speciesID
                && (generation.variantID
                    ?? CompanionVariantRegistry.migrated(
                        from: generation.finalRarity)) == variantID
        }?.generationID
    }

    private func creditDuplicateXP(
        to generationID: UUID,
        in state: inout CompanionGameState) -> Int
    {
        let curve = CompanionLevelCurve.standard
        if generationID == state.generationID {
            let level = state.level
            guard level < curve.maximumLevel else { return 0 }
            let requested = max(
                Int(ceil(Double(curve.xpToNextLevel(from: level)) * 0.25)),
                1)
            let credited = min(requested, curve.maximumXP - state.growthXP)
            state.growthXP += credited
            state.highestPetLevel = max(state.highestPetLevel, state.level)
            return credited
        }
        guard let index = state.collection.recentCompletedGenerations
            .firstIndex(where: { $0.generationID == generationID })
        else { return 0 }
        let xp = state.collection.recentCompletedGenerations[index].growthXP
        let level = curve.level(forXP: xp)
        guard level < curve.maximumLevel else { return 0 }
        let requested = max(
            Int(ceil(Double(curve.xpToNextLevel(from: level)) * 0.25)),
            1)
        let credited = min(requested, curve.maximumXP - xp)
        state.collection.recentCompletedGenerations[index].growthXP += credited
        state.highestPetLevel = max(
            state.highestPetLevel,
            curve.level(forXP: xp + credited))
        return credited
    }

    private func recordEncounter(
        speciesID: CompanionSpeciesID,
        stage: CompanionGameStage,
        rarity: CompanionRarity,
        variantID: CompanionVariantID,
        at date: Date,
        in state: inout CompanionGameState) -> [String]
    {
        let currentFormID = self.formID(
            speciesID: speciesID,
            stage: stage,
            rarity: rarity,
            variantID: variantID)
        if let index = state.collection.forms.firstIndex(where: {
            $0.formID == currentFormID
        }) {
            state.collection.forms[index].unlockKind = .encountered
            state.collection.forms[index].lastEncounteredAt = date
            state.collection.forms[index].encounterCount += 1
            return []
        }
        state.collection.forms.append(CompanionFormRecord(
            formID: currentFormID,
            speciesID: speciesID,
            stage: stage,
            rarity: rarity,
            variantID: variantID,
            unlockKind: .encountered,
            firstUnlockedAt: date,
            lastEncounteredAt: date,
            encounterCount: 1))
        return [currentFormID]
    }

    /// Grants any collection milestone eggs that were not claimed yet.
    ///
    /// This is public so migrated saves can be reconciled on load as well as
    /// immediately after opening an egg. Claimed IDs keep the operation
    /// idempotent across repeated launches.
    @discardableResult
    public func reconcileEggMilestones(
        at now: Date,
        in state: inout CompanionGameState) -> [CompanionGameEvent]
    {
        let candidates: [(String, CompanionEggDefinitionID, Bool)] = [
            ("species-5", .discovery,
             state.collection.discoveredSpeciesIDs.count >= 5),
            ("variants-5", .prismatic,
             state.collection.discoveredCollectibleVariantCount >= 5),
            ("variants-10", .prismatic,
             state.collection.discoveredCollectibleVariantCount >= 10),
        ]
        var events: [CompanionGameEvent] = []
        for (milestoneID, definitionID, reached) in candidates
            where reached && !state.claimedEggMilestoneIDs.contains(milestoneID)
        {
            state.claimedEggMilestoneIDs.append(milestoneID)
            state.eggs.append(CompanionEggInstance(
                definitionID: definitionID,
                seed: CompanionEggRegistry.deterministicSeed(
                    for: milestoneID),
                acquiredAt: now,
                source: .collectionMilestone))
            events.append(.eggAcquired(definitionID))
        }
        state.claimedEggMilestoneIDs.sort()
        return events
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
        state.activeMutationID = nil
        state.nickname = nil
        state.personalityID = nil
        state.activeAcquisitionEggID = nil
        state.growthXP = 0
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
        state.memories = CompanionMemoryPolicy.pruned(state.memories)
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
