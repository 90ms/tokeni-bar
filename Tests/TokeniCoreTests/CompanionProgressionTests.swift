import Testing
@testable import TokeniCore

struct CompanionProgressionTests {
    @Test("The standard curve reaches the published early levels")
    func publishedThresholds() {
        let curve = CompanionLevelCurve.standard

        #expect(curve.totalXPRequired(forLevel: 1) == 0)
        #expect(curve.totalXPRequired(forLevel: 10) == 18)
        #expect(curve.totalXPRequired(forLevel: 25) == 66)
        #expect(curve.level(forXP: 17) == 9)
        #expect(curve.level(forXP: 18) == 10)
        #expect(curve.level(forXP: 66) == 25)
    }

    @Test("Level costs remain bounded without imposing a maximum level")
    func unboundedLevels() {
        let curve = CompanionLevelCurve.standard
        let highLevel = 1_000_000
        let xp = curve.totalXPRequired(forLevel: highLevel)

        #expect(curve.xpToNextLevel(from: highLevel) == 15)
        #expect(curve.level(forXP: xp) == highLevel)
        #expect(curve.level(forXP: xp + 15) == highLevel + 1)
    }

    @Test("Progress reports the fractional position inside a level")
    func progress() {
        let curve = CompanionLevelCurve.standard

        #expect(curve.xpIntoLevel(forXP: 19) == 1)
        #expect(curve.progress(forXP: 19) == 0.5)
    }

    @Test("Evolution milestones are level-gated")
    func evolutionMilestones() {
        #expect(CompanionEvolutionRegistry.requiredLevel(for: .hatchling) == 1)
        #expect(CompanionEvolutionRegistry.requiredLevel(for: .junior) == 10)
        #expect(CompanionEvolutionRegistry.requiredLevel(for: .adult) == 25)
        #expect(CompanionEvolutionRegistry.next(after: .adult) == nil)
    }
}
