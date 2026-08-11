import SwiftUI
import TokeniCore

struct CompanionHatchReveal: Identifiable, Equatable {
    let id = UUID()
    let speciesID: CompanionSpeciesID
    let rarity: CompanionRarity
    let variantID: CompanionVariantID
    let personalityID: CompanionPersonalityID
    let isNewSpecies: Bool
}

struct CompanionHatchBatchReveal: Identifiable, Equatable {
    let id = UUID()
    let reveals: [CompanionHatchReveal]
}

struct CompanionHatchBatchRevealView: View {
    let batch: CompanionHatchBatchReveal
    let animationsEnabled: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(AppLocalization.string("companion.reveal.batch.title"))
                .font(.title2.bold())
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 5),
                spacing: 12)
            {
                ForEach(self.batch.reveals) { reveal in
                    VStack(spacing: 5) {
                        ByteBotSpriteView(
                            speciesID: reveal.speciesID,
                            stage: .hatchling,
                            rarity: reveal.rarity,
                            behavior: reveal.variantID == .standard
                                ? .idle
                                : .celebrate,
                            dimension: 72,
                            animationsEnabled: self.animationsEnabled)
                        Text(AppLocalization.string(
                            "companion.species.\(reveal.speciesID.rawValue).name"))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        CompanionVariantBadge(variantID: reveal.variantID)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(
                        self.cardColor(for: reveal.variantID),
                        in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Button(AppLocalization.string("companion.reveal.continue")) {
                self.dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 430)
    }

    private func cardColor(_ variantID: CompanionVariantID) -> Color {
        switch variantID {
        case .standard: Color.secondary.opacity(0.08)
        case .prismatic: Color.pink.opacity(0.18)
        case .mutated: Color.purple.opacity(0.2)
        }
    }
}

struct CompanionHatchRevealView: View {
    let reveal: CompanionHatchReveal
    let animationsEnabled: Bool
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            self.specialBackground

            VStack(spacing: 16) {
            Text(AppLocalization.string(
                self.reveal.isNewSpecies
                    ? "companion.reveal.new"
                    : "companion.reveal.returning"))
                .font(.headline)
                .foregroundStyle(.secondary)

            ByteBotSpriteView(
                speciesID: self.reveal.speciesID,
                stage: .hatchling,
                rarity: self.reveal.rarity,
                behavior: .celebrate,
                dimension: 150,
                animationsEnabled: self.animationsEnabled)

            Text(self.speciesName)
                .font(.largeTitle.bold())

            HStack {
                CompanionVariantBadge(variantID: self.reveal.variantID)
                Text(AppLocalization.string(
                    "companion.personality.\(self.reveal.personalityID.rawValue)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(self.personality)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)

            Button(AppLocalization.string("companion.reveal.continue")) {
                self.dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            }
            .padding(28)
        }
        .frame(minWidth: 400, minHeight: 420)
        .animation(.easeInOut(duration: 0.7), value: self.reveal.id)
    }

    @ViewBuilder
    private var specialBackground: some View {
        switch self.reveal.variantID {
        case .standard:
            Color.clear
        case .prismatic:
            AngularGradient(
                colors: [.pink, .purple, .blue, .mint, .yellow, .pink],
                center: .center)
                .opacity(0.2)
                .blur(radius: 18)
                .overlay(Image(systemName: "sparkles")
                    .font(.system(size: 120))
                    .foregroundStyle(.white.opacity(0.22)))
        case .mutated:
            LinearGradient(
                colors: [.purple.opacity(0.35), .black.opacity(0.12),
                         .green.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
                .overlay(Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 110))
                    .foregroundStyle(.purple.opacity(0.24)))
        }
    }

    private var speciesName: String {
        AppLocalization.string(
            "companion.species.\(self.reveal.speciesID.rawValue).name")
    }

    private var personality: String {
        AppLocalization.string(
            "companion.species.\(self.reveal.speciesID.rawValue).personality")
    }
}
