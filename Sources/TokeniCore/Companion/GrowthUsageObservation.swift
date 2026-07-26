import Foundation

public enum GrowthUsageScope: String, Codable, Hashable, Sendable {
    case daily
    case lifetime
    case session
}

/// A provider-neutral cumulative token measurement used by the companion game.
///
/// `scopeID` must be stable for the lifetime of one counter and must not contain
/// credentials, account identifiers, prompts, response content, or absolute paths.
public struct GrowthUsageObservation: Codable, Hashable, Sendable {
    public let providerID: ProviderID
    public let scope: GrowthUsageScope
    public let scopeID: String
    public let totalTokens: Int64
    public let observedAt: Date

    public init(
        providerID: ProviderID,
        scope: GrowthUsageScope,
        scopeID: String,
        totalTokens: Int64,
        observedAt: Date)
    {
        self.providerID = providerID
        self.scope = scope
        self.scopeID = scopeID
        self.totalTokens = totalTokens
        self.observedAt = observedAt
    }

    public static func daily(
        providerID: ProviderID,
        dateKey: String,
        totalTokens: Int64,
        observedAt: Date) -> Self
    {
        Self(
            providerID: providerID,
            scope: .daily,
            scopeID: dateKey,
            totalTokens: totalTokens,
            observedAt: observedAt)
    }

    public var measurementKey: String {
        "\(self.providerID.rawValue):\(self.scope.rawValue):\(self.scopeID)"
    }
}

public enum GrowthLocalDate {
    public static func key(
        for date: Date,
        calendar requestedCalendar: Calendar = .current) -> String
    {
        var calendar = requestedCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0)
    }
}
