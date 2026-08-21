import Foundation
import TokeniCore

/// The host-facing state for a shared application session.
///
/// This value contains only provider-neutral state and host controls. A tray,
/// window, or other UI can consume it without importing AppKit or SwiftUI.
public struct UsageApplicationSessionState: Equatable, Sendable {
    public let applicationState: UsageApplicationState
    public let providerDescriptors: [ProviderDescriptor]
    public let enabledProviderIDs: Set<ProviderID>
    public let isRefreshing: Bool

    public init(
        applicationState: UsageApplicationState = UsageApplicationState(),
        providerDescriptors: [ProviderDescriptor] = [],
        enabledProviderIDs: Set<ProviderID> = [],
        isRefreshing: Bool = false)
    {
        self.applicationState = applicationState
        self.providerDescriptors = providerDescriptors
        self.enabledProviderIDs = enabledProviderIDs
        self.isRefreshing = isRefreshing
    }
}

/// Owns the shared application runtime and its refresh lifecycle.
///
/// UI hosts can use this actor for bootstrap, refresh, history, and growth
/// operations without depending on a platform UI framework or on the macOS
/// `UsageStore`.
public actor UsageApplicationSession {
    private let runtime: UsageApplicationRuntime
    private let providerDescriptors: [ProviderDescriptor]
    private let knownProviderIDs: Set<ProviderID>
    private let providerPreferences: ProviderPreferenceCoordinator?
    private var enabledProviderIDs: Set<ProviderID>
    private var applicationState = UsageApplicationState()
    private var isRefreshing = false
    private var refreshOperationCount = 0
    private var periodicRefreshTask: Task<Void, Never>?

    public init(
        providers: [any UsageProviding],
        runtime: UsageApplicationRuntime? = nil,
        enabledProviderIDs: Set<ProviderID>? = nil,
        providerPreferences: ProviderPreferenceCoordinator? = nil)
    {
        let descriptors = providers.map(\.descriptor)
        let knownProviderIDs = Set(descriptors.map(\.id))
        let persistedProviderIDs = providerPreferences?
            .load(knownProviderIDs: knownProviderIDs)
            .enabledProviderIDs

        self.runtime = runtime ?? UsageApplicationRuntime(providers: providers)
        self.providerDescriptors = descriptors
        self.knownProviderIDs = knownProviderIDs
        self.providerPreferences = providerPreferences
        self.enabledProviderIDs = (
            enabledProviderIDs ?? persistedProviderIDs ?? knownProviderIDs)
            .intersection(knownProviderIDs)
    }

    public func state() -> UsageApplicationSessionState {
        UsageApplicationSessionState(
            applicationState: self.applicationState,
            providerDescriptors: self.providerDescriptors,
            enabledProviderIDs: self.enabledProviderIDs,
            isRefreshing: self.isRefreshing)
    }

    /// Loads persisted history and growth state before the host starts using
    /// the session. Persistence errors are intentionally propagated.
    public func bootstrap() async throws {
        self.applicationState = try await self.runtime.loadHistory()
        self.applicationState = try await self.runtime.loadGrowthLedger()
    }

    /// Refreshes enabled providers and then attempts to persist a history
    /// sample. This operation shares the runtime's FIFO order with direct
    /// refresh and history calls. A history write failure must not discard a
    /// successful refresh.
    public func refresh(
        forceProviderReload: Bool = false,
        now: Date = .now) async
    {
        self.refreshOperationCount += 1
        self.isRefreshing = true
        defer {
            self.refreshOperationCount -= 1
            self.isRefreshing = self.refreshOperationCount > 0
        }

        self.applicationState = await self.runtime.refreshAndRecordHistory(
            enabledProviderIDs: self.enabledProviderIDs,
            forceProviderReload: forceProviderReload,
            now: now)
    }

    public func setEnabledProviderIDs(_ providerIDs: Set<ProviderID>) {
        let enabledProviderIDs = providerIDs.intersection(self.knownProviderIDs)
        self.enabledProviderIDs = self.providerPreferences?
            .setEnabledProviderIDs(
                enabledProviderIDs,
                knownProviderIDs: self.knownProviderIDs)
            .enabledProviderIDs ?? enabledProviderIDs
    }

    public func setEnabled(_ enabled: Bool, for providerID: ProviderID) {
        guard self.knownProviderIDs.contains(providerID) else { return }
        var enabledProviderIDs = self.enabledProviderIDs
        if enabled {
            enabledProviderIDs.insert(providerID)
        } else {
            enabledProviderIDs.remove(providerID)
        }
        self.setEnabledProviderIDs(enabledProviderIDs)
    }

    public func clearHistory() async throws {
        self.applicationState = try await self.runtime.clearHistory()
    }

    public func processGrowth(at now: Date = .now) async throws {
        _ = try await self.runtime.processGrowth(at: now)
        self.applicationState = await self.runtime.state()
    }

    public func markGrowthAwardApplied(_ awardID: GrowthEnergyAward.ID) async throws {
        _ = try await self.runtime.markGrowthAwardApplied(awardID)
        self.applicationState = await self.runtime.state()
    }

    /// Starts one cancellable refresh loop. Calling `start` again while the
    /// loop is active leaves the existing loop in place.
    public func start(refreshInterval: Duration = .seconds(60)) {
        guard self.periodicRefreshTask == nil else { return }

        self.periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                guard !Task.isCancelled else { return }

                do {
                    try await Task.sleep(for: refreshInterval)
                } catch {
                    return
                }
            }
        }
    }

    /// Cancels the periodic loop and waits for any refresh it already started
    /// to leave its `isRefreshing` critical section before returning.
    public func stop() async {
        guard let periodicRefreshTask = self.periodicRefreshTask else { return }
        periodicRefreshTask.cancel()
        self.periodicRefreshTask = nil
        await periodicRefreshTask.value
    }
}
