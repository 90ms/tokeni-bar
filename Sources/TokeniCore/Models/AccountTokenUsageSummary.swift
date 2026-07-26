import Foundation

/// A date-only account usage bucket returned by a provider account service.
/// `startDate` must use the Gregorian `yyyy-MM-dd` format.
public struct AccountDailyTokenBucket: Codable, Hashable, Sendable {
    public let startDate: String
    public let tokenCount: Int64

    public init(startDate: String, tokenCount: Int64) {
        self.startDate = startDate
        self.tokenCount = tokenCount
    }
}

/// Provider-account totals aligned to one explicit local calendar boundary.
public struct AccountTokenUsageSummary: Hashable, Sendable {
    public let todayTokens: Int64?
    public let latestDailyTokens: Int64?
    public let currentMonthTokens: Int64
    public let lifetimeTokens: Int64
    public let localDate: String
    public let latestBucketDate: String?
    public let discardedBucketCount: Int
    public let didClampOverflow: Bool

    public init(
        todayTokens: Int64?,
        latestDailyTokens: Int64? = nil,
        currentMonthTokens: Int64,
        lifetimeTokens: Int64,
        localDate: String,
        latestBucketDate: String? = nil,
        discardedBucketCount: Int = 0,
        didClampOverflow: Bool = false)
    {
        self.todayTokens = todayTokens.map { max($0, 0) }
        self.latestDailyTokens = latestDailyTokens.map { max($0, 0) }
        self.currentMonthTokens = max(currentMonthTokens, 0)
        self.lifetimeTokens = max(lifetimeTokens, 0)
        self.localDate = localDate
        self.latestBucketDate = latestBucketDate
        self.discardedBucketCount = max(discardedBucketCount, 0)
        self.didClampOverflow = didClampOverflow
    }
}

public enum AccountTokenUsageAggregator {
    /// Summarizes date-only buckets using Gregorian dates in `timeZone`.
    ///
    /// Invalid, negative, and future buckets are discarded. Duplicate dates are
    /// added, and an integer overflow saturates at `Int64.max` rather than wrapping.
    public static func summarize(
        dailyBuckets: [AccountDailyTokenBucket],
        lifetimeTokens: Int64,
        now: Date = .now,
        timeZone: TimeZone = .current) -> AccountTokenUsageSummary
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone

        let today = calendar.dateComponents([.year, .month, .day], from: now)
        let todayKey = self.dateKey(today)
        var todayTokens: Int64?
        var latestDailyTokens: Int64?
        var currentMonthTokens: Int64 = 0
        var latestBucketDate: String?
        var discardedBucketCount = 0
        var didClampOverflow = false

        for bucket in dailyBuckets {
            guard bucket.tokenCount >= 0,
                  let components = self.parseDate(bucket.startDate, calendar: calendar),
                  self.isNotAfter(components, today)
            else {
                discardedBucketCount += 1
                continue
            }

            if latestBucketDate.map({ bucket.startDate > $0 }) != false {
                latestBucketDate = bucket.startDate
                latestDailyTokens = bucket.tokenCount
            } else if bucket.startDate == latestBucketDate {
                let addition = self.saturatedAdd(latestDailyTokens ?? 0, bucket.tokenCount)
                latestDailyTokens = addition.value
                didClampOverflow = didClampOverflow || addition.didClamp
            }

            if self.isSameDay(components, today) {
                let addition = self.saturatedAdd(todayTokens ?? 0, bucket.tokenCount)
                todayTokens = addition.value
                didClampOverflow = didClampOverflow || addition.didClamp
            }
            if components.year == today.year, components.month == today.month {
                let addition = self.saturatedAdd(currentMonthTokens, bucket.tokenCount)
                currentMonthTokens = addition.value
                didClampOverflow = didClampOverflow || addition.didClamp
            }
        }

        return AccountTokenUsageSummary(
            todayTokens: todayTokens,
            latestDailyTokens: latestDailyTokens,
            currentMonthTokens: currentMonthTokens,
            lifetimeTokens: lifetimeTokens,
            localDate: todayKey,
            latestBucketDate: latestBucketDate,
            discardedBucketCount: discardedBucketCount,
            didClampOverflow: didClampOverflow)
    }

    private static func parseDate(_ value: String, calendar: Calendar) -> DateComponents? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard value.count == 10,
              parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }

        var requested = DateComponents()
        requested.calendar = calendar
        requested.timeZone = calendar.timeZone
        requested.year = year
        requested.month = month
        requested.day = day
        requested.hour = 12

        guard let date = calendar.date(from: requested) else { return nil }
        let normalized = calendar.dateComponents([.year, .month, .day], from: date)
        guard normalized.year == year,
              normalized.month == month,
              normalized.day == day
        else { return nil }
        return normalized
    }

    private static func dateKey(_ components: DateComponents) -> String {
        String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0)
    }

    private static func isSameDay(_ lhs: DateComponents, _ rhs: DateComponents) -> Bool {
        lhs.year == rhs.year && lhs.month == rhs.month && lhs.day == rhs.day
    }

    private static func isNotAfter(_ lhs: DateComponents, _ rhs: DateComponents) -> Bool {
        self.dateKey(lhs) <= self.dateKey(rhs)
    }

    private static func saturatedAdd(_ lhs: Int64, _ rhs: Int64) -> (value: Int64, didClamp: Bool) {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? (.max, true) : (result.partialValue, false)
    }
}
