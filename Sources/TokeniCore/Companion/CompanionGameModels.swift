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

/// A visual-only appearance carried by one companion for its entire journey.
///
/// `CompanionRarity` remains in persisted models as a compatibility bridge for
/// releases that ranked the four original sprite palettes. New game rules and
/// UI must use variants instead: variants have no rank and grant no power.
public struct CompanionVariantID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let standard = Self(rawValue: "standard")
    public static let prismatic = Self(rawValue: "prismatic")
    public static let legacyAzure = Self(rawValue: "legacy-azure")
    public static let legacyViolet = Self(rawValue: "legacy-violet")
}

public struct CompanionVariantDefinition: Identifiable, Hashable, Sendable {
    public let id: CompanionVariantID
    public let assetRarity: CompanionRarity
    public let isCollectible: Bool
    public let isSpecial: Bool

    public init(
        id: CompanionVariantID,
        assetRarity: CompanionRarity,
        isCollectible: Bool,
        isSpecial: Bool)
    {
        self.id = id
        self.assetRarity = assetRarity
        self.isCollectible = isCollectible
        self.isSpecial = isSpecial
    }
}

public enum CompanionVariantRegistry {
    public static let definitions: [CompanionVariantDefinition] = [
        CompanionVariantDefinition(
            id: .standard,
            assetRarity: .normal,
            isCollectible: true,
            isSpecial: false),
        CompanionVariantDefinition(
            id: .prismatic,
            assetRarity: .legendary,
            isCollectible: true,
            isSpecial: true),
        CompanionVariantDefinition(
            id: .legacyAzure,
            assetRarity: .rare,
            isCollectible: false,
            isSpecial: true),
        CompanionVariantDefinition(
            id: .legacyViolet,
            assetRarity: .epic,
            isCollectible: false,
            isSpecial: true),
    ]

    public static var collectibleIDs: [CompanionVariantID] {
        self.definitions.filter(\.isCollectible).map(\.id)
    }

    public static func definition(
        for id: CompanionVariantID) -> CompanionVariantDefinition
    {
        self.definitions.first { $0.id == id }
            ?? CompanionVariantDefinition(
                id: id,
                assetRarity: .normal,
                isCollectible: false,
                isSpecial: false)
    }

