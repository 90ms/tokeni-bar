import Testing
import TokeniCore
import TokeniWindows

struct WindowsCompanionOverlayTests {
    @Test
    func overlayStateClampsUnsafeValues() {
        let state = WindowsCompanionOverlayState(
            stage: -2,
            level: -9,
            speciesIndex: -4,
            rarityRank: 8)

        #expect(state.stage == 0)
        #expect(state.level == 0)
        #expect(state.speciesIndex == 0)
        #expect(state.rarityRank == 3)
    }

    @Test
    func overlayStateContainsOnlyCompanionPresentationValues() {
        var companion = CompanionGameState()
        companion.stage = .hatchling
        companion.speciesID = CompanionSpeciesID.allCases.first
        companion.growthXP = CompanionLevelCurve.standard.totalXPRequired(
            forLevel: 4)

        let state = WindowsCompanionOverlayState(companionState: companion)

        #expect(state.stage == 1)
        #expect(state.level == 4)
        #expect(state.speciesIndex == 0)
        #expect(state.rarityRank == 0)
    }
}
