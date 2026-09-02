import Foundation

enum CompanionMemoryPolicy {
    static let maximumPerCompanion = 40
    static let maximumTotal = 2_000

    static func pruned(
        _ memories: [CompanionMemoryRecord]) -> [CompanionMemoryRecord]
    {
        let retainedIDs = Set(
            Dictionary(grouping: memories, by: \.generationID)
                .values
                .flatMap { $0.suffix(Self.maximumPerCompanion).map(\.id) })
        return Array(memories.filter {
            retainedIDs.contains($0.id)
        }.suffix(Self.maximumTotal))
    }
}

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
/// `CompanionRarity` remains in persisted models as a decoding bridge for old
/// saves. New game rules and UI use variants: variants have no rank or power.
public struct CompanionVariantID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let standard = Self(rawValue: "standard")
    public static let mutated = Self(rawValue: "mutated")
    public static let prismatic = Self(rawValue: "prismatic")
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
    public static let collectionDisplayOrder: [CompanionVariantID] = [
        .standard,
        .prismatic,
        .mutated,
    ]

    public static let definitions: [CompanionVariantDefinition] = [
        CompanionVariantDefinition(
            id: .standard,
            assetRarity: .normal,
            isCollectible: true,
            isSpecial: false),
        CompanionVariantDefinition(
            id: .mutated,
            assetRarity: .normal,
            isCollectible: true,
            isSpecial: true),
        CompanionVariantDefinition(
            id: .prismatic,
            assetRarity: .legendary,
            isCollectible: true,
            isSpecial: true),
    ]

    public static var collectibleIDs: [CompanionVariantID] {
        let collectible = Set(
            self.definitions.filter(\.isCollectible).map(\.id))
        let ordered = self.collectionDisplayOrder.filter {
            collectible.contains($0)
        }
        let remaining = self.definitions
            .filter { $0.isCollectible && !ordered.contains($0.id) }
            .map(\.id)
        return ordered + remaining
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
        case .rare, .epic: .standard
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
    public var mutationID: CompanionMutationID?
    public var nickname: String?
    public var personalityID: CompanionPersonalityID?
    public let bondEnergy: Int
    public var growthXP: Int
    public let stage: CompanionGameStage
    public let acquisitionEggID: CompanionEggDefinitionID?
    public let createdAt: Date
    public let completedAt: Date

    public var id: UUID { self.generationID }

    public init(
        generationID: UUID,
        generationNumber: Int,
        speciesID: CompanionSpeciesID = .bytebot,
        finalRarity: CompanionRarity,
        variantID: CompanionVariantID? = nil,
        mutationID: CompanionMutationID? = nil,
        nickname: String? = nil,
        personalityID: CompanionPersonalityID? = nil,
        bondEnergy: Int,
        growthXP: Int = 0,
        stage: CompanionGameStage = .adult,
        acquisitionEggID: CompanionEggDefinitionID? = nil,
        createdAt: Date? = nil,
        completedAt: Date)
    {
        self.generationID = generationID
        self.generationNumber = generationNumber
        self.speciesID = speciesID
        self.finalRarity = finalRarity
        self.variantID = variantID
        self.mutationID = mutationID
        self.nickname = nickname
        self.personalityID = personalityID
        self.bondEnergy = bondEnergy
        self.growthXP = CompanionLevelCurve.standard.clampedXP(growthXP)
        self.stage = stage
        self.acquisitionEggID = acquisitionEggID
        self.createdAt = createdAt ?? completedAt
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case generationID
        case generationNumber
        case speciesID
        case finalRarity
        case variantID
        case mutationID
        case nickname
        case personalityID
        case bondEnergy
        case growthXP
        case stage
        case acquisitionEggID
        case createdAt
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
        self.mutationID = try container.decodeIfPresent(
            CompanionMutationID.self,
            forKey: .mutationID)
        self.nickname = try container.decodeIfPresent(
            String.self,
            forKey: .nickname)
        self.personalityID = try container.decodeIfPresent(
            CompanionPersonalityID.self,
            forKey: .personalityID)
        self.bondEnergy = try container.decode(Int.self, forKey: .bondEnergy)
        self.growthXP = CompanionLevelCurve.standard.clampedXP(
            try container.decodeIfPresent(Int.self, forKey: .growthXP) ?? 0)
        self.stage = try container.decodeIfPresent(
            CompanionGameStage.self,
            forKey: .stage) ?? .adult
        self.acquisitionEggID = try container.decodeIfPresent(
            CompanionEggDefinitionID.self,
            forKey: .acquisitionEggID)
        self.completedAt = try container.decode(Date.self, forKey: .completedAt)
        self.createdAt = try container.decodeIfPresent(
            Date.self,
            forKey: .createdAt) ?? self.completedAt
    }
}

