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
/// while this runtime owns the refresh and history transitions that must be
/// shared by macOS and Windows clients. Refresh and history operations are
/// admitted in FIFO order. Cancelling a queued operation removes only that
/// operation and never invalidates work that is already running.
public actor UsageApplicationRuntime {
    private let refreshCoordinator: UsageRefreshCoordinator
    private let historyCoordinator: UsageHistoryCoordinator
    private let growthLedgerCoordinator: TokenGrowthLedgerCoordinator
    private var currentState: UsageApplicationState
    private let operationGate = UsageApplicationOperationGate()

    public init(
        providers: [any UsageProviding],
        historyCoordinator: UsageHistoryCoordinator = UsageHistoryCoordinator(),
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
        guard await self.operationGate.acquire() else {
            return self.currentState
        }
        let result = await self.refreshCoordinator.refresh(
            enabledProviderIDs: enabledProviderIDs,
            forceProviderReload: forceProviderReload,
            now: now)
        let state = self.commitRefresh(result)
        await self.operationGate.release()
        return state
    }

    /// Refreshes providers and records their resulting snapshots as one FIFO
    /// operation. A history failure leaves the successful refresh state intact.
    @discardableResult
    public func refreshAndRecordHistory(
        enabledProviderIDs: Set<ProviderID>,
        forceProviderReload: Bool = false,
        now: Date = .now) async -> UsageApplicationState
    {
        guard await self.operationGate.acquire() else {
            return self.currentState
        }
        let result = await self.refreshCoordinator.refresh(
            enabledProviderIDs: enabledProviderIDs,
            forceProviderReload: forceProviderReload,
            now: now)
        _ = self.commitRefresh(result)
        do {
            _ = try await self.recordHistoryWithoutOperationGate(at: now)
        } catch {
            // Provider usage remains valid when its optional history sample
            // cannot be saved.
        }
        let state = self.currentState
        await self.operationGate.release()
        return state
    }

    private func commitRefresh(_ result: UsageRefreshResult) -> UsageApplicationState {
        self.currentState = UsageApplicationState(
            snapshots: result.snapshots,
            historyRecords: self.currentState.historyRecords,
            growthLedgerState: self.currentState.growthLedgerState,
            lastRefresh: result.refreshedAt)
        return self.currentState
    }

    @discardableResult
    public func loadHistory() async throws -> UsageApplicationState {
        guard await self.operationGate.acquire() else {
            throw CancellationError()
        }
        do {
            let records = try await self.historyCoordinator.load()
            self.currentState = UsageApplicationState(
                snapshots: self.currentState.snapshots,
                historyRecords: records,
                growthLedgerState: self.currentState.growthLedgerState,
                lastRefresh: self.currentState.lastRefresh)
            let state = self.currentState
            await self.operationGate.release()
            return state
        } catch {
            await self.operationGate.release()
            throw error
        }
    }

    @discardableResult
    public func recordHistory(
        at timestamp: Date = .now) async throws -> UsageApplicationState
    {
        guard await self.operationGate.acquire() else {
            throw CancellationError()
        }
        do {
            let state = try await self.recordHistoryWithoutOperationGate(
                at: timestamp)
            await self.operationGate.release()
            return state
        } catch {
            await self.operationGate.release()
            throw error
        }
    }

    private func recordHistoryWithoutOperationGate(
        at timestamp: Date) async throws -> UsageApplicationState
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
        guard await self.operationGate.acquire() else {
            throw CancellationError()
        }
        do {
            let records = try await self.historyCoordinator.clear()
            self.currentState = UsageApplicationState(
                snapshots: self.currentState.snapshots,
                historyRecords: records,
                growthLedgerState: self.currentState.growthLedgerState,
                lastRefresh: self.currentState.lastRefresh)
            let state = self.currentState
            await self.operationGate.release()
            return state
        } catch {
            await self.operationGate.release()
            throw error
        }
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

    func queuedOperationCount() async -> Int {
        await self.operationGate.queuedOperationCount()
    }
}

private actor UsageApplicationOperationGate {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    private var isAcquired = false
    private var waiters: [Waiter] = []

    func acquire() async -> Bool {
        guard !Task.isCancelled else { return false }
        guard self.isAcquired else {
            self.isAcquired = true
            return true
        }

        let waiterID = UUID()
        let acquired = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: false)
                } else {
                    self.waiters.append(Waiter(
                        id: waiterID,
                        continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancel(waiterID) }
        }
        guard acquired else { return false }
        guard !Task.isCancelled else {
            self.release()
            return false
        }
        return true
    }

    func release() {
        guard !self.waiters.isEmpty else {
            self.isAcquired = false
            return
        }
        let waiter = self.waiters.removeFirst()
        waiter.continuation.resume(returning: true)
    }

    func queuedOperationCount() -> Int {
        self.waiters.count
    }

    private func cancel(_ waiterID: UUID) {
        guard let index = self.waiters.firstIndex(where: {
            $0.id == waiterID
        }) else { return }
        let waiter = self.waiters.remove(at: index)
        waiter.continuation.resume(returning: false)
    }
}
