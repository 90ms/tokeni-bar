import SwiftUI
import TokeniCore

struct CompanionMutationReveal: Identifiable, Equatable {
    let id = UUID()
    let speciesID: CompanionSpeciesID
    let mutationID: CompanionMutationID
    let isNewMutation: Bool
}

struct CompanionMutationRevealView: View {
    let reveal: CompanionMutationReveal
    let animationsEnabled: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(AppLocalization.string(
                self.reveal.isNewMutation
                    ? "companion.mutation.reveal.new"
                    : "companion.mutation.reveal.repeat"))
                .font(.headline)
                .foregroundStyle(.secondary)

            ByteBotSpriteView(
                speciesID: self.reveal.speciesID,
                stage: .hatchling,
                rarity: .normal,
                variantID: .mutated,
                behavior: .celebrate,
                dimension: 150,
                animationsEnabled: self.animationsEnabled)
                .frame(width: 150, height: 150)

            Text(AppLocalization.string(
                "companion.species.\(self.reveal.speciesID.rawValue).name"))
                .font(.title2.bold())

            Text(AppLocalization.string(
                "companion.mutation.\(self.reveal.mutationID.rawValue).name"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text(AppLocalization.string(
                "companion.mutation.\(self.reveal.mutationID.rawValue).description"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)

            Text(AppLocalization.string("companion.mutation.reveal.added"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Button(AppLocalization.string("companion.mutation.continue")) {
                self.dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(minWidth: 400, minHeight: 430)
    }
}
