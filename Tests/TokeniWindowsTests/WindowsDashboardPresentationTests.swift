import Foundation
import Testing
import TokeniApplication
import TokeniCore
import TokeniWindows

struct WindowsDashboardPresentationTests {
    @Test func emptyDashboardExplainsHowToStart() {
        let dashboard = WindowsDashboardPresentation(
            UsageApplicationPresentation(sessionState: UsageApplicationSessionState()))
        #expect(dashboard.rows.isEmpty)
        #expect(dashboard.summary.contains("Settings"))
        #expect(!dashboard.refreshing)
    }

    @Test func staleValuesAreNotPresentedAsCurrentQuota() {
        let descriptor = ProviderDescriptor(id: .claude, displayName: "Claude", shortName: "Claude",
            systemImage: "circle", capabilities: ProviderCapabilities(supportsQuotaWindows: true))
        let snapshot = ProviderSnapshot(descriptor: descriptor, availability: .stale, source: nil,
            quotaWindows: [QuotaWindow(id: "session", kind: .session, label: "Session", usedPercent: 25)],
            tokenUsage: TokenUsage(label: "Today", totalTokens: 1234), updatedAt: .now)
        let dashboard = WindowsDashboardPresentation(UsageApplicationPresentation(sessionState:
            UsageApplicationSessionState(applicationState: UsageApplicationState(snapshots: [snapshot]),
                providerDescriptors: [descriptor], enabledProviderIDs: [.claude])))
        #expect(dashboard.rows == [["Claude", "Stale · refresh needed", "—", "—", "—", "—"]])
    }
}
