import Foundation
import Testing
import TokeniApplication
import TokeniCore

struct ApplicationPresentationTests {
    @Test
    func mapsQuotaTokensAndConnectionStateWithoutInventingValues() {
        let available = Self.snapshot(
            id: .codex,
            availability: .available,
            quotaWindows: [
                QuotaWindow(
                    id: "daily",
                    kind: .custom,
                    label: "Daily",
                    usedPercent: 28),
                QuotaWindow(
                    id: "weekly",
                    kind: .weekly,
                    label: "Weekly",
                    usedPercent: 52),
            ],
            tokenTotal: 120,
            connectionState: nil)
        let unavailable = Self.snapshot(
            id: .claude,
            availability: .unavailable,
            quotaWindows: [
                QuotaWindow(
                    id: "daily",
                    kind: .custom,
                    label: "Daily",
                    usedPercent: 1),
            ],
            tokenTotal: nil,
            connectionState: nil,
            detail: "Sign in required")
        let sessionState = UsageApplicationSessionState(
            applicationState: UsageApplicationState(
                snapshots: [available, unavailable],
                lastRefresh: Self.fixedDate),
            providerDescriptors: [available.descriptor, unavailable.descriptor],
            enabledProviderIDs: [.codex, .claude],
            isRefreshing: true)

        let presentation = UsageApplicationPresentation(sessionState: sessionState)

        #expect(presentation.providers.count == 2)
        #expect(presentation.providers[0].remainingPercent == 48)
        #expect(presentation.providers[0].tokenTotal == 120)
        #expect(presentation.providers[0].connectionState == .localOnly)
        #expect(presentation.providers[1].remainingPercent == nil)
        #expect(presentation.providers[1].tokenTotal == nil)
        #expect(presentation.providers[1].connectionState == .stale)
        #expect(presentation.providers[1].detail == "Sign in required")
        #expect(presentation.minimumRemainingPercent == 48)
        #expect(presentation.hasUnavailableData)
        #expect(presentation.isRefreshing)
    }

    @Test
    func preservesExplicitConnectionState() {
        let snapshot = Self.snapshot(
            id: .codex,
            availability: .available,
            connectionState: .connected)
        let state = UsageApplicationSessionState(
            applicationState: UsageApplicationState(snapshots: [snapshot]),
            providerDescriptors: [snapshot.descriptor],
            enabledProviderIDs: [.codex])

        let presentation = UsageApplicationPresentation(sessionState: state)

        #expect(presentation.providers[0].connectionState == .connected)
        #expect(!presentation.hasUnavailableData)
    }

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static func snapshot(
        id: ProviderID,
        availability: ProviderAvailability,
        quotaWindows: [QuotaWindow] = [],
        tokenTotal: Int64? = nil,
        connectionState: ProviderConnectionState?,
        detail: String? = nil) -> ProviderSnapshot
    {
        ProviderSnapshot(
            descriptor: ProviderDescriptor(
                id: id,
                displayName: id.rawValue,
                shortName: id.rawValue,
                systemImage: "circle",
                capabilities: ProviderCapabilities(
                    supportsQuotaWindows: !quotaWindows.isEmpty,
                    supportsTokenUsage: tokenTotal != nil)),
            availability: availability,
            source: .localProtocol,
            quotaWindows: quotaWindows,
            tokenUsage: tokenTotal.map {
                TokenUsage(label: "Today", totalTokens: $0)
            },
            connectionState: connectionState,
            detail: detail,
            updatedAt: Self.fixedDate)
    }
}
