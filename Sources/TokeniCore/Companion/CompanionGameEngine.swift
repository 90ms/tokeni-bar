import Foundation

public struct CompanionGameEngine: Sendable {
    public let rules: CompanionGameRules

    public init(rules: CompanionGameRules = .standard) {
        self.rules = rules
    }

    public func apply(
        award: GrowthEnergyAward,
        randomValues: [Double],
        to state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        guard !state.appliedGrowthAwardIDs.contains(award.id) else { return [] }
        let rollCount = self.requiredRollCount(
            adding: award.energy,
            to: state)
        guard randomValues.count >= rollCount else {
            throw CompanionGameError.insufficientRandomValues
        }

        state.appliedGrowthAwardIDs.append(award.id)
        state.appliedGrowthAwardIDs = Array(state.appliedGrowthAwardIDs.suffix(256))
        state.updatedAt = award.createdAt
        guard award.energy > 0 else { return [] }

        if state.stage == .adult {
            state.bondEnergy = Self.saturatedAdd(state.bondEnergy, award.energy)
            return [.bondIncreased(award.energy)]
        }

        let combinedEnergy = Self.saturatedAdd(state.growthEnergy, award.energy)
        let growthTarget = min(combinedEnergy, self.rules.adultEnergy)
        let overflow = max(combinedEnergy - self.rules.adultEnergy, 0)
        state.growthEnergy = growthTarget
        var events: [CompanionGameEvent] = [.energyApplied(award.energy - overflow)]
        var rollIndex = 0

        while let nextStage = self.rules.nextStage(after: state.stage),
              state.growthEnergy >= self.rules.threshold(for: nextStage)
        {
            let fromStage = state.stage
            let fromRarity = state.rarity
            var nextRarity = self.rollRarity(
                from: state.rarity,
                unitValue: randomValues[rollIndex])
            rollIndex += 1
            if nextStage == .adult {
                nextRarity = CompanionRarity.max(
                    nextRarity,
                    state.pity.nextAdultMinimumRarity)
            }
            state.stage = nextStage
            state.rarity = nextRarity
            let unlocked = self.recordEvolution(
                stage: nextStage,
                previousRarity: fromRarity,
                rarity: nextRarity,
                at: award.createdAt,
                in: &state)
            events.append(.evolved(
                fromStage: fromStage,
                toStage: nextStage,
                fromRarity: fromRarity,
                toRarity: nextRarity,
                unlockedFormIDs: unlocked))
        }

        if overflow > 0 {
            state.bondEnergy = Self.saturatedAdd(state.bondEnergy, overflow)
            events.append(.bondIncreased(overflow))
        }
        return events
    }

    public func completeGeneration(
        at now: Date = .now,
        in state: inout CompanionGameState) throws -> [CompanionGameEvent]
    {
        guard state.stage == .adult else { throw CompanionGameError.adultRequired }
        let completion = CompletedCompanionGeneration(
            generationID: state.generationID,
            generationNumber: state.generationNumber,
            finalRarity: state.rarity,
            bondEnergy: state.bondEnergy,
            completedAt: now)
        self.recordCompletion(completion, in: &state)
        self.startNewEgg(at: now, in: &state)
        return [
            .generationCompleted(completion),
            .newEgg(generationNumber: state.generationNumber),
        ]
    }

    public func abandonForNewEgg(
        at now: Date = .now,
        in state: inout CompanionGameState) -> CompanionGameEvent
    {
        self.startNewEgg(at: now, in: &state)
        return .newEgg(generationNumber: state.generationNumber)
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

    private func requiredRollCount(
        adding energy: Int,
        to state: CompanionGameState) -> Int
    {
        guard state.stage != .adult else { return 0 }
        let target = min(
            Self.saturatedAdd(state.growthEnergy, max(energy, 0)),
            self.rules.adultEnergy)
        var stage = state.stage
        var count = 0
        while let next = self.rules.nextStage(after: stage),
              target >= self.rules.threshold(for: next)
        {
            count += 1
            stage = next
        }
        return count
    }

    private func recordEvolution(
        stage: CompanionGameStage,
        previousRarity: CompanionRarity,
        rarity: CompanionRarity,
        at date: Date,
        in state: inout CompanionGameState) -> [String]
    {
        var unlocked: [String] = []
        if rarity.rank > previousRarity.rank {
            for lineageStage in CompanionGameStage.allCases
                where lineageStage != .egg
                    && self.rules.threshold(for: lineageStage)
                        <= self.rules.threshold(for: stage)
            {
                if self.unlock(
                    stage: lineageStage,
                    rarity: rarity,
                    kind: lineageStage == stage ? .encountered : .lineage,
                    at: date,
                    in: &state)
                {
                    unlocked.append(CompanionGameState.formID(
                        speciesID: state.speciesID,
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
                speciesID: state.speciesID,
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
        let formID = CompanionGameState.formID(
            speciesID: state.speciesID,
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
        state.stage = .egg
        state.rarity = .normal
        state.growthEnergy = 0
        state.bondEnergy = 0
        state.lastPattedAt = nil
        state.celebrationUntil = nil
        state.generationCreatedAt = now
        state.updatedAt = now
        _ = self.unlock(
            stage: .egg,
            rarity: .normal,
            kind: .encountered,
            at: now,
            in: &state)
    }

    private static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }
}
