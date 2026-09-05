import Foundation
import TokeniApplication
import TokeniCore

/// Applies provider-neutral growth awards to the Windows companion state.
///
/// The coordinator deliberately serializes the state-file and ledger updates:
/// an award is removed from the ledger only after the companion state that
/// contains its ID has been saved successfully. The persisted award ID also
/// makes retrying after a ledger-write failure idempotent.
public actor WindowsCompanionGrowthCoordinator {
    public typealias LoadState = @Sendable () async throws -> CompanionGameState
    public typealias SaveState = @Sendable (
        CompanionGameState,
        UInt64) async throws -> Void
    public typealias ProcessGrowth = @Sendable (Date) async throws -> Void
    public typealias LoadLedger = @Sendable () async -> TokenGrowthLedgerState
    public typealias MarkAwardApplied = @Sendable (
        GrowthEnergyAward.ID) async throws -> Void

    private let loadState: LoadState
    private let saveState: SaveState
    private let processGrowth: ProcessGrowth
    private let loadLedger: LoadLedger
    private let markAwardApplied: MarkAwardApplied
    private let gameEngine: CompanionGameEngine
    private var state: CompanionGameState?
    private var saveRevision: UInt64 = 0
    private var lastProcessedRefresh: Date?

    public init(
        session: UsageApplicationSession,
        stateStore: CompanionGameStateStore = CompanionGameStateStore(),
        gameEngine: CompanionGameEngine = CompanionGameEngine())
    {
        self.loadState = { try await stateStore.load() }
        self.saveState = { state, revision in
            try await stateStore.save(state, revision: revision)
        }
        self.processGrowth = { date in
            try await session.processGrowth(at: date)
        }
        self.loadLedger = {
            await session.state().applicationState.growthLedgerState
        }
        self.markAwardApplied = { awardID in
            try await session.markGrowthAwardApplied(awardID)
        }
        self.gameEngine = gameEngine
    }

    public init(
        loadState: @escaping LoadState,
        saveState: @escaping SaveState,
        processGrowth: @escaping ProcessGrowth,
        loadLedger: @escaping LoadLedger,
        markAwardApplied: @escaping MarkAwardApplied,
        gameEngine: CompanionGameEngine = CompanionGameEngine())
    {
        self.loadState = loadState
        self.saveState = saveState
        self.processGrowth = processGrowth
        self.loadLedger = loadLedger
        self.markAwardApplied = markAwardApplied
        self.gameEngine = gameEngine
    }

    @discardableResult
    public func load() async throws -> CompanionGameState {
        let loaded = try await self.loadState()
        self.state = loaded
        return loaded
    }

    public func currentState() -> CompanionGameState? {
        self.state
    }

    public func selectGrowthTarget(_ id: UUID) async throws {
        guard var updated = self.state else { throw WindowsCompanionGrowthError.stateNotLoaded }
        try self.gameEngine.selectGrowthTarget(id, in: &updated)
        try await self.persistUserChange(updated)
    }

    public func openNextEgg() async throws {
        guard var updated = self.state else { throw WindowsCompanionGrowthError.stateNotLoaded }
        guard let egg = updated.eggs.first else { throw CompanionEggError.eggNotFound }
        try self.gameEngine.openEgg(egg.id, in: &updated)
        try await self.persistUserChange(updated)
    }

    private func persistUserChange(_ updated: CompanionGameState) async throws {
        self.saveRevision &+= 1
        do {
            try await self.saveState(updated, self.saveRevision)
            self.state = updated
        } catch {
            self.saveRevision &-= 1
            throw error
        }
    }

    /// Processes each completed provider refresh once. Overlay visibility is
    /// intentionally not an input: hiding the window must not drop usage.
    @discardableResult
    public func synchronize(
        afterRefreshAt refreshDate: Date?) async throws -> CompanionGameState
    {
        if let refreshDate, refreshDate != self.lastProcessedRefresh {
            try await self.processGrowth(refreshDate)
            self.lastProcessedRefresh = refreshDate
        }
        return try await self.applyPendingAwards()
    }

    /// Applies awards already present in the persisted ledger. This is called
    /// during startup before a new provider refresh is necessarily available.
    @discardableResult
    public func applyPendingAwards() async throws -> CompanionGameState {
        guard var current = self.state else {
            throw WindowsCompanionGrowthError.stateNotLoaded
        }

        let pendingAwards = await self.loadLedger().pendingAwards
        for award in pendingAwards {
            if current.appliedGrowthAwardIDs.contains(award.id) {
                // Presence in a state loaded from disk, or retained after a
                // successful save, proves the state side of the transaction.
                try await self.markAwardApplied(award.id)
                continue
            }

            var updated = current
            _ = self.gameEngine.apply(award: award, to: &updated)
            self.saveRevision &+= 1
            do {
                try await self.saveState(updated, self.saveRevision)
            } catch {
                self.saveRevision &-= 1
                throw error
            }

            current = updated
            self.state = updated
            try await self.markAwardApplied(award.id)
        }

        self.state = current
        return current
    }
}

public enum WindowsCompanionGrowthError: Error, Equatable {
    case stateNotLoaded
}
