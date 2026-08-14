import Foundation

public enum CompanionBenefitActivation: String, Codable, Hashable, Sendable {
    case active
    case passive
}

public enum CompanionBenefitID: String, Codable, CaseIterable, Hashable, Sendable {
    case tokenOptimization
    case starlightCache
    case stackOptimization
    case luckyCheer
    case rewardAbsorption
}

public struct CompanionBenefitDefinition: Identifiable, Hashable, Sendable {
    public let id: CompanionBenefitID
    public let speciesID: CompanionSpeciesID
    public let activation: CompanionBenefitActivation

    public init(
        id: CompanionBenefitID,
        speciesID: CompanionSpeciesID,
        activation: CompanionBenefitActivation)
    {
        self.id = id
        self.speciesID = speciesID
        self.activation = activation
    }
}

public enum CompanionBenefitRegistry {
    public static let definitions: [CompanionBenefitDefinition] = [
        CompanionBenefitDefinition(
            id: .tokenOptimization,
            speciesID: .bytebot,
            activation: .active),
        CompanionBenefitDefinition(
            id: .starlightCache,
            speciesID: .cachecat,
            activation: .active),
        CompanionBenefitDefinition(
            id: .stackOptimization,
            speciesID: .stackfox,
            activation: .passive),
        CompanionBenefitDefinition(
            id: .luckyCheer,
            speciesID: .promptpup,
            activation: .passive),
        CompanionBenefitDefinition(
            id: .rewardAbsorption,
            speciesID: .nullslime,
            activation: .passive),
        CompanionBenefitDefinition(
            id: .tokenOptimization,
            speciesID: .queryowl,
            activation: .active),
        CompanionBenefitDefinition(
            id: .rewardAbsorption,
            speciesID: .patchpanda,
            activation: .passive),
        CompanionBenefitDefinition(
            id: .luckyCheer,
            speciesID: .loophare,
            activation: .passive),
        CompanionBenefitDefinition(
            id: .starlightCache,
            speciesID: .relayray,
            activation: .active),
        CompanionBenefitDefinition(
            id: .stackOptimization,
            speciesID: .kernelcrab,
            activation: .passive),
    ]

    public static func definition(
        for speciesID: CompanionSpeciesID) -> CompanionBenefitDefinition?
    {
        Self.definitions.first { $0.speciesID == speciesID }
    }

    public static func tokenOptimization(
        for rarity: CompanionRarity) -> (requiredBaseEnergy: Int, dailyCap: Int)
    {
        switch rarity {
        case .normal: (5, 10)
        case .rare: (4, 15)
        case .epic: (3, 25)
        case .legendary: (2, 40)
        }
    }

    public static func starlightCache(
        for rarity: CompanionRarity) -> (interval: TimeInterval, dailyCap: Int)
    {
        switch rarity {
        case .normal: (12 * 60 * 60, 2)
        case .rare: (8 * 60 * 60, 3)
        case .epic: (6 * 60 * 60, 4)
        case .legendary: (4 * 60 * 60, 6)
        }
    }

    public static func stackOptimizationBasisPoints(
        for rarity: CompanionRarity) -> Int
    {
        switch rarity {
        case .normal: 300
        case .rare: 500
        case .epic: 800
        case .legendary: 1_200
        }
    }

    public static func luckyCheerBasisPoints(
        for rarity: CompanionRarity) -> Int
    {
        switch rarity {
        case .normal: 300
        case .rare: 600
        case .epic: 1_000
        case .legendary: 1_500
        }
    }

    public static func rewardAbsorptionBasisPoints(
        for rarity: CompanionRarity) -> Int
    {
        switch rarity {
        case .normal: 500
        case .rare: 800
        case .epic: 1_200
        case .legendary: 1_500
        }
    }
}

public struct CompanionBenefitCompanion: Hashable, Sendable {
    public let generationID: UUID
    public let speciesID: CompanionSpeciesID
    public let rarity: CompanionRarity

    public init(
        generationID: UUID,
        speciesID: CompanionSpeciesID,
        rarity: CompanionRarity)
    {
        self.generationID = generationID
        self.speciesID = speciesID
        self.rarity = rarity
    }
}

public struct CompanionBenefitProgress: Codable, Hashable, Sendable {
    public let generationID: UUID
    public var baseEnergyRemainder: Int
    public var activeSeconds: TimeInterval

