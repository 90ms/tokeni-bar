import Foundation

public actor CompanionGameStateStore {
    private let fileURL: URL
    private var lastSavedRevision: UInt64 = 0

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "companion-state.json")
    }

    public func load() throws -> CompanionGameState {
        try RecoverableFileStorage.load(
            from: self.fileURL,
            decode: Self.decode) ?? CompanionGameState()
    }

    private static func decode(_ data: Data) throws -> CompanionGameState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state: CompanionGameState
        let version = try? decoder.decode(SchemaVersion.self, from: data).schemaVersion
        if version == 2,
           let legacy = try? decoder.decode(LegacyCompanionGameStateV2.self, from: data)
        {
            state = legacy.migrated(at: .now)
        } else if version == 3,
                  let legacy = try? decoder.decode(
                      LegacyCompanionGameStateV3.self,
                      from: data)
        {
            state = legacy.migrated()
        } else if version == 4,
                  let legacy = try? decoder.decode(
                      LegacyCompanionGameStateV4.self,
                      from: data)
        {
            state = legacy.migrated()
        } else if version == 5,
                  let legacy = try? decoder.decode(
                      LegacyCompanionGameStateV5.self,
                      from: data)
        {
            state = legacy.migrated()
        } else if version == 6,
                  let legacy = try? decoder.decode(
                      LegacyCompanionGameStateV6.self,
                      from: data)
        {
            state = legacy.migrated()
        } else if version == CompanionGameState.currentSchemaVersion,
                  let current = try? decoder.decode(
            CompanionGameState.self,
            from: data)
        {
            state = current
        } else {
            throw CompanionGameStateStoreError.invalidState
        }
        guard state.isValid() else {
            throw CompanionGameStateStoreError.invalidState
        }
        return state
    }

    public func save(
        _ state: CompanionGameState,
        revision: UInt64? = nil) throws
    {
        if let revision, revision <= self.lastSavedRevision {
            return
        }
        try FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try RecoverableFileStorage.write(
            encoder.encode(state),
            to: self.fileURL)
        if let revision {
            self.lastSavedRevision = revision
        }
    }

    public func clear() throws {
        try RecoverableFileStorage.removePrimaryAndBackups(for: self.fileURL)
    }
}

private struct LegacyCompanionGameStateV6: Decodable {
    let speciesID: CompanionSpeciesID?
    let generationID: UUID
    let generationNumber: Int
    let stage: CompanionGameStage
    let rarity: CompanionRarity?
    let variantID: CompanionVariantID?
    let growthEnergy: Int
    let growthDateKey: String
    let growthEarnedToday: Int
    let delayedGrowthEarnedToday: Int
    let growthCarriedToday: Int
    let growthSpentToday: Int
    let bondEnergy: Int
    let collection: CompanionCollection
    let consecutiveDuplicateHatches: Int
    let pity: CompanionPityState
    let variantPity: CompanionVariantPityState
    let appliedGrowthAwardIDs: [UUID]
    let lastActiveAt: Date?
    let lastPattedAt: Date?
    let celebrationUntil: Date?
    let showcasedGenerationID: UUID?
    let generationCreatedAt: Date
    let updatedAt: Date

    func migrated() -> CompanionGameState {
        CompanionGameState(
            speciesID: self.speciesID,
            generationID: self.generationID,
            generationNumber: self.generationNumber,
            stage: self.stage,
            rarity: self.rarity,
            variantID: self.variantID
                ?? self.rarity.map(CompanionVariantRegistry.migrated),
            personalityID: self.stage == .egg ? nil : .calm,
            growthEnergy: self.growthEnergy,
            growthDateKey: self.growthDateKey,
            growthEarnedToday: self.growthEarnedToday,
            delayedGrowthEarnedToday: self.delayedGrowthEarnedToday,
            growthCarriedToday: self.growthCarriedToday,
            growthSpentToday: self.growthSpentToday,
            bondEnergy: self.bondEnergy,
            collection: self.collection,
            consecutiveDuplicateHatches: self.consecutiveDuplicateHatches,
            pity: self.pity,
            variantPity: self.variantPity,
            appliedGrowthAwardIDs: self.appliedGrowthAwardIDs,
            lastActiveAt: self.lastActiveAt,
            lastPattedAt: self.lastPattedAt,
            celebrationUntil: self.celebrationUntil,
            showcasedGenerationID: self.showcasedGenerationID,
            generationCreatedAt: self.generationCreatedAt,
            updatedAt: self.updatedAt)
    }
}

