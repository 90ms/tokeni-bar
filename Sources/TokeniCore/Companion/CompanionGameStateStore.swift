import Foundation

public actor CompanionGameStateStore {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "companion-state.json")
    }

    public func load() throws -> CompanionGameState {
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
            return CompanionGameState()
        }
        let data = try Data(contentsOf: self.fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state: CompanionGameState
        if let version = try? decoder.decode(SchemaVersion.self, from: data).schemaVersion,
           version == 2,
           let legacy = try? decoder.decode(LegacyCompanionGameStateV2.self, from: data)
        {
            state = legacy.migrated(at: .now)
        } else if let current = try? decoder.decode(
            CompanionGameState.self,
            from: data)
        {
            state = current
        } else {
            try FileManager.default.removeItem(at: self.fileURL)
            return CompanionGameState()
        }
        guard state.isValid() else {
            try FileManager.default.removeItem(at: self.fileURL)
            return CompanionGameState()
        }
        return state
    }

    public func save(_ state: CompanionGameState) throws {
        try FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: self.fileURL, options: .atomic)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        try FileManager.default.removeItem(at: self.fileURL)
    }
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
    let pity: CompanionPityState
    let appliedGrowthAwardIDs: [UUID]
    let lastActiveAt: Date?
    let lastPattedAt: Date?
    let celebrationUntil: Date?
    let generationCreatedAt: Date
    let updatedAt: Date

    func migrated(at now: Date) -> CompanionGameState {
        var collection = self.collection
        collection.forms.removeAll { $0.stage == .egg }
        let balance = min(
            max(self.growthEnergy, 0),
            CompanionGameRules.standard.maximumEnergyBalance)
        return CompanionGameState(
            speciesID: self.speciesID,
            generationID: self.generationID,
            generationNumber: self.generationNumber,
            stage: self.stage,
            rarity: self.stage == .egg ? nil : self.rarity,
            growthEnergy: balance,
            growthDateKey: GrowthLocalDate.key(for: now),
            growthCarriedToday: balance,
            bondEnergy: self.bondEnergy,
            collection: collection,
            pity: self.pity,
            appliedGrowthAwardIDs: self.appliedGrowthAwardIDs,
            lastActiveAt: self.lastActiveAt,
            lastPattedAt: self.lastPattedAt,
            celebrationUntil: self.celebrationUntil,
            generationCreatedAt: self.generationCreatedAt,
            updatedAt: max(self.updatedAt, now))
    }
}
