import Foundation
import TokeniCore

struct CompanionGrowthProgressPresentation: Equatable {
    static let targetEnergy = 100

    let progress: Double
    let displayedEnergy: Int

    init(
        growthXP: Int,
        remainderTokens: Int64 = 0,
        includesTokenRemainder: Bool = false,
        curve: CompanionLevelCurve = .standard,
        formula: TokenGrowthEnergyFormula = .standard)
    {
        let normalizedXP = curve.clampedXP(growthXP)
        let level = curve.level(forXP: normalizedXP)
        guard level < curve.maximumLevel else {
            self.progress = 1
            self.displayedEnergy = Self.targetEnergy
            return
        }

        let requiredXP = curve.xpToNextLevel(from: level)
        let earnedXP = curve.xpIntoLevel(forXP: normalizedXP)
        let fractionalXP: Double
        if includesTokenRemainder, formula.tokensPerEnergy > 0 {
            let normalizedRemainder = min(
                max(remainderTokens, 0),
                formula.tokensPerEnergy - 1)
            fractionalXP = Double(normalizedRemainder)
                / Double(formula.tokensPerEnergy)
        } else {
            fractionalXP = 0
        }

        self.progress = min(
            max((Double(earnedXP) + fractionalXP) / Double(requiredXP), 0),
            1)
        self.displayedEnergy = min(
            Int((self.progress * Double(Self.targetEnergy)).rounded()),
            Self.targetEnergy - 1)
    }
}
