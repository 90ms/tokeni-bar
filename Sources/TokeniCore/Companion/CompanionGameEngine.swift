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

        var events: [CompanionGameEvent] = []
        if credited > 0 {
            events.append(.energyApplied(credited))
        }
        if state.stage == .adult {
            state.bondEnergy = Self.saturatedAdd(state.bondEnergy, award.energy)
            events.append(.bondIncreased(award.energy))
        }
        return events
    }

    public func hatch(
        speciesUnitValue: Double,
        rarityUnitValue: Double,
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        self.rollOverEnergyIfNeeded(at: now, in: &state)
        guard state.stage == .egg else { throw CompanionGameError.eggRequired }
        try self.spend(self.rules.hatchCost, in: &state)
        return [.energySpent(self.rules.hatchCost)] + self.revealHatch(
            speciesUnitValue: speciesUnitValue,
            rarityUnitValue: rarityUnitValue,
            at: now,
            in: &state)
    }

    private func revealHatch(
        speciesUnitValue: Double,
        rarityUnitValue: Double,
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
        let rarity = self.rollRarity(
            from: .normal,
            unitValue: rarityUnitValue)
        state.speciesID = speciesID
        state.stage = .hatchling
        state.rarity = rarity
        state.consecutiveDuplicateHatches = isNewSpecies
            ? 0
            : Self.saturatedAdd(state.consecutiveDuplicateHatches, 1)
        state.updatedAt = now
        let unlocked = self.recordHatch(
            rarity: rarity,
            at: now,
            in: &state)
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
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        self.rollOverEnergyIfNeeded(at: now, in: &state)
        guard state.stage == .hatchling || state.stage == .junior,
              let nextStage = self.rules.nextStage(after: state.stage)
        else { throw CompanionGameError.evolutionUnavailable }
        guard let fromRarity = state.rarity else {
            throw CompanionGameError.rarityMissing
        }

        let cost = self.rules.actionCost(to: nextStage)
        try self.spend(cost, in: &state)
        var nextRarity = self.rollRarity(
            from: fromRarity,
            unitValue: unitValue)
        if nextStage == .adult {
            nextRarity = CompanionRarity.max(
                nextRarity,
                state.pity.nextAdultMinimumRarity)
        }

        let fromStage = state.stage
        state.stage = nextStage
        state.rarity = nextRarity
        state.updatedAt = now
        state.celebrationUntil = now.addingTimeInterval(6)
        let unlocked = self.recordEvolution(
            stage: nextStage,
            previousRarity: fromRarity,
            rarity: nextRarity,
            at: now,
            in: &state)
        return [
            .energySpent(cost),
            .evolved(
                fromStage: fromStage,
                toStage: nextStage,
                fromRarity: fromRarity,
                toRarity: nextRarity,
                unlockedFormIDs: unlocked),
        ]
    }

    public func completeGeneration(
        speciesUnitValue: Double,
        rarityUnitValue: Double,
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
        let completionCost = self.rules.journeyCompletionCost
        try self.spend(completionCost, in: &state)

        let completion = CompletedCompanionGeneration(
            generationID: state.generationID,
            generationNumber: state.generationNumber,
            speciesID: speciesID,
            finalRarity: rarity,
            bondEnergy: state.bondEnergy,
            completedAt: now)
        self.recordCompletion(completion, in: &state)
        self.startNewEgg(at: now, in: &state)
        let hatchEvents = self.revealHatch(
            speciesUnitValue: speciesUnitValue,
            rarityUnitValue: rarityUnitValue,
            at: now,
            in: &state)
        return [
            .energySpent(completionCost),
            .generationCompleted(completion),
            .newEgg(generationNumber: state.generationNumber),
        ] + hatchEvents
    }

    public func abandonForNewEgg(
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        self.rollOverEnergyIfNeeded(at: now, in: &state)
        guard state.stage != .egg else { throw CompanionGameError.eggRequired }
        try self.spend(self.rules.newEggCost, in: &state)
        self.startNewEgg(at: now, in: &state)
        return [
            .energySpent(self.rules.newEggCost),
            .newEgg(generationNumber: state.generationNumber),
        ]
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
        state.growthSpentToday = 0
        state.updatedAt = now
    }

    public func actionCost(for stage: CompanionGameStage) -> Int? {
        switch stage {
        case .egg:
            self.rules.hatchCost
        case .hatchling, .junior:
            self.rules.nextActionCost(after: stage)
        case .adult:
            self.rules.journeyCompletionCost
        }
    }

    public func canPerformAction(for state: CompanionGameState) -> Bool {
        self.actionCost(for: state.stage).map {
            state.growthEnergy >= $0
        } ?? false
    }

    public func pat(
        at now: Date = .now,
        celebrationDuration: TimeInterval = 4,
        in state: inout CompanionGameState)
    {
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

    public func rollRarity(
        from rarity: CompanionRarity,
        unitValue requestedValue: Double) -> CompanionRarity
    {
        let value = min(max(requestedValue, 0), 0.999_999_999_999)
        switch rarity {
        case .normal:
            if value < 0.75 { return .normal }
            if value < 0.96 { return .rare }
            if value < 0.998 { return .epic }
            return .legendary
        case .rare:
            if value < 0.86 { return .rare }
            if value < 0.99 { return .epic }
            return .legendary
        case .epic:
            return value < 0.97 ? .epic : .legendary
        case .legendary:
            return .legendary
        }
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

    private func spend(
        _ amount: Int,
        in state: inout CompanionGameState) throws
    {
        guard state.growthEnergy >= amount else {
            throw CompanionGameError.insufficientEnergy(
                required: amount,
                available: state.growthEnergy)
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
        return [CompanionGameState.formID(
            speciesID: speciesID,
            stage: .hatchling,
            rarity: rarity)]
    }

    private func recordEvolution(
        stage: CompanionGameStage,
        previousRarity: CompanionRarity,
        rarity: CompanionRarity,
        at date: Date,
        in state: inout CompanionGameState) -> [String]
    {
        guard let speciesID = state.speciesID else { return [] }
        var unlocked: [String] = []
        if rarity.rank > previousRarity.rank {
            for lineageStage in [CompanionGameStage.hatchling, .junior, .adult]
                where self.stageRank(lineageStage) <= self.stageRank(stage)
            {
                if self.unlock(
                    stage: lineageStage,
                    rarity: rarity,
                    kind: lineageStage == stage ? .encountered : .lineage,
                    at: date,
                    in: &state)
                {
                    unlocked.append(CompanionGameState.formID(
                        speciesID: speciesID,
                        stage: lineageStage,
                        rarity: rarity))
                }
            }
        } else if self.unlock(
            stage: stage,
            rarity: rarity,
            kind: .encountered,
            at: date,
            in: &state)
        {
            unlocked.append(CompanionGameState.formID(
                speciesID: speciesID,
                stage: stage,
                rarity: rarity))
        }
        return unlocked
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
        let formID = CompanionGameState.formID(
            speciesID: speciesID,
            stage: stage,
            rarity: rarity)
        if let index = state.collection.forms.firstIndex(where: {
            $0.formID == formID
        }) {
            if kind == .encountered {
                state.collection.forms[index].unlockKind = .encountered
                state.collection.forms[index].lastEncounteredAt = date
                state.collection.forms[index].encounterCount += 1
            }
            return false
        }
        state.collection.forms.append(CompanionFormRecord(
            formID: formID,
            speciesID: speciesID,
            stage: stage,
            rarity: rarity,
            unlockKind: kind,
            firstUnlockedAt: date,
            lastEncounteredAt: kind == .encountered ? date : nil,
            encounterCount: kind == .encountered ? 1 : 0))
        return true
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
        state.collection.recentCompletedGenerations = Array(
            state.collection.recentCompletedGenerations.suffix(20))

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
        state.bondEnergy = 0
        state.lastPattedAt = nil
        state.celebrationUntil = nil
        state.generationCreatedAt = now
        state.updatedAt = now
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

    private func stageRank(_ stage: CompanionGameStage) -> Int {
        switch stage {
        case .egg: 0
        case .hatchling: 1
        case .junior: 2
        case .adult: 3
        }
    }

    private static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }
}
