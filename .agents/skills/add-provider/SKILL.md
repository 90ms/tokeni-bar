---
name: add-provider
description: Use this skill when implementing, updating, or testing an AI provider adapter in TokeniCore.
---

# Add or Update Provider Adapter

Step-by-step workflow for integrating new AI assistant usage tracking (e.g., Claude, Codex, Gemini, Antigravity) into TokeniCore.

## When to Use

- Adding a new provider usage scanner or CLI reader.
- Updating an existing provider's parsing logic for newer CLI / API format changes.

## Step 1: Create Provider Module in TokeniCore

Keep all provider-specific authentication, file reading, and format parsing isolated inside:
`Sources/TokeniCore/Providers/<ProviderName>/`

Key files typically needed:
- `<ProviderName>UsageProvider.swift`: Implements `UsageProviding` protocol.
- `<ProviderName>CLIUsage.swift`: Data structures representing the provider's local cache or output format.

## Step 2: Implement Required Interfaces

1. Conform to `UsageProviding` (defined in `Sources/TokeniCore/Models/UsageProvider.swift`):
   ```swift
   public struct MyProviderUsageProvider: UsageProviding {
       public let id: ProviderID = .custom("my-provider")
       public let displayName: String = "My Provider"

       public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) { ... }

       public func fetchUsage() async throws -> UsageSummary { ... }
       public func checkActivity() async -> ProviderActivitySnapshot { ... }
   }
   ```
2. If the provider tracks granular input/output/cache tokens, conform to `AccountTokenUsageProviding`.

## Step 3: Register in ProviderRegistry

Add the provider instantiation into `ProviderRegistry.defaultProviders(...)` in:
`Sources/TokeniCore/Models/UsageProvider.swift`

```swift
public enum ProviderRegistry {
    public static func defaultProviders(...) -> [any UsageProviding] {
        [
            CodexUsageProvider(...),
            ClaudeUsageProvider(...),
            ...
            MyProviderUsageProvider(...),
        ]
    }
}
```

> **Strict Rule**: Never add provider-specific switch cases or conditionals in shared UI (`Sources/TokeniBar/`). The UI must dynamically iterate over `ProviderRegistry`.

## Step 4: Strict Privacy & Safety Rules

- **Never log or persist**: Access tokens, refresh tokens, session cookies, prompt texts, or response bodies.
- **Fail gracefully**: Prefer returning an `.unavailable` or `.stale` state over fabricating quota or cost estimates.
- **Companion independence**: Companion state must never contain provider names, token totals, prompts, or response content.

## Step 5: Add Sanitized Fixtures & Tests

Treat local CLI formats and remote endpoints as unstable. Every parser must have a sanitized fixture test.

1. Create a sanitized fixture file in:
   `Tests/TokeniCoreTests/Fixtures/<provider-name>-usage.json` (or `.jsonl`)
   - Replace any sensitive keys, account IDs, emails, or personal prompts with placeholder data.
2. If adding JSON or base64 files, declare line endings in `.gitattributes`:
   ```gitattributes
   Tests/TokeniCoreTests/Fixtures/*.json text eol=lf
   ```
3. Write parser test cases in `Tests/TokeniCoreTests/`:
   - Verify correct parsing of valid outputs.
   - Verify graceful handling of malformed, partial, or unavailable data.
