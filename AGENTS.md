# Tokeni Bar contributor guide

## Project shape

- `Sources/TokeniCore`: provider-neutral models, parsers, token observation ledger, companion progression, and asset pack stores.
- `Sources/TokeniApplication`: platform-neutral application session, refresh coordination, growth ledger, and preferences.
- `Sources/TokeniBar`: macOS menu-bar popover, standalone window UI, and thin bridge state.
- `Sources/TokeniWindows` & `Sources/TokeniWindowsNative`: Windows tray shell, overlay, notifications, and native Win32/C bridges.
- `Tests/TokeniCoreTests`: parser and model tests backed by sanitized fixtures.
- `Tests/TokeniApplicationTests`: application session and coordinator tests.
- `Tests/TokeniBarTests`: macOS UI component and state tests.
- `Tests/TokeniWindowsTests`: Windows tray and runtime tests.
- `packaging`: macOS app-bundle, Homebrew templates, and Windows packaging scripts.

## Conventions

- Architecture layering:
  - Keep domain models, parsers, and game logic in `Sources/TokeniCore`.
  - Keep state management, refresh coordination, and preferences in `Sources/TokeniApplication`.
  - UI layers (`TokeniBar`, `TokeniWindows`) must remain thin bridges over `TokeniApplication`; never duplicate business logic across platforms.
  - Do not scatter `#if os(...)` conditionals across Core and Application; use protocol abstractions from `PlatformContracts.swift`.
- Keep provider-specific authentication and parsing inside its provider directory (`Sources/TokeniCore/Providers/<Name>`).
- Add providers through `ProviderRegistry`; do not add provider switches to shared UI.
- Keep Tokeni growth provider-neutral and derive it only from verified cumulative
  token observations. Active minutes may drive animations, but never growth.
- Companion state must not contain provider names, token totals, prompts, or response content.
- Never log or persist access tokens, refresh tokens, cookies, prompts, or response content.
- Treat local CLI formats and remote endpoints as unstable. Every parser change needs a sanitized fixture test.
- Prefer an unavailable or stale state over fabricated quota or cost values.
- Shared files (`Package.swift`, `UsageStore.swift`, `ProviderRegistry.swift`) must not be modified concurrently by multiple agents or branches. Follow `docs/WINDOWS_DEVELOPMENT_WORKFLOW.ko.md` for role-based write sets.

## Verification

- When working in an environment with the Swift toolchain: run `swift test` and `swift build` before handing off changes.
- When working in containerized or script-only environments without Swift: run the fast script verification suite (`./Tests/Scripts/*.sh`, `./Scripts/validate_localizations.sh`, `./Scripts/validate_companion_assets.sh`, `./Scripts/validate_release_notes.sh all`).

## Release notes

- Every user-visible source or packaging change must add a unique bilingual
  `.changes/YYYYMMDD-lowercase-slug.md` fragment following
  `.changes/README.md`.
- Write concise user-facing Korean and English summaries. Do not copy commit
  messages, internal implementation detail, secrets, paths, prompts, responses,
  or raw token totals into release notes.
- Mark user action with `breaking: true` and provide both `action_ko` and
  `action_en`. Otherwise use `breaking: false`.
- Never edit or delete a released fragment. The renderer includes only fragments
  added or modified after the previous semantic-version tag.
- Before creating a release tag, run
  `Scripts/render_release_notes.sh <version> <output-file>` and review both
  languages. Do not tag or deploy without a successful main-branch CI run.
- The release workflow must publish the validated rendered file with
  `--notes-file`; do not switch back to unstructured generated notes.

## Agent skills and workflows

This repository provides standardized agent skills under `.agents/skills/`, shared across Claude Code, Codex CLI, and Antigravity CLI:

- `.agents/skills/release-fragment/SKILL.md`: Create and validate bilingual `.changes/` release note fragments.
- `.agents/skills/project-verify/SKILL.md`: Run test suites, localization parity, companion asset validation, and release note linter.
- `.agents/skills/add-provider/SKILL.md`: Implement, register, and test new AI provider adapters in `TokeniCore`.
- `.agents/skills/package-macos/SKILL.md`: Build, package, and smoke-test macOS app bundles and Homebrew formulas.
- `.agents/skills/companion-assets/SKILL.md`: Generate and validate companion pet sprite assets, palettes, and manifests.
- `.agents/skills/localization/SKILL.md`: Add and update bilingual UI strings and verify Korean/English parity.
- `.agents/skills/prepare-pr/SKILL.md`: Verify branch scope, pre-PR checks, release fragments, and create GitHub PRs.
- `.agents/skills/release-deploy/SKILL.md`: Tag semantic releases, monitor GitHub Release workflows, and complete Homebrew distribution.
- `.agents/skills/package-windows/SKILL.md`: Build, package, and smoke-test Windows portable zip and native binaries.
- `.agents/skills/diagnostic-report/SKILL.md`: Generate and validate sanitized provider diagnostic reports.



For CLI inter-compatibility:
- Claude Code discovers guidelines via `CLAUDE.md` (symlinked to `AGENTS.md`) and `.claude/skills` (symlinked to `.agents/skills`).
- Codex CLI natively discovers `AGENTS.md` and `.agents/skills/`.
- Antigravity CLI natively discovers `AGENTS.md` and `.agents/skills/` with progressive disclosure.
- Refer to `docs/AGENT_SKILLS.md` (`docs/AGENT_SKILLS.ko.md`) for detailed workflow guides.