    public init(
        generationID: UUID,
        baseEnergyRemainder: Int = 0,
        activeSeconds: TimeInterval = 0)
    {
        self.generationID = generationID
        self.baseEnergyRemainder = max(baseEnergyRemainder, 0)
        self.activeSeconds = max(activeSeconds, 0)
    }
}

public struct CompanionPendingEnergyBonus: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let sourceAwardID: UUID
    public let amount: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceAwardID: UUID,
        amount: Int,
        createdAt: Date)
    {
        self.id = id
        self.sourceAwardID = sourceAwardID
        self.amount = max(amount, 0)
        self.createdAt = createdAt
    }
}

public struct CompanionBenefitState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var unlockedPassiveSlotCount: Int
    public var passiveGenerationIDs: [UUID?]
    public var progress: [CompanionBenefitProgress]
    public var processedGrowthAwardIDs: [UUID]
    public var pendingEnergyBonuses: [CompanionPendingEnergyBonus]
    public var dailyDateKey: String
    public var tokenOptimizationGrantedToday: Int
    public var starlightCacheGrantedToday: Int
    public var rewardBonusRemainderBasisPoints: Int
    public var activeGenerationID: UUID?
    public var lastTimeEvaluationAt: Date?
    public var latestObservedAt: Date?
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        unlockedPassiveSlotCount: Int = 1,
        passiveGenerationIDs: [UUID?] = [],
        progress: [CompanionBenefitProgress] = [],
        processedGrowthAwardIDs: [UUID] = [],
        pendingEnergyBonuses: [CompanionPendingEnergyBonus] = [],
        dailyDateKey: String? = nil,
        tokenOptimizationGrantedToday: Int = 0,
        starlightCacheGrantedToday: Int = 0,
        rewardBonusRemainderBasisPoints: Int = 0,
        activeGenerationID: UUID? = nil,
        lastTimeEvaluationAt: Date? = nil,
        latestObservedAt: Date? = nil,
        updatedAt: Date = .now)
    {
        self.schemaVersion = schemaVersion
        self.unlockedPassiveSlotCount = min(max(unlockedPassiveSlotCount, 1), 5)
        self.passiveGenerationIDs = Array(passiveGenerationIDs.prefix(5))
        self.progress = progress
        self.processedGrowthAwardIDs = Array(processedGrowthAwardIDs.suffix(512))
        self.pendingEnergyBonuses = pendingEnergyBonuses
        self.dailyDateKey = dailyDateKey ?? GrowthLocalDate.key(for: updatedAt)
        self.tokenOptimizationGrantedToday = max(
            tokenOptimizationGrantedToday,
            0)
        self.starlightCacheGrantedToday = max(starlightCacheGrantedToday, 0)
        self.rewardBonusRemainderBasisPoints = min(
            max(rewardBonusRemainderBasisPoints, 0),
            9_999)
        self.activeGenerationID = activeGenerationID
        self.lastTimeEvaluationAt = lastTimeEvaluationAt
        self.latestObservedAt = latestObservedAt
        self.updatedAt = updatedAt
    }

    public func isValid() -> Bool {
        let assigned = self.passiveGenerationIDs.compactMap { $0 }
        return self.schemaVersion == Self.currentSchemaVersion
            && (1...5).contains(self.unlockedPassiveSlotCount)
            && self.passiveGenerationIDs.count <= 5
            && Set(assigned).count == assigned.count
            && self.progress.allSatisfy {
                $0.baseEnergyRemainder >= 0 && $0.activeSeconds >= 0
            }
            && Set(self.progress.map(\.generationID)).count == self.progress.count
            && Set(self.processedGrowthAwardIDs).count
                == self.processedGrowthAwardIDs.count
            && self.pendingEnergyBonuses.allSatisfy { $0.amount > 0 }
            && self.tokenOptimizationGrantedToday >= 0
            && self.starlightCacheGrantedToday >= 0
            && (0..<10_000).contains(self.rewardBonusRemainderBasisPoints)
            && !self.dailyDateKey.isEmpty
    }
}

public enum CompanionBenefitError: Error, Equatable, Sendable {
    case slotLocked
    case archivedCompanionNotFound
    case passiveCompanionRequired
    case duplicateCompanion
    case duplicateSpecies
}