private struct LegacyCompanionGameStateV5: Decodable {
    let speciesID: CompanionSpeciesID?
    let generationID: UUID
    let generationNumber: Int
    let stage: CompanionGameStage
    let rarity: CompanionRarity?
    let growthEnergy: Int
    let growthDateKey: String
    let growthEarnedToday: Int
    let delayedGrowthEarnedToday: Int
    let growthCarriedToday: Int
    let growthSpentToday: Int
    let bondEnergy: Int
    let collection: CompanionCollection
    let consecutiveDuplicateHatches: Int
    let pity: CompanionPityState
    let appliedGrowthAwardIDs: [UUID]
    let lastActiveAt: Date?
    let lastPattedAt: Date?
    let celebrationUntil: Date?
    let showcasedGenerationID: UUID?
    let generationCreatedAt: Date
    let updatedAt: Date

    func migrated() -> CompanionGameState {
        var collection = self.collection
        for index in collection.recentCompletedGenerations.indices
            where collection.recentCompletedGenerations[index].variantID == nil
        {
            collection.recentCompletedGenerations[index].variantID =
                CompanionVariantRegistry.migrated(
                    from: collection.recentCompletedGenerations[index].finalRarity)
        }
        return CompanionGameState(
            speciesID: self.speciesID,
            generationID: self.generationID,
            generationNumber: self.generationNumber,
            stage: self.stage,
            rarity: self.rarity,
            variantID: self.rarity.map(CompanionVariantRegistry.migrated),
            personalityID: self.stage == .egg ? nil : .calm,
            growthEnergy: self.growthEnergy,
            growthDateKey: self.growthDateKey,
            growthEarnedToday: self.growthEarnedToday,
            delayedGrowthEarnedToday: self.delayedGrowthEarnedToday,
            growthCarriedToday: self.growthCarriedToday,
            growthSpentToday: self.growthSpentToday,
            bondEnergy: self.bondEnergy,
            collection: collection,
            consecutiveDuplicateHatches: self.consecutiveDuplicateHatches,
            pity: self.pity,
            appliedGrowthAwardIDs: self.appliedGrowthAwardIDs,
            lastActiveAt: self.lastActiveAt,
            lastPattedAt: self.lastPattedAt,
            celebrationUntil: self.celebrationUntil,
            showcasedGenerationID: self.showcasedGenerationID,
            generationCreatedAt: self.generationCreatedAt,
            updatedAt: self.updatedAt)
    }
}

private enum CompanionGameStateStoreError: Error {
    case invalidState
}

private struct SchemaVersion: Decodable {
    let schemaVersion: Int
}

private struct LegacyCompanionGameStateV2: Decodable {
    let speciesID: String
    let generationID: UUID
    let generationNumber: Int
    let stage: CompanionGameStage
    let rarity: CompanionRarity
    let growthEnergy: Int
    let bondEnergy: Int
    let collection: CompanionCollection
    let consecutiveDuplicateHatches: Int?
    let pity: CompanionPityState
    let appliedGrowthAwardIDs: [UUID]
    let lastActiveAt: Date?
    let lastPattedAt: Date?
    let celebrationUntil: Date?
    let generationCreatedAt: Date
    let updatedAt: Date

    func migrated(at now: Date) -> CompanionGameState {
        var collection = self.collection
        collection.forms.removeAll {
            $0.stage == .egg || $0.unlockKind == .lineage
        }
        let balance = min(
            max(self.growthEnergy, 0),
            CompanionGameRules.standard.maximumEnergyBalance)
        return CompanionGameState(
            speciesID: self.stage == .egg
                ? nil
                : CompanionSpeciesID(rawValue: self.speciesID) ?? .bytebot,
            generationID: self.generationID,
            generationNumber: self.generationNumber,
            stage: self.stage,
            rarity: self.stage == .egg ? nil : self.rarity,
            variantID: self.stage == .egg
                ? nil
                : CompanionVariantRegistry.migrated(from: self.rarity),
            personalityID: self.stage == .egg ? nil : .calm,
            growthEnergy: balance,
            growthDateKey: GrowthLocalDate.key(for: now),
            growthCarriedToday: balance,
            bondEnergy: self.bondEnergy,
            collection: collection,
            consecutiveDuplicateHatches: self.consecutiveDuplicateHatches ?? 0,
            pity: self.pity,
            appliedGrowthAwardIDs: self.appliedGrowthAwardIDs,
            lastActiveAt: self.lastActiveAt,
            lastPattedAt: self.lastPattedAt,
            celebrationUntil: self.celebrationUntil,
            generationCreatedAt: self.generationCreatedAt,
            updatedAt: max(self.updatedAt, now))
    }
}

