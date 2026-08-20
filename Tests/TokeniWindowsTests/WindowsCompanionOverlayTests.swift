import Testing
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
}
