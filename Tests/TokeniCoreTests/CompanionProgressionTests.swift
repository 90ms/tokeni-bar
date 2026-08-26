import Testing
@testable import TokeniCore

struct CompanionProgressionTests {
    @Test("The standard curve starts quickly and reaches level 100 at 500 XP")
    func publishedThresholds() {
        let curve = CompanionLevelCurve.standard

        #expect(curve.totalXPRequired(forLevel: 1) == 0)
        #expect(curve.totalXPRequired(forLevel: 100) == 500)
        #expect(curve.level(forXP: 0) == 1)
        #expect(curve.level(forXP: 500) == 100)
    }

    @Test("Level costs rise toward a product maximum")
    func maximumLevel() {
        let curve = CompanionLevelCurve.standard

        #expect(curve.xpToNextLevel(from: 1) < curve.xpToNextLevel(from: 99))
        #expect(curve.xpToNextLevel(from: 100) == 0)
        #expect(curve.level(forXP: Int.max) == 100)
        #expect(curve.totalXPRequired(forLevel: 101) == 500)
        #expect(curve.clampedXP(Int.max) == 500)
    }

    @Test("Progress reports the fractional position inside a level")
    func progress() {
        let curve = CompanionLevelCurve.standard

        let level = 50
        let floor = curve.totalXPRequired(forLevel: level)
        let required = curve.xpToNextLevel(from: level)

        #expect(curve.xpIntoLevel(forXP: floor) == 0)
        #expect(curve.progress(forXP: floor) == 0)
        if required > 1 {
            #expect(curve.progress(forXP: floor + 1) > 0)
        }
        #expect(curve.progress(forXP: curve.maximumXP) == 1)
    }

    @Test("Evolution milestones are level-gated")
    func evolutionMilestones() {
        #expect(CompanionEvolutionRegistry.requiredLevel(for: .hatchling) == 1)
        #expect(CompanionEvolutionRegistry.requiredLevel(for: .junior) == 30)
        #expect(CompanionEvolutionRegistry.requiredLevel(for: .adult) == 70)
        #expect(CompanionEvolutionRegistry.next(after: .adult) == nil)
    }
}
