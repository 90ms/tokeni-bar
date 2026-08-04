import Foundation

public struct TokenGrowthEnergyFormula: Hashable, Sendable {
    public static let standard = TokenGrowthEnergyFormula(
        tokensPerEnergy: 25_000)

    public let tokensPerEnergy: Int64

    public init(tokensPerEnergy: Int64) {
        self.tokensPerEnergy = max(tokensPerEnergy, 0)
    }

    /// Returns a linear, uncapped energy amount for verified tokens.
    public func energy(forDailyTokens tokens: Int64) -> Int {
        guard tokens > 0, self.tokensPerEnergy > 0 else { return 0 }
        let value = tokens / self.tokensPerEnergy
        return value >= Int64(Int.max) ? Int.max : Int(value)
    }

    /// Returns the smallest token total that reaches `targetEnergy`.
    public func minimumDailyTokens(forEnergy targetEnergy: Int) -> Int64? {
        guard targetEnergy > 0 else { return 0 }
        guard self.tokensPerEnergy > 0 else { return nil }
        let (tokens, overflow) = Int64(targetEnergy)
            .multipliedReportingOverflow(by: self.tokensPerEnergy)
        return overflow ? nil : tokens
    }

    /// Returns the additional tokens required to gain one more energy.
    public func additionalTokensForNextEnergy(afterDailyTokens tokens: Int64) -> Int64? {
        let normalizedTokens = max(tokens, 0)
        let currentEnergy = self.energy(forDailyTokens: normalizedTokens)
        guard currentEnergy < Int.max,
              let threshold = self.minimumDailyTokens(forEnergy: currentEnergy + 1)
        else { return nil }
        return max(threshold - normalizedTokens, 0)
    }
}
