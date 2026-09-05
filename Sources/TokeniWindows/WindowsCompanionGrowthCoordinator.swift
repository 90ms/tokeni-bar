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
    private let rewardStore: CompanionRewardStateStore?
    private let journalStore: CompanionEconomyTransactionStore?
    private let rewardEngine = CompanionRewardEngine()
    private var rewards: CompanionRewardState?
    private var mutationInProgress = false

    public init(
        session: UsageApplicationSession,
        stateStore: CompanionGameStateStore = CompanionGameStateStore(),
        rewardStore: CompanionRewardStateStore = CompanionRewardStateStore(),
        journalStore: CompanionEconomyTransactionStore = CompanionEconomyTransactionStore(),
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
        self.rewardStore = rewardStore
        self.journalStore = journalStore
    }

    public init(
        loadState: @escaping LoadState,
        saveState: @escaping SaveState,
        processGrowth: @escaping ProcessGrowth,
        loadLedger: @escaping LoadLedger,
        markAwardApplied: @escaping MarkAwardApplied,
        rewardStore: CompanionRewardStateStore? = nil,
        journalStore: CompanionEconomyTransactionStore? = nil,
        gameEngine: CompanionGameEngine = CompanionGameEngine())
    {
        self.loadState = loadState
        self.saveState = saveState
        self.processGrowth = processGrowth
        self.loadLedger = loadLedger
        self.markAwardApplied = markAwardApplied
        self.gameEngine = gameEngine
        self.rewardStore = rewardStore
        self.journalStore = journalStore
    }

    @discardableResult
    public func load() async throws -> CompanionGameState {
        guard !self.mutationInProgress else { throw WindowsCompanionGrowthError.busy }
        self.mutationInProgress = true
        defer { self.mutationInProgress = false }
        let loaded = try await self.loadState()
        self.state = loaded
        do {
            self.rewards = try await self.rewardStore?.load()
            if let journalStore {
                for transaction in try await journalStore.load().pending {
                    try await self.commitEconomy(transaction, begin: false)
                }
            }
            return self.state ?? loaded
        } catch { self.state = nil; throw error }
    }

    public func currentState() -> CompanionGameState? {
        self.state
    }

    public func selectGrowthTarget(_ id: UUID) async throws {
        guard !self.mutationInProgress else { throw WindowsCompanionGrowthError.busy }
        self.mutationInProgress = true
        defer { self.mutationInProgress = false }
        guard var updated = self.state else { throw WindowsCompanionGrowthError.stateNotLoaded }
        try self.gameEngine.selectGrowthTarget(id, in: &updated)
        try await self.persistUserChange(updated)
    }

    public func openNextEgg() async throws {
        guard !self.mutationInProgress else { throw WindowsCompanionGrowthError.busy }
        self.mutationInProgress = true
        defer { self.mutationInProgress = false }
        guard var updated = self.state else { throw WindowsCompanionGrowthError.stateNotLoaded }
        guard let egg = updated.eggs.first else { throw CompanionEggError.eggNotFound }
        try self.gameEngine.openEgg(egg.id, in: &updated)
        try await self.persistUserChange(updated)
    }

    private func persistUserChange(_ updated: CompanionGameState) async throws {
        guard updated.isValid() else { throw WindowsCompanionGrowthError.invalidState }
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
        guard !self.mutationInProgress else { throw WindowsCompanionGrowthError.busy }
        self.mutationInProgress = true
        defer { self.mutationInProgress = false }
        guard var current = self.state else {
            throw WindowsCompanionGrowthError.stateNotLoaded
        }

        let pendingAwards = await self.loadLedger().pendingAwards
        for award in pendingAwards {
            if current.appliedGrowthAwardIDs.contains(award.id) {
                // Presence in a state loaded from disk, or retained after a
                // successful save, proves the state side of the transaction.
                try await self.settleRewards(energy: award.energy, at: award.createdAt, companion: current)
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
            try await self.settleRewards(energy: award.energy, at: award.createdAt, companion: updated)
            try await self.markAwardApplied(award.id)
        }

        self.state = current
        try await self.settleRewards(energy: 0, at: .now, companion: current)
        return current
    }

    private func settleRewards(energy: Int, at date: Date, companion: CompanionGameState) async throws {
        guard var updated = self.rewards, let rewardStore else { return }
        _ = self.rewardEngine.rewardVerifiedGrowth(energy: energy, at: date, in: &updated)
        _ = self.rewardEngine.reconcile(collection: companion.collection, at: date, in: &updated)
        guard updated != self.rewards else { return }
        guard updated.isValid() else { throw WindowsCompanionGrowthError.invalidState }
        // Keep the award in the growth ledger until both saves have succeeded.
        // Reward date/discovery receipts make recovery idempotent after either save.
        try await rewardStore.save(updated)
        self.rewards = updated
    }

    public func currentRewards() -> CompanionRewardState? { self.rewards }

    /// Every action is validated again against current state; UI selections are identifiers only.
    public func perform(_ action: WindowsCompanionAction) async throws {
        guard !self.mutationInProgress else { throw WindowsCompanionGrowthError.busy }
        self.mutationInProgress = true
        defer { self.mutationInProgress = false }
        guard var state = self.state else { throw WindowsCompanionGrowthError.stateNotLoaded }
        switch action {
        case let .showcase(id):
            try self.gameEngine.selectPrimaryCompanion(id, in: &state)
            try await self.persistUserChange(state)
        case let .rename(id, name):
            let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
            if id == state.generationID {
                guard state.stage != .egg else { throw WindowsCompanionGrowthError.invalidState }
                self.gameEngine.rename(clean, in: &state)
            } else if let index = state.collection.archivedGenerations.firstIndex(where: { $0.generationID == id }) {
                state.collection.recentCompletedGenerations[index].nickname = clean.isEmpty ? nil : clean
                state.updatedAt = .now
            } else { throw CompanionGameError.archivedGenerationNotFound }
            try await self.persistUserChange(state)
        case let .openEgg(id):
            try self.gameEngine.openEgg(id, in: &state)
            try await self.persistUserChange(state)
        case let .buyEgg(id):
            guard let definition = CompanionEggRegistry.definition(for: id), let price = definition.price else { throw CompanionEggError.eggNotPurchasable }
            guard CompanionEggRegistry.isUnlocked(definition, highestPetLevel: state.highestPetLevel,
                discoveredSpeciesCount: state.collection.discoveredSpeciesIDs.count) else { throw CompanionEggError.eggLocked }
            try await self.commitEconomy(CompanionEconomyTransaction(kind: .purchaseEgg(definitionID: id,
                seed: UInt64.random(in: 0...UInt64(Int64.max)), price: price)), begin: true)
        case let .sellEgg(id):
            guard let egg = state.eggs.first(where: { $0.id == id }),
                  let definition = CompanionEggRegistry.definition(for: egg.definitionID), definition.isSellable else { throw CompanionEggError.eggNotSellable }
            try await self.commitEconomy(CompanionEconomyTransaction(kind: .sellEgg(eggID: id, value: definition.resaleValue)), begin: true)
        case let .sellPet(id):
            guard let pet = state.collection.archivedGenerations.first(where: { $0.generationID == id }) else { throw CompanionGameError.archivedGenerationNotFound }
            let variant = pet.variantID ?? CompanionVariantRegistry.migrated(from: pet.finalRarity)
            try await self.commitEconomy(CompanionEconomyTransaction(kind: .sellPet(generationID: id, value: variant == .prismatic ? 60 : 30)), begin: true)
        case .checkIn, .buyCosmetic, .equipCosmetic:
            guard var rewards = self.rewards, let rewardStore else { throw WindowsCompanionGrowthError.stateNotLoaded }
            switch action {
            case .checkIn: _ = try self.rewardEngine.checkIn(in: &rewards)
            case let .buyCosmetic(id): try self.rewardEngine.purchase(cosmeticID: id, in: &rewards)
            case let .equipCosmetic(id):
                if rewards.selectedCosmeticIDs.contains(id) { self.rewardEngine.unequip(slot: id.slot, in: &rewards) }
                else { try self.rewardEngine.select(cosmeticID: id, in: &rewards) }
            default: break
            }
            _ = self.rewardEngine.reconcile(collection: state.collection, in: &rewards)
            guard rewards.isValid() else { throw WindowsCompanionGrowthError.invalidState }
            try await rewardStore.save(rewards)
            self.rewards = rewards
        }
    }

    private func commitEconomy(_ transaction: CompanionEconomyTransaction, begin: Bool) async throws {
        guard var companion = self.state, var rewards = self.rewards, let rewardStore, let journalStore else { throw WindowsCompanionGrowthError.stateNotLoaded }
        switch transaction.kind {
        case let .purchaseEgg(id, seed, price):
            try self.rewardEngine.spendStarShards(price, transactionID: transaction.id, at: transaction.createdAt, in: &rewards)
            _ = try self.gameEngine.acquireEgg(definitionID: id, seed: seed, source: .shop, transactionID: transaction.id, at: transaction.createdAt, in: &companion)
        case let .sellEgg(id, value):
            _ = try self.gameEngine.sellEgg(id, transactionID: transaction.id, at: transaction.createdAt, in: &companion)
            self.rewardEngine.grantStarShards(value, transactionID: transaction.id, at: transaction.createdAt, in: &rewards)
        case let .sellPet(id, value):
            _ = try self.gameEngine.sellArchivedGeneration(id, transactionID: transaction.id, at: transaction.createdAt, in: &companion)
            self.rewardEngine.grantStarShards(value, transactionID: transaction.id, at: transaction.createdAt, in: &rewards)
        }
        guard companion.isValid(), rewards.isValid() else { throw WindowsCompanionGrowthError.invalidState }
        if begin { try await journalStore.begin(transaction) }
        do {
            self.saveRevision &+= 1
            try await self.saveState(companion, self.saveRevision)
            try await rewardStore.save(rewards)
            try await journalStore.complete(transaction.id)
            self.state = companion
            self.rewards = rewards
        } catch {
            // Do not overwrite either side after a partial save. Startup replays the durable ID.
            self.state = nil
            throw error
        }
    }
}

public enum WindowsCompanionAction: Sendable {
    case showcase(UUID), rename(UUID, String), openEgg(UUID), buyEgg(CompanionEggDefinitionID)
    case sellEgg(UUID), sellPet(UUID), checkIn
    case buyCosmetic(CompanionCosmeticID), equipCosmetic(CompanionCosmeticID)
}

public enum WindowsCompanionGrowthError: Error, Equatable {
    case stateNotLoaded
    case busy
    case invalidState
}
