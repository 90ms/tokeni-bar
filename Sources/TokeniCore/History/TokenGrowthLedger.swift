import Foundation

public struct GrowthMeasurementCheckpoint: Codable, Hashable, Sendable {
    public let measurementKey: String
    public let providerID: ProviderID
    public let scope: GrowthUsageScope
    public let scopeID: String
    public var highWaterTokens: Int64
    public var pendingJumpTokens: Int64?
    public var lastDateKey: String
    public var lastObservedAt: Date
}

public struct GrowthProviderDayTotal: Codable, Hashable, Sendable {
    public let dateKey: String
    public let providerID: ProviderID
    public var tokens: Int64
    public var lastCreditedAt: Date?

    public init(
        dateKey: String,
        providerID: ProviderID,
        tokens: Int64,
        lastCreditedAt: Date? = nil)
    {
        self.dateKey = dateKey
        self.providerID = providerID
        self.tokens = max(tokens, 0)
        self.lastCreditedAt = lastCreditedAt
    }
}

public struct GrowthDayCredit: Codable, Hashable, Sendable {
    public let dateKey: String
    public var aggregateTokens: Int64
    public var targetEnergy: Int
    public var awardedEnergy: Int
}

public struct GrowthEnergyAward: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let dateKey: String
    public let energy: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        dateKey: String,
        energy: Int,
        createdAt: Date)
    {
        self.id = id
        self.dateKey = dateKey
        self.energy = max(energy, 0)
        self.createdAt = createdAt
    }
}

public struct TokenGrowthLedgerState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var checkpoints: [GrowthMeasurementCheckpoint]
    public var providerDayTotals: [GrowthProviderDayTotal]
    public var dayCredits: [GrowthDayCredit]
    public var pendingAwards: [GrowthEnergyAward]
    public var conversionRemainderTokens: Int64

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        checkpoints: [GrowthMeasurementCheckpoint] = [],
        providerDayTotals: [GrowthProviderDayTotal] = [],
        dayCredits: [GrowthDayCredit] = [],
        pendingAwards: [GrowthEnergyAward] = [],
        conversionRemainderTokens: Int64 = 0)
    {
        self.schemaVersion = schemaVersion
        self.checkpoints = checkpoints
        self.providerDayTotals = providerDayTotals
        self.dayCredits = dayCredits
        self.pendingAwards = pendingAwards
        self.conversionRemainderTokens = max(conversionRemainderTokens, 0)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case checkpoints
        case providerDayTotals
        case dayCredits
        case pendingAwards
        case conversionRemainderTokens
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
                debugDescription: "Unsupported token growth ledger schema")
        }
        self.init(
            checkpoints: try container.decodeIfPresent(
                [GrowthMeasurementCheckpoint].self,
                forKey: .checkpoints) ?? [],
            providerDayTotals: try container.decodeIfPresent(
                [GrowthProviderDayTotal].self,
                forKey: .providerDayTotals) ?? [],
            dayCredits: try container.decodeIfPresent(
                [GrowthDayCredit].self,
                forKey: .dayCredits) ?? [],
            pendingAwards: try container.decodeIfPresent(
                [GrowthEnergyAward].self,
                forKey: .pendingAwards) ?? [],
            conversionRemainderTokens: try container.decodeIfPresent(
                Int64.self,
                forKey: .conversionRemainderTokens) ?? 0)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(self.checkpoints, forKey: .checkpoints)
        try container.encode(self.providerDayTotals, forKey: .providerDayTotals)
        try container.encode(self.dayCredits, forKey: .dayCredits)
        try container.encode(self.pendingAwards, forKey: .pendingAwards)
        try container.encode(
            self.conversionRemainderTokens,
            forKey: .conversionRemainderTokens)
    }
}

public struct TokenGrowthLedgerEngine: Sendable {
    public let formula: TokenGrowthEnergyFormula
    public let maximumUnconfirmedDelta: Int64
    public let lateDailyWindow: Int
    private var calendar: Calendar