public struct CompanionCollection: Codable, Hashable, Sendable {
    public var forms: [CompanionFormRecord]
    public var mutations: [CompanionMutationRecord]
    public var mutationSynthesisCount: Int
    public var totalCompletedGenerations: Int
    public var completedByRarity: [String: Int]
    public var highestRarity: CompanionRarity
    public var highestBondEnergy: Int
    public var recentCompletedGenerations: [CompletedCompanionGeneration]

    public init(
        forms: [CompanionFormRecord] = [],
        mutations: [CompanionMutationRecord] = [],
        mutationSynthesisCount: Int = 0,
        totalCompletedGenerations: Int = 0,
        completedByRarity: [String: Int] = [:],
        highestRarity: CompanionRarity = .normal,
        highestBondEnergy: Int = 0,
        recentCompletedGenerations: [CompletedCompanionGeneration] = [])
    {
        self.forms = forms
        self.mutations = mutations
        self.mutationSynthesisCount = max(mutationSynthesisCount, 0)
        self.totalCompletedGenerations = max(totalCompletedGenerations, 0)
        self.completedByRarity = completedByRarity
        self.highestRarity = highestRarity
        self.highestBondEnergy = max(highestBondEnergy, 0)
        self.recentCompletedGenerations = recentCompletedGenerations
    }

    private enum CodingKeys: String, CodingKey {
        case forms
        case mutations
        case mutationSynthesisCount
        case totalCompletedGenerations
        case completedByRarity
        case highestRarity
        case highestBondEnergy
        case recentCompletedGenerations
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.forms = try container.decode(
            [CompanionFormRecord].self,
            forKey: .forms)
        self.mutations = try container.decodeIfPresent(
            [CompanionMutationRecord].self,
            forKey: .mutations) ?? []
        self.mutationSynthesisCount = max(
            try container.decodeIfPresent(
                Int.self,
                forKey: .mutationSynthesisCount) ?? 0,
            0)
        self.totalCompletedGenerations = try container.decode(
            Int.self,
            forKey: .totalCompletedGenerations)
        self.completedByRarity = try container.decode(
            [String: Int].self,
            forKey: .completedByRarity)
        self.highestRarity = try container.decode(
            CompanionRarity.self,
            forKey: .highestRarity)
        self.highestBondEnergy = try container.decode(
            Int.self,
            forKey: .highestBondEnergy)
        self.recentCompletedGenerations = try container.decode(
            [CompletedCompanionGeneration].self,
            forKey: .recentCompletedGenerations)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.forms, forKey: .forms)
        try container.encode(self.mutations, forKey: .mutations)
        try container.encode(
            self.mutationSynthesisCount,
            forKey: .mutationSynthesisCount)
        try container.encode(
            self.totalCompletedGenerations,
            forKey: .totalCompletedGenerations)
        try container.encode(
            self.completedByRarity,
            forKey: .completedByRarity)
        try container.encode(self.highestRarity, forKey: .highestRarity)
        try container.encode(
            self.highestBondEnergy,
            forKey: .highestBondEnergy)
        try container.encode(
            self.recentCompletedGenerations,
            forKey: .recentCompletedGenerations)
    }

    public var unlockedFormCount: Int { self.forms.count }

    public var discoveredMutationKeys: Set<String> {
        Set(self.mutations.map(\.id))
    }

    public var discoveredMutationCount: Int {
        self.discoveredMutationKeys.count
    }

    public var discoveredCollectionEntryCount: Int {
        self.discoveredCollectibleVariantCount
            + self.discoveredMutationCount
    }

    public func mutationRecord(
        for speciesID: CompanionSpeciesID,
        mutationID: CompanionMutationID) -> CompanionMutationRecord?
    {
        self.mutations.first {
            $0.speciesID == speciesID && $0.mutationID == mutationID
        }
    }

    public var discoveredSpeciesIDs: Set<CompanionSpeciesID> {
        Set(self.forms.filter { $0.unlockKind == .encountered }.map(\.speciesID))
    }

    public var discoveredCollectibleVariantKeys: Set<String> {
        Set(self.forms.compactMap { form in
            guard form.unlockKind == .encountered else { return nil }
            let variantID = form.variantID
                ?? CompanionVariantRegistry.migrated(from: form.rarity)
            guard CompanionVariantRegistry.definition(
                for: variantID).isCollectible
            else { return nil }
            return "\(form.speciesID.rawValue).\(variantID.rawValue)"
        })
    }

    public var discoveredCollectibleVariantCount: Int {
        self.discoveredCollectibleVariantKeys.count
    }

    public var discoveredVariantIDs: Set<CompanionVariantID> {
        Set(self.forms.compactMap { form in
            guard form.unlockKind == .encountered else { return nil }
            return form.variantID
                ?? CompanionVariantRegistry.migrated(from: form.rarity)
        })
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
        mutationChance: 0.01,
        prismaticChance: 0.08,
        prismaticPityHatches: 12)

    public let newEggCost: Int
    public let hatchCost: Int
    public let juniorEvolutionCost: Int
    public let adultEvolutionCost: Int
    public let dailyCarryoverRate: Double
    public let maximumEnergyBalance: Int
    public let duplicateSpeciesPityHatches: Int
    public let mutationChance: Double
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
        mutationChance: Double = 0.01,
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
        self.mutationChance = min(max(mutationChance, 0), 1)
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

