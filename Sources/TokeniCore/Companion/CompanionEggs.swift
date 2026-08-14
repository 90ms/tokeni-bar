import Foundation

public struct CompanionEggDefinitionID:
    RawRepresentable, Codable, Hashable, Sendable
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let starter = Self(rawValue: "starter")
    public static let homecoming = Self(rawValue: "homecoming")
    public static let mystery = Self(rawValue: "mystery")
    public static let discovery = Self(rawValue: "discovery")
    public static let prismatic = Self(rawValue: "prismatic")
}

public enum CompanionEggSource: String, Codable, Hashable, Sendable {
    case starter
    case migrationGift
    case shop
    case collectionMilestone
    case dailyAttendance
}

public struct CompanionEggInstance: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let definitionID: CompanionEggDefinitionID
    public let seed: UInt64
    public let acquiredAt: Date
    public let source: CompanionEggSource
    /// Freezes the species pool at acquisition time so a content update cannot
    /// change the deterministic result of an unopened egg.
    public let speciesPoolGeneration: Int

    public init(
        id: UUID = UUID(),
        definitionID: CompanionEggDefinitionID,
        seed: UInt64,
        acquiredAt: Date = .now,
        source: CompanionEggSource,
        speciesPoolGeneration: Int = CompanionSpeciesID.latestContentGeneration)
    {
        self.id = id
        self.definitionID = definitionID
        self.seed = seed
        self.acquiredAt = acquiredAt
        self.source = source
        self.speciesPoolGeneration = max(speciesPoolGeneration, 1)
    }

    public var availableSpecies: [CompanionSpeciesID] {
        let species = CompanionSpeciesID.allCases.filter {
            $0.contentGeneration <= self.speciesPoolGeneration
        }
        return species.isEmpty ? CompanionSpeciesID.allCases : species
    }

    public static func starter(
        id: UUID = UUID(),
        seed: UInt64 = UInt64.random(in: 0...UInt64(Int64.max)),
        at date: Date = .now) -> Self
    {
        Self(
            id: id,
            definitionID: .starter,
            seed: seed,
            acquiredAt: date,
            source: .starter)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case definitionID
        case seed
        case acquiredAt
        case source
        case speciesPoolGeneration
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.definitionID = try container.decode(
            CompanionEggDefinitionID.self,
            forKey: .definitionID)
        self.seed = try container.decode(UInt64.self, forKey: .seed)
        self.acquiredAt = try container.decode(Date.self, forKey: .acquiredAt)
        self.source = try container.decode(CompanionEggSource.self, forKey: .source)
        self.speciesPoolGeneration = max(
            try container.decodeIfPresent(
                Int.self,
                forKey: .speciesPoolGeneration) ?? 1,
            1)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.definitionID, forKey: .definitionID)
        try container.encode(self.seed, forKey: .seed)
        try container.encode(self.acquiredAt, forKey: .acquiredAt)
        try container.encode(self.source, forKey: .source)
        try container.encode(
            self.speciesPoolGeneration,
            forKey: .speciesPoolGeneration)
    }
}

public enum CompanionEggUnlockRequirement: Hashable, Sendable {
    case starterOnly
    case highestPetLevel(Int)
    case discoveredSpecies(Int)
    case milestoneOnly
}

public struct CompanionEggDefinition: Identifiable, Hashable, Sendable {
    public let id: CompanionEggDefinitionID
    public let price: Int?
    public let resaleValue: Int
    public let unlockRequirement: CompanionEggUnlockRequirement
    public let prefersUndiscoveredSpecies: Bool
    public let guaranteesPrismatic: Bool
    public let prismaticChanceBonus: Double
    public let mutationChanceBonus: Double
    public let isSellable: Bool

    public init(
        id: CompanionEggDefinitionID,
        price: Int?,
        resaleValue: Int,
        unlockRequirement: CompanionEggUnlockRequirement,
        prefersUndiscoveredSpecies: Bool = false,
        guaranteesPrismatic: Bool = false,
        prismaticChanceBonus: Double = 0,
        mutationChanceBonus: Double = 0,
        isSellable: Bool = true)
    {
        self.id = id
        self.price = price.map { max($0, 0) }
        self.resaleValue = max(resaleValue, 0)
        self.unlockRequirement = unlockRequirement
        self.prefersUndiscoveredSpecies = prefersUndiscoveredSpecies
        self.guaranteesPrismatic = guaranteesPrismatic
        self.prismaticChanceBonus = min(max(prismaticChanceBonus, 0), 1)
        self.mutationChanceBonus = min(max(mutationChanceBonus, 0), 1)
        self.isSellable = isSellable
    }
}

public enum CompanionEggRegistry {
    public static let definitions: [CompanionEggDefinition] = [
        CompanionEggDefinition(
            id: .starter,
            price: nil,
            resaleValue: 0,
            unlockRequirement: .starterOnly,
            isSellable: false),
        CompanionEggDefinition(
            id: .homecoming,
            price: nil,
            resaleValue: 0,
            unlockRequirement: .milestoneOnly,
            prefersUndiscoveredSpecies: true,
            isSellable: false),
        CompanionEggDefinition(
            id: .mystery,
            price: 90,
            resaleValue: 30,
            unlockRequirement: .highestPetLevel(5)),
        CompanionEggDefinition(
            id: .discovery,
            price: 180,
            resaleValue: 60,
            unlockRequirement: .discoveredSpecies(3),
            prefersUndiscoveredSpecies: true,
            prismaticChanceBonus: 0.02,
            mutationChanceBonus: 0.01),
        CompanionEggDefinition(
            id: .prismatic,
            price: nil,
            resaleValue: 60,
            unlockRequirement: .milestoneOnly,
            guaranteesPrismatic: true),
    ]

    public static func definition(
        for id: CompanionEggDefinitionID) -> CompanionEggDefinition?
    {
        self.definitions.first { $0.id == id }
    }

    public static func isUnlocked(
        _ definition: CompanionEggDefinition,
        highestPetLevel: Int,
        discoveredSpeciesCount: Int) -> Bool
    {
        switch definition.unlockRequirement {
        case .starterOnly, .milestoneOnly:
            false
        case let .highestPetLevel(level):
            highestPetLevel >= level
        case let .discoveredSpecies(count):
            discoveredSpeciesCount >= count
        }
    }

    public static func unitValue(seed: UInt64, salt: UInt64) -> Double {
        var value = seed &+ salt &+ 0x9E37_79B9_7F4A_7C15
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value >> 11) / Double(1 << 53)
    }

    public static func deterministicSeed(for value: String) -> UInt64 {
        value.utf8.reduce(1_469_598_103_934_665_603) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

public enum CompanionEggError: Error, Equatable, Sendable {
    case eggNotFound
    case definitionNotFound
    case eggLocked
    case eggNotPurchasable
    case eggNotSellable
    case insufficientShards(required: Int, available: Int)
    case activePetRequired
    case lastPetCannotBeSold
    case activePetCannotBeSold
}
