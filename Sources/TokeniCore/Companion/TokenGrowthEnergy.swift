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

    /// Returns the smallest daily token total that reaches `targetEnergy`.
    ///
    /// The curve is monotonic, so a binary search avoids exposing floating-point
    /// inversion details to callers and preserves the exact rounding behavior of
    /// `energy(forDailyTokens:)`.
    public func minimumDailyTokens(forEnergy targetEnergy: Int) -> Int64? {
        guard targetEnergy > 0 else { return 0 }
        guard self.scale > 0,
              self.energy(forDailyTokens: Int64.max) >= targetEnergy
        else { return nil }

        var lower: Int64 = 0
        var upper: Int64 = 1
        while self.energy(forDailyTokens: upper) < targetEnergy {
            if upper > Int64.max / 2 {
                upper = Int64.max
                break
            }
            upper *= 2
        }

        while lower < upper {
            let midpoint = lower + (upper - lower) / 2
            if self.energy(forDailyTokens: midpoint) >= targetEnergy {
                upper = midpoint
            } else {
                lower = midpoint + 1
            }
        }
        return lower
    }

    /// Returns the additional tokens required to increase today's energy target
    /// by one point.
    public func additionalTokensForNextEnergy(afterDailyTokens tokens: Int64) -> Int64? {
        let normalizedTokens = max(tokens, 0)
        let currentEnergy = self.energy(forDailyTokens: normalizedTokens)
        guard currentEnergy < Int.max,
              let threshold = self.minimumDailyTokens(forEnergy: currentEnergy + 1)
        else { return nil }
        return max(threshold - normalizedTokens, 0)
    }
}
