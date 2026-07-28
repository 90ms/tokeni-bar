import Combine
import Foundation
import SwiftUI
import TokeniCore

struct ByteBotTransitionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let speciesID: CompanionSpeciesID?
    let stage: CompanionGameStage
    let rarity: CompanionRarity?
    let behavior: CompanionBehavior
    var cosmeticID: CompanionCosmeticID? = nil
    var dimension: CGFloat = 64
    var animationsEnabled = true

    @State private var effect: Effect?
    @State private var expanded = false
    @State private var effectTask: Task<Void, Never>?
    @State private var lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        ZStack {
            if let effect {
                self.burst(for: effect)
            }

            ByteBotSpriteView(
                speciesID: self.speciesID,
                stage: self.stage,
                rarity: self.rarity ?? .normal,
                behavior: self.behavior,
                dimension: self.dimension,
                animationsEnabled: self.animationsEnabled)
                .scaleEffect(self.effect == nil ? 1 : (self.expanded ? 1.08 : 0.72))

            if let cosmeticID = self.cosmeticID {
                CompanionCosmeticDecoration(
                    cosmeticID: cosmeticID,
                    dimension: self.dimension)
            }

            if let effect {
                Text(self.message(for: effect))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(self.color(for: effect))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -(self.dimension * 0.42))
                    .opacity(self.expanded ? 1 : 0)
            }
        }
        .frame(width: self.dimension, height: self.dimension)
        .onChange(of: self.transitionKey) { oldValue, newValue in
            self.handleTransition(from: oldValue, to: newValue)
        }
        .onChange(of: self.animationsEnabled) { _, enabled in
            if !enabled {
                self.effectTask?.cancel()
                self.effect = nil
            }
        }
        .onDisappear {
            self.effectTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: .NSProcessInfoPowerStateDidChange))
        { _ in
            self.lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            if self.lowPowerModeEnabled {
                self.effectTask?.cancel()
                self.effect = nil
            }
        }
    }

    private func burst(for effect: Effect) -> some View {
        let color = self.color(for: effect)
        return ZStack {
            Circle()
                .stroke(color.opacity(0.8), lineWidth: 3)
                .frame(width: self.dimension, height: self.dimension)
                .scaleEffect(self.expanded ? 1.55 : 0.2)
                .opacity(self.expanded ? 0 : 1)

            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * .pi / 4
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: max(self.dimension * 0.12, 7)))
                    .foregroundStyle(color)
                    .offset(
                        x: self.expanded
                            ? CGFloat(cos(angle)) * self.dimension * 0.62
                            : 0,
                        y: self.expanded
                            ? CGFloat(sin(angle)) * self.dimension * 0.62
                            : 0)
                    .scaleEffect(self.expanded ? 1 : 0.25)
                    .opacity(self.expanded ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var transitionKey: TransitionKey {
        TransitionKey(
            speciesID: self.speciesID,
            stage: self.stage,
            rarity: self.rarity)
    }

    private func handleTransition(
        from oldValue: TransitionKey,
        to newValue: TransitionKey)
    {
        guard self.animationsEnabled,
              !self.reduceMotion,
              !self.lowPowerModeEnabled
        else { return }

        let effect: Effect?
        if oldValue.stage == .egg,
           newValue.stage == .hatchling,
           let rarity = newValue.rarity
        {
            effect = Effect(kind: .hatch, rarity: rarity)
        } else if let oldRarity = oldValue.rarity,
                  let newRarity = newValue.rarity,
                  newRarity.rank > oldRarity.rank
        {
            effect = Effect(kind: .rarityUp, rarity: newRarity)
        } else {
            effect = nil
        }
        guard let effect else { return }

        self.effectTask?.cancel()
        self.effect = effect
        self.expanded = false
        self.effectTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.58)) {
                self.expanded = true
            }
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.effect = nil
            }
        }
    }

    private func color(for effect: Effect) -> Color {
        switch effect.rarity {
        case .normal: .mint
        case .rare: .blue
        case .epic: .purple
        case .legendary: .yellow
        }
    }

    private func message(for effect: Effect) -> String {
        let rarity = AppLocalization.string(
            "companion.rarity.\(effect.rarity.rawValue)")
        switch effect.kind {
        case .hatch:
            return AppLocalization.format("companion.animation.hatched", rarity)
        case .rarityUp:
            return AppLocalization.format("companion.animation.rarityUp", rarity)
        }
    }
}

private struct TransitionKey: Equatable {
    let speciesID: CompanionSpeciesID?
    let stage: CompanionGameStage
    let rarity: CompanionRarity?
}

private struct Effect: Equatable {
    enum Kind: Equatable {
        case hatch
        case rarityUp
    }

    let kind: Kind
    let rarity: CompanionRarity
}
