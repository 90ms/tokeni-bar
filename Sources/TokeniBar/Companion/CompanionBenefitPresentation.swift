import Foundation
import TokeniCore

enum CompanionBenefitPresentation {
    static func name(_ id: CompanionBenefitID) -> String {
        AppLocalization.string("companion.benefit.\(id.rawValue).name")
    }

    static func mode(_ activation: CompanionBenefitActivation) -> String {
        AppLocalization.string(
            "companion.benefit.mode.\(activation.rawValue)")
    }

    static func value(
        _ id: CompanionBenefitID,
        rarity: CompanionRarity) -> String
    {
        switch id {
        case .tokenOptimization:
            let tier = CompanionBenefitRegistry.tokenOptimization(for: rarity)
            return AppLocalization.format(
                "companion.benefit.tokenOptimization.value",
                tier.requiredBaseEnergy,
                tier.dailyCap)
        case .starlightCache:
            let tier = CompanionBenefitRegistry.starlightCache(for: rarity)
            return AppLocalization.format(
                "companion.benefit.starlightCache.value",
                Int(tier.interval / 3_600),
                tier.dailyCap)
        case .stackOptimization:
            return self.percentValue(
                key: "companion.benefit.stackOptimization.value",
                CompanionBenefitRegistry.stackOptimizationBasisPoints(
                    for: rarity))
        case .luckyCheer:
            return self.percentValue(
                key: "companion.benefit.luckyCheer.value",
                CompanionBenefitRegistry.luckyCheerBasisPoints(for: rarity))
        case .rewardAbsorption:
            return self.percentValue(
                key: "companion.benefit.rewardAbsorption.value",
                CompanionBenefitRegistry.rewardAbsorptionBasisPoints(
                    for: rarity))
        }
    }

    static func speciesName(_ speciesID: CompanionSpeciesID) -> String {
        AppLocalization.string(
            "companion.species.\(speciesID.rawValue).name")
    }

    static func rarityName(_ rarity: CompanionRarity) -> String {
        AppLocalization.string("companion.rarity.\(rarity.rawValue)")
    }

    private static func percentValue(
        key: String,
        _ basisPoints: Int) -> String
    {
        AppLocalization.format(key, Double(basisPoints) / 100)
    }
}
