@testable import TokeniCore
import Foundation
import Testing

struct AccountTokenUsageSummaryTests {
    private let seoul = TimeZone(identifier: "Asia/Seoul")!
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    @Test
    func aggregatesTodayCurrentMonthAndLifetime() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-21T12:00:00Z"))
        let buckets = [
            AccountDailyTokenBucket(startDate: "2026-06-30", tokenCount: 90),
            AccountDailyTokenBucket(startDate: "2026-07-01", tokenCount: 100),
            AccountDailyTokenBucket(startDate: "2026-07-21", tokenCount: 20),
            AccountDailyTokenBucket(startDate: "2026-07-21", tokenCount: 30),
        ]

        let summary = AccountTokenUsageAggregator.summarize(
            dailyBuckets: buckets,
            lifetimeTokens: 5_000,
            now: now,
            timeZone: self.seoul)

        #expect(summary.todayTokens == 50)
        #expect(summary.latestDailyTokens == 50)
        #expect(summary.currentMonthTokens == 150)
        #expect(summary.lifetimeTokens == 5_000)
        #expect(summary.localDate == "2026-07-21")
        #expect(summary.latestBucketDate == "2026-07-21")
        #expect(summary.discardedBucketCount == 0)
        #expect(summary.didClampOverflow == false)
    }

    @Test
    func missingTodayKeepsTheLatestDailyBucketVisible() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-21T12:00:00Z"))
        let summary = AccountTokenUsageAggregator.summarize(
            dailyBuckets: [
                AccountDailyTokenBucket(startDate: "2026-07-01", tokenCount: 40),
                AccountDailyTokenBucket(startDate: "2026-07-20", tokenCount: 60),
            ],
            lifetimeTokens: 100,
            now: now,
            timeZone: self.seoul)

        #expect(summary.todayTokens == nil)
        #expect(summary.latestDailyTokens == 60)
        #expect(summary.currentMonthTokens == 100)
        #expect(summary.latestBucketDate == "2026-07-20")
        #expect(summary.discardedBucketCount == 0)
    }

    @Test
    func appliesTheRequestedTimeZoneAtTheDateBoundary() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-21T00:30:00Z"))
        let buckets = [
            AccountDailyTokenBucket(startDate: "2026-07-20", tokenCount: 20),
            AccountDailyTokenBucket(startDate: "2026-07-21", tokenCount: 21),
        ]

        let seoul = AccountTokenUsageAggregator.summarize(
            dailyBuckets: buckets,
            lifetimeTokens: 41,
            now: now,
            timeZone: self.seoul)
        let losAngeles = AccountTokenUsageAggregator.summarize(
            dailyBuckets: buckets,
            lifetimeTokens: 41,
            now: now,
            timeZone: self.losAngeles)

        #expect(seoul.localDate == "2026-07-21")
        #expect(seoul.todayTokens == 21)
        #expect(seoul.latestDailyTokens == 21)
        #expect(losAngeles.localDate == "2026-07-20")
        #expect(losAngeles.todayTokens == 20)
        #expect(losAngeles.latestDailyTokens == 20)
        #expect(losAngeles.discardedBucketCount == 1)
    }

    @Test
    func discardsInvalidNegativeAndFutureBucketsAndClampsOverflow() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-21T12:00:00Z"))
        let summary = AccountTokenUsageAggregator.summarize(
            dailyBuckets: [
                AccountDailyTokenBucket(startDate: "2026-02-31", tokenCount: 1),
                AccountDailyTokenBucket(startDate: "2026-07-20", tokenCount: -1),
                AccountDailyTokenBucket(startDate: "2026-07-22", tokenCount: 1),
                AccountDailyTokenBucket(startDate: "2026-07-21", tokenCount: .max),
                AccountDailyTokenBucket(startDate: "2026-07-21", tokenCount: 1),
            ],
            lifetimeTokens: -10,
            now: now,
            timeZone: self.seoul)

        #expect(summary.todayTokens == .max)
        #expect(summary.latestDailyTokens == .max)
        #expect(summary.currentMonthTokens == .max)
        #expect(summary.lifetimeTokens == 0)
        #expect(summary.discardedBucketCount == 3)
        #expect(summary.didClampOverflow)
    }

    @Test
    func estimatesExplicitApiEquivalentReferenceCosts() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-07-21T12:00:00Z"))
        let estimator = try #require(
            AccountTokenReferenceCostEstimator.codexInputOutputReferenceV1(at: referenceDate))
        let summary = AccountTokenUsageSummary(
            todayTokens: 2_000_000,
            currentMonthTokens: 10_000_000,
            lifetimeTokens: 100_000_000,
            localDate: "2026-07-21")

        let costs = estimator.estimate(summary: summary)

        #expect(estimator.assumption.profileVersion == 1)
        #expect(estimator.assumption.profileID == "codex-reference-80-input-20-output-v1")
        #expect(estimator.assumption.referenceModelID == "gpt-5-codex")
        #expect(estimator.assumption.inputTokenShare == 0.8)
        #expect(estimator.assumption.outputTokenShare == 0.2)
        #expect(estimator.assumption.cachedInputTokenShare == 0)
        #expect(estimator.assumption.usdPerMillionTokens == 3)
        #expect(costs.today?.amountUSD == 6)
        #expect(costs.currentMonth.amountUSD == 30)
        #expect(costs.lifetime.amountUSD == 300)
        #expect(costs.today?.isApproximate == true)
        #expect(costs.today?.disclosureID == "api-equivalent-reference-not-actual-charge")
    }

    @Test
    func normalizesNegativeTokensAndKeepsMaximumAmountFinite() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-07-21T12:00:00Z"))
        let estimator = try #require(
            AccountTokenReferenceCostEstimator.codexInputOutputReferenceV1(at: referenceDate))

        let negative = estimator.estimate(tokenCount: -1)
        let maximum = estimator.estimate(tokenCount: .max)

        #expect(negative.tokenCount == 0)
        #expect(negative.amountUSD == 0)
        #expect(maximum.tokenCount == .max)
        #expect(maximum.amountUSD.isFinite)
    }
}
