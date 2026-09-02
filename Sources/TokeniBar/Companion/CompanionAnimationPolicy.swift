struct CompanionAnimationPolicy {
    static func shouldAnimate(
        animationsEnabled: Bool,
        reduceMotion: Bool,
        lowPowerModeEnabled: Bool,
        isVisible: Bool,
        sceneIsActive: Bool) -> Bool
    {
        animationsEnabled
            && !reduceMotion
            && !lowPowerModeEnabled
            && isVisible
            && sceneIsActive
    }
}
