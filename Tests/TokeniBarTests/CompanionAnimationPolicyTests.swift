import Testing
@testable import TokeniBar

struct CompanionAnimationPolicyTests {
    @Test("Animation runs only while every motion gate permits it")
    func animationGates() {
        #expect(CompanionAnimationPolicy.shouldAnimate(
            animationsEnabled: true,
            reduceMotion: false,
            lowPowerModeEnabled: false,
            isVisible: true,
            sceneIsActive: true))

        let blockedStates = [
            (false, false, false, true, true),
            (true, true, false, true, true),
            (true, false, true, true, true),
            (true, false, false, false, true),
            (true, false, false, true, false),
        ]
        for state in blockedStates {
            #expect(!CompanionAnimationPolicy.shouldAnimate(
                animationsEnabled: state.0,
                reduceMotion: state.1,
                lowPowerModeEnabled: state.2,
                isVisible: state.3,
                sceneIsActive: state.4))
        }
    }
}
