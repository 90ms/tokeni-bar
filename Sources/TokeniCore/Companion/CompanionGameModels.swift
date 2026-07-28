import Foundation

public enum CompanionGameStage: String, Codable, CaseIterable, Hashable, Sendable {
    case egg
    case hatchling
    case junior
    case adult
}

public enum CompanionRarity: String, Codable, CaseIterable, Hashable, Sendable {
    case normal
    case rare
    case epic
    case legendary

    public var rank: Int {
        switch self {
        case .normal: 0
        case .rare: 1
        case .epic: 2
        case .legendary: 3
        }
    }

    public static func max(_ lhs: Self, _ rhs: Self) -> Self {
        lhs.rank >= rhs.rank ? lhs : rhs
    }
}

public enum CompanionFormUnlockKind: String, Codable, Hashable, Sendable {
    case lineage
    case encountered
}

public struct CompanionFormRecord: Codable, Hashable, Sendable {
    public let formID: String
    public let speciesID: CompanionSpeciesID
    public let stage: CompanionGameStage
    public let rarity: CompanionRarity
    public var unlockKind: CompanionFormUnlockKind
    public let firstUnlockedAt: Date
    public var lastEncounteredAt: Date?
    public var encounterCount: Int

    public init(
        formID: String,
        speciesID: CompanionSpeciesID = .bytebot,
        stage: CompanionGameStage,
        rarity: CompanionRarity,
        unlockKind: CompanionFormUnlockKind,
        firstUnlockedAt: Date,
        lastEncounteredAt: Date?,
        encounterCount: Int)
    {
        self.formID = formID
        self.speciesID = speciesID
        self.stage = stage
        self.rarity = rarity
        self.unlockKind = unlockKind
        self.firstUnlockedAt = firstUnlockedAt
        self.lastEncounteredAt = lastEncounteredAt
        self.encounterCount = encounterCount
    }

    private enum CodingKeys: String, CodingKey {
        case formID
        case speciesID
        case stage
        case rarity
        case unlockKind
        case firstUnlockedAt
        case lastEncounteredAt
        case encounterCount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.formID = try container.decode(String.self, forKey: .formID)
        self.speciesID = try container.decodeIfPresent(
            CompanionSpeciesID.self,
            forKey: .speciesID) ?? .bytebot
        self.stage = try container.decode(CompanionGameStage.self, forKey: .stage)
        self.rarity = try container.decode(CompanionRarity.self, forKey: .rarity)
        self.unlockKind = try container.decode(
            CompanionFormUnlockKind.self,
            forKey: .unlockKind)
        self.firstUnlockedAt = try container.decode(Date.self, forKey: .firstUnlockedAt)
        self.lastEncounteredAt = try container.decodeIfPresent(
            Date.self,
            forKey: .lastEncounteredAt)
        self.encounterCount = try container.decode(Int.self, forKey: .encounterCount)
    }
}

public struct CompletedCompanionGeneration: Codable, Hashable, Sendable {
    public let generationID: UUID
    public let generationNumber: Int
    public let speciesID: CompanionSpeciesID
    public let finalRarity: CompanionRarity
    public let bondEnergy: Int
    public let completedAt: Date

    public init(
        generationID: UUID,
        generationNumber: Int,
        speciesID: CompanionSpeciesID = .bytebot,
        finalRarity: CompanionRarity,
        bondEnergy: Int,
        completedAt: Date)
    {
        self.generationID = generationID
        self.generationNumber = generationNumber
        self.speciesID = speciesID
        self.finalRarity = finalRarity
        self.bondEnergy = bondEnergy
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case generationID
        case generationNumber
        case speciesID
        case finalRarity
        case bondEnergy
        case completedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.generationID = try container.decode(UUID.self, forKey: .generationID)
        self.generationNumber = try container.decode(Int.self, forKey: .generationNumber)
        self.speciesID = try container.decodeIfPresent(
            CompanionSpeciesID.self,
            forKey: .speciesID) ?? .bytebot
        self.finalRarity = try container.decode(
            CompanionRarity.self,
            forKey: .finalRarity)
        self.bondEnergy = try container.decode(Int.self, forKey: .bondEnergy)
        self.completedAt = try container.decode(Date.self, forKey: .completedAt)
    }
}

public struct CompanionCollection: Codable, Hashable, Sendable {
    public var forms: [CompanionFormRecord]
    public var totalCompletedGenerations: Int
    public var completedByRarity: [String: Int]
    public var highestRarity: CompanionRarity
    public var highestBondEnergy: Int
    public var recentCompletedGenerations: [CompletedCompanionGeneration]

