import Combine
import Foundation
import SwiftUI
import TokeniCore

struct ByteBotTransitionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let speciesID: CompanionSpeciesID?
    let stage: CompanionGameStage
    let rarity: CompanionRarity?
    var variantID: CompanionVariantID? = nil
    let behavior: CompanionBehavior
    var mutationID: CompanionMutationID? = nil
    var cosmeticIDs: Set<CompanionCosmeticID> = []
    var dimension: CGFloat = 64
    var animationsEnabled = true
    var animationIntensity = 1.0
    var interactionPulse = 0
    var growthPulse = 0

    @State private var effect: Effect?
    @State private var expanded = false
    @State private var presentedKey: TransitionKey?
    @State private var effectTask: Task<Void, Never>?
    @State private var interactionOffset: CGSize = .zero
    @State private var interactionTask: Task<Void, Never>?
    @State private var ambientOffset: CGSize = .zero
    @State private var growthEffectVisible = false
    @State private var growthExpanded = false
    @State private var growthTask: Task<Void, Never>?
    @State private var lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        ZStack {
            if let cosmeticID = self.cosmeticID(in: .background) {
                CompanionCosmeticDecoration(
                    cosmeticID: cosmeticID,
                    dimension: self.dimension,
                    animationsEnabled: self.cosmeticMotionEnabled,
                    motionIntensity: self.animationIntensity,
                    isBackground: true)
            }

            if let cosmeticID = self.cosmeticID(in: .scene) {
                CompanionCosmeticDecoration(
                    cosmeticID: cosmeticID,
                    dimension: self.dimension,
                    animationsEnabled: self.cosmeticMotionEnabled,
                    motionIntensity: self.animationIntensity,
                    isBackground: true)
            }

            if let cosmeticID = self.cosmeticID(in: .aura) {
                CompanionCosmeticDecoration(
                    cosmeticID: cosmeticID,
                    dimension: self.dimension,
                    animationsEnabled: self.cosmeticMotionEnabled,
                    motionIntensity: self.animationIntensity,
                    lightBackground: self.cosmeticID(in: .background)
                        == .cloudGarden)
            }

            if let effect {
                self.burst(for: effect)
            }

            if self.growthEffectVisible {
                self.growthBurst
                    .transition(.opacity)
            }

            ByteBotSpriteView(
                speciesID: self.displayedKey.speciesID,
                stage: self.displayedKey.stage,
                rarity: self.displayedKey.rarity ?? .normal,
                variantID: self.displayedKey.variantID,
                behavior: self.behavior,
                dimension: self.dimension,
                animationsEnabled: self.animationsEnabled)
                .scaleEffect(self.displayedKey.stage == .adult ? 0.9 : 1)
                .scaleEffect(self.effect == nil ? 1 : (self.expanded ? 1.08 : 0.72))

            if let cosmeticID = self.cosmeticID(in: .sidekick) {
                CompanionCosmeticDecoration(
                    cosmeticID: cosmeticID,
                    dimension: self.dimension,
                    animationsEnabled: self.cosmeticMotionEnabled,
                    motionIntensity: self.animationIntensity)
            }


            if let cosmeticID = self.cosmeticID(in: .frame) {
                CompanionCosmeticDecoration(
                    cosmeticID: cosmeticID,
                    dimension: self.dimension,
                    animationsEnabled: self.cosmeticMotionEnabled,
                    motionIntensity: self.animationIntensity,
                    isBackground: true)
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
        .frame(
            width: self.displayDimension,
            height: self.displayDimension)
        .offset(
            x: self.interactionOffset.width + self.ambientOffset.width,
            y: self.interactionOffset.height + self.ambientOffset.height)
        .scaleEffect(self.growthExpanded ? 1.08 : 1)
        .onChange(of: self.transitionKey) { oldValue, newValue in
            self.handleTransition(from: oldValue, to: newValue)
        }
        .onChange(of: self.interactionPulse) { _, newValue in
            self.handleInteraction(pulse: newValue)
        }
        .onChange(of: self.growthPulse) { _, newValue in
            self.handleGrowth(pulse: newValue)
        }
        .onChange(of: self.animationsEnabled) { _, enabled in
            if !enabled {
                self.effectTask?.cancel()
                self.interactionTask?.cancel()
                self.growthTask?.cancel()
                self.effect = nil
                self.presentedKey = nil
                self.interactionOffset = .zero
                self.growthEffectVisible = false
                self.growthExpanded = false
            }
        }
        .onDisappear {
            self.effectTask?.cancel()
            self.interactionTask?.cancel()
            self.growthTask?.cancel()
        }
        .task(id: self.ambientMotionEnabled) {
            await self.runAmbientMotion()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: .NSProcessInfoPowerStateDidChange))
        { _ in
            self.lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            if self.lowPowerModeEnabled {
                self.effectTask?.cancel()
                self.interactionTask?.cancel()
                self.growthTask?.cancel()
                self.effect = nil
                self.presentedKey = nil
                self.interactionOffset = .zero
                self.growthEffectVisible = false
                self.growthExpanded = false
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

    private var growthBurst: some View {
        ZStack {
            Circle()
                .stroke(Color.mint.opacity(0.85), lineWidth: 2)
                .frame(width: self.dimension, height: self.dimension)
                .scaleEffect(self.growthExpanded ? 1.38 : 0.35)
                .opacity(self.growthExpanded ? 0 : 1)

            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) * .pi / 3
                Image(systemName: "sparkle")
                    .font(.system(size: max(self.dimension * 0.12, 7)))
                    .foregroundStyle(
                        index.isMultiple(of: 2) ? Color.mint : Color.yellow)
                    .offset(
                        x: self.growthExpanded
                            ? CGFloat(cos(angle)) * self.dimension * 0.52
                            : 0,
                        y: self.growthExpanded
                            ? CGFloat(sin(angle)) * self.dimension * 0.52
                            : 0)
                    .scaleEffect(self.growthExpanded ? 1 : 0.2)
                    .opacity(self.growthExpanded ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var transitionKey: TransitionKey {
        TransitionKey(
            speciesID: self.speciesID,
            stage: self.stage,
            rarity: self.rarity,
            variantID: self.variantID)
    }

    private var displayDimension: CGFloat {
        self.dimension
    }

    private var displayedKey: TransitionKey {
        self.presentedKey ?? self.transitionKey
    }

    private var ambientMotionEnabled: Bool {
        self.behavior == .idle
            && self.animationsEnabled
            && !self.reduceMotion
            && !self.lowPowerModeEnabled
    }

    private var cosmeticMotionEnabled: Bool {
        self.animationsEnabled
            && !self.reduceMotion
            && !self.lowPowerModeEnabled
    }

    private func cosmeticID(in slot: CompanionCosmeticSlot) -> CompanionCosmeticID? {
        self.cosmeticIDs.first { $0.slot == slot }
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
        let isEvolution = oldValue.stage != newValue.stage
            && oldValue.stage != .egg
            && newValue.stage != .egg
        if isEvolution,
           let rarity = newValue.rarity
        {
            effect = Effect(
                kind: .evolution,
                rarity: rarity,
                variantID: newValue.variantID,
                stage: newValue.stage)
        } else if oldValue.stage == .egg,
           newValue.stage == .hatchling,
           let rarity = newValue.rarity
        {
            effect = Effect(
                kind: .hatch,
                rarity: rarity,
                variantID: newValue.variantID,
                stage: newValue.stage)
        } else if let oldRarity = oldValue.rarity,
                  let newRarity = newValue.rarity,
                  newValue.variantID != oldValue.variantID
                    || newRarity.rank > oldRarity.rank
        {
            effect = Effect(
                kind: .rarityUp,
                rarity: newRarity,
                variantID: newValue.variantID,
                stage: newValue.stage)
        } else {
            effect = nil
        }
        guard let effect else { return }

        self.effectTask?.cancel()
        self.effect = effect
        self.presentedKey = isEvolution ? oldValue : nil
        self.expanded = isEvolution
        self.effectTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            if isEvolution {
                withAnimation(.easeIn(duration: 0.35)) {
                    self.expanded = false
                }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                self.presentedKey = newValue
            }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.58)) {
                self.expanded = true
            }
            try? await Task.sleep(for: .milliseconds(isEvolution ? 800 : 1_250))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.effect = nil
                self.presentedKey = nil
            }
        }
    }

    private func handleInteraction(pulse: Int) {
        guard pulse > 0,
              self.animationsEnabled,
              !self.reduceMotion,
              !self.lowPowerModeEnabled
        else { return }

        self.interactionTask?.cancel()
        let direction: CGFloat = pulse.isMultiple(of: 2) ? -1 : 1
        self.interactionTask = Task { @MainActor in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
                self.interactionOffset = CGSize(
                    width: direction * self.dimension * 0.18,
                    height: -self.dimension * 0.16)
            }
            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
                self.interactionOffset = .zero
            }
        }
    }

    private func handleGrowth(pulse: Int) {
        guard pulse > 0,
              self.animationsEnabled,
              !self.reduceMotion,
              !self.lowPowerModeEnabled
        else { return }

        self.growthTask?.cancel()
        self.growthEffectVisible = true
        self.growthExpanded = false
        self.growthTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                self.growthExpanded = true
            }
            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                self.growthEffectVisible = false
                self.growthExpanded = false
            }
        }
    }

    @MainActor
    private func runAmbientMotion() async {
        guard self.ambientMotionEnabled else {
            self.ambientOffset = .zero
            return
        }

        while !Task.isCancelled {
            try? await Task.sleep(
                for: .milliseconds(Int.random(in: 18_000...32_000)))
            guard !Task.isCancelled, self.ambientMotionEnabled else { return }
            let direction: CGFloat = Bool.random() ? -1 : 1
            withAnimation(.easeInOut(duration: 0.28)) {
                self.ambientOffset = CGSize(
                    width: direction * self.dimension * 0.07,
                    height: -self.dimension * 0.025)
            }
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.32)) {
                self.ambientOffset = .zero
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
        let variantID = effect.variantID
            ?? CompanionVariantRegistry.migrated(from: effect.rarity)
        let variant = AppLocalization.string(
            "companion.variant.\(variantID.rawValue)")
        switch effect.kind {
        case .evolution:
            let stage = AppLocalization.string(
                "companion.stage.\(effect.stage.rawValue)")
            return AppLocalization.format("companion.animation.evolved", stage)
        case .hatch:
            return AppLocalization.format("companion.animation.hatched", variant)
        case .rarityUp:
            return AppLocalization.format(
                "companion.animation.variantChanged",
                variant)
        }
    }
}

private struct TransitionKey: Equatable {
    let speciesID: CompanionSpeciesID?
    let stage: CompanionGameStage
    let rarity: CompanionRarity?
    let variantID: CompanionVariantID?
}

private struct Effect: Equatable {
    enum Kind: Equatable {
        case evolution
        case hatch
        case rarityUp
    }

    let kind: Kind
    let rarity: CompanionRarity
    let variantID: CompanionVariantID?
    let stage: CompanionGameStage
}
