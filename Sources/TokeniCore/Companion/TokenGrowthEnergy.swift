import Foundation

public struct TokenGrowthEnergyFormula: Hashable, Sendable {
    public static let standard = TokenGrowthEnergyFormula(
        scale: 32,
        tokenUnit: 25_000)

    public let scale: Double
    public let tokenUnit: Double

    public init(scale: Double, tokenUnit: Double) {
        self.scale = max(scale, 0)
        self.tokenUnit = max(tokenUnit, 1)
    }

    /// Returns a monotonic, uncapped energy target for one local calendar day.
    public func energy(forDailyTokens tokens: Int64) -> Int {
        guard tokens > 0, self.scale > 0 else { return 0 }
        let value = floor(self.scale * log2(1 + Double(tokens) / self.tokenUnit))
        guard value.isFinite, value > 0 else { return 0 }
        return value >= Double(Int.max) ? Int.max : Int(value)
    }
}
