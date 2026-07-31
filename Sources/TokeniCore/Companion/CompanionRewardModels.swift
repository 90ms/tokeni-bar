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

    public var slot: CompanionCosmeticSlot {
        switch self {
        case .sparkleAura, .nightRing, .pixelHearts, .fireflyAura, .orbitAura:
            .aura
        case .terminalNight, .cloudGarden, .sunsetGrid, .pixelForest:
            .background
        case .azurePalette, .violetPalette:
            .palette
        }
    }
}

public enum CompanionCosmeticSlot: String, Codable, CaseIterable, Hashable, Sendable {
    case aura
    case background
    case palette
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
    public static let currentSchemaVersion = 6

    public var schemaVersion: Int
    public var starShards: Int
    public var attendanceRecords: [CompanionAttendanceRecord]
    public var awardedMilestoneIDs: Set<String>
    public var rewardedSpeciesIDs: Set<CompanionSpeciesID>
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
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        starShards: Int = 0,
        attendanceRecords: [CompanionAttendanceRecord] = [],
        awardedMilestoneIDs: Set<String> = [],
        rewardedSpeciesIDs: Set<CompanionSpeciesID> = [],
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
        updatedAt: Date = .now)
    {
        self.schemaVersion = schemaVersion
        self.starShards = max(starShards, 0)
        self.attendanceRecords = Array(attendanceRecords.suffix(400))
        self.awardedMilestoneIDs = awardedMilestoneIDs
        self.rewardedSpeciesIDs = rewardedSpeciesIDs
        self.rewardedJourneyCount = max(rewardedJourneyCount, 0)
        self.rewardedFormMilestones = rewardedFormMilestones
        self.rewardedRarities = rewardedRarities
        self.rewardedVariantIDs = rewardedVariantIDs
        self.rewardedGrowthDateKeys = Array(rewardedGrowthDateKeys.suffix(400))
        self.latestRewardedAppVersion = latestRewardedAppVersion
        self.latestObservedDateKey = latestObservedDateKey
        self.unlockedCosmeticIDs = unlockedCosmeticIDs
        self.selectedCosmeticIDs = selectedCosmeticIDs
        self.energyBoosterInventory = energyBoosterInventory.mapValues {
            max($0, 0)
        }
        self.activeEnergyBooster = activeEnergyBooster
        self.rewardedBondMilestoneIDs = rewardedBondMilestoneIDs
        self.updatedAt = updatedAt
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
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case starShards
        case attendanceRecords
        case awardedMilestoneIDs
        case rewardedSpeciesIDs
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
        self.init(
            starShards: try container.decodeIfPresent(
                Int.self,
                forKey: .starShards) ?? 0,
            attendanceRecords: try container.decodeIfPresent(
                [CompanionAttendanceRecord].self,
                forKey: .attendanceRecords) ?? [],
            awardedMilestoneIDs: try container.decodeIfPresent(
                Set<String>.self,
                forKey: .awardedMilestoneIDs) ?? [],
            rewardedSpeciesIDs: try container.decodeIfPresent(
                Set<CompanionSpeciesID>.self,
                forKey: .rewardedSpeciesIDs) ?? [],
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
        try container.encode(self.updatedAt, forKey: .updatedAt)
    }
}

public enum CompanionRewardReason: Hashable, Sendable {
    case dailyAttendance
    case weeklyAttendance(days: Int)
    case monthlyAttendance(days: Int)
    case speciesDiscovered(CompanionSpeciesID)
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