    public static func migrated(from rarity: CompanionRarity) -> CompanionVariantID {
        switch rarity {
        case .normal: .standard
        case .rare: .legacyAzure
        case .epic: .legacyViolet
        case .legendary: .prismatic
        }
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
    public var variantID: CompanionVariantID?
    public var unlockKind: CompanionFormUnlockKind
    public let firstUnlockedAt: Date
    public var lastEncounteredAt: Date?
    public var encounterCount: Int

    public init(
        formID: String,
        speciesID: CompanionSpeciesID = .bytebot,
        stage: CompanionGameStage,
        rarity: CompanionRarity,
        variantID: CompanionVariantID? = nil,
        unlockKind: CompanionFormUnlockKind,
        firstUnlockedAt: Date,
        lastEncounteredAt: Date?,
        encounterCount: Int)
    {
        self.formID = formID
        self.speciesID = speciesID
        self.stage = stage
        self.rarity = rarity
        self.variantID = variantID
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
        case variantID
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
        self.variantID = try container.decodeIfPresent(
            CompanionVariantID.self,
            forKey: .variantID)
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

public struct CompletedCompanionGeneration: Codable, Hashable, Identifiable, Sendable {
    public let generationID: UUID
    public let generationNumber: Int
    public let speciesID: CompanionSpeciesID
    public let finalRarity: CompanionRarity
    public var variantID: CompanionVariantID?
    public let bondEnergy: Int
    public let completedAt: Date

    public var id: UUID { self.generationID }

    public init(
        generationID: UUID,
        generationNumber: Int,
        speciesID: CompanionSpeciesID = .bytebot,
        finalRarity: CompanionRarity,
        variantID: CompanionVariantID? = nil,
        bondEnergy: Int,
        completedAt: Date)
    {
        self.generationID = generationID
        self.generationNumber = generationNumber
        self.speciesID = speciesID
        self.finalRarity = finalRarity
        self.variantID = variantID
        self.bondEnergy = bondEnergy
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case generationID
        case generationNumber
        case speciesID
        case finalRarity
        case variantID
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
        self.variantID = try container.decodeIfPresent(
            CompanionVariantID.self,
            forKey: .variantID)
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
        self.recentCompletedGenerations = recentCompletedGenerations
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

    public var archivedGenerations: [CompletedCompanionGeneration] {
        self.recentCompletedGenerations
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

public struct CompanionVariantPityState: Codable, Hashable, Sendable {
    public var standardHatches: Int

    public init(standardHatches: Int = 0) {
        self.standardHatches = max(standardHatches, 0)
    }
}

public struct CompanionGameRules: Hashable, Sendable {
    public static let standard = CompanionGameRules(
        newEggCost: 300,
        hatchCost: 500,
        juniorEvolutionCost: 800,
        adultEvolutionCost: 1_400,
        dailyCarryoverRate: 1,
        maximumEnergyBalance: 100_000,
        duplicateSpeciesPityHatches: 5,
        prismaticChance: 0.08,
        prismaticPityHatches: 12)

    public let newEggCost: Int
    public let hatchCost: Int
    public let juniorEvolutionCost: Int
    public let adultEvolutionCost: Int
    public let dailyCarryoverRate: Double
    public let maximumEnergyBalance: Int
    public let duplicateSpeciesPityHatches: Int
    public let prismaticChance: Double
    public let prismaticPityHatches: Int

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
        duplicateSpeciesPityHatches: Int = 5,
        prismaticChance: Double = 0.08,
        prismaticPityHatches: Int = 12)
    {
        self.newEggCost = max(newEggCost, 0)
        self.hatchCost = max(hatchCost, 0)
        self.juniorEvolutionCost = max(juniorEvolutionCost, 0)
        self.adultEvolutionCost = max(adultEvolutionCost, 0)
        self.dailyCarryoverRate = min(max(dailyCarryoverRate, 0), 1)
        self.maximumEnergyBalance = max(maximumEnergyBalance, 0)
        self.duplicateSpeciesPityHatches = max(duplicateSpeciesPityHatches, 1)
        self.prismaticChance = min(max(prismaticChance, 0), 1)
        self.prismaticPityHatches = max(prismaticPityHatches, 1)
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
    public static let currentSchemaVersion = 6

    public var schemaVersion: Int
    public var speciesID: CompanionSpeciesID?
    public var generationID: UUID
    public var generationNumber: Int
    public var stage: CompanionGameStage
    public var rarity: CompanionRarity?
    public var variantID: CompanionVariantID?
    public var growthEnergy: Int
    public var growthDateKey: String
    public var growthEarnedToday: Int
    public var delayedGrowthEarnedToday: Int
    public var growthCarriedToday: Int
    public var growthSpentToday: Int
    public var bondEnergy: Int
    public var collection: CompanionCollection
    public var consecutiveDuplicateHatches: Int
    public var pity: CompanionPityState
    public var variantPity: CompanionVariantPityState
    public var appliedGrowthAwardIDs: [UUID]
    public var lastActiveAt: Date?
    public var lastPattedAt: Date?
    public var celebrationUntil: Date?
    public var showcasedGenerationID: UUID?
    public var generationCreatedAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        speciesID: CompanionSpeciesID? = nil,
        generationID: UUID = UUID(),
        generationNumber: Int = 1,
        stage: CompanionGameStage = .egg,
        rarity: CompanionRarity? = nil,
        variantID: CompanionVariantID? = nil,
        growthEnergy: Int = 0,
        growthDateKey: String? = nil,
        growthEarnedToday: Int = 0,
        delayedGrowthEarnedToday: Int = 0,
        growthCarriedToday: Int = 0,
        growthSpentToday: Int = 0,
        bondEnergy: Int = 0,
        collection: CompanionCollection? = nil,
        consecutiveDuplicateHatches: Int = 0,
        pity: CompanionPityState = CompanionPityState(),
        variantPity: CompanionVariantPityState = CompanionVariantPityState(),
        appliedGrowthAwardIDs: [UUID] = [],
        lastActiveAt: Date? = nil,
        lastPattedAt: Date? = nil,
        celebrationUntil: Date? = nil,
        showcasedGenerationID: UUID? = nil,
        generationCreatedAt: Date = .now,
        updatedAt: Date = .now)
    {
        self.schemaVersion = schemaVersion
        self.speciesID = speciesID
        self.generationID = generationID
        self.generationNumber = max(generationNumber, 1)
        self.stage = stage
        self.rarity = rarity
        self.variantID = variantID
        self.growthEnergy = max(growthEnergy, 0)
        self.growthDateKey = growthDateKey
            ?? GrowthLocalDate.key(for: generationCreatedAt)
        self.growthEarnedToday = max(growthEarnedToday, 0)
        self.delayedGrowthEarnedToday = min(
            max(delayedGrowthEarnedToday, 0),
            self.growthEarnedToday)
        self.growthCarriedToday = max(growthCarriedToday, 0)
        self.growthSpentToday = max(growthSpentToday, 0)
        self.bondEnergy = max(bondEnergy, 0)
        self.collection = collection ?? CompanionCollection()
        self.consecutiveDuplicateHatches = max(consecutiveDuplicateHatches, 0)
        self.pity = pity
        self.variantPity = variantPity
        self.appliedGrowthAwardIDs = Array(appliedGrowthAwardIDs.suffix(256))
        self.lastActiveAt = lastActiveAt
        self.lastPattedAt = lastPattedAt
        self.celebrationUntil = celebrationUntil
        self.showcasedGenerationID = showcasedGenerationID
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

    public static func variantFormID(
        speciesID: CompanionSpeciesID,
        stage: CompanionGameStage,
        variantID: CompanionVariantID) -> String
    {
        "\(speciesID.rawValue).\(stage.rawValue).\(variantID.rawValue)"
    }

    public var resolvedVariantID: CompanionVariantID? {
        self.variantID ?? self.rarity.map(CompanionVariantRegistry.migrated)
    }

    public func isValid(rules: CompanionGameRules = .standard) -> Bool {
        let archivedGenerationsAreValid =
            self.collection.archivedGenerations.allSatisfy { generation in
                generation.generationNumber >= 1 && generation.bondEnergy >= 0
            }
        let showcasedGenerationIsValid = self.showcasedGenerationID.map { generationID in
            self.collection.archivedGenerations.contains { generation in
                generation.generationID == generationID
            }
        } != false
        guard self.schemaVersion == Self.currentSchemaVersion,
              self.generationNumber >= 1,
              self.growthEnergy >= 0,
              self.growthEnergy <= rules.maximumEnergyBalance,
              !self.growthDateKey.isEmpty,
              self.growthEarnedToday >= 0,
              self.delayedGrowthEarnedToday >= 0,
              self.delayedGrowthEarnedToday <= self.growthEarnedToday,
              self.growthCarriedToday >= 0,
              self.growthSpentToday >= 0,
              self.bondEnergy >= 0,
              self.consecutiveDuplicateHatches >= 0,
              (self.stage == .egg
                  ? self.rarity == nil
                      && self.variantID == nil
                      && self.speciesID == nil
                  : self.rarity != nil
                      && self.resolvedVariantID != nil
                      && self.speciesID != nil),
              Set(self.appliedGrowthAwardIDs).count == self.appliedGrowthAwardIDs.count,
              Set(self.collection.archivedGenerations.map(\.generationID)).count
                == self.collection.archivedGenerations.count,
              self.collection.archivedGenerations.count
                <= self.collection.totalCompletedGenerations,
              archivedGenerationsAreValid,
              showcasedGenerationIsValid,
              self.collection.forms.count
                <= CompanionSpeciesID.totalRegisteredFormCount
        else { return false }

        let formIDs = self.collection.forms.map(\.formID)
        guard Set(formIDs).count == formIDs.count else { return false }
        return self.collection.forms.allSatisfy { form in
            let expectedFormID = form.variantID.map {
                Self.variantFormID(
                    speciesID: form.speciesID,
                    stage: form.stage,
                    variantID: $0)
            } ?? Self.formID(
                speciesID: form.speciesID,
                stage: form.stage,
                rarity: form.rarity)
            return form.stage != .egg
                && form.formID == expectedFormID
                && form.unlockKind == .encountered
                && form.encounterCount > 0
                && form.lastEncounteredAt != nil
        }
    }

    public var showcasedGeneration: CompletedCompanionGeneration? {
        guard let showcasedGenerationID else { return nil }
        return self.collection.archivedGenerations.first {
            $0.generationID == showcasedGenerationID
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
    case archivedGenerationNotFound
}
