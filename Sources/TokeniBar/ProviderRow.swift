import TokeniCore
import SwiftUI

struct ProviderRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: ProviderSnapshot
    let costCurrency: CostDisplayCurrency
    let exchangeRate: ExchangeRateQuote?
    let compact: Bool
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: self.compact ? 5 : 9) {
            HStack(spacing: 8) {
                ProviderIcon(descriptor: self.snapshot.descriptor)
                    .frame(width: 18)
                Text(self.snapshot.descriptor.displayName)
                    .font(.headline)
                if self.isActive {
                    Image(systemName: "waveform")
                        .foregroundStyle(.green)
                        .symbolEffect(
                            .pulse,
                            options: .repeating,
                            isActive: !self.reduceMotion)
                        .help(AppLocalization.string("activity.active"))
                        .accessibilityLabel(AppLocalization.string("activity.active"))
                }
                Spacer()
                self.availabilityBadge
            }

            ForEach(self.snapshot.quotaWindows) { window in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(window.label)
                        Spacer()
                        Text(window.remainingPercent, format: .number.precision(.fractionLength(0)))
                            + Text(AppLocalization.string("usage.percentLeft"))
                        if let reset = window.resetsAt {
                            Text("·")
                            Text(reset, style: .relative)
                        }
                    }
                    .font(.caption)
                    ProgressView(value: window.remainingPercent, total: 100)
                        .tint(self.tint(forRemainingPercent: window.remainingPercent))
                }
            }

            if let resetCredits = self.snapshot.quotaResetCredits {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(
                            AppLocalization.string("usage.resetCredits"),
                            systemImage: "ticket.fill")
                        Spacer()
                        Text(AppLocalization.format(
                            "usage.resetCredits.available",
                            resetCredits.availableCount))
                            .monospacedDigit()
                    }
                    .font(.caption)

                    if !self.compact {
                        ForEach(resetCredits.credits) { credit in
                            HStack {
                                Text(credit.title)
                                Spacer()
                                if let expiresAt = credit.expiresAt {
                                    Text(AppLocalization.string("usage.resetCredits.expires"))
                                    Text(expiresAt, format: .dateTime
                                        .year().month().day().hour().minute())
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !self.compact, let accountUsage = snapshot.accountTokenUsage {
                let referenceCosts = AccountTokenReferenceCostEstimator
                    .codexInputOutputReferenceV1()
                    .map { $0.estimate(summary: accountUsage) }
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        AppLocalization.string("usage.accountTokens.title"),
                        systemImage: "chart.bar.xaxis")
                        .font(.caption)

                    self.accountTokenUsageRow(
                        label: accountUsage.latestBucketDate.map {
                            AppLocalization.format("usage.accountTokens.latestDaily", $0)
                        } ?? AppLocalization.string("usage.accountTokens.latestDailyUnavailable"),
                        tokens: accountUsage.latestDailyTokens,
                        costUSD: accountUsage.latestDailyTokens.flatMap {
                            AccountTokenReferenceCostEstimator
                                .codexInputOutputReferenceV1()?
                                .estimate(tokenCount: $0).amountUSD
                        })
                    self.accountTokenUsageRow(
                        label: AppLocalization.string("usage.accountTokens.month"),
                        tokens: accountUsage.currentMonthTokens,
                        costUSD: referenceCosts?.currentMonth.amountUSD)
                    self.accountTokenUsageRow(
                        label: AppLocalization.string("usage.accountTokens.lifetime"),
                        tokens: accountUsage.lifetimeTokens,
                        costUSD: referenceCosts?.lifetime.amountUSD)
                }
            }

            if !self.compact,
               snapshot.accountTokenUsage == nil,
               let tokenUsage = snapshot.tokenUsage
            {
                HStack {
                    Text(tokenUsage.label)
                    Spacer()
                    Text(tokenUsage.totalTokens.formatted(.number.notation(.compactName)))
                        .monospacedDigit()
                    Text(AppLocalization.string("usage.tokens"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !self.compact,
               snapshot.accountTokenUsage == nil,
               let estimate = snapshot.costEstimate,
               let formattedCost = self.formattedCost(estimate.amountUSD)
            {
                HStack {
                    Text(AppLocalization.string("usage.apiCostEstimate"))
                    Spacer()
                    Text(formattedCost)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(estimate.modelIDs.joined(separator: ", "))
            }

            if !self.compact, let detail = snapshot.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !self.compact, let source = snapshot.source {
                HStack(spacing: 4) {
                    Text(AppLocalization.sourceName(source))
                    Spacer()
                    Text(AppLocalization.string("usage.updated"))
                    Text(snapshot.updatedAt, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, self.compact ? 2 : 6)
    }

    @ViewBuilder
    private var availabilityBadge: some View {
        switch self.snapshot.availability {
        case .available:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .loading:
            ProgressView().controlSize(.small)
        case .stale:
            Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange)
        case .unavailable:
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }

    private func tint(forRemainingPercent percent: Double) -> Color {
        switch percent {
        case ..<10: .red
        case ..<30: .orange
        default: .accentColor
        }
    }

    @ViewBuilder
    private func accountTokenUsageRow(
        label: String,
        tokens: Int64?,
        costUSD: Double?) -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                if let tokens {
                    Text(tokens.formatted(.number.notation(.compactName)))
                        .monospacedDigit()
                    Text(AppLocalization.string("usage.tokens"))
                } else {
                    Text(AppLocalization.string("usage.accountTokens.unavailable"))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let costUSD,
               let formattedCost = self.formattedCost(costUSD)
            {
                HStack {
                    Spacer()
                    Text(AppLocalization.format(
                        "usage.accountTokens.referenceCost",
                        formattedCost))
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .help(AppLocalization.string("usage.accountTokens.costDisclaimer"))
            }
        }
    }

    private func formattedCost(_ amountUSD: Double) -> String? {
        self.costCurrency.formatted(
            amountUSD: amountUSD,
            exchangeRate: self.exchangeRate)
    }
}
