import Foundation
import TokeniCore

/// The provider row data needed by a host UI.
///
/// This model keeps display adapters from reimplementing availability and
/// remaining-quota decisions for each platform. It contains no UI framework
/// types and remains safe to pass across an actor boundary.
public struct UsageApplicationProviderPresentation: Identifiable, Equatable, Sendable {
    public let descriptor: ProviderDescriptor
    public let availability: ProviderAvailability
    public let connectionState: ProviderConnectionState
    public let quotaWindows: [QuotaWindow]
    public let remainingPercent: Double?
    public let tokenTotal: Int64?
    public let costUSD: Double?
    public let detail: String?
    public let updatedAt: Date

    public var id: ProviderID { self.descriptor.id }

    public init(snapshot: ProviderSnapshot) {
        self.descriptor = snapshot.descriptor
        self.availability = snapshot.availability
        self.connectionState = snapshot.connectionState
            ?? (snapshot.availability == .available ? .localOnly : .stale)
        self.quotaWindows = snapshot.quotaWindows
        self.remainingPercent = snapshot.availability == .available
            ? snapshot.quotaWindows.map(\.remainingPercent).min()
            : nil
        self.tokenTotal = snapshot.tokenUsage?.totalTokens
        self.costUSD = snapshot.costEstimate?.amountUSD
        self.detail = snapshot.detail
        self.updatedAt = snapshot.updatedAt
    }
}

/// A platform-neutral presentation snapshot for tray or window hosts.
public struct UsageApplicationPresentation: Equatable, Sendable {
    public let providerDescriptors: [ProviderDescriptor]
    public let enabledProviderIDs: Set<ProviderID>
    public let providers: [UsageApplicationProviderPresentation]
    public let minimumRemainingPercent: Double?
    public let lastRefresh: Date?
    public let isRefreshing: Bool
    public let hasUnavailableData: Bool

    public init(sessionState: UsageApplicationSessionState) {
        let snapshots = sessionState.applicationState.snapshots
        self.providerDescriptors = sessionState.providerDescriptors
        self.enabledProviderIDs = sessionState.enabledProviderIDs
        self.providers = snapshots.map(UsageApplicationProviderPresentation.init)
        self.minimumRemainingPercent = UsageSummary.minimumRemainingPercent(
            in: snapshots)
        self.lastRefresh = sessionState.applicationState.lastRefresh
        self.isRefreshing = sessionState.isRefreshing
        self.hasUnavailableData = snapshots.contains {
            $0.availability != .available
        }
    }
}
