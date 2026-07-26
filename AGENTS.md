# Tokeni Bar contributor guide

## Project shape

- `Sources/TokeniCore`: provider-neutral models, scanners, and provider adapters.
- `Sources/TokeniBar`: macOS menu-bar UI and app state.
- `Tests/TokeniCoreTests`: parser tests backed by sanitized fixtures.
- `packaging`: app-bundle and Homebrew templates.

## Conventions

- Keep provider-specific authentication and parsing inside its provider directory.
- Add providers through `ProviderRegistry`; do not add provider switches to shared UI.
- Keep Tokeni growth provider-neutral and derive it only from verified cumulative
  token observations. Active minutes may drive animations, but never growth.
- Companion state must not contain provider names, token totals, prompts, or response content.
- Never log or persist access tokens, refresh tokens, cookies, prompts, or response content.
- Treat local CLI formats and remote endpoints as unstable. Every parser change needs a sanitized fixture test.
- Prefer an unavailable or stale state over fabricated quota or cost values.

## Verification

Run `swift test` and `swift build` before handing off changes.
