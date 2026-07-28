@testable import TokeniCore
import Foundation
import Testing

struct ProviderDiagnosticReportTests {
    @Test
    func reportContainsOnlyAggregatedFieldsAndSanitizedIdentifiers() {
        let homePath = "/Users/alice/private/session.jsonl"
        let secret = "sk-private-auth-token"
        let prompt = "PROMPT-MUST-NOT-BE-COPIED"
        let response = "RESPONSE-MUST-NOT-BE-COPIED"
        let descriptor = ProviderDescriptor(
            id: ProviderID(rawValue: "custom/provider"),
            displayName: "\(prompt) \(homePath)",
            shortName: secret,
            systemImage: response,
            capabilities: .init(supportsQuotaWindows: true, supportsTokenUsage: true))
        let snapshot = ProviderSnapshot(
            descriptor: descriptor,
            availability: .failed,
            source: .localSessionLog,
            quotaWindows: [
                QuotaWindow(
                    id: secret,
                    kind: .weekly,
                    label: "\(prompt) \(homePath)",
                    usedPercent: 42,
                    durationMinutes: 10_080),
            ],
            tokenUsage: TokenUsage(
                label: response,
                modelID: "safe-model-1",
                inputTokens: 10,
                outputTokens: 2,
                totalTokens: 12),
            costEstimate: TokenCostEstimate(
                label: prompt,
                amountUSD: 99,
                modelIDs: ["safe-model-1"]),
            accountTokenUsage: AccountTokenUsageSummary(
                todayTokens: 1_000,
                currentMonthTokens: 2_000,
                lifetimeTokens: 3_000,
                localDate: "2026-07-21"),
            accountTokenUsageIssue: .unsupported,
            credits: CreditBalance(balance: secret, hasCredits: true, unlimited: false),
            quotaResetCredits: QuotaResetCreditSummary(
                availableCount: 1,
                totalEarnedCount: 2,
                credits: [QuotaResetCredit(
                    id: secret,
                    status: "available",
                    title: prompt,
                    expiresAt: Date(timeIntervalSince1970: 1_800_000_000))]),
            detail: "Authorization: Bearer \(secret); cookie=value; \(prompt); \(response); \(homePath)",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000))

        let report = ProviderDiagnosticReportBuilder.text(
            appName: "Tokeni Bar",
            appVersion: "1.2.3",
            appBuild: "45",
            osVersion: "macOS 15.5",
            snapshots: [snapshot],
            includeTokenDetails: true,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_060))

        #expect(report.contains("id=custom_provider"))
        #expect(report.contains("availability=failed"))
        #expect(report.contains("quota_0_used_percent=42"))
        #expect(report.contains("reset_credit_available_count=1"))
        #expect(report.contains("reset_credit_returned_count=1"))
        #expect(report.contains("token_model=safe-model-1"))
        #expect(report.contains("token_total=12"))
        #expect(report.contains("account_token_today=1000"))
        #expect(report.contains("account_token_current_month=2000"))
        #expect(report.contains("account_token_lifetime=3000"))
        #expect(report.contains("account_token_issue=unsupported"))
        #expect(report.contains("cost_models=safe-model-1"))
        #expect(report.contains("freshness_seconds=60"))
        #expect(!report.contains(homePath))
        #expect(!report.contains(secret))
        #expect(!report.contains(prompt))
        #expect(!report.contains(response))
        #expect(!report.localizedCaseInsensitiveContains("cookie=value"))
        #expect(!report.localizedCaseInsensitiveContains("authorization:"))
        #expect(!report.contains("99"))
    }

    @Test
    func reportExcludesTokenTotalsAndModelIDsByDefault() {
        let descriptor = ProviderDescriptor(
            id: .codex,
            displayName: "Codex",
            shortName: "Codex",
            systemImage: "terminal",
            capabilities: .init(supportsTokenUsage: true))
        let snapshot = ProviderSnapshot(
            descriptor: descriptor,
            availability: .available,
            source: .officialAPI,
            tokenUsage: TokenUsage(
                label: "Today",
                modelID: "private-model-id",
                inputTokens: 123_456,
                totalTokens: 987_654),
            accountTokenUsage: AccountTokenUsageSummary(
                todayTokens: 111_111,
                currentMonthTokens: 222_222,
                lifetimeTokens: 333_333,
                localDate: "2026-07-28"))

        let report = ProviderDiagnosticReportBuilder.text(
            appName: "Tokeni Bar",
            appVersion: "1.2.3",
            appBuild: "45",
            osVersion: "macOS",
            snapshots: [snapshot])

        #expect(report.contains("token_details=excluded"))
        #expect(!report.contains("private-model-id"))
        #expect(!report.contains("123456"))
        #expect(!report.contains("987654"))
        #expect(!report.contains("111111"))
        #expect(!report.contains("222222"))
        #expect(!report.contains("333333"))
    }

    @Test
    func sanitizerRejectsAbsolutePathsAndCredentialLikeValues() {
        #expect(DiagnosticSanitizer.scalar("/Users/alice/.config") == "redacted")
        #expect(DiagnosticSanitizer.scalar("Bearer abc123") == "redacted")
        #expect(DiagnosticSanitizer.scalar("model/with/slash") == "model_with_slash")
    }
}
