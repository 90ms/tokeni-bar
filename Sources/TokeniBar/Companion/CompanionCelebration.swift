import SwiftUI
import TokeniCore

struct CompanionCelebration: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case hatch
        case evolution
    }

    let id: UUID
    let kind: Kind
    let speciesID: CompanionSpeciesID
    let stage: CompanionGameStage
    let rarity: CompanionRarity
    let variantID: CompanionVariantID
    let personalityID: CompanionPersonalityID
    let isNewSpecies: Bool
    let fromStage: CompanionGameStage?

    init(
        id: UUID = UUID(),
        kind: Kind,
        speciesID: CompanionSpeciesID,
        stage: CompanionGameStage,
        rarity: CompanionRarity,
        variantID: CompanionVariantID,
        personalityID: CompanionPersonalityID,
        isNewSpecies: Bool = false,
        fromStage: CompanionGameStage? = nil)
    {
        self.id = id
        self.kind = kind
        self.speciesID = speciesID
        self.stage = stage
        self.rarity = rarity
        self.variantID = variantID
        self.personalityID = personalityID
        self.isNewSpecies = isNewSpecies
        self.fromStage = fromStage
    }
}

struct CompanionCelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let celebration: CompanionCelebration
    let animationsEnabled: Bool
    let dismiss: () -> Void

    @State private var revealed = false
    @State private var animationTask: Task<Void, Never>?
    @State private var lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(self.revealed ? 0.28 : 0.12)

                self.auraField(in: proxy.size)

                VStack(spacing: 18) {
                    Spacer()

                    self.petReveal

                    if self.revealed {
                        self.details
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer()

                    if self.revealed {
                        Button(AppLocalization.string("companion.celebration.continue")) {
                            self.dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .transition(.opacity)
                    }
                }
                .padding(32)
                .frame(maxWidth: 560, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .onAppear {
            self.startAnimation()
        }
        .onDisappear {
            self.animationTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: .NSProcessInfoPowerStateDidChange))
        { _ in
            self.lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            if self.lowPowerModeEnabled {
                self.animationTask?.cancel()
                withAnimation(.easeOut(duration: 0.2)) {
                    self.revealed = true
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(self.accessibilityLabel)
    }

    @ViewBuilder
    private var petReveal: some View {
        ZStack {
            if self.revealed || self.celebration.kind == .evolution {
                ByteBotSpriteView(
                    speciesID: self.celebration.speciesID,
                    stage: self.revealed
                        ? self.celebration.stage
                        : (self.celebration.fromStage ?? .hatchling),
                    rarity: self.celebration.rarity,
                    behavior: .celebrate,
                    dimension: 240,
                    animationsEnabled: self.animationsEnabled)
                    .scaleEffect(self.revealed ? 1 : 0.55)
                    .opacity(self.revealed ? 1 : 0.35)
            } else {
                Image(systemName: "oval.fill")
                    .font(.system(size: 116))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.white, .mint.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom))
                    .shadow(color: .mint.opacity(0.75), radius: 32)
                    .scaleEffect(self.revealed ? 0.25 : 1)
                    .opacity(self.revealed ? 0 : 1)
            }
        }
        .frame(width: 280, height: 280)
        .animation(
            self.motionAnimation(duration: 0.7),
            value: self.revealed)
    }

    private func auraField(in size: CGSize) -> some View {
        let diameter = min(size.width, size.height)
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .mint.opacity(self.revealed ? 0.18 : 0.42),
                            .blue.opacity(self.revealed ? 0.08 : 0.2),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: diameter * 0.42))
                .frame(width: diameter * 0.95, height: diameter * 0.95)
                .scaleEffect(self.revealed ? 1.2 : 0.45)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        index.isMultiple(of: 2)
                            ? Color.mint.opacity(0.7)
                            : Color.yellow.opacity(0.62),
                        lineWidth: index == 0 ? 3 : 1.5)
                    .frame(
                        width: diameter * (0.24 + CGFloat(index) * 0.17),
                        height: diameter * (0.24 + CGFloat(index) * 0.17))
                    .scaleEffect(self.revealed ? 2.5 : 0.28)
                    .opacity(self.revealed ? 0 : 0.9)
                    .rotationEffect(.degrees(self.revealed ? 120 : 0))
                    .animation(
                        self.motionAnimation(
                            duration: 0.9 + Double(index) * 0.16)
                            .delay(Double(index) * 0.08),
                        value: self.revealed)
            }

            ForEach(0..<16, id: \.self) { index in
                let angle = Double(index) * .pi / 8
                let distance = diameter * (self.revealed ? 0.38 : 0.08)
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: max(12, diameter * 0.025)))
                    .foregroundStyle(
                        index.isMultiple(of: 2) ? Color.yellow : Color.mint)
                    .offset(
                        x: CGFloat(cos(angle)) * distance,
                        y: CGFloat(sin(angle)) * distance)
                    .scaleEffect(self.revealed ? 0.4 : 0.2)
                    .opacity(self.revealed ? 0 : 0.95)
                    .animation(
                        self.motionAnimation(duration: 0.7)
                            .delay(Double(index) * 0.015),
                        value: self.revealed)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(spacing: 8) {
            Text(self.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(self.subtitle)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                CompanionVariantBadge(variantID: self.celebration.variantID)
                Text(AppLocalization.string(
                    "companion.personality.\(self.celebration.personalityID.rawValue)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    private var title: String {
        AppLocalization.string(
            self.celebration.kind == .hatch
                ? "companion.celebration.hatch.title"
                : "companion.celebration.evolution.title")
    }

    private var subtitle: String {
        let species = AppLocalization.string(
            "companion.species.\(self.celebration.speciesID.rawValue).name")
        if self.celebration.kind == .hatch {
            let discovery = AppLocalization.string(
                self.celebration.isNewSpecies
                    ? "companion.reveal.new"
                    : "companion.reveal.returning")
            return "\(discovery) · \(species)"
        }
        let stage = AppLocalization.string(
            "companion.stage.\(self.celebration.stage.rawValue)")
        return AppLocalization.format("companion.animation.evolved", stage)
    }

    private var accessibilityLabel: String {
        "\(self.title) \(self.subtitle)"
    }

    private func startAnimation() {
        guard self.animationTask == nil else { return }
        guard self.animationsEnabled,
              !self.reduceMotion,
              !self.lowPowerModeEnabled
        else {
            self.revealed = true
            return
        }

        self.animationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            withAnimation(self.motionAnimation(duration: 0.85)) {
                self.revealed = true
            }
            try? await Task.sleep(for: .milliseconds(2_600))
            guard !Task.isCancelled else { return }
            self.dismiss()
        }
    }

    private func motionAnimation(duration: Double) -> Animation {
        if self.reduceMotion || self.lowPowerModeEnabled {
            return .linear(duration: 0.01)
        }
        return .spring(response: duration, dampingFraction: 0.78)
    }
}
