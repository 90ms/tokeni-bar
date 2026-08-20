import Foundation
import TokeniApplication

/// Formats the provider-neutral presentation for the small native tray detail
/// surface. It deliberately formats only verified values carried by the
/// presentation model and never invents a reset time.
public enum WindowsUsageDetailFormatter {
    public static func text(
        for presentation: UsageApplicationPresentation,
        now: Date = .now) -> String
    {
        var lines = ["Tokeni Bar"]

        if presentation.providers.isEmpty {
            lines.append("No provider usage is available yet.")
        } else {
            for provider in presentation.providers {
                lines.append("")
                lines.append(provider.descriptor.displayName)

                switch provider.availability {
                case .available:
                    if provider.quotaWindows.isEmpty {
                        lines.append("  Usage available")
                    } else {
                        for window in provider.quotaWindows {
                            var line = "  \(window.label): "
                                + "\(Int(window.remainingPercent.rounded()))% remaining"
                            if let reset = window.resetsAt {
                                line += " · resets \(Self.relativeReset(reset, now: now))"
                            }
                            lines.append(line)
                        }
                    }
                    if let tokenTotal = provider.tokenTotal {
                        lines.append("  Tokens: \(tokenTotal)")
                    }
                case .loading:
                    lines.append("  Refreshing usage…")
                case .stale:
                    lines.append("  Usage is stale")
                case .unavailable:
                    lines.append("  Usage unavailable")
                case .failed:
                    lines.append("  Usage refresh failed")
                }
            }
        }

        if let lastRefresh = presentation.lastRefresh {
            lines.append("")
            lines.append("Updated \(Self.relativeAge(lastRefresh, now: now))")
        }
        if presentation.isRefreshing {
            lines.append("Refreshing…")
        }
        return lines.joined(separator: "\n")
    }

    static func relativeReset(_ date: Date, now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 {
            return "now"
        }

        let minutes = max(Int(ceil(seconds / 60)), 1)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return remainingMinutes == 0
                ? "in \(hours)h"
                : "in \(hours)h \(remainingMinutes)m"
        }
        return "in \(minutes)m"
    }

    private static func relativeAge(_ date: Date, now: Date) -> String {
        let seconds = max(now.timeIntervalSince(date), 0)
        let minutes = Int(floor(seconds / 60))
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return remainingMinutes == 0
                ? "\(hours)h ago"
                : "\(hours)h \(remainingMinutes)m ago"
        }
        return minutes == 0 ? "just now" : "\(minutes)m ago"
    }
}
