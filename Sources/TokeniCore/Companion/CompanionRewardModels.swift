import Foundation

public enum CompanionCosmeticID: String, Codable, CaseIterable, Hashable, Sendable {
    case sparkleAura
    case nightRing
    case pixelHearts
    case fireflyAura
    case orbitAura
    case terminalNight
    case cloudGarden
    case sunsetGrid
    case pixelForest
    case azurePalette
    case violetPalette
    case cloudCushion
    case hologramPlatform
    case meadowPatch
    case constellationFrame
    case pixelPortalFrame
    case driftingClouds
    case hologramScanlines
    case fallingPetals
    case miniDrone
    case starSprite
    case pixelChick

    public var slot: CompanionCosmeticSlot {
        switch self {
        case .sparkleAura, .nightRing, .pixelHearts, .fireflyAura, .orbitAura:
            .aura
        case .terminalNight, .cloudGarden, .sunsetGrid, .pixelForest:
            .background
        case .azurePalette, .violetPalette:
            .palette
        case .cloudCushion, .hologramPlatform, .meadowPatch:
            .ground
        case .constellationFrame, .pixelPortalFrame:
            .frame
        case .driftingClouds, .hologramScanlines, .fallingPetals:
            .scene
        case .miniDrone, .starSprite, .pixelChick:
            .sidekick
        }
    }
}

public enum CompanionCosmeticSlot: String, Codable, CaseIterable, Hashable, Sendable {
    case aura
    case background
    case palette
    case ground
    case sidekick
    case frame
    case scene
}

public struct CompanionCosmetic: Identifiable, Hashable, Sendable {
    public let id: CompanionCosmeticID
    public let cost: Int

    public init(id: CompanionCosmeticID, cost: Int) {
        self.id = id
        self.cost = max(cost, 0)
    }
}

public enum CompanionEnergyBoosterID:
    String, Codable, CaseIterable, Hashable, Sendable
{
    case double30Minutes
    case triple20Minutes
    case quintuple10Minutes

    public var multiplier: Int {
        switch self {
        case .double30Minutes: 2
        case .triple20Minutes: 3
        case .quintuple10Minutes: 5
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .double30Minutes: 30 * 60
        case .triple20Minutes: 20 * 60
        case .quintuple10Minutes: 10 * 60
        }
    }

    public var cost: Int {
        switch self {
        case .double30Minutes: 80
        case .triple20Minutes: 150
        case .quintuple10Minutes: 280
        }
    }
}

public struct CompanionActiveEnergyBooster: Codable, Hashable, Sendable {
    public let id: CompanionEnergyBoosterID
    public let activatedAt: Date
    public let expiresAt: Date

    public init(id: CompanionEnergyBoosterID, activatedAt: Date) {
        self.id = id
        self.activatedAt = activatedAt
        self.expiresAt = activatedAt.addingTimeInterval(id.duration)
    }

    public init(
        id: CompanionEnergyBoosterID,
        activatedAt: Date,
        expiresAt: Date)
    {
        self.id = id
        self.activatedAt = activatedAt
        self.expiresAt = max(expiresAt, activatedAt)
    }

    public func isActive(at date: Date) -> Bool {
        date >= self.activatedAt && date < self.expiresAt
    }
}

public struct CompanionAttendanceRecord: Codable, Hashable, Sendable {
    public let dateKey: String
    public let weekKey: String
    public let monthKey: String
    public let claimedAt: Date

    public init(
        dateKey: String,
        weekKey: String,
        monthKey: String,
        claimedAt: Date)
    {
        self.dateKey = dateKey
        self.weekKey = weekKey
        self.monthKey = monthKey
        self.claimedAt = claimedAt
    }
}

