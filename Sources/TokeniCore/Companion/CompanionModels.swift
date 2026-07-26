import Foundation

public enum CompanionStage: String, Codable, CaseIterable, Hashable, Sendable {
    case egg
    case hatchling
    case baby
    case adult
}

public enum CompanionBehavior: String, Codable, CaseIterable, Hashable, Sendable {
    case idle
    case working
    case warning
    case celebrate
    case sleep
}

public struct CompanionGrowthRules: Hashable, Sendable {
    public static let standard = CompanionGrowthRules(
        dailyXPCap: 90,
        hatchXP: 15,
        babyXP: 120,
        adultXP: 360)

    public let dailyXPCap: Int
    public let hatchXP: Int
    public let babyXP: Int
    public let adultXP: Int

    public init(dailyXPCap: Int, hatchXP: Int, babyXP: Int, adultXP: Int) {
        let normalizedHatchXP = max(hatchXP, 0)
        let normalizedBabyXP = max(babyXP, normalizedHatchXP)
        self.dailyXPCap = max(dailyXPCap, 0)
        self.hatchXP = normalizedHatchXP
        self.babyXP = normalizedBabyXP
        self.adultXP = max(adultXP, normalizedBabyXP)
    }

    public func stage(for totalXP: Int) -> CompanionStage {
        switch max(totalXP, 0) {
        case self.adultXP...:
            .adult
        case self.babyXP...:
            .baby
        case self.hatchXP...:
            .hatchling
        default:
            .egg
        }
    }

    public func nextStageXP(after stage: CompanionStage) -> Int? {
        switch stage {
        case .egg: self.hatchXP
        case .hatchling: self.babyXP
        case .baby: self.adultXP
        case .adult: nil
        }
    }
}

public struct CompanionState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var companionID: String
    public var totalXP: Int
    public var dailyXP: Int
    public var dailyXPDate: String?
    public var lastAwardedMinute: Date?
    public var lastActiveAt: Date?
    public var lastPattedAt: Date?
    public var celebrationUntil: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = CompanionState.currentSchemaVersion,
        companionID: String = "bytebot",
        totalXP: Int = 0,
        dailyXP: Int = 0,
        dailyXPDate: String? = nil,
        lastAwardedMinute: Date? = nil,
        lastActiveAt: Date? = nil,
        lastPattedAt: Date? = nil,
        celebrationUntil: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now)
    {
        self.schemaVersion = schemaVersion
        self.companionID = companionID
        self.totalXP = max(totalXP, 0)
        self.dailyXP = max(dailyXP, 0)
        self.dailyXPDate = dailyXPDate
        self.lastAwardedMinute = lastAwardedMinute
        self.lastActiveAt = lastActiveAt
        self.lastPattedAt = lastPattedAt
        self.celebrationUntil = celebrationUntil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum CompanionGrowthEvent: Hashable, Sendable {
    case none
    case xpAwarded(totalXP: Int, dailyXP: Int)
    case stageChanged(from: CompanionStage, to: CompanionStage)
}
