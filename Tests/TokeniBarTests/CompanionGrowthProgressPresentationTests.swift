import Testing
import TokeniCore
@testable import TokeniBar

struct CompanionGrowthProgressPresentationTests {
    private let curve = CompanionLevelCurve(
        maximumLevel: 4,
        totalXPAtMaximumLevel: 9,
        exponent: 1)
    private let formula = TokenGrowthEnergyFormula(tokensPerEnergy: 100)

    @Test("Level 33 presents one of four XP as 25 Growth Energy")
    func scalesStandardLevelToOneHundred() {
        let standard = CompanionLevelCurve.standard
        let levelFloor = standard.totalXPRequired(forLevel: 33)
        let presentation = CompanionGrowthProgressPresentation(
            growthXP: levelFloor + 1)

        #expect(standard.xpToNextLevel(from: 33) == 4)
        #expect(presentation.progress == 0.25)
        #expect(presentation.displayedEnergy == 25)
    }

    @Test("Verified token remainder advances the visible progress")
    func includesTokenRemainderForGrowthTarget() {
        let presentation = CompanionGrowthProgressPresentation(
            growthXP: 1,
            remainderTokens: 50,
            includesTokenRemainder: true,
            curve: self.curve,
            formula: self.formula)

        #expect(presentation.progress == 0.5)
        #expect(presentation.displayedEnergy == 50)
    }

    @Test("Token remainder is hidden for a different growth target")
    func excludesTokenRemainderForOtherCompanion() {
        let presentation = CompanionGrowthProgressPresentation(
            growthXP: 1,
            remainderTokens: 50,
            includesTokenRemainder: false,
            curve: self.curve,
            formula: self.formula)

        #expect(presentation.displayedEnergy == 33)
    }

    @Test("Maximum level is presented as complete")
    func presentsMaximumLevelAsComplete() {
        let presentation = CompanionGrowthProgressPresentation(
            growthXP: self.curve.maximumXP,
            curve: self.curve,
            formula: self.formula)

        #expect(presentation.progress == 1)
        #expect(presentation.displayedEnergy == 100)
    }
}
