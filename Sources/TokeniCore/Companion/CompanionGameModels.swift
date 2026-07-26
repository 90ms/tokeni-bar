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
    public let stage: CompanionGameStage
    public let rarity: CompanionRarity
    public var unlockKind: CompanionFormUnlockKind
    public let firstUnlockedAt: Date
    public var lastEncounteredAt: Date?
    public var encounterCount: Int
}

public struct CompletedCompanionGeneration: Codable, Hashable, Sendable {
    public let generationID: UUID
    public let generationNumber: Int
    public let finalRarity: CompanionRarity
    public let bondEnergy: Int
    public let completedAt: Date
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
        hatchlingEnergy: 80,
        juniorEnergy: 280,
        adultEnergy: 800)

    public let hatchlingEnergy: Int
    public let juniorEnergy: Int
    public let adultEnergy: Int

    public init(
        hatchlingEnergy: Int,
        juniorEnergy: Int,
        adultEnergy: Int)
    {
        let hatchling = max(hatchlingEnergy, 0)
        let junior = max(juniorEnergy, hatchling)
        self.hatchlingEnergy = hatchling
        self.juniorEnergy = junior
        self.adultEnergy = max(adultEnergy, junior)
    }

    public func stage(for growthEnergy: Int) -> CompanionGameStage {
        switch max(growthEnergy, 0) {
        case self.adultEnergy...: .adult
        case self.juniorEnergy...: .junior
        case self.hatchlingEnergy...: .hatchling
        default: .egg
        }
    }

    public func threshold(for stage: CompanionGameStage) -> Int {
        switch stage {
        case .egg: 0
        case .hatchling: self.hatchlingEnergy
        case .junior: self.juniorEnergy
        case .adult: self.adultEnergy
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

    public func nextThreshold(after stage: CompanionGameStage) -> Int? {
        self.nextStage(after: stage).map { self.threshold(for: $0) }
    }
}

public struct CompanionGameState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var speciesID: String
    public var generationID: UUID
    public var generationNumber: Int
    public var stage: CompanionGameStage
    public var rarity: CompanionRarity
    public var growthEnergy: Int
    public var bondEnergy: Int
    public var collection: CompanionCollection
    public var pity: CompanionPityState
    public var appliedGrowthAwardIDs: [UUID]
    public var lastActiveAt: Date?
    public var lastPattedAt: Date?
    public var celebrationUntil: Date?
    public var generationCreatedAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        speciesID: String = "bytebot",
        generationID: UUID = UUID(),
        generationNumber: Int = 1,
        stage: CompanionGameStage = .egg,
        rarity: CompanionRarity = .normal,
        growthEnergy: Int = 0,
        bondEnergy: Int = 0,
        collection: CompanionCollection? = nil,
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
        self.bondEnergy = max(bondEnergy, 0)
        self.collection = collection ?? CompanionCollection()
        self.pity = pity
        self.appliedGrowthAwardIDs = Array(appliedGrowthAwardIDs.suffix(256))
        self.lastActiveAt = lastActiveAt
        self.lastPattedAt = lastPattedAt
        self.celebrationUntil = celebrationUntil
        self.generationCreatedAt = generationCreatedAt
        self.updatedAt = updatedAt

        if self.collection.forms.isEmpty {
            self.collection.forms.append(CompanionFormRecord(
                formID: Self.formID(
                    speciesID: speciesID,
                    stage: .egg,
                    rarity: .normal),
                stage: .egg,
                rarity: .normal,
                unlockKind: .encountered,
                firstUnlockedAt: generationCreatedAt,
                lastEncounteredAt: generationCreatedAt,
                encounterCount: 1))
        }
    }

    public static func formID(
        speciesID: String,
        stage: CompanionGameStage,
        rarity: CompanionRarity) -> String
    {
        "\(speciesID).\(stage.rawValue).\(rarity.rawValue)"
    }
}

public enum CompanionGameEvent: Hashable, Sendable {
    case energyApplied(Int)
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
    case insufficientRandomValues
    case adultRequired
}
