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
        var lines: [String] = []

        if presentation.providers.isEmpty {
            lines.append(WindowsLocalization.message("No provider usage is available yet."))
        } else {
            for provider in presentation.providers {
                if !lines.isEmpty {
                    lines.append("")
                }
                lines.append(provider.descriptor.displayName)

                switch provider.availability {
                case .available:
                    if provider.quotaWindows.isEmpty {
                        lines.append(WindowsLocalization.text("  Usage available", "  사용량 확인 가능"))
                    } else {
                        for window in provider.quotaWindows {
                            var line = "  \(window.label): "
                                + WindowsLocalization.text("\(Int(window.remainingPercent.rounded()))% remaining", "\(Int(window.remainingPercent.rounded()))% 남음")
                            if let reset = window.resetsAt {
                                line += WindowsLocalization.text(" · resets \(Self.relativeReset(reset, now: now))", " · 초기화 \(Self.relativeReset(reset, now: now))")
                            }
                            lines.append(line)
                        }
                    }
                    if let tokenTotal = provider.tokenTotal {
                        lines.append(WindowsLocalization.text("  Tokens: \(tokenTotal)", "  토큰: \(tokenTotal)"))
                    }
                case .loading:
                    lines.append(WindowsLocalization.text("  Refreshing usage…", "  사용량 갱신 중…"))
                case .stale:
                    lines.append(WindowsLocalization.text("  Usage is stale", "  오래된 사용량 · 갱신 필요"))
                case .unavailable:
                    lines.append(WindowsLocalization.text("  Usage unavailable", "  사용량 확인 불가"))
                case .failed:
                    lines.append(WindowsLocalization.text("  Usage refresh failed", "  사용량 갱신 실패"))
                }
            }
        }

        if let lastRefresh = presentation.lastRefresh {
            if !lines.isEmpty {
                lines.append("")
            }
            lines.append(WindowsLocalization.text("Updated \(Self.relativeAge(lastRefresh, now: now))", "갱신: \(Self.relativeAge(lastRefresh, now: now))"))
        }
        if presentation.isRefreshing {
            lines.append(WindowsLocalization.text("Refreshing…", "갱신 중…"))
        }
        return lines.joined(separator: "\n")
    }

    static func relativeReset(_ date: Date, now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 {
            return WindowsLocalization.text("now", "지금")
        }

        let minutes = max(Int(ceil(seconds / 60)), 1)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return remainingMinutes == 0
                ? WindowsLocalization.text("in \(hours)h", "\(hours)시간 후")
                : WindowsLocalization.text("in \(hours)h \(remainingMinutes)m", "\(hours)시간 \(remainingMinutes)분 후")
        }
        return WindowsLocalization.text("in \(minutes)m", "\(minutes)분 후")
    }

    private static func relativeAge(_ date: Date, now: Date) -> String {
        let seconds = max(now.timeIntervalSince(date), 0)
        let minutes = Int(floor(seconds / 60))
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return remainingMinutes == 0
                ? WindowsLocalization.text("\(hours)h ago", "\(hours)시간 전")
                : WindowsLocalization.text("\(hours)h \(remainingMinutes)m ago", "\(hours)시간 \(remainingMinutes)분 전")
        }
        return minutes == 0 ? WindowsLocalization.text("just now", "방금") : WindowsLocalization.text("\(minutes)m ago", "\(minutes)분 전")
    }
}
