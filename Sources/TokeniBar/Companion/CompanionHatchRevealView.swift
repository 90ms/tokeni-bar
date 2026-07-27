import SwiftUI
import TokeniCore

struct CompanionHatchReveal: Identifiable, Equatable {
    let id = UUID()
    let speciesID: CompanionSpeciesID
    let rarity: CompanionRarity
    let isNewSpecies: Bool
}

struct CompanionHatchRevealView: View {
    let reveal: CompanionHatchReveal
    let animationsEnabled: Bool
    let dismiss: () -> Void

    var body: some View {
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

            CompanionRarityBadge(rarity: self.reveal.rarity)

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
        .frame(minWidth: 400, minHeight: 420)
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
