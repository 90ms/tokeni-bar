import Foundation

public enum CompanionCosmeticID: String, Codable, CaseIterable, Hashable, Sendable {
    case sparkleAura
    case starCrown
    case nightRing
    case pixelHearts
    case developerHeadphones
    case wizardHat
    case terminalNight
    case cloudGarden

    public var slot: CompanionCosmeticSlot {
        switch self {
        case .sparkleAura, .nightRing, .pixelHearts:
            .aura
        case .starCrown, .developerHeadphones, .wizardHat:
            .head
        case .terminalNight, .cloudGarden:
            .background
        }
    }
}

public enum CompanionCosmeticSlot: String, Codable, CaseIterable, Hashable, Sendable {
    case head
    case aura
    case background
}

public struct CompanionCosmetic: Identifiable, Hashable, Sendable {
    public let id: CompanionCosmeticID
    public let cost: Int

    public init(id: CompanionCosmeticID, cost: Int) {
        self.id = id
        self.cost = max(cost, 0)
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
    public static let currentSchemaVersion = 4

    public var schemaVersion: Int
    public var starShards: Int
    public var attendanceRecords: [CompanionAttendanceRecord]
    public var awardedMilestoneIDs: Set<String>
    public var rewardedSpeciesIDs: Set<CompanionSpeciesID>
    public var rewardedJourneyCount: Int
    public var rewardedFormMilestones: Set<Int>
    public var rewardedRarities: Set<CompanionRarity>
    public var rewardedGrowthDateKeys: [String]
    public var latestRewardedAppVersion: String?
    public var latestObservedDateKey: String?
    public var unlockedCosmeticIDs: Set<CompanionCosmeticID>
    public var selectedCosmeticIDs: Set<CompanionCosmeticID>
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
        rewardedGrowthDateKeys: [String] = [],
        latestRewardedAppVersion: String? = nil,
        latestObservedDateKey: String? = nil,
        unlockedCosmeticIDs: Set<CompanionCosmeticID> = [],
        selectedCosmeticIDs: Set<CompanionCosmeticID> = [],
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
        self.rewardedGrowthDateKeys = Array(rewardedGrowthDateKeys.suffix(400))
        self.latestRewardedAppVersion = latestRewardedAppVersion
        self.latestObservedDateKey = latestObservedDateKey
        self.unlockedCosmeticIDs = unlockedCosmeticIDs
        self.selectedCosmeticIDs = selectedCosmeticIDs
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
        case rewardedGrowthDateKeys
        case latestRewardedAppVersion
        case latestObservedDateKey
        case unlockedCosmeticIDs
        case selectedCosmeticIDs
        case selectedCosmeticID
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
            rewardedRarities: try container.decodeIfPresent(
                Set<CompanionRarity>.self,
                forKey: .rewardedRarities) ?? [],
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
            updatedAt: try container.decodeIfPresent(
                Date.self,
                forKey: .updatedAt) ?? .now)
    }
}

public enum CompanionRewardReason: Hashable, Sendable {
    case dailyAttendance
    case weeklyAttendance(days: Int)
    case monthlyAttendance(days: Int)
    case speciesDiscovered(CompanionSpeciesID)
    case rarityDiscovered(CompanionRarity)
    case journeysCompleted(Int)
    case collectionForms(Int)
    case verifiedGrowth(dateKey: String)
    case releaseGift(version: String)
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
}