    public init(
        formula: TokenGrowthEnergyFormula = .standard,
        maximumUnconfirmedDelta: Int64 = 10_000_000_000,
        lateDailyWindow: Int = 3,
        calendar: Calendar = .current)
    {
        self.formula = formula
        self.maximumUnconfirmedDelta = max(maximumUnconfirmedDelta, 0)
        self.lateDailyWindow = max(lateDailyWindow, 0)
        self.calendar = calendar
    }

    @discardableResult
    public func process(
        observations: [GrowthUsageObservation],
        at now: Date = .now,
        in state: inout TokenGrowthLedgerState) -> [GrowthEnergyAward]
    {
        let currentDateKey = GrowthLocalDate.key(for: now, calendar: self.calendar)
        var affectedDateKeys = Set<String>()

        for observation in observations.sorted(by: {
            if $0.providerID.rawValue != $1.providerID.rawValue {
                return $0.providerID.rawValue < $1.providerID.rawValue
            }
            return $0.measurementKey < $1.measurementKey
        }) {
            guard observation.totalTokens >= 0,
                  observation.observedAt <= now.addingTimeInterval(5 * 60),
                  !observation.scopeID.isEmpty
            else { continue }

            switch observation.scope {
            case .daily:
                guard self.isAcceptedDailyKey(
                    observation.scopeID,
                    currentDateKey: currentDateKey,
                    now: now)
                else { continue }
                if self.recordDaily(
                    observation,
                    dateKey: observation.scopeID,
                    in: &state)
                {
                    affectedDateKeys.insert(observation.scopeID)
                }
            case .lifetime, .session:
                if self.recordCumulative(
                    observation,
                    dateKey: currentDateKey,
                    in: &state)
                {
                    affectedDateKeys.insert(currentDateKey)
                }
            }
        }

        var awards: [GrowthEnergyAward] = []
        for dateKey in affectedDateKeys.sorted() {
            let aggregate = self.aggregateTokens(for: dateKey, in: state)
            let index = state.dayCredits.firstIndex { $0.dateKey == dateKey }
            let previousAggregate = index.map {
                state.dayCredits[$0].aggregateTokens
            } ?? 0
            let newTokens = max(aggregate - previousAggregate, 0)

            if let index {
                state.dayCredits[index].aggregateTokens = aggregate
            } else {
                state.dayCredits.append(GrowthDayCredit(
                    dateKey: dateKey,
                    aggregateTokens: aggregate,
                    targetEnergy: 0,
                    awardedEnergy: 0))
            }

            let convertibleTokens = Self.saturatedAdd(
                state.conversionRemainderTokens,
                newTokens)
            let energy = self.formula.energy(
                forDailyTokens: convertibleTokens)
            let consumedTokens = self.formula.minimumDailyTokens(
                forEnergy: energy) ?? 0
            state.conversionRemainderTokens = max(
                convertibleTokens - consumedTokens,
                0)
            guard energy > 0,
                  let creditIndex = state.dayCredits.firstIndex(where: {
                      $0.dateKey == dateKey
                  })
            else { continue }
            state.dayCredits[creditIndex].targetEnergy += energy
            state.dayCredits[creditIndex].awardedEnergy += energy
            let award = GrowthEnergyAward(
                dateKey: dateKey,
                energy: energy,
                createdAt: now)
            state.pendingAwards.append(award)
            awards.append(award)
        }

        self.prune(at: now, in: &state)
        return awards
    }

    public func markApplied(
        _ awardID: GrowthEnergyAward.ID,
        in state: inout TokenGrowthLedgerState)
    {
        state.pendingAwards.removeAll { $0.id == awardID }
    }