    public init(
        forms: [CompanionFormRecord] = [],
        totalCompletedGenerations: Int = 0,
        completedByRarity: [String: Int] = [:],
        highestRarity: CompanionRarity = .normal,
        highestBondEnergy: Int = 0,
        recentCompletedGenerations: [CompletedCompanionGeneration] = [])
    {
        self.forms = forms
        self.totalCompletedGenerations = max(totalCompletedGenerations, 0)
        self.completedByRarity = completedByRarity
        self.highestRarity = highestRarity
        self.highestBondEnergy = max(highestBondEnergy, 0)
        self.recentCompletedGenerations = Array(
            recentCompletedGenerations.suffix(20))
    }

    public var unlockedFormCount: Int { self.forms.count }

    public var discoveredSpeciesIDs: Set<CompanionSpeciesID> {
        Set(self.forms.filter { $0.unlockKind == .encountered }.map(\.speciesID))
    }

    public func encounterCount(for speciesID: CompanionSpeciesID) -> Int {
        self.forms
            .filter {
                $0.speciesID == speciesID
                    && $0.stage == .hatchling
                    && $0.unlockKind == .encountered
            }
            .reduce(0) { $0 + $1.encounterCount }
    }

    public func completedCount(for rarity: CompanionRarity) -> Int {
        self.completedByRarity[rarity.rawValue, default: 0]
    }
}

public struct CompanionPityState: Codable, Hashable, Sendable {
    public var adultsWithoutRareOrHigher: Int
    public var adultsWithoutEpicOrHigher: Int
    public var adultsWithoutLegendary: Int

    public init(
        adultsWithoutRareOrHigher: Int = 0,
        adultsWithoutEpicOrHigher: Int = 0,
        adultsWithoutLegendary: Int = 0)
    {
        self.adultsWithoutRareOrHigher = max(adultsWithoutRareOrHigher, 0)
        self.adultsWithoutEpicOrHigher = max(adultsWithoutEpicOrHigher, 0)
        self.adultsWithoutLegendary = max(adultsWithoutLegendary, 0)
    }

    public var nextAdultMinimumRarity: CompanionRarity {
        if self.adultsWithoutLegendary >= 15 {
            return .legendary
        }
        if self.adultsWithoutEpicOrHigher >= 6 {
            return .epic
        }
        if self.adultsWithoutRareOrHigher >= 2 {
            return .rare
        }
        return .normal
    }
}

public struct CompanionGameRules: Hashable, Sendable {
    public static let standard = CompanionGameRules(
        newEggCost: 40,
        hatchCost: 60,
        juniorEvolutionCost: 100,
        adultEvolutionCost: 160,
        dailyCarryoverRate: 0.20,
        maximumEnergyBalance: 320,
        duplicateSpeciesPityHatches: 5)

    public let newEggCost: Int
    public let hatchCost: Int
    public let juniorEvolutionCost: Int
    public let adultEvolutionCost: Int
    public let dailyCarryoverRate: Double
    public let maximumEnergyBalance: Int
    public let duplicateSpeciesPityHatches: Int

    public var journeyCompletionCost: Int {
        Self.saturatedAdd(self.newEggCost, self.hatchCost)
    }

    public init(
        newEggCost: Int,
        hatchCost: Int,
        juniorEvolutionCost: Int,
        adultEvolutionCost: Int,
        dailyCarryoverRate: Double,
        maximumEnergyBalance: Int,
        duplicateSpeciesPityHatches: Int = 5)
    {
        self.newEggCost = max(newEggCost, 0)
        self.hatchCost = max(hatchCost, 0)
        self.juniorEvolutionCost = max(juniorEvolutionCost, 0)
        self.adultEvolutionCost = max(adultEvolutionCost, 0)
        self.dailyCarryoverRate = min(max(dailyCarryoverRate, 0), 1)
        self.maximumEnergyBalance = max(maximumEnergyBalance, 0)
        self.duplicateSpeciesPityHatches = max(duplicateSpeciesPityHatches, 1)
    }

    public func actionCost(to stage: CompanionGameStage) -> Int {
        switch stage {
        case .egg: self.newEggCost
        case .hatchling: self.hatchCost
        case .junior: self.juniorEvolutionCost
        case .adult: self.adultEvolutionCost
        }
    }

    public func nextStage(after stage: CompanionGameStage) -> CompanionGameStage? {
        switch stage {
        case .egg: .hatchling
        case .hatchling: .junior
        case .junior: .adult
        case .adult: nil
        }
    }

    public func nextActionCost(after stage: CompanionGameStage) -> Int? {
        self.nextStage(after: stage).map { self.actionCost(to: $0) }
    }

    private static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : sum
    }
}

