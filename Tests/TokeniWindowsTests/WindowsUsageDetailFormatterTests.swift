import Foundation
import Testing
import TokeniApplication
import TokeniCore
import TokeniWindows

struct WindowsUsageDetailFormatterTests {
    @Test
    func includesVerifiedQuotaResetTimeAndTokenTotal() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ProviderSnapshot(
            descriptor: ProviderDescriptor(
                id: .claude,
                displayName: "Claude Code",
                shortName: "Claude",
                systemImage: "circle",
                capabilities: ProviderCapabilities(supportsQuotaWindows: true)),
            availability: .available,
            source: .cli,
            quotaWindows: [
                QuotaWindow(
                    id: "five-hour",
                    kind: .session,
                    label: "5-hour",
                    usedPercent: 25,
                    resetsAt: now.addingTimeInterval(2 * 60 * 60 + 30 * 60)),
            ],
            tokenUsage: TokenUsage(label: "Today", totalTokens: 1234),
            updatedAt: now)
        let state = UsageApplicationSessionState(
            applicationState: UsageApplicationState(
                snapshots: [snapshot],
                lastRefresh: now),
            providerDescriptors: [snapshot.descriptor],
            enabledProviderIDs: [.claude])

        let text = WindowsUsageDetailFormatter.text(
            for: UsageApplicationPresentation(sessionState: state),
            now: now)

        #expect(text.contains("5-hour: 75% remaining"))
        #expect(text.contains("resets in 2h 30m"))
        #expect(text.contains("Tokens: 1234"))
    }

    @Test
    func doesNotInventResetTimeForUnavailableProvider() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ProviderSnapshot(
            descriptor: ProviderDescriptor(
                id: .claude,
                displayName: "Claude Code",
                shortName: "Claude",
                systemImage: "circle",
                capabilities: ProviderCapabilities(supportsQuotaWindows: true)),
            availability: .unavailable,
            source: nil,
            quotaWindows: [
                QuotaWindow(
                    id: "five-hour",
                    kind: .session,
                    label: "5-hour",
                    usedPercent: 25,
                    resetsAt: now.addingTimeInterval(3600)),
            ],
            detail: "Sign in required",
            updatedAt: now)
        let state = UsageApplicationSessionState(
            applicationState: UsageApplicationState(snapshots: [snapshot]),
            providerDescriptors: [snapshot.descriptor],
            enabledProviderIDs: [.claude])

        let text = WindowsUsageDetailFormatter.text(
            for: UsageApplicationPresentation(sessionState: state),
            now: now)

        #expect(text.contains("Usage unavailable"))
        #expect(!text.contains("resets in"))
    }
}