    private func recordDaily(
        _ observation: GrowthUsageObservation,
        dateKey: String,
        in state: inout TokenGrowthLedgerState) -> Bool
    {
        let checkpointIndex = self.checkpointIndex(
            for: observation.measurementKey,
            in: state)
        if let checkpointIndex {
            let highWater = state.checkpoints[checkpointIndex].highWaterTokens
            guard observation.totalTokens > highWater else {
                state.checkpoints[checkpointIndex].lastObservedAt = observation.observedAt
                return false
            }
            let delta = observation.totalTokens - highWater
            guard self.confirmIfNeeded(
                total: observation.totalTokens,
                delta: delta,
                checkpointIndex: checkpointIndex,
                in: &state)
            else { return false }
            state.checkpoints[checkpointIndex].highWaterTokens = observation.totalTokens
            state.checkpoints[checkpointIndex].pendingJumpTokens = nil
            state.checkpoints[checkpointIndex].lastObservedAt = observation.observedAt
        } else {
            if observation.totalTokens > self.maximumUnconfirmedDelta {
                state.checkpoints.append(self.checkpoint(
                    for: observation,
                    dateKey: dateKey,
                    highWaterTokens: 0,
                    pendingJumpTokens: observation.totalTokens))
                return false
            }
            state.checkpoints.append(self.checkpoint(
                for: observation,
                dateKey: dateKey,
                highWaterTokens: observation.totalTokens))
        }

        let totalIndex = state.providerDayTotals.firstIndex {
            $0.dateKey == dateKey && $0.providerID == observation.providerID
        }
        if let totalIndex {
            state.providerDayTotals[totalIndex].tokens = max(
                state.providerDayTotals[totalIndex].tokens,
                observation.totalTokens)
            state.providerDayTotals[totalIndex].lastCreditedAt = observation.observedAt
        } else {
            state.providerDayTotals.append(GrowthProviderDayTotal(
                dateKey: dateKey,
                providerID: observation.providerID,
                tokens: observation.totalTokens,
                lastCreditedAt: observation.observedAt))
        }
        return true
    }

    private func recordCumulative(
        _ observation: GrowthUsageObservation,
        dateKey: String,
        in state: inout TokenGrowthLedgerState) -> Bool
    {
        guard let checkpointIndex = self.checkpointIndex(
            for: observation.measurementKey,
            in: state)
        else {
            state.checkpoints.append(self.checkpoint(
                for: observation,
                dateKey: dateKey,
                highWaterTokens: observation.totalTokens))
            return false
        }

        let previousDateKey = state.checkpoints[checkpointIndex].lastDateKey
        state.checkpoints[checkpointIndex].lastObservedAt = observation.observedAt
        state.checkpoints[checkpointIndex].lastDateKey = dateKey
        guard previousDateKey == dateKey else {
            state.checkpoints[checkpointIndex].highWaterTokens = max(
                state.checkpoints[checkpointIndex].highWaterTokens,
                observation.totalTokens)
            state.checkpoints[checkpointIndex].pendingJumpTokens = nil
            return false
        }

        let highWater = state.checkpoints[checkpointIndex].highWaterTokens
        guard observation.totalTokens > highWater else { return false }
        let delta = observation.totalTokens - highWater
        guard self.confirmIfNeeded(
            total: observation.totalTokens,
            delta: delta,
            checkpointIndex: checkpointIndex,
            in: &state)
        else { return false }

        state.checkpoints[checkpointIndex].highWaterTokens = observation.totalTokens
        state.checkpoints[checkpointIndex].pendingJumpTokens = nil
        let totalIndex = state.providerDayTotals.firstIndex {
            $0.dateKey == dateKey && $0.providerID == observation.providerID
        }
        if let totalIndex {
            state.providerDayTotals[totalIndex].tokens = Self.saturatedAdd(
                state.providerDayTotals[totalIndex].tokens,
                delta)
            state.providerDayTotals[totalIndex].lastCreditedAt = observation.observedAt
        } else {
            state.providerDayTotals.append(GrowthProviderDayTotal(
                dateKey: dateKey,
                providerID: observation.providerID,
                tokens: delta,
                lastCreditedAt: observation.observedAt))
        }
        return true
    }

