import Foundation

public struct CompanionMigrationID:
    RawRepresentable,
    Codable,
    Hashable,
    Sendable
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let companionRedesignV2 = Self(
        rawValue: "companion-redesign-v2")
}

public struct CompanionCosmeticRefund: Codable, Hashable, Sendable {
    public let cosmeticID: CompanionCosmeticID
    public let starShards: Int

    public init(cosmeticID: CompanionCosmeticID, starShards: Int) {
        self.cosmeticID = cosmeticID
        self.starShards = max(starShards, 0)
    }
}

public struct CompanionAssetResetQuote: Codable, Hashable, Sendable {
    public let migrationID: CompanionMigrationID
    public let currentStage: CompanionGameStage
    public let currentPetEnergyRefund: Int
    public let completedPetCount: Int
    public let completedPetEnergyRefund: Int
    public let cosmeticRefunds: [CompanionCosmeticRefund]
    public let existingGrowthEnergy: Int
    public let existingMigrationEnergyReserve: Int
    public let existingStarShards: Int

    public init(
        migrationID: CompanionMigrationID,
        currentStage: CompanionGameStage,
        currentPetEnergyRefund: Int,
        completedPetCount: Int,
        completedPetEnergyRefund: Int,
        cosmeticRefunds: [CompanionCosmeticRefund],
        existingGrowthEnergy: Int,
        existingMigrationEnergyReserve: Int,
        existingStarShards: Int)
    {
        self.migrationID = migrationID
        self.currentStage = currentStage
        self.currentPetEnergyRefund = max(currentPetEnergyRefund, 0)
        self.completedPetCount = max(completedPetCount, 0)
        self.completedPetEnergyRefund = max(completedPetEnergyRefund, 0)
        self.cosmeticRefunds = cosmeticRefunds
        self.existingGrowthEnergy = max(existingGrowthEnergy, 0)
        self.existingMigrationEnergyReserve = max(
            existingMigrationEnergyReserve,
            0)
        self.existingStarShards = max(existingStarShards, 0)
    }

    public var petEnergyRefund: Int {
        Self.saturatedAdd(
            self.currentPetEnergyRefund,
            self.completedPetEnergyRefund)
    }

    public var cosmeticStarShardRefund: Int {
        self.cosmeticRefunds.reduce(0) {
            Self.saturatedAdd($0, $1.starShards)
        }
    }

    public var resultingGrowthEnergy: Int {
        Self.saturatedAdd(
            Self.saturatedAdd(
                self.existingGrowthEnergy,
                self.existingMigrationEnergyReserve),
            self.petEnergyRefund)
    }

    public var resultingStarShards: Int {
        Self.saturatedAdd(
            self.existingStarShards,
            self.cosmeticStarShardRefund)
    }

    public var requiresConfirmation: Bool {
        self.currentStage != .egg
            || self.completedPetCount > 0
            || !self.cosmeticRefunds.isEmpty
    }

    private static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : sum
    }
}

public enum CompanionMigrationStatus: String, Codable, Hashable, Sendable {
    case prepared
    case completed
}

public struct CompanionAssetResetJournal: Codable, Hashable, Sendable {
    public let migrationID: CompanionMigrationID
    public var status: CompanionMigrationStatus
    public let quote: CompanionAssetResetQuote
    public let sourceCompanionState: CompanionGameState
    public let sourceRewardState: CompanionRewardState
    public let sourceBenefitState: CompanionBenefitState
    public let targetCompanionState: CompanionGameState
    public let targetRewardState: CompanionRewardState
    public let targetBenefitState: CompanionBenefitState
    public let preparedAt: Date
    public var completedAt: Date?

    public init(
        migrationID: CompanionMigrationID,
        status: CompanionMigrationStatus = .prepared,
        quote: CompanionAssetResetQuote,
        sourceCompanionState: CompanionGameState,
        sourceRewardState: CompanionRewardState,
        sourceBenefitState: CompanionBenefitState,
        targetCompanionState: CompanionGameState,
        targetRewardState: CompanionRewardState,
        targetBenefitState: CompanionBenefitState,
        preparedAt: Date,
        completedAt: Date? = nil)
    {
        self.migrationID = migrationID
        self.status = status
        self.quote = quote
        self.sourceCompanionState = sourceCompanionState
        self.sourceRewardState = sourceRewardState
        self.sourceBenefitState = sourceBenefitState
        self.targetCompanionState = targetCompanionState
        self.targetRewardState = targetRewardState
        self.targetBenefitState = targetBenefitState
        self.preparedAt = preparedAt
        self.completedAt = completedAt
    }
}