public enum CompanionDisplayRole: String, Codable, CaseIterable, Sendable {
    case primary
    case growthTarget
    case showcase
}

/// A provider-neutral snapshot of the distinct jobs owned companions can have.
/// Role IDs contain no usage observations, provider data, or token totals.
public struct CompanionRoleSelection: Equatable, Sendable {
    public let primaryGenerationID: UUID?
    public let growthTargetGenerationID: UUID?
    public let showcaseGenerationIDs: [UUID]

    public init(
        primaryGenerationID: UUID?,
        growthTargetGenerationID: UUID?,
        showcaseGenerationIDs: [UUID] = [])
    {
        self.primaryGenerationID = primaryGenerationID
        self.growthTargetGenerationID = growthTargetGenerationID
        self.showcaseGenerationIDs = Array(
            Set(showcaseGenerationIDs)).sorted {
                $0.uuidString < $1.uuidString
            }
    }
}

public struct CompanionGameState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 11

    public var schemaVersion: Int
    public var speciesID: CompanionSpeciesID?
    public var generationID: UUID
    public var generationNumber: Int
    public var stage: CompanionGameStage
    public var rarity: CompanionRarity?
    public var variantID: CompanionVariantID?
    public var activeMutationID: CompanionMutationID?
    public var nickname: String?
    public var personalityID: CompanionPersonalityID?
    public var activeAcquisitionEggID: CompanionEggDefinitionID?
    public var growthTargetGenerationID: UUID?
    public var growthXP: Int
    public var growthEnergy: Int
    public var growthDateKey: String
    public var growthEarnedToday: Int
    public var delayedGrowthEarnedToday: Int
    public var growthCarriedToday: Int
    public var growthSpentToday: Int
    public var bondEnergy: Int
    public var memories: [CompanionMemoryRecord]
    public var collection: CompanionCollection
    public var consecutiveDuplicateHatches: Int
    public var pity: CompanionPityState
    public var variantPity: CompanionVariantPityState
    public var eggs: [CompanionEggInstance]
    public var highestPetLevel: Int
    public var claimedEggMilestoneIDs: [String]
    public var processedEggTransactionIDs: [UUID]
    public var legacyMigratedGenerationIDs: [UUID]
    public var appliedGrowthAwardIDs: [UUID]
    public var lastActiveAt: Date?
    public var lastPattedAt: Date?
    public var celebrationUntil: Date?
    public var showcasedGenerationID: UUID?
    public var displayStageGenerationID: UUID?
    public var displayStage: CompanionGameStage?
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
        activeMutationID: CompanionMutationID? = nil,
        nickname: String? = nil,
        personalityID: CompanionPersonalityID? = nil,
        activeAcquisitionEggID: CompanionEggDefinitionID? = nil,
        growthTargetGenerationID: UUID? = nil,
        growthXP: Int? = nil,
        growthEnergy: Int = 0,
        growthDateKey: String? = nil,
        growthEarnedToday: Int = 0,
        delayedGrowthEarnedToday: Int = 0,
        growthCarriedToday: Int = 0,
        growthSpentToday: Int = 0,
        bondEnergy: Int = 0,
        memories: [CompanionMemoryRecord] = [],
        collection: CompanionCollection? = nil,
        consecutiveDuplicateHatches: Int = 0,
        pity: CompanionPityState = CompanionPityState(),
        variantPity: CompanionVariantPityState = CompanionVariantPityState(),
        eggs: [CompanionEggInstance]? = nil,
        highestPetLevel: Int = 0,
        claimedEggMilestoneIDs: [String] = [],
        processedEggTransactionIDs: [UUID] = [],
        legacyMigratedGenerationIDs: [UUID] = [],
        appliedGrowthAwardIDs: [UUID] = [],
        lastActiveAt: Date? = nil,
        lastPattedAt: Date? = nil,
        celebrationUntil: Date? = nil,
        showcasedGenerationID: UUID? = nil,
        displayStageGenerationID: UUID? = nil,
        displayStage: CompanionGameStage? = nil,
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
        self.activeMutationID = nil
        self.nickname = nickname
        self.personalityID = personalityID
        self.activeAcquisitionEggID = activeAcquisitionEggID
        self.growthTargetGenerationID = growthTargetGenerationID
        self.growthXP = CompanionLevelCurve.standard.clampedXP(
            growthXP ?? Self.migratedGrowthXP(
                stage: stage,
                growthEnergy: growthEnergy,
                bondEnergy: bondEnergy))
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
        self.memories = CompanionMemoryPolicy.pruned(memories)
        self.collection = Self.migratedCollection(
            collection ?? CompanionCollection())
        self.consecutiveDuplicateHatches = max(consecutiveDuplicateHatches, 0)
        self.pity = pity
        self.variantPity = variantPity
        self.eggs = eggs ?? (stage == .egg && speciesID == nil
            ? [CompanionEggInstance.starter(at: generationCreatedAt)]
            : [])
        let activeLevel = stage == .egg
            ? 0
            : CompanionLevelCurve.standard.level(forXP: self.growthXP)
        let ownedHighestLevel = self.collection.archivedGenerations.map {
            CompanionLevelCurve.standard.level(forXP: $0.growthXP)
        }.max() ?? 0
        self.highestPetLevel = max(
            highestPetLevel,
            max(activeLevel, ownedHighestLevel))
        self.claimedEggMilestoneIDs = Array(
            Set(claimedEggMilestoneIDs)).sorted()
        self.processedEggTransactionIDs = Array(
            processedEggTransactionIDs.suffix(512))
        self.legacyMigratedGenerationIDs = Array(
            Set(legacyMigratedGenerationIDs)).sorted {
                $0.uuidString < $1.uuidString
            }
        self.appliedGrowthAwardIDs = Array(appliedGrowthAwardIDs.suffix(256))
        self.lastActiveAt = lastActiveAt
        self.lastPattedAt = lastPattedAt
        self.celebrationUntil = celebrationUntil
        self.showcasedGenerationID = showcasedGenerationID
        self.displayStageGenerationID = displayStageGenerationID
        self.displayStage = displayStage == .egg ? nil : displayStage
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

    public var availableGrowthEnergy: Int {
        self.growthEnergy
    }

    public var level: Int {
        self.stage == .egg
            ? 0
            : CompanionLevelCurve.standard.level(forXP: self.growthXP)
    }

    public var resolvedGrowthTargetGenerationID: UUID? {
        guard self.stage != .egg else { return nil }
        return self.growthTargetGenerationID ?? self.generationID
    }

    public var roleSelection: CompanionRoleSelection {
        return CompanionRoleSelection(
            primaryGenerationID: self.showcasedGenerationID
                ?? self.generationID,
            growthTargetGenerationID: self.resolvedGrowthTargetGenerationID)
    }

    public var growthTargetLevel: Int {
        guard let targetID = self.resolvedGrowthTargetGenerationID else {
            return 0
        }
        if targetID == self.generationID { return self.level }
        return self.collection.archivedGenerations.first {
            $0.generationID == targetID
        }.map {
            CompanionLevelCurve.standard.level(forXP: $0.growthXP)
        } ?? 0
    }

    public var nextEvolution: CompanionEvolutionDefinition? {
        CompanionEvolutionRegistry.next(after: self.stage)
    }

    public var canEvolve: Bool {
        self.nextEvolution.map { self.level >= $0.requiredLevel } ?? false
    }

    public func isValid(rules: CompanionGameRules = .standard) -> Bool {
        let archivedGenerationsAreValid =
            self.collection.archivedGenerations.allSatisfy { generation in
                generation.generationNumber >= 1
                    && generation.bondEnergy >= 0
                    && generation.growthXP >= 0
                    && generation.stage != .egg
                    && generation.personalityID.map {
                        CompanionPersonalityRegistry.allIDs.contains($0)
                    } != false
                    && generation.mutationID.map { mutationID in
                        self.collection.mutationRecord(
                            for: generation.speciesID,
                            mutationID: mutationID) != nil
                    } != false
            }
        let showcasedGenerationIsValid = self.showcasedGenerationID.map { generationID in
            self.collection.archivedGenerations.contains { generation in
                generation.generationID == generationID
            }
        } != false
        let nicknameIsValid = self.nickname.map {
            !$0.isEmpty && $0.count <= 24
        } != false
        let memoryIDsAreUnique =
            Set(self.memories.map(\.id)).count == self.memories.count
        let memoriesAreValid = self.memories.allSatisfy { memory in
            memory.bondLevel.map {
                (1...CompanionBond.levelThresholds.count).contains($0)
            } != false
        }
        let eggIDsAreUnique = Set(self.eggs.map(\.id)).count == self.eggs.count
        let eggsAreKnown = self.eggs.allSatisfy {
            CompanionEggRegistry.definition(for: $0.definitionID) != nil
        }
        let mutationKeys = self.collection.mutations.map(\.id)
        let mutationRecordsAreValid = self.collection.mutations.allSatisfy {
            CompanionMutationRegistry.definition(for: $0.mutationID) != nil
                && $0.synthesisCount > 0
        }
        let activeMutationIsValid = self.activeMutationID.map { mutationID in
            guard let speciesID = self.speciesID else { return false }
            return self.collection.mutationRecord(
                for: speciesID,
                mutationID: mutationID) != nil
        } != false
        let activeGenerationIsNotArchived = !self.collection
            .archivedGenerations.contains(where: {
                $0.generationID == self.generationID
            })
        let growthTargetIsValid = self.growthTargetGenerationID.map { targetID in
            targetID == self.generationID
                || self.collection.archivedGenerations.contains {
                    $0.generationID == targetID
                }
        } != false
        let displayStageSelectionIsValid: Bool = switch (
            self.displayStageGenerationID,
            self.displayStage)
        {
        case (nil, nil):
            true
        case let (generationID?, stage?):
            stage != .egg && (generationID == self.generationID
                ? self.level == CompanionLevelCurve.standard.maximumLevel
                : self.collection.archivedGenerations.contains { generation in
                    generation.generationID == generationID
                        && CompanionLevelCurve.standard.level(
                            forXP: generation.growthXP)
                            == CompanionLevelCurve.standard.maximumLevel
                })
        default:
            false
        }
        guard self.schemaVersion == Self.currentSchemaVersion,
              self.generationNumber >= 1,
              self.growthEnergy >= 0,
              self.growthEnergy <= rules.maximumEnergyBalance,
              self.growthXP >= 0,
              !self.growthDateKey.isEmpty,
              self.growthEarnedToday >= 0,
              self.delayedGrowthEarnedToday >= 0,
              self.delayedGrowthEarnedToday <= self.growthEarnedToday,
              self.growthCarriedToday >= 0,
              self.growthSpentToday >= 0,
              self.bondEnergy >= 0,
              self.consecutiveDuplicateHatches >= 0,
              self.highestPetLevel >= self.level,
              Set(self.claimedEggMilestoneIDs).count
                == self.claimedEggMilestoneIDs.count,
              Set(self.processedEggTransactionIDs).count
                == self.processedEggTransactionIDs.count,
              Set(self.legacyMigratedGenerationIDs).count
                == self.legacyMigratedGenerationIDs.count,
              Set(mutationKeys).count == mutationKeys.count,
              self.collection.mutationSynthesisCount >= 0,
              mutationRecordsAreValid,
              activeMutationIsValid,
              self.processedEggTransactionIDs.count <= 512,
              eggIDsAreUnique,
              eggsAreKnown,
              (self.stage == .egg
                  ? self.rarity == nil
                      && self.variantID == nil
                      && self.nickname == nil
                      && self.personalityID == nil
                      && self.activeAcquisitionEggID == nil
                      && self.activeMutationID == nil
                      && self.speciesID == nil
                  : self.rarity != nil
                      && self.resolvedVariantID != nil
                      && self.personalityID.map {
                          CompanionPersonalityRegistry.allIDs.contains($0)
                      } == true
                      && self.speciesID != nil),
              nicknameIsValid,
              memoryIDsAreUnique,
              memoriesAreValid,
              Set(self.appliedGrowthAwardIDs).count == self.appliedGrowthAwardIDs.count,
              Set(self.collection.archivedGenerations.map(\.generationID)).count
                == self.collection.archivedGenerations.count,
              activeGenerationIsNotArchived,
              growthTargetIsValid,
              displayStageSelectionIsValid,
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

    private static func migratedGrowthXP(
        stage: CompanionGameStage,
        growthEnergy: Int,
        bondEnergy: Int) -> Int
    {
        guard stage != .egg else { return 0 }
        let minimumLevel = CompanionEvolutionRegistry.requiredLevel(for: stage) ?? 1
        let base = CompanionLevelCurve.standard.totalXPRequired(
            forLevel: minimumLevel)
        let legacyProgress = max(growthEnergy, stage == .adult ? bondEnergy : 0)
        let (value, overflow) = base.addingReportingOverflow(
            max(legacyProgress, 0))
        return overflow ? Int.max : value
    }

    private static func migratedCollection(
        _ collection: CompanionCollection) -> CompanionCollection
    {
        var migrated = collection
        migrated.mutations = []
        migrated.mutationSynthesisCount = 0
        migrated.recentCompletedGenerations = collection
            .recentCompletedGenerations.map { generation in
                guard generation.growthXP == 0,
                      generation.stage == .adult
                else { return generation }
                let base = CompanionLevelCurve.standard.totalXPRequired(
                    forLevel: CompanionEvolutionRegistry.requiredLevel(
                        for: .adult) ?? 70)
                let (xp, overflow) = base.addingReportingOverflow(
                    max(generation.bondEnergy, 0))
                return CompletedCompanionGeneration(
                    generationID: generation.generationID,
                    generationNumber: generation.generationNumber,
                    speciesID: generation.speciesID,
                    finalRarity: generation.finalRarity,
                    variantID: generation.variantID,
                    mutationID: generation.mutationID,
                    nickname: generation.nickname,
                    personalityID: generation.personalityID,
                    bondEnergy: generation.bondEnergy,
                    growthXP: overflow ? Int.max : xp,
                    stage: generation.stage,
                    acquisitionEggID: generation.acquisitionEggID,
                    createdAt: generation.createdAt,
                    completedAt: generation.completedAt)
            }
            .filter { $0.mutationID == nil }
        return migrated
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
    case levelIncreased(generationID: UUID, from: Int, to: Int)
    case eggAcquired(CompanionEggDefinitionID)
    case eggOpened(UUID)
    case activeCompanionChanged(UUID)
    case companionSold(UUID, value: Int)
    case duplicateConverted(generationID: UUID, creditedXP: Int)
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
    case mutationSynthesized(
        speciesID: CompanionSpeciesID,
        mutationID: CompanionMutationID,
        consumedGenerationIDs: [UUID],
        createdGeneration: CompletedCompanionGeneration,
        isNewMutation: Bool)
}

public enum CompanionGameError: Error, Equatable {
    case insufficientEnergy(required: Int, available: Int)
    case eggRequired
    case evolutionUnavailable
    case rarityMissing
    case adultRequired
    case archivedGenerationNotFound
    case eggNotFound
    case evolutionLevelRequired(required: Int, current: Int)
    case maximumLevelReached
}

public enum CompanionMutationError: Error, Equatable, Sendable {
    case requiresThreeSources
    case sourceNotFound(UUID)
    case sourceSpeciesMismatch
    case sourceNotEligible
    case sourceIsActive
    case mutationNotDiscovered
}
