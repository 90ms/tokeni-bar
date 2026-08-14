@testable import TokeniCore
import Foundation
import Testing

struct UsageCostSummaryTests {
    @Test
    func accumulatedCostCountsPositiveDeltasAndScopeResets() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let records = [
            self.record(provider: .codex, cost: 0.08, at: start.addingTimeInterval(-60)),
            self.record(provider: .codex, cost: 0.10, at: start),
            self.record(provider: .codex, cost: 0.30, at: start.addingTimeInterval(60)),
            self.record(provider: .claude, cost: 0.20, at: start.addingTimeInterval(90)),
            self.record(provider: .codex, cost: 0.05, at: start.addingTimeInterval(120)),
        ]

        let all = UsageCostSummary.accumulatedUSD(in: records, since: start)
        let codex = UsageCostSummary.accumulatedUSD(
            in: records,
            since: start,
            providerID: .codex)

        #expect(abs(all - 0.27) < 0.000_001)
        #expect(abs(codex - 0.27) < 0.000_001)
    }

    @Test
    func dailyCumulativeCostUsesEachProvidersMaximumPerDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let firstDay = try #require(TimestampParser.parse("2026-08-14T00:00:00Z"))
        let records = [
            self.record(provider: .codex, cost: 0.10, at: firstDay.addingTimeInterval(60)),
            self.record(provider: .codex, cost: 0.30, at: firstDay.addingTimeInterval(120)),
            self.record(provider: .claude, cost: 0.20, at: firstDay.addingTimeInterval(180)),
            self.record(provider: .codex, cost: 0.05, at: firstDay.addingTimeInterval(86_400)),
        ]

        let total = UsageCostSummary.dailyCumulativeUSD(
            in: records,
            since: firstDay,
            calendar: calendar)

        #expect(abs(total - 0.55) < 0.000_001)
    }

    private func record(
        provider: ProviderID,
        cost: Double,
        at timestamp: Date) -> UsageHistoryRecord
    {
        UsageHistoryRecord(
            timestamp: timestamp,
            providerID: provider,
            providerName: provider.rawValue,
            windows: [],
            tokenTotal: nil,
            costUSD: cost)
    }
}