public struct CompanionAssetResetEngine: Sendable {
    public let migrationID: CompanionMigrationID
    public let cosmetics: [CompanionCosmetic]

    public init(
        migrationID: CompanionMigrationID = .companionRedesignV2,
        cosmetics: [CompanionCosmetic] = CompanionRewardEngine().cosmetics)
    {
        self.migrationID = migrationID
        self.cosmetics = cosmetics
    }

    public func quote(
        companion: CompanionGameState,
        rewards: CompanionRewardState) -> CompanionAssetResetQuote
    {
        let prices = Dictionary(
            uniqueKeysWithValues: self.cosmetics.map { ($0.id, $0.cost) })
        let cosmeticRefunds = rewards.unlockedCosmeticIDs
            .map {
                CompanionCosmeticRefund(
                    cosmeticID: $0,
                    starShards: prices[$0, default: 0])
            }
            .sorted { $0.cosmeticID.rawValue < $1.cosmeticID.rawValue }
        let completedCount = companion.collection.totalCompletedGenerations
        return CompanionAssetResetQuote(
            migrationID: self.migrationID,
            currentStage: companion.stage,
            currentPetEnergyRefund: self.energyRefund(for: companion.stage),
            completedPetCount: completedCount,
            completedPetEnergyRefund: Self.saturatedMultiply(
                completedCount,
                2_700),
            cosmeticRefunds: cosmeticRefunds,
            existingGrowthEnergy: companion.growthEnergy,
            existingMigrationEnergyReserve: companion.migrationEnergyReserve,
            existingStarShards: rewards.starShards)
    }

    public func prepare(
        companion: CompanionGameState,
        rewards: CompanionRewardState,
        benefits: CompanionBenefitState,
        at now: Date = .now) -> CompanionAssetResetJournal
    {
        let quote = self.quote(companion: companion, rewards: rewards)
        return CompanionAssetResetJournal(
            migrationID: self.migrationID,
            quote: quote,
            sourceCompanionState: companion,
            sourceRewardState: rewards,
            sourceBenefitState: benefits,
            targetCompanionState: self.reset(
                companion,
                refund: quote.petEnergyRefund,
                at: now),
            targetRewardState: self.reset(
                rewards,
                refund: quote.cosmeticStarShardRefund,
                at: now),
            targetBenefitState: CompanionBenefitState(),
            preparedAt: now)
    }

    private func energyRefund(for stage: CompanionGameStage) -> Int {
        switch stage {
        case .egg: 0
        case .hatchling: 500
        case .junior: 1_300
        case .adult: 2_700
        }
    }

    private func reset(
        _ state: CompanionGameState,
        refund: Int,
        at now: Date) -> CompanionGameState
    {
        CompanionGameState(
            growthEnergy: state.growthEnergy,
            migrationEnergyReserve: Self.saturatedAdd(
                state.migrationEnergyReserve,
                refund),
            growthDateKey: state.growthDateKey,
            growthEarnedToday: state.growthEarnedToday,
            delayedGrowthEarnedToday: state.delayedGrowthEarnedToday,
            growthCarriedToday: state.growthCarriedToday,
            growthSpentToday: state.growthSpentToday,
            appliedGrowthAwardIDs: state.appliedGrowthAwardIDs,
            lastActiveAt: state.lastActiveAt,
            generationCreatedAt: now,
            updatedAt: now)
    }

    private func reset(
        _ state: CompanionRewardState,
        refund: Int,
        at now: Date) -> CompanionRewardState
    {
        CompanionRewardState(
            starShards: Self.saturatedAdd(state.starShards, refund),
            attendanceRecords: state.attendanceRecords,
            awardedMilestoneIDs: state.awardedMilestoneIDs,
            rewardedGrowthDateKeys: state.rewardedGrowthDateKeys,
            latestRewardedAppVersion: state.latestRewardedAppVersion,
            latestObservedDateKey: state.latestObservedDateKey,
            updatedAt: now)
    }

    private static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : sum
    }

    private static func saturatedMultiply(_ lhs: Int, _ rhs: Int) -> Int {
        let (product, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        return overflow ? Int.max : product
    }
}

public actor CompanionAssetResetStore {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "companion-migrations.json")
    }

    public func load() throws -> CompanionAssetResetJournal? {
        try RecoverableFileStorage.load(
            from: self.fileURL,
            decode: Self.decode)
    }

    public func save(_ journal: CompanionAssetResetJournal) throws {
        try FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try RecoverableFileStorage.write(
            encoder.encode(journal),
            to: self.fileURL)
    }

    private static func decode(_ data: Data) throws -> CompanionAssetResetJournal {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CompanionAssetResetJournal.self, from: data)
    }
}
