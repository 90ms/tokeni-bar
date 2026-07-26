import Foundation
import SwiftUI
import TokeniCore

struct ByteBotSpriteView: View {
    let stage: CompanionStage
    let behavior: CompanionBehavior
    var dimension: CGFloat = 64
    var animationsEnabled = true

    var body: some View {
        let catalog = ByteBotAssetCatalog.shared
        let animation = catalog.manifest?.animation(for: self.behavior)
        TimelineView(.animation(
            minimumInterval: self.minimumInterval(for: animation),
            paused: !self.animationsEnabled))
        { context in
            let frameIndex = self.frameIndex(
                at: context.date,
                animation: animation)
            if let frame = catalog.frame(
                stage: self.stage,
                behavior: self.behavior,
                index: frameIndex)
            {
                Image(decorative: frame, scale: 1)
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
        .accessibilityLabel("ByteBot")
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
        animation: CompanionSpriteManifest.Animation?) -> Int
    {
        guard self.animationsEnabled,
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