public struct CompanionRewardState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 10

    public var schemaVersion: Int
    public var starShards: Int
    public var attendanceRecords: [CompanionAttendanceRecord]
    public var awardedMilestoneIDs: Set<String>
    public var rewardedSpeciesIDs: Set<CompanionSpeciesID>
    public var rewardedMutationKeys: Set<String>
    public var rewardedJourneyCount: Int
    public var rewardedFormMilestones: Set<Int>
    public var rewardedRarities: Set<CompanionRarity>
    public var rewardedVariantIDs: Set<CompanionVariantID>
    public var rewardedGrowthDateKeys: [String]
    public var latestRewardedAppVersion: String?
    public var latestObservedDateKey: String?
    public var unlockedCosmeticIDs: Set<CompanionCosmeticID>
    public var selectedCosmeticIDs: Set<CompanionCosmeticID>
    public var energyBoosterInventory: [CompanionEnergyBoosterID: Int]
    public var activeEnergyBooster: CompanionActiveEnergyBooster?
    public var rewardedBondMilestoneIDs: Set<String>
    public var processedEggTransactionIDs: [UUID]
    public var maxLevelConversionRemainders: [UUID: Int64]
    public var processedMaxLevelGrowthAwardIDs: [UUID]
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        starShards: Int = 0,
        attendanceRecords: [CompanionAttendanceRecord] = [],
        awardedMilestoneIDs: Set<String> = [],
        rewardedSpeciesIDs: Set<CompanionSpeciesID> = [],
        rewardedMutationKeys: Set<String> = [],
        rewardedJourneyCount: Int = 0,
        rewardedFormMilestones: Set<Int> = [],
        rewardedRarities: Set<CompanionRarity> = [],
        rewardedVariantIDs: Set<CompanionVariantID> = [],
        rewardedGrowthDateKeys: [String] = [],
        latestRewardedAppVersion: String? = nil,
        latestObservedDateKey: String? = nil,
        unlockedCosmeticIDs: Set<CompanionCosmeticID> = [],
        selectedCosmeticIDs: Set<CompanionCosmeticID> = [],
        energyBoosterInventory: [CompanionEnergyBoosterID: Int] = [:],
        activeEnergyBooster: CompanionActiveEnergyBooster? = nil,
        rewardedBondMilestoneIDs: Set<String> = [],
        processedEggTransactionIDs: [UUID] = [],
        maxLevelConversionRemainders: [UUID: Int64] = [:],
        processedMaxLevelGrowthAwardIDs: [UUID] = [],
        updatedAt: Date = .now)
    {
        let removedCosmetics: Set<CompanionCosmeticID> = [.nightRing]
        let migratedUnlockedCosmeticIDs = Self.migrateLegacyCosmetics(
            unlockedCosmeticIDs)
        let migratedSelectedCosmeticIDs = Self.migrateLegacyCosmetics(
            selectedCosmeticIDs)
        self.schemaVersion = schemaVersion
        self.starShards = max(starShards, 0)
        self.attendanceRecords = Array(attendanceRecords.suffix(400))
        self.awardedMilestoneIDs = awardedMilestoneIDs
        self.rewardedSpeciesIDs = rewardedSpeciesIDs
        self.rewardedMutationKeys = rewardedMutationKeys
        self.rewardedJourneyCount = max(rewardedJourneyCount, 0)
        self.rewardedFormMilestones = rewardedFormMilestones
        self.rewardedRarities = rewardedRarities
        self.rewardedVariantIDs = rewardedVariantIDs
        self.rewardedGrowthDateKeys = Array(rewardedGrowthDateKeys.suffix(400))
        self.latestRewardedAppVersion = latestRewardedAppVersion
        self.latestObservedDateKey = latestObservedDateKey
        self.unlockedCosmeticIDs = migratedUnlockedCosmeticIDs
            .subtracting(removedCosmetics)
        self.selectedCosmeticIDs = migratedSelectedCosmeticIDs
            .subtracting(removedCosmetics)
        self.energyBoosterInventory = energyBoosterInventory.mapValues {
            max($0, 0)
        }
        self.activeEnergyBooster = activeEnergyBooster
        self.rewardedBondMilestoneIDs = rewardedBondMilestoneIDs
        self.processedEggTransactionIDs = Array(
            processedEggTransactionIDs.suffix(512))
        self.maxLevelConversionRemainders =
            maxLevelConversionRemainders.mapValues { max($0, 0) }
        self.processedMaxLevelGrowthAwardIDs = Array(
            processedMaxLevelGrowthAwardIDs.suffix(512))
        self.updatedAt = updatedAt
    }

    private static func migrateLegacyCosmetics(
        _ cosmeticIDs: Set<CompanionCosmeticID>) -> Set<CompanionCosmeticID>
    {
        let replacements: [CompanionCosmeticID: CompanionCosmeticID] = [
            .azurePalette: .constellationFrame,
            .violetPalette: .pixelPortalFrame,
            .cloudCushion: .driftingClouds,
            .hologramPlatform: .hologramScanlines,
            .meadowPatch: .fallingPetals,
        ]
        return Set(cosmeticIDs.map { replacements[$0] ?? $0 })
    }

    public func isValid() -> Bool {
        let dateKeys = self.attendanceRecords.map(\.dateKey)
        if let latestRecordDateKey = dateKeys.max(),
           self.latestObservedDateKey.map({ $0 >= latestRecordDateKey }) != true
        {
            return false
        }
        return self.schemaVersion == Self.currentSchemaVersion
            && self.starShards >= 0
            && Set(dateKeys).count == dateKeys.count
            && self.attendanceRecords.allSatisfy {
                !$0.dateKey.isEmpty && !$0.weekKey.isEmpty && !$0.monthKey.isEmpty
            }
            && self.rewardedMutationKeys.allSatisfy { !$0.isEmpty }
            && self.rewardedJourneyCount >= 0
            && self.rewardedFormMilestones.allSatisfy { $0 > 0 }
            && Set(self.rewardedGrowthDateKeys).count
                == self.rewardedGrowthDateKeys.count
            && self.rewardedGrowthDateKeys.allSatisfy { !$0.isEmpty }
            && self.latestRewardedAppVersion.map {
                SemanticVersion($0) != nil
            } != false
            && Set(self.selectedCosmeticIDs.map(\.slot)).count
                == self.selectedCosmeticIDs.count
            && self.selectedCosmeticIDs.isSubset(of: self.unlockedCosmeticIDs)
            && self.energyBoosterInventory.values.allSatisfy { $0 >= 0 }
            && Set(self.processedEggTransactionIDs).count
                == self.processedEggTransactionIDs.count
            && self.maxLevelConversionRemainders.values.allSatisfy {
                $0 >= 0 && $0 < CompanionRewardEngine.maxLevelTokenCost
            }
            && Set(self.processedMaxLevelGrowthAwardIDs).count
                == self.processedMaxLevelGrowthAwardIDs.count
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case starShards
        case attendanceRecords
        case awardedMilestoneIDs
        case rewardedSpeciesIDs
        case rewardedMutationKeys
        case rewardedJourneyCount
        case rewardedFormMilestones
        case rewardedRarities
        case rewardedVariantIDs
        case rewardedGrowthDateKeys
        case latestRewardedAppVersion
        case latestObservedDateKey
        case unlockedCosmeticIDs
        case selectedCosmeticIDs
        case selectedCosmeticID
        case energyBoosterInventory
        case activeEnergyBooster
        case rewardedBondMilestoneIDs
        case processedEggTransactionIDs
        case maxLevelConversionRemainders
        case maxLevelGrowthRemainders
        case processedMaxLevelGrowthAwardIDs
        case updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .schemaVersion) ?? 1
        guard decodedVersion <= Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported companion reward schema")
        }
        let unlockedCosmeticIDs = try container.decodeIfPresent(
            Set<CompanionCosmeticID>.self,
            forKey: .unlockedCosmeticIDs) ?? []
        let selectedCosmeticIDs: Set<CompanionCosmeticID>
        if let current = try container.decodeIfPresent(
            Set<CompanionCosmeticID>.self,
            forKey: .selectedCosmeticIDs)
        {
            selectedCosmeticIDs = current
        } else if let legacy = try container.decodeIfPresent(
            CompanionCosmeticID.self,
            forKey: .selectedCosmeticID)
        {
            selectedCosmeticIDs = [legacy]
        } else {
            selectedCosmeticIDs = []
        }
        let rewardedRarities = try container.decodeIfPresent(
            Set<CompanionRarity>.self,
            forKey: .rewardedRarities) ?? []
        var rewardedVariantIDs = try container.decodeIfPresent(
            Set<CompanionVariantID>.self,
            forKey: .rewardedVariantIDs) ?? []
        if rewardedRarities.contains(.legendary) {
            rewardedVariantIDs.insert(.prismatic)
        }
        let decodedStarShards = try container.decodeIfPresent(
            Int.self,
            forKey: .starShards) ?? 0
        let migratedMaxLevelState: (
            starShards: Int,
            remainders: [UUID: Int64])
        if decodedVersion >= 9 {
            migratedMaxLevelState = (
                decodedStarShards,
                try container.decodeIfPresent(
                    [UUID: Int64].self,
                    forKey: .maxLevelConversionRemainders) ?? [:])
        } else {
            migratedMaxLevelState = Self.migrateLegacyMaxLevelGrowth(
                try container.decodeIfPresent(
                    [UUID: Int].self,
                    forKey: .maxLevelGrowthRemainders) ?? [:],
                starShards: decodedStarShards)
        }
        self.init(
            starShards: migratedMaxLevelState.starShards,
            attendanceRecords: try container.decodeIfPresent(
                [CompanionAttendanceRecord].self,
                forKey: .attendanceRecords) ?? [],
            awardedMilestoneIDs: try container.decodeIfPresent(
                Set<String>.self,
                forKey: .awardedMilestoneIDs) ?? [],
            rewardedSpeciesIDs: try container.decodeIfPresent(
                Set<CompanionSpeciesID>.self,
                forKey: .rewardedSpeciesIDs) ?? [],
            rewardedMutationKeys: try container.decodeIfPresent(
                Set<String>.self,
                forKey: .rewardedMutationKeys) ?? [],
            rewardedJourneyCount: try container.decodeIfPresent(
                Int.self,
                forKey: .rewardedJourneyCount) ?? 0,
            rewardedFormMilestones: try container.decodeIfPresent(
                Set<Int>.self,
                forKey: .rewardedFormMilestones) ?? [],
            rewardedRarities: rewardedRarities,
            rewardedVariantIDs: rewardedVariantIDs,
            rewardedGrowthDateKeys: try container.decodeIfPresent(
                [String].self,
                forKey: .rewardedGrowthDateKeys) ?? [],
            latestRewardedAppVersion: try container.decodeIfPresent(
                String.self,
                forKey: .latestRewardedAppVersion),
            latestObservedDateKey: try container.decodeIfPresent(
                String.self,
                forKey: .latestObservedDateKey),
            unlockedCosmeticIDs: unlockedCosmeticIDs,
            selectedCosmeticIDs: selectedCosmeticIDs,
            energyBoosterInventory: try container.decodeIfPresent(
                [CompanionEnergyBoosterID: Int].self,
                forKey: .energyBoosterInventory) ?? [:],
            activeEnergyBooster: try container.decodeIfPresent(
                CompanionActiveEnergyBooster.self,
                forKey: .activeEnergyBooster),
            rewardedBondMilestoneIDs: try container.decodeIfPresent(
                Set<String>.self,
                forKey: .rewardedBondMilestoneIDs) ?? [],
            processedEggTransactionIDs: try container.decodeIfPresent(
                [UUID].self,
                forKey: .processedEggTransactionIDs) ?? [],
            maxLevelConversionRemainders: migratedMaxLevelState.remainders,
            processedMaxLevelGrowthAwardIDs: try container.decodeIfPresent(
                [UUID].self,
                forKey: .processedMaxLevelGrowthAwardIDs) ?? [],
            updatedAt: try container.decodeIfPresent(
                Date.self,
                forKey: .updatedAt) ?? .now)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(self.starShards, forKey: .starShards)
        try container.encode(self.attendanceRecords, forKey: .attendanceRecords)
        try container.encode(
            self.awardedMilestoneIDs,
            forKey: .awardedMilestoneIDs)
        try container.encode(
            self.rewardedSpeciesIDs,
            forKey: .rewardedSpeciesIDs)
        try container.encode(
            self.rewardedMutationKeys,
            forKey: .rewardedMutationKeys)
        try container.encode(
            self.rewardedJourneyCount,
            forKey: .rewardedJourneyCount)
        try container.encode(
            self.rewardedFormMilestones,
            forKey: .rewardedFormMilestones)
        try container.encode(
            self.rewardedRarities,
            forKey: .rewardedRarities)
        try container.encode(
            self.rewardedVariantIDs,
            forKey: .rewardedVariantIDs)
        try container.encode(
            self.rewardedGrowthDateKeys,
            forKey: .rewardedGrowthDateKeys)
        try container.encodeIfPresent(
            self.latestRewardedAppVersion,
            forKey: .latestRewardedAppVersion)
        try container.encodeIfPresent(
            self.latestObservedDateKey,
            forKey: .latestObservedDateKey)
        try container.encode(
            self.unlockedCosmeticIDs,
            forKey: .unlockedCosmeticIDs)
        try container.encode(
            self.selectedCosmeticIDs,
            forKey: .selectedCosmeticIDs)
        try container.encode(
            self.energyBoosterInventory,
            forKey: .energyBoosterInventory)
        try container.encodeIfPresent(
            self.activeEnergyBooster,
            forKey: .activeEnergyBooster)
        try container.encode(
            self.rewardedBondMilestoneIDs,
            forKey: .rewardedBondMilestoneIDs)
        try container.encode(
            self.processedEggTransactionIDs,
            forKey: .processedEggTransactionIDs)
        try container.encode(
            self.maxLevelConversionRemainders,
            forKey: .maxLevelConversionRemainders)
        try container.encode(
            self.processedMaxLevelGrowthAwardIDs,
            forKey: .processedMaxLevelGrowthAwardIDs)
        try container.encode(self.updatedAt, forKey: .updatedAt)
    }

    private static func migrateLegacyMaxLevelGrowth(
        _ legacyRemainders: [UUID: Int],
        starShards: Int) -> (starShards: Int, remainders: [UUID: Int64])
    {
        var migratedStarShards = max(starShards, 0)
        var migratedRemainders: [UUID: Int64] = [:]
        for (generationID, legacyEnergy) in legacyRemainders {
            let (tokenProduct, tokenOverflow) = Int64(max(legacyEnergy, 0))
                .multipliedReportingOverflow(
                    by: TokenGrowthEnergyFormula.standard.tokensPerEnergy)
            let tokens = tokenOverflow ? Int64.max : tokenProduct
            let cycles = tokens / CompanionRewardEngine.maxLevelTokenCost
            let (shardProduct, shardOverflow) = cycles
                .multipliedReportingOverflow(by: Int64(
                    CompanionRewardEngine.maxLevelTokenShardReward))
            let shardValue = shardOverflow ? Int64.max : shardProduct
            let shards = shardValue >= Int64(Int.max)
                ? Int.max
                : Int(shardValue)
            let (sum, overflow) = migratedStarShards.addingReportingOverflow(
                shards)
            migratedStarShards = overflow ? Int.max : sum
            let remainder = tokens % CompanionRewardEngine.maxLevelTokenCost
            if remainder > 0 {
                migratedRemainders[generationID] = remainder
            }
        }
        return (migratedStarShards, migratedRemainders)
    }
}

