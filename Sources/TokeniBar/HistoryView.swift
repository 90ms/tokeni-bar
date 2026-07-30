import TokeniCore
import Charts
import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: UsageStore
    @State private var selectedProviderID: ProviderID?
    @State private var rangeDays = 7
    @State private var metric = HistoryMetric.quota
    @State private var confirmsClearHistory = false

    private enum HistoryMetric: String, Hashable {
        case quota
        case cost
    }

    private struct CostPoint: Identifiable {
        let id: UUID
        let timestamp: Date
        let amount: Double
    }

    private var availableProviders: [(id: ProviderID, name: String)] {
        var seen = Set<ProviderID>()
        return self.store.historyRecords.compactMap { record in
            guard seen.insert(record.providerID).inserted else { return nil }
            return (record.providerID, record.providerName)
        }
    }

    private var visibleRecords: [UsageHistoryRecord] {
        let providerID = self.selectedProviderID ?? self.availableProviders.first?.id
        let cutoff = Date.now.addingTimeInterval(TimeInterval(-self.rangeDays * 24 * 60 * 60))
        return self.store.historyRecords.filter {
            $0.providerID == providerID && $0.timestamp >= cutoff
        }
    }

    private var costPoints: [CostPoint] {
        let providerID = self.selectedProviderID ?? self.availableProviders.first?.id
        let cutoff = Date.now.addingTimeInterval(TimeInterval(-self.rangeDays * 24 * 60 * 60))
        var previousUSD: Double?
        var accumulatedUSD = 0.0
        let records = self.store.historyRecords
            .filter { $0.providerID == providerID }
            .sorted(by: { $0.timestamp < $1.timestamp })
        return records.compactMap { record in
            guard let costUSD = record.costUSD,
                  costUSD >= 0
            else { return nil }
            guard record.timestamp >= cutoff else {
                previousUSD = costUSD
                return nil
            }
            if let previousUSD {
                accumulatedUSD += costUSD >= previousUSD ? costUSD - previousUSD : costUSD
            }
            previousUSD = costUSD
            guard let converted = self.store.costDisplayCurrency.amount(
                fromUSD: accumulatedUSD,
                exchangeRate: self.store.exchangeRateQuote)
            else { return nil }
            return CostPoint(id: record.id, timestamp: record.timestamp, amount: converted)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 12) {
                    self.providerPicker
                    self.rangePicker
                }
                self.metricPicker
                    .frame(maxWidth: 280)
            }

            if self.visibleSampleCount > 0 {
                HStack {
                    Label(
                        AppLocalization.format(
                            "history.summary.samples",
                            self.visibleSampleCount),
                        systemImage: "point.3.connected.trianglepath.dotted")
                    Spacer()
                    if let latestTimestamp = self.latestVisibleTimestamp {
                        Text(AppLocalization.format(
                            "history.summary.latest",
                            latestTimestamp.formatted(
                                date: .abbreviated,
                                time: .shortened)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }

            if (self.metric == .quota
                    && self.visibleRecords.flatMap(\.windows).isEmpty)
                || (self.metric == .cost && self.costPoints.isEmpty)
            {
                ContentUnavailableView(
                    AppLocalization.string("history.empty.title"),
                    systemImage: "chart.xyaxis.line",
                    description: Text(AppLocalization.string(
                        "history.empty.description")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.metric == .quota {
                Chart {
                    ForEach(self.visibleRecords) { record in
                        ForEach(record.windows) { window in
                            LineMark(
                                x: .value(
                                    AppLocalization.string("history.time"),
                                    record.timestamp),
                                y: .value(
                                    AppLocalization.string(
                                        "history.remaining"),
                                    window.remainingPercent))
                                .foregroundStyle(by: .value(
                                    AppLocalization.string("history.limit"),
                                    window.label))
                                .interpolationMethod(.monotone)
                            PointMark(
                                x: .value(
                                    AppLocalization.string("history.time"),
                                    record.timestamp),
                                y: .value(
                                    AppLocalization.string(
                                        "history.remaining"),
                                    window.remainingPercent))
                                .foregroundStyle(by: .value(
                                    AppLocalization.string("history.limit"),
                                    window.label))
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxisLabel(AppLocalization.string(
                    "history.percentLeft"))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(AppLocalization.string(
                    "history.metric.quota"))
                .accessibilityValue(self.chartAccessibilitySummary)
            } else {
                Chart(self.costPoints) { point in
                    LineMark(
                        x: .value(
                            AppLocalization.string("history.time"),
                            point.timestamp),
                        y: .value(
                            AppLocalization.string("history.cost"),
                            point.amount))
                        .interpolationMethod(.monotone)
                    AreaMark(
                        x: .value(
                            AppLocalization.string("history.time"),
                            point.timestamp),
                        y: .value(
                            AppLocalization.string("history.cost"),
                            point.amount))
                        .foregroundStyle(.blue.opacity(0.12))
                }
                .chartYAxisLabel(AppLocalization.string("history.cost"))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(AppLocalization.string(
                    "history.metric.cost"))
                .accessibilityValue(self.chartAccessibilitySummary)
            }

            HStack {
                Text(AppLocalization.format("history.retention", 30))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(
                    AppLocalization.string("history.clear"),
                    role: .destructive)
                {
                    self.confirmsClearHistory = true
                }
                .disabled(self.store.historyRecords.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 420)
        .confirmationDialog(
            AppLocalization.string("history.clear.confirm.title"),
            isPresented: self.$confirmsClearHistory,
            titleVisibility: .visible)
        {
            Button(
                AppLocalization.string("history.clear.confirm.action"),
                role: .destructive)
            {
                self.store.clearHistory()
            }
            Button(AppLocalization.string("action.cancel"), role: .cancel) {}
        } message: {
            Text(AppLocalization.format(
                "history.clear.confirm.message",
                self.store.historyRecords.count))
        }
    }

    private var providerPicker: some View {
        Picker(
            AppLocalization.string("history.provider"),
            selection: Binding(
                get: {
                    self.selectedProviderID
                        ?? self.availableProviders.first?.id
                },
                set: { self.selectedProviderID = $0 }))
        {
            ForEach(self.availableProviders, id: \.id) { provider in
                if let descriptor = self.store.descriptors.first(where: {
                    $0.id == provider.id
                }) {
                    Label {
                        Text(provider.name)
                    } icon: {
                        ProviderIcon(descriptor: descriptor)
                    }
                    .tag(Optional(provider.id))
                } else {
                    Text(provider.name).tag(Optional(provider.id))
                }
            }
        }
        .frame(minWidth: 180, maxWidth: .infinity)
    }

    private var rangePicker: some View {
        Picker(
            AppLocalization.string("history.range"),
            selection: self.$rangeDays)
        {
            Text(AppLocalization.string("history.range.day")).tag(1)
            Text(AppLocalization.string("history.range.week")).tag(7)
            Text(AppLocalization.string("history.range.month")).tag(30)
        }
        .pickerStyle(.segmented)
        .frame(minWidth: 220, maxWidth: 280)
    }

    private var metricPicker: some View {
        Picker(
            AppLocalization.string("history.metric"),
            selection: self.$metric)
        {
            Text(AppLocalization.string("history.metric.quota"))
                .tag(HistoryMetric.quota)
            Text(AppLocalization.string("history.metric.cost"))
                .tag(HistoryMetric.cost)
        }
        .pickerStyle(.segmented)
    }

    private var visibleSampleCount: Int {
        switch self.metric {
        case .quota: self.visibleRecords.count
        case .cost: self.costPoints.count
        }
    }

    private var latestVisibleTimestamp: Date? {
        switch self.metric {
        case .quota: self.visibleRecords.map(\.timestamp).max()
        case .cost: self.costPoints.map(\.timestamp).max()
        }
    }

    private var chartAccessibilitySummary: String {
        AppLocalization.format(
            "history.chart.accessibility",
            self.visibleSampleCount,
            self.rangeDays)
    }
}
