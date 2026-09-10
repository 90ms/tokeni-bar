---
name: diagnostic-report
description: Use this skill to inspect, generate, and validate provider diagnostic reports for troubleshooting without leaking credentials.
---

# Provider Diagnostic Report & Troubleshooting

Runbook for generating and analyzing sanitized diagnostic reports when troubleshooting provider detection, CLI communication, or usage parsing failures.

## When to Use

- When diagnosing why a provider reports `unavailable` or `stale`.
- When validating that user-facing diagnostic export is 100% sanitized and free of confidential credentials.

## Architectural Boundaries

Diagnostic reporting is implemented in:
- Core Model: `Sources/TokeniCore/Diagnostics/ProviderDiagnosticReport.swift`
- macOS View: `Sources/TokeniBar/DiagnosticsView.swift`
- Windows Formatter: `Sources/TokeniWindows/WindowsUsageDetailFormatter.swift`

## Strict Privacy Rules

When inspecting or writing diagnostic reports:
- **Allowed Information**:
  - Provider identifier and display name
  - CLI binary location (executable path)
  - Connection/detection latency (ms)
  - HTTP status codes or CLI exit codes
  - Rate limit quota reset timestamp
  - Normalized error categories (`notFound`, `formatError`, `timeout`, `permissionDenied`)
- **Strictly Prohibited**:
  - API keys, OAuth access tokens, refresh tokens, session cookies
  - User prompt contents or AI completion responses
  - Full personal filesystem paths containing user identity

## Verification Checklist

When reviewing diagnostic code changes:
1. Verify `ProviderDiagnosticReport` contains no raw headers or token strings.
2. Ensure JSON export produces valid, readable output without sensitive tokens.
3. Verify that diagnostic views in both macOS and Windows handle missing or partially available providers gracefully.
