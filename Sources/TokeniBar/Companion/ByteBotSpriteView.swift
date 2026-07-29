import Combine
import Foundation
import SwiftUI
import TokeniCore

struct ByteBotSpriteView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    let speciesID: CompanionSpeciesID?
    let stage: CompanionGameStage
    let rarity: CompanionRarity
    let behavior: CompanionBehavior
    var dimension: CGFloat = 64
    var animationsEnabled = true

    var body: some View {
        let catalog = CompanionAssetCatalog.shared
        let animation = catalog.animation(
            for: self.speciesID,
            behavior: self.behavior)
        let shouldAnimate = self.animationsEnabled
            && !self.reduceMotion
            && !self.lowPowerModeEnabled
        TimelineView(.animation(
            minimumInterval: self.minimumInterval(for: animation),
            paused: !shouldAnimate))
        { context in
            let frameIndex = self.frameIndex(
                at: context.date,
                animation: animation,
                shouldAnimate: shouldAnimate)
            if let frame = catalog.frame(
                speciesID: self.speciesID,
                stage: self.stage,
                rarity: self.rarity,
                behavior: self.behavior,
                index: frameIndex)
            {
                Image(decorative: frame, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: self.dimension, height: self.dimension)
            } else {
                Image(systemName: "cpu")
                    .resizable()
                    .scaledToFit()
                    .padding(self.dimension * 0.2)
                    .frame(width: self.dimension, height: self.dimension)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: self.dimension, height: self.dimension)
        .accessibilityLabel(self.accessibilityName)
        .onReceive(NotificationCenter.default.publisher(
            for: .NSProcessInfoPowerStateDidChange))
        { _ in
            self.lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private var accessibilityName: String {
        guard let speciesID else {
            return AppLocalization.string("companion.species.mystery.name")
        }
        return AppLocalization.string(
            "companion.species.\(speciesID.rawValue).name")
    }

    private func minimumInterval(
        for animation: CompanionSpriteManifest.Animation?) -> TimeInterval
    {
        guard let framesPerSecond = animation?.framesPerSecond,
              framesPerSecond > 0
        else {
            return 1
        }
        return 1 / framesPerSecond
    }

    private func frameIndex(
        at date: Date,
        animation: CompanionSpriteManifest.Animation?,
        shouldAnimate: Bool) -> Int
    {
        guard shouldAnimate,
              let animation,
              animation.frameCount > 1,
              animation.framesPerSecond > 0
        else {
            return 0
        }
        let elapsedFrames = Int(
            floor(date.timeIntervalSinceReferenceDate * animation.framesPerSecond))
        if animation.loops {
            return elapsedFrames % animation.frameCount
        }
        return min(elapsedFrames, animation.frameCount - 1)
    }
}
