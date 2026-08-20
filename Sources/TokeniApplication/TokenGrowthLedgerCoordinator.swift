import Foundation
import TokeniCore

public struct TokenGrowthLedgerUpdate: Equatable, Sendable {
    public let state: TokenGrowthLedgerState
    public let awards: [GrowthEnergyAward]

    public init(
        state: TokenGrowthLedgerState,
        awards: [GrowthEnergyAward])
    {
        self.state = state
        self.awards = awards
    }
}

public actor TokenGrowthLedgerCoordinator {
    private let store: TokenGrowthLedgerStore
    private let engine: TokenGrowthLedgerEngine
    private var state = TokenGrowthLedgerState()
    private var saveRevision: UInt64 = 0

    public init(
        store: TokenGrowthLedgerStore = TokenGrowthLedgerStore(),
        engine: TokenGrowthLedgerEngine = TokenGrowthLedgerEngine())
    {
        self.store = store
        self.engine = engine
    }

    public func load() async throws -> TokenGrowthLedgerState {
        let state = try await self.store.load()
        self.state = state
        return state
    }

    public func process(
        observations: [GrowthUsageObservation],
        at now: Date = .now) async throws -> TokenGrowthLedgerUpdate
    {
        var nextState = self.state
        let awards = self.engine.process(
            observations: observations,
            at: now,
            in: &nextState)
        try await self.save(nextState)
        self.state = nextState
        return TokenGrowthLedgerUpdate(state: nextState, awards: awards)
    }

    public func markApplied(
        _ awardID: GrowthEnergyAward.ID) async throws -> TokenGrowthLedgerState
    {
        var nextState = self.state
        self.engine.markApplied(awardID, in: &nextState)
        try await self.save(nextState)
        self.state = nextState
        return nextState
    }

    private func save(_ nextState: TokenGrowthLedgerState) async throws {
        self.saveRevision &+= 1
        try await self.store.save(nextState, revision: self.saveRevision)
    }
}
