import Foundation
import TokeniCore
import TokeniWindowsNative

/// Samples remain observations: cumulative token/cost values must never be added together.
public enum WindowsHistoryPresentation {
    public static func publish(_ records: [UsageHistoryRecord]) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: WindowsLocalization.isKorean ? "ko_KR" : "en_US")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        tokeni_windows_history_begin()
        for record in records.sorted(by: { $0.timestamp < $1.timestamp }).suffix(50_000) {
            let windows = record.windows.filter { $0.remainingPercent.isFinite && (0...100).contains($0.remainingPercent) }
            let quota = windows.map { "\($0.label): \(Int($0.remainingPercent.rounded()))%" }.joined(separator: " · ")
            let tokens = record.tokenTotal.map(String.init) ?? "—"
            let cost = record.costUSD.flatMap { $0.isFinite && $0 >= 0 ? String(format: "$%.2f", $0) : nil } ?? "—"
            record.providerName.withCString { provider in
                formatter.string(from: record.timestamp).withCString { date in
                    String(quota.prefix(120)).withCString { quota in
                        tokens.withCString { tokens in
                            cost.withCString { cost in
                                tokeni_windows_history_append(record.timestamp.timeIntervalSince1970,
                                    windows.map(\.remainingPercent).min() ?? -1, provider, date, quota, tokens, cost)
                            }
                        }
                    }
                }
            }
        }
        tokeni_windows_history_commit()
    }
}
