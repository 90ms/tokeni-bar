import TokeniCore
import SwiftUI

struct ProviderRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: ProviderSnapshot
    let costCurrency: CostDisplayCurrency
    let exchangeRate: ExchangeRateQuote?
    let compact: Bool
    let isActive: Bool
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            self.providerHeader

            if let primaryQuota = self.snapshot.quotaWindows.first {
                self.quotaView(primaryQuota, emphasizesValue: true)
            } else if let detail = self.snapshot.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !self.compact, self.hasExpandableDetails {
                DisclosureGroup(isExpanded: self.$isExpanded) {
                    self.providerDetails
                        .padding(.top, 7)
                } label: {
                    Text(AppLocalization.string(
                        self.isExpanded
                            ? "usage.details.hide"
                            : "usage.details.show"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.secondary)
            }
        }
        .padding(10)
        .background(
            .quaternary.opacity(0.38),
            in: RoundedRectangle(cornerRadius: 10))
    }

    private var providerHeader: some View {
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
    }

    private func quotaView(
        _ window: QuotaWindow,
        emphasizesValue: Bool = false) -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 0) {
                    Text(
                        window.remainingPercent,
                        format: .number.precision(.fractionLength(0)))
                    Text(AppLocalization.string("usage.percentLeft"))
                }
                .font(emphasizesValue ? .subheadline.weight(.semibold) : .caption)
                .monospacedDigit()
            }

            ProgressView(value: window.remainingPercent, total: 100)
                .tint(self.tint(forRemainingPercent: window.remainingPercent))

            if let reset = window.resetsAt {
                HStack(spacing: 3) {
                    Text(AppLocalization.string("usage.resets"))
                    Text(reset, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var providerDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(self.snapshot.quotaWindows.dropFirst())) { window in
                self.quotaView(window)
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

            if let accountUsage = snapshot.accountTokenUsage {
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

            if snapshot.accountTokenUsage == nil,
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

            if snapshot.accountTokenUsage == nil,
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

            if let detail = snapshot.detail,
               !self.snapshot.quotaWindows.isEmpty
            {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let source = snapshot.source {
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
    }

    @ViewBuilder
    private var availabilityBadge: some View {
        switch self.snapshot.availability {
        case .available:
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
                .help(AppLocalization.string("provider.status.available"))
                .accessibilityLabel(AppLocalization.string(
                    "provider.status.available"))
        case .loading:
            ProgressView().controlSize(.small)
        case .stale:
            self.statusBadge(
                key: "provider.status.stale",
                systemImage: "clock.badge.exclamationmark",
                color: .orange)
        case .unavailable:
            self.statusBadge(
                key: "provider.status.unavailable",
                systemImage: "minus.circle",
                color: .gray)
        case .failed:
            self.statusBadge(
                key: "provider.status.failed",
                systemImage: "exclamationmark.triangle.fill",
                color: .red)
        }
    }

    private func statusBadge(
        key: String,
        systemImage: String,
        color: Color) -> some View
    {
        Label(AppLocalization.string(key), systemImage: systemImage)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var hasExpandableDetails: Bool {
        self.snapshot.quotaWindows.count > 1
            || self.snapshot.quotaResetCredits != nil
            || self.snapshot.accountTokenUsage != nil
            || self.snapshot.tokenUsage != nil
            || self.snapshot.costEstimate != nil
            || (self.snapshot.detail != nil
                && !self.snapshot.quotaWindows.isEmpty)
            || self.snapshot.source != nil
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
