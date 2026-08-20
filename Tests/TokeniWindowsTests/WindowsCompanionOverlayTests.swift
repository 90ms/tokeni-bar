import Testing
import TokeniWindows

struct WindowsCompanionOverlayTests {
    @Test
    func overlayStateClampsUnsafeValues() {
        let state = WindowsCompanionOverlayState(stage: -2, level: -9)

        #expect(state.stage == 0)
        #expect(state.level == 0)
    }
}