public struct CompanionGameState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 4

    public var schemaVersion: Int
    public var speciesID: CompanionSpeciesID?
    public var generationID: UUID
    public var generationNumber: Int
    public var stage: CompanionGameStage
    public var rarity: CompanionRarity?
    public var growthEnergy: Int
    public var growthDateKey: String
    public var growthEarnedToday: Int
    public var growthCarriedToday: Int
    public var growthSpentToday: Int
    public var bondEnergy: Int
    public var collection: CompanionCollection
    public var consecutiveDuplicateHatches: Int
    public var pity: CompanionPityState
    public var appliedGrowthAwardIDs: [UUID]
    public var lastActiveAt: Date?
    public var lastPattedAt: Date?
    public var celebrationUntil: Date?
    public var generationCreatedAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        speciesID: CompanionSpeciesID? = nil,
        generationID: UUID = UUID(),
        generationNumber: Int = 1,
        stage: CompanionGameStage = .egg,
        rarity: CompanionRarity? = nil,
        growthEnergy: Int = 0,
        growthDateKey: String? = nil,
        growthEarnedToday: Int = 0,
        growthCarriedToday: Int = 0,
        growthSpentToday: Int = 0,
        bondEnergy: Int = 0,
        collection: CompanionCollection? = nil,
        consecutiveDuplicateHatches: Int = 0,
        pity: CompanionPityState = CompanionPityState(),
        appliedGrowthAwardIDs: [UUID] = [],
        lastActiveAt: Date? = nil,
        lastPattedAt: Date? = nil,
        celebrationUntil: Date? = nil,
        generationCreatedAt: Date = .now,
        updatedAt: Date = .now)
    {
        self.schemaVersion = schemaVersion
        self.speciesID = speciesID
        self.generationID = generationID
        self.generationNumber = max(generationNumber, 1)
        self.stage = stage
        self.rarity = rarity
        self.growthEnergy = max(growthEnergy, 0)
        self.growthDateKey = growthDateKey
            ?? GrowthLocalDate.key(for: generationCreatedAt)
        self.growthEarnedToday = max(growthEarnedToday, 0)
        self.growthCarriedToday = max(growthCarriedToday, 0)
        self.growthSpentToday = max(growthSpentToday, 0)
        self.bondEnergy = max(bondEnergy, 0)
        self.collection = collection ?? CompanionCollection()
        self.consecutiveDuplicateHatches = max(consecutiveDuplicateHatches, 0)
        self.pity = pity
        self.appliedGrowthAwardIDs = Array(appliedGrowthAwardIDs.suffix(256))
        self.lastActiveAt = lastActiveAt
        self.lastPattedAt = lastPattedAt
        self.celebrationUntil = celebrationUntil
        self.generationCreatedAt = generationCreatedAt
        self.updatedAt = updatedAt
    }

    public static func formID(
        speciesID: CompanionSpeciesID,
        stage: CompanionGameStage,
        rarity: CompanionRarity) -> String
    {
        "\(speciesID.rawValue).\(stage.rawValue).\(rarity.rawValue)"
    }

    public func isValid(rules: CompanionGameRules = .standard) -> Bool {
        guard self.schemaVersion == Self.currentSchemaVersion,
              self.generationNumber >= 1,
              self.growthEnergy >= 0,
              self.growthEnergy <= rules.maximumEnergyBalance,
              !self.growthDateKey.isEmpty,
              self.growthEarnedToday >= 0,
              self.growthCarriedToday >= 0,
              self.growthSpentToday >= 0,
              self.bondEnergy >= 0,
              self.consecutiveDuplicateHatches >= 0,
              (self.stage == .egg
                  ? self.rarity == nil && self.speciesID == nil
                  : self.rarity != nil && self.speciesID != nil),
              Set(self.appliedGrowthAwardIDs).count == self.appliedGrowthAwardIDs.count,
              self.collection.forms.count
                <= CompanionSpeciesID.allCases.count
                    * 3
                    * CompanionRarity.allCases.count
        else { return false }

        let formIDs = self.collection.forms.map(\.formID)
        guard Set(formIDs).count == formIDs.count else { return false }
        return self.collection.forms.allSatisfy { form in
            form.stage != .egg
                && form.formID == Self.formID(
                speciesID: form.speciesID,
                stage: form.stage,
                rarity: form.rarity)
                && form.encounterCount >= 0
                && (form.unlockKind == .encountered
                    ? form.encounterCount > 0 && form.lastEncounteredAt != nil
                    : form.encounterCount == 0)
        }
    }
}

public enum CompanionGameEvent: Hashable, Sendable {
    case energyApplied(Int)
    case energySpent(Int)
    case hatched(
        speciesID: CompanionSpeciesID,
        rarity: CompanionRarity,
        isNewSpecies: Bool,
        unlockedFormIDs: [String])
    case evolved(
        fromStage: CompanionGameStage,
        toStage: CompanionGameStage,
        fromRarity: CompanionRarity,
        toRarity: CompanionRarity,
        unlockedFormIDs: [String])
    case bondIncreased(Int)
    case generationCompleted(CompletedCompanionGeneration)
    case newEgg(generationNumber: Int)
}

public enum CompanionGameError: Error, Equatable {
    case insufficientEnergy(required: Int, available: Int)
    case eggRequired
    case evolutionUnavailable
    case rarityMissing
    case adultRequired
}
