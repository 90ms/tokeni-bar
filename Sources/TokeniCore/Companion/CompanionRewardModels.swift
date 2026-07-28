import Foundation

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
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var starShards: Int
    public var attendanceRecords: [CompanionAttendanceRecord]
    public var awardedMilestoneIDs: Set<String>
    public var rewardedSpeciesIDs: Set<CompanionSpeciesID>
    public var rewardedJourneyCount: Int
    public var rewardedFormMilestones: Set<Int>
    public var latestObservedDateKey: String?
    public var updatedAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        starShards: Int = 0,
        attendanceRecords: [CompanionAttendanceRecord] = [],
        awardedMilestoneIDs: Set<String> = [],
        rewardedSpeciesIDs: Set<CompanionSpeciesID> = [],
        rewardedJourneyCount: Int = 0,
        rewardedFormMilestones: Set<Int> = [],
        latestObservedDateKey: String? = nil,
        updatedAt: Date = .now)
    {
        self.schemaVersion = schemaVersion
        self.starShards = max(starShards, 0)
        self.attendanceRecords = Array(attendanceRecords.suffix(400))
        self.awardedMilestoneIDs = awardedMilestoneIDs
        self.rewardedSpeciesIDs = rewardedSpeciesIDs
        self.rewardedJourneyCount = max(rewardedJourneyCount, 0)
        self.rewardedFormMilestones = rewardedFormMilestones
        self.latestObservedDateKey = latestObservedDateKey
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
    }
}

public enum CompanionRewardReason: Hashable, Sendable {
    case dailyAttendance
    case weeklyAttendance(days: Int)
    case monthlyAttendance(days: Int)
    case speciesDiscovered(CompanionSpeciesID)
    case journeysCompleted(Int)
    case collectionForms(Int)
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
}
