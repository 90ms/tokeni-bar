import Foundation
import TokeniCore

/// The provider-independent state exchanged between an application host and its UI.
///
/// The state deliberately contains only verified usage snapshots and local domain
/// state. Platform hosts can observe this value without importing AppKit, SwiftUI,
/// or a platform-specific persistence implementation.
public struct UsageApplicationState: Equatable, Sendable {
    public let snapshots: [ProviderSnapshot]
    public let historyRecords: [UsageHistoryRecord]
    public let growthLedgerState: TokenGrowthLedgerState
    public let lastRefresh: Date?

    public init(
        snapshots: [ProviderSnapshot] = [],
        historyRecords: [UsageHistoryRecord] = [],
        growthLedgerState: TokenGrowthLedgerState = TokenGrowthLedgerState(),
        lastRefresh: Date? = nil)
    {
        self.snapshots = snapshots
        self.historyRecords = historyRecords
        self.growthLedgerState = growthLedgerState
        self.lastRefresh = lastRefresh
    }
}

/// Coordinates shared application work independently from a specific UI host.
///
/// A host owns presentation state such as loading indicators and notifications,
/// while this runtime owns the serialized refresh, history, and growth-ledger
/// transitions that must be shared by macOS and Windows clients.
public actor UsageApplicationRuntime {
    private let refreshCoordinator: UsageRefreshCoordinator
    private let historyCoordinator: any UsageHistoryCoordinating
    private let growthLedgerCoordinator: TokenGrowthLedgerCoordinator
    private var currentState: UsageApplicationState
    private var refreshRevision: UInt64 = 0

    public init(
        providers: [any UsageProviding],
        historyCoordinator: any UsageHistoryCoordinating = UsageHistoryCoordinator(),
        growthLedgerCoordinator: TokenGrowthLedgerCoordinator =
            TokenGrowthLedgerCoordinator(),
        initialState: UsageApplicationState = UsageApplicationState())
    {
        self.refreshCoordinator = UsageRefreshCoordinator(providers: providers)
        self.historyCoordinator = historyCoordinator
        self.growthLedgerCoordinator = growthLedgerCoordinator
        self.currentState = initialState
    }

    public func state() -> UsageApplicationState {
        self.currentState
    }

    @discardableResult
    public func refresh(
        enabledProviderIDs: Set<ProviderID>,
        forceProviderReload: Bool = false,
        now: Date = .now) async -> UsageApplicationState
    {
        self.refreshRevision &+= 1
        let revision = self.refreshRevision
        let result = await self.fetchUsage(
            enabledProviderIDs: enabledProviderIDs,
            forceProviderReload: forceProviderReload,
            now: now)
        guard revision == self.refreshRevision else {
            return self.currentState
        }
        return self.commitRefresh(result)
    }

    func fetchUsage(
        enabledProviderIDs: Set<ProviderID>,
        forceProviderReload: Bool = false,
        now: Date = .now) async -> UsageRefreshResult
    {
        await self.refreshCoordinator.refresh(
            enabledProviderIDs: enabledProviderIDs,
            forceProviderReload: forceProviderReload,
            now: now)
    }

    func commitRefresh(_ result: UsageRefreshResult) -> UsageApplicationState {
        self.currentState = UsageApplicationState(
            snapshots: result.snapshots,
            historyRecords: self.currentState.historyRecords,
            growthLedgerState: self.currentState.growthLedgerState,
            lastRefresh: result.refreshedAt)
        return self.currentState
    }

    @discardableResult
    public func loadHistory() async throws -> UsageApplicationState {
        let records = try await self.historyCoordinator.load()
        self.currentState = UsageApplicationState(
            snapshots: self.currentState.snapshots,
            historyRecords: records,
            growthLedgerState: self.currentState.growthLedgerState,
            lastRefresh: self.currentState.lastRefresh)
        return self.currentState
    }

    @discardableResult
    public func recordHistory(
        at timestamp: Date = .now) async throws -> UsageApplicationState
    {
        let records = try await self.historyCoordinator.record(
            self.currentState.snapshots,
            at: timestamp)
        self.currentState = UsageApplicationState(
            snapshots: self.currentState.snapshots,
            historyRecords: records,
            growthLedgerState: self.currentState.growthLedgerState,
            lastRefresh: self.currentState.lastRefresh)
        return self.currentState
    }

    @discardableResult
    public func clearHistory() async throws -> UsageApplicationState {
        let records = try await self.historyCoordinator.clear()
        self.currentState = UsageApplicationState(
            snapshots: self.currentState.snapshots,
            historyRecords: records,
            growthLedgerState: self.currentState.growthLedgerState,
            lastRefresh: self.currentState.lastRefresh)
        return self.currentState
    }

    @discardableResult
    public func loadGrowthLedger() async throws -> UsageApplicationState {
        let state = try await self.growthLedgerCoordinator.load()
        self.currentState = UsageApplicationState(
            snapshots: self.currentState.snapshots,
            historyRecords: self.currentState.historyRecords,
            growthLedgerState: state,
            lastRefresh: self.currentState.lastRefresh)
        return self.currentState
    }

    @discardableResult
    public func processGrowth(
        at now: Date = .now) async throws -> TokenGrowthLedgerUpdate
    {
        let update = try await self.growthLedgerCoordinator.process(
            observations: self.currentState.snapshots.compactMap(
                \.growthUsageObservation),
            at: now)
        self.currentState = UsageApplicationState(
            snapshots: self.currentState.snapshots,
            historyRecords: self.currentState.historyRecords,
            growthLedgerState: update.state,
            lastRefresh: self.currentState.lastRefresh)
        return update
    }

    @discardableResult
    public func markGrowthAwardApplied(
        _ awardID: GrowthEnergyAward.ID) async throws -> UsageApplicationState
    {
        let state = try await self.growthLedgerCoordinator.markApplied(awardID)
        self.currentState = UsageApplicationState(
            snapshots: self.currentState.snapshots,
            historyRecords: self.currentState.historyRecords,
            growthLedgerState: state,
            lastRefresh: self.currentState.lastRefresh)
        return self.currentState
    }
}
