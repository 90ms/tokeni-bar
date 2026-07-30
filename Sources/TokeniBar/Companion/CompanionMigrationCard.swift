import SwiftUI
import TokeniCore

struct CompanionMigrationCard: View {
    @ObservedObject var store: UsageStore
    var showsReceiptDismissButton = false

    @State private var confirmsReset = false

    var body: some View {
        if let quote = self.store.companionMigrationQuote {
            self.card(
                title: AppLocalization.string("companion.migration.title"),
                systemImage: "arrow.triangle.2.circlepath")
            {
                Text(AppLocalization.string("companion.migration.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                self.quoteRows(quote)
                Button(
                    AppLocalization.string("companion.migration.review"),
                    role: .destructive)
                {
                    self.confirmsReset = true
                }
                .disabled(self.store.isApplyingCompanionMigration)
                if self.store.isApplyingCompanionMigration {
                    ProgressView()
                        .controlSize(.small)
                }
                if let error = self.store.companionMigrationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .confirmationDialog(
                AppLocalization.string("companion.migration.confirm.title"),
                isPresented: self.$confirmsReset,
                titleVisibility: .visible)
            {
                Button(
                    AppLocalization.string("companion.migration.confirm.action"),
                    role: .destructive)
                {
                    self.store.applyCompanionAssetReset()
                }
                Button(
                    AppLocalization.string("action.cancel"),
                    role: .cancel)
                {}
            } message: {
                Text(AppLocalization.string(
                    "companion.migration.confirm.message"))
            }
        } else if let receipt = self.store.companionMigrationReceipt {
            self.card(
                title: AppLocalization.string(
                    "companion.migration.receipt.title"),
                systemImage: "checkmark.seal.fill")
            {
                Text(AppLocalization.string(
                    "companion.migration.receipt.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                self.quoteRows(receipt.quote)
                if self.showsReceiptDismissButton {
                    Button(AppLocalization.string(
                        "companion.migration.receipt.dismiss"))
                    {
                        self.store.acknowledgeCompanionMigrationReceipt()
                    }
                }
            }
        }
    }

    private func card<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content) -> some View
    {
        GroupBox {
            VStack(alignment: .leading, spacing: 9) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func quoteRows(_ quote: CompanionAssetResetQuote) -> some View {
        VStack(spacing: 5) {
            self.row(
                AppLocalization.format(
                    "companion.migration.currentPet",
                    AppLocalization.string(
                        "companion.stage.\(quote.currentStage.rawValue)")),
                value: AppLocalization.format(
                    "companion.migration.energy",
                    quote.currentPetEnergyRefund))
            self.row(
                AppLocalization.format(
                    "companion.migration.completedPets",
                    quote.completedPetCount),
                value: AppLocalization.format(
                    "companion.migration.energy",
                    quote.completedPetEnergyRefund))
            self.row(
                AppLocalization.format(
                    "companion.migration.collection",
                    quote.collectionDiscoveryCount),
                value: AppLocalization.string(
                    "companion.migration.collectionReset"))
            self.row(
                AppLocalization.format(
                    "companion.migration.cosmetics",
                    quote.cosmeticRefunds.count),
                value: AppLocalization.format(
                    "companion.migration.shards",
                    quote.cosmeticStarShardRefund))
            Divider()
            self.row(
                AppLocalization.string("companion.migration.after"),
                value: AppLocalization.format(
                    "companion.migration.afterValue",
                    quote.resultingGrowthEnergy,
                    quote.resultingStarShards),
                emphasized: true)
        }
    }

    private func row(
        _ title: String,
        value: String,
        emphasized: Bool = false) -> some View
    {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(emphasized ? .semibold : .regular)
                .foregroundStyle(emphasized ? .primary : .secondary)
        }
        .font(.caption)
    }
}
