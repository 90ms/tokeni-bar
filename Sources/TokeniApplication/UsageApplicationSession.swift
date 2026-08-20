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
    private var enabledProviderIDs: Set<ProviderID>
    private var applicationState = UsageApplicationState()
    private var isRefreshing = false
    private var refreshOperationCount = 0
    private var periodicRefreshTask: Task<Void, Never>?

    public init(
        providers: [any UsageProviding],
        runtime: UsageApplicationRuntime? = nil,
        enabledProviderIDs: Set<ProviderID>? = nil)
    {
        let descriptors = providers.map(\.descriptor)
        let knownProviderIDs = Set(descriptors.map(\.id))

        self.runtime = runtime ?? UsageApplicationRuntime(providers: providers)
        self.providerDescriptors = descriptors
        self.knownProviderIDs = knownProviderIDs
        self.enabledProviderIDs = (enabledProviderIDs ?? knownProviderIDs)
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
    /// sample. A history write failure must not discard a successful refresh.
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

        let refreshedState = await self.runtime.refresh(
            enabledProviderIDs: self.enabledProviderIDs,
            forceProviderReload: forceProviderReload,
            now: now)
        self.applicationState = refreshedState

        do {
            self.applicationState = try await self.runtime.recordHistory(at: now)
        } catch {
            // Usage data is still valid when its optional history sample could
            // not be saved. Keep the state returned by the provider refresh.
        }
    }

    public func setEnabledProviderIDs(_ providerIDs: Set<ProviderID>) {
        self.enabledProviderIDs = providerIDs.intersection(self.knownProviderIDs)
    }

    public func setEnabled(_ enabled: Bool, for providerID: ProviderID) {
        guard self.knownProviderIDs.contains(providerID) else { return }
        if enabled {
            self.enabledProviderIDs.insert(providerID)
        } else {
            self.enabledProviderIDs.remove(providerID)
        }
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

    public func stop() {
        self.periodicRefreshTask?.cancel()
        self.periodicRefreshTask = nil
    }
}