public enum CompanionRewardReason: Hashable, Sendable {
    case dailyAttendance
    case weeklyAttendance(days: Int)
    case monthlyAttendance(days: Int)
    case speciesDiscovered(CompanionSpeciesID)
    case mutationDiscovered(
        speciesID: CompanionSpeciesID,
        mutationID: CompanionMutationID)
    case rarityDiscovered(CompanionRarity)
    case variantDiscovered(CompanionVariantID)
    case journeysCompleted(Int)
    case collectionForms(Int)
    case collectionVariants(Int)
    case verifiedGrowth(dateKey: String)
    case releaseGift(version: String)
    case benefit(CompanionBenefitID)
}

public struct CompanionRewardGrant: Hashable, Sendable {
    public let amount: Int
    public let reason: CompanionRewardReason

    public init(amount: Int, reason: CompanionRewardReason) {
        self.amount = max(amount, 0)
        self.reason = reason
    }
}

public enum CompanionAttendanceStatus: Hashable, Sendable {
    case available
    case claimed
    case clockRollback
}

public enum CompanionRewardError: Error, Equatable, Sendable {
    case alreadyClaimed
    case clockRollback
    case unknownCosmetic
    case cosmeticAlreadyOwned
    case cosmeticNotOwned
    case insufficientStarShards
    case energyBoosterNotOwned
    case energyBoosterAlreadyActive
}
