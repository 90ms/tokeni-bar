import Foundation

public enum DiagnosticSanitizer {
    private static let maximumLength = 120
    private static let suspiciousFragments = [
        "authorization", "bearer", "cookie", "password", "prompt", "response",
        "secret", "session", "sk-", "token=", "~", "/users/", "/home/",
    ]

    /// Sanitizes short identifiers and application metadata. Provider detail text and log
    /// contents must never be passed to this function or included in a diagnostic report.
    public static func scalar(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = trimmed.lowercased()
        guard !trimmed.isEmpty,
              !self.suspiciousFragments.contains(where: lowercase.contains)
        else { return "redacted" }

        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: " ._:+-()"))
        let filteredScalars = trimmed.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(String(scalar)) : Character("_")
        }
        let filtered = String(filteredScalars.prefix(self.maximumLength))
            .trimmingCharacters(in: .whitespaces)
        return filtered.isEmpty ? "redacted" : filtered
    }
}

public enum ProviderDiagnosticReportBuilder {
    public static func text(
        appName: String,
        appVersion: String,
        appBuild: String,
        osVersion: String,
        snapshots: [ProviderSnapshot],
        includeTokenDetails: Bool = false,
        generatedAt: Date = .now) -> String
    {
        var lines = [
            "Tokeni Bar diagnostics",
            "generated_at=\(self.timestamp(generatedAt))",
            "app_name=\(DiagnosticSanitizer.scalar(appName))",
            "app_version=\(DiagnosticSanitizer.scalar(appVersion))",
            "app_build=\(DiagnosticSanitizer.scalar(appBuild))",
            "os_version=\(DiagnosticSanitizer.scalar(osVersion))",
            "provider_count=\(snapshots.count)",
        ]

        for snapshot in snapshots.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            lines.append("")
            lines.append("[provider]")
            lines.append("id=\(DiagnosticSanitizer.scalar(snapshot.id.rawValue))")
            lines.append("availability=\(snapshot.availability.rawValue)")
            lines.append("source=\(snapshot.source?.rawValue ?? "none")")
            lines.append("updated_at=\(self.timestamp(snapshot.updatedAt))")
            lines.append("freshness_seconds=\(max(0, Int(generatedAt.timeIntervalSince(snapshot.updatedAt))))")
            lines.append("quota_window_count=\(snapshot.quotaWindows.count)")
            lines.append("reset_credit_available_count=\(snapshot.quotaResetCredits?.availableCount ?? 0)")
            lines.append("reset_credit_returned_count=\(snapshot.quotaResetCredits?.credits.count ?? 0)")
            lines.append(
                "account_token_issue=\(snapshot.accountTokenUsageIssue?.rawValue ?? "none")")
            if includeTokenDetails {
                self.append(
                    snapshot.accountTokenUsage?.todayTokens,
                    as: "account_token_today",
                    to: &lines)
                self.append(
                    snapshot.accountTokenUsage?.currentMonthTokens,
                    as: "account_token_current_month",
                    to: &lines)
                self.append(
                    snapshot.accountTokenUsage?.lifetimeTokens,
                    as: "account_token_lifetime",
                    to: &lines)
            }

            for (index, window) in snapshot.quotaWindows.enumerated() {
                let prefix = "quota_\(index)"
                lines.append("\(prefix)_kind=\(window.kind.rawValue)")
                lines.append("\(prefix)_used_percent=\(self.number(window.usedPercent))")
                lines.append("\(prefix)_reset_known=\(window.resetsAt != nil)")
                if let durationMinutes = window.durationMinutes {
                    lines.append("\(prefix)_duration_minutes=\(durationMinutes)")
                }
            }

            if includeTokenDetails {
                lines.append("token_details=included")
                if let usage = snapshot.tokenUsage {
                    lines.append(
                        "token_model=\(usage.modelID.map(DiagnosticSanitizer.scalar) ?? "unknown")")
                    lines.append("token_total=\(usage.totalTokens)")
                    self.append(usage.inputTokens, as: "token_input", to: &lines)
                    self.append(
                        usage.cacheCreationInputTokens,
                        as: "token_cache_creation",
                        to: &lines)
                    self.append(
                        usage.cacheCreation1hInputTokens,
                        as: "token_cache_creation_1h",
                        to: &lines)
                    self.append(usage.cachedInputTokens, as: "token_cached_input", to: &lines)
                    self.append(usage.outputTokens, as: "token_output", to: &lines)
                    self.append(usage.reasoningTokens, as: "token_reasoning", to: &lines)
                } else {
                    lines.append("token_model=none")
                    lines.append("token_total=none")
                }
            } else {
                lines.append("token_details=excluded")
            }

            let costModels = snapshot.costEstimate?.modelIDs
                .map(DiagnosticSanitizer.scalar)
                .filter { $0 != "redacted" }
                .sorted() ?? []
            if includeTokenDetails {
                lines.append(
                    "cost_models=\(costModels.isEmpty ? "none" : costModels.joined(separator: ","))")
            } else {
                lines.append("cost_model_count=\(costModels.count)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func append(_ value: Int64?, as key: String, to lines: inout [String]) {
        if let value { lines.append("\(key)=\(value)") }
    }

    private static func number(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...2)))
    }

    private static func timestamp(_ date: Date) -> String {
        date.formatted(.iso8601.timeZone(separator: .omitted).time(includingFractionalSeconds: false))
    }
}