    private func confirmIfNeeded(
        total: Int64,
        delta: Int64,
        checkpointIndex: Int,
        in state: inout TokenGrowthLedgerState) -> Bool
    {
        guard delta > self.maximumUnconfirmedDelta else { return true }
        if let pending = state.checkpoints[checkpointIndex].pendingJumpTokens,
           total >= pending
        {
            return true
        }
        state.checkpoints[checkpointIndex].pendingJumpTokens = total
        return false
    }

    private func checkpoint(
        for observation: GrowthUsageObservation,
        dateKey: String,
        highWaterTokens: Int64,
        pendingJumpTokens: Int64? = nil) -> GrowthMeasurementCheckpoint
    {
        GrowthMeasurementCheckpoint(
            measurementKey: observation.measurementKey,
            providerID: observation.providerID,
            scope: observation.scope,
            scopeID: observation.scopeID,
            highWaterTokens: highWaterTokens,
            pendingJumpTokens: pendingJumpTokens,
            lastDateKey: dateKey,
            lastObservedAt: observation.observedAt)
    }

    private func checkpointIndex(
        for measurementKey: String,
        in state: TokenGrowthLedgerState) -> Int?
    {
        state.checkpoints.firstIndex { $0.measurementKey == measurementKey }
    }

    private func aggregateTokens(
        for dateKey: String,
        in state: TokenGrowthLedgerState) -> Int64
    {
        state.providerDayTotals
            .filter { $0.dateKey == dateKey }
            .reduce(0) { Self.saturatedAdd($0, $1.tokens) }
    }

    private func isAcceptedDailyKey(
        _ dateKey: String,
        currentDateKey: String,
        now: Date) -> Bool
    {
        guard dateKey <= currentDateKey,
              let date = self.date(from: dateKey),
              let cutoff = self.calendar.date(
                  byAdding: .day,
                  value: -self.lateDailyWindow,
                  to: self.calendar.startOfDay(for: now))
        else { return false }
        return date >= cutoff
    }

    private func date(from key: String) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }
        var components = DateComponents()
        components.calendar = self.calendar
        components.timeZone = self.calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = self.calendar.date(from: components) else { return nil }
        let normalized = self.calendar.dateComponents([.year, .month, .day], from: date)
        guard normalized.year == year,
              normalized.month == month,
              normalized.day == day
        else { return nil }
        return date
    }

    private func prune(at now: Date, in state: inout TokenGrowthLedgerState) {
        let dayCutoff = GrowthLocalDate.key(
            for: self.calendar.date(byAdding: .day, value: -7, to: now) ?? now,
            calendar: self.calendar)
        let checkpointCutoff = now.addingTimeInterval(-30 * 24 * 60 * 60)
        state.providerDayTotals.removeAll { $0.dateKey < dayCutoff }
        state.dayCredits.removeAll { $0.dateKey < dayCutoff }
        state.checkpoints.removeAll { $0.lastObservedAt < checkpointCutoff }
    }

    private static func saturatedAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }
}

public actor TokenGrowthLedgerStore {
    private let fileURL: URL
    private var lastSavedRevision: UInt64 = 0

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? AppStoragePaths.applicationSupportDirectory()
            .appending(path: "usage-growth-ledger.json")
    }

    public func load() throws -> TokenGrowthLedgerState {
        try RecoverableFileStorage.load(
            from: self.fileURL,
            decode: Self.decode) ?? TokenGrowthLedgerState()
    }

    private static func decode(_ data: Data) throws -> TokenGrowthLedgerState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(
            TokenGrowthLedgerState.self,
            from: data)
        guard state.schemaVersion == TokenGrowthLedgerState.currentSchemaVersion else {
            throw TokenGrowthLedgerStoreError.invalidState
        }
        return state
    }

    public func save(
        _ state: TokenGrowthLedgerState,
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

private enum TokenGrowthLedgerStoreError: Error {
    case invalidState
}