private struct LegacyCompanionGameStateV4: Decodable {
    let speciesID: CompanionSpeciesID?
    let generationID: UUID
    let generationNumber: Int
    let stage: CompanionGameStage
    let rarity: CompanionRarity?
    let growthEnergy: Int
    let growthDateKey: String
    let growthEarnedToday: Int
    let growthCarriedToday: Int
    let growthSpentToday: Int
    let bondEnergy: Int
    let collection: CompanionCollection
    let consecutiveDuplicateHatches: Int
    let pity: CompanionPityState
    let appliedGrowthAwardIDs: [UUID]
    let lastActiveAt: Date?
    let lastPattedAt: Date?
    let celebrationUntil: Date?
    let showcasedGenerationID: UUID?
    let generationCreatedAt: Date
    let updatedAt: Date

    func migrated() -> CompanionGameState {
        var collection = self.collection
        collection.forms.removeAll { $0.unlockKind == .lineage }
        return CompanionGameState(
            speciesID: self.speciesID,
            generationID: self.generationID,
            generationNumber: self.generationNumber,
            stage: self.stage,
            rarity: self.rarity,
            variantID: self.rarity.map(CompanionVariantRegistry.migrated),
            personalityID: self.stage == .egg ? nil : .calm,
            growthEnergy: self.growthEnergy,
            growthDateKey: self.growthDateKey,
            growthEarnedToday: self.growthEarnedToday,
            growthCarriedToday: self.growthCarriedToday,
            growthSpentToday: self.growthSpentToday,
            bondEnergy: self.bondEnergy,
            collection: collection,
            consecutiveDuplicateHatches: self.consecutiveDuplicateHatches,
            pity: self.pity,
            appliedGrowthAwardIDs: self.appliedGrowthAwardIDs,
            lastActiveAt: self.lastActiveAt,
            lastPattedAt: self.lastPattedAt,
            celebrationUntil: self.celebrationUntil,
            showcasedGenerationID: self.showcasedGenerationID,
            generationCreatedAt: self.generationCreatedAt,
            updatedAt: self.updatedAt)
    }
}

private struct LegacyCompanionGameStateV3: Decodable {
    let speciesID: String
    let generationID: UUID
    let generationNumber: Int
    let stage: CompanionGameStage
    let rarity: CompanionRarity?
    let growthEnergy: Int
    let growthDateKey: String
    let growthEarnedToday: Int
    let growthCarriedToday: Int
    let growthSpentToday: Int
    let bondEnergy: Int
    let collection: CompanionCollection
    let consecutiveDuplicateHatches: Int?
    let pity: CompanionPityState
    let appliedGrowthAwardIDs: [UUID]
    let lastActiveAt: Date?
    let lastPattedAt: Date?
    let celebrationUntil: Date?
    let generationCreatedAt: Date
    let updatedAt: Date

    func migrated() -> CompanionGameState {
        var collection = self.collection
        collection.forms.removeAll { $0.unlockKind == .lineage }
        return CompanionGameState(
            speciesID: self.stage == .egg
                ? nil
                : CompanionSpeciesID(rawValue: self.speciesID) ?? .bytebot,
            generationID: self.generationID,
            generationNumber: self.generationNumber,
            stage: self.stage,
            rarity: self.stage == .egg ? nil : self.rarity,
            variantID: self.stage == .egg
                ? nil
                : self.rarity.map(CompanionVariantRegistry.migrated),
            personalityID: self.stage == .egg ? nil : .calm,
            growthEnergy: self.growthEnergy,
            growthDateKey: self.growthDateKey,
            growthEarnedToday: self.growthEarnedToday,
            growthCarriedToday: self.growthCarriedToday,
            growthSpentToday: self.growthSpentToday,
            bondEnergy: self.bondEnergy,
            collection: collection,
            consecutiveDuplicateHatches: self.consecutiveDuplicateHatches ?? 0,
            pity: self.pity,
            appliedGrowthAwardIDs: self.appliedGrowthAwardIDs,
            lastActiveAt: self.lastActiveAt,
            lastPattedAt: self.lastPattedAt,
            celebrationUntil: self.celebrationUntil,
            generationCreatedAt: self.generationCreatedAt,
            updatedAt: self.updatedAt)
    }
}
