# Windows porting plan

This is the living implementation plan for Windows support. Each step is developed on
top of the previous branch as a stacked pull request. The status, decisions, and
verification results are updated before each PR is submitted.

## Goals

- Add a Windows tray client while preserving the existing macOS app.
- Reuse provider models, parsers, history, cost calculations, Tokeni growth rules, and
  companion game rules wherever possible.
- Use only verified Windows provider paths and CLI behavior; retain unavailable or stale
  states instead of inventing values.
- Keep existing macOS builds and behavior regression-free throughout the port.

## Target architecture

```text
TokeniCore
  models, parsers, calculations, history, growth, companion domain

TokeniApplication
  usage refresh, shared state, alert policy, preference coordination

TokeniPlatformMac
  macOS paths, processes, notifications, launch-at-login, updates

TokeniBar
  existing macOS SwiftUI/AppKit UI

TokeniWindows
  Windows tray, windows, notifications, and overlay UI
```

`UsageStore` currently combines state, persistence, notifications, updates, companion
coordination, and macOS APIs. It will not be reused directly by another UI. Shared state
and calculations move to `TokeniApplication`, while the macOS `ObservableObject` becomes
a thin bridge.

## Stacked PR order

Every branch is created from the immediately preceding PR branch. PRs are reviewed,
verified, and merged in this order; the plan is updated before each submission.

| Step | Example branch | Scope | Status |
|---|---|---|---|
| PR1 | `windows/01-porting-plan` | This plan and common-boundary decisions | PR created |
| PR2 | `windows/02-platform-contracts` | Windows core target, platform protocols, target boundaries | CI passed |
| PR3 | `windows/03-platform-infrastructure` | App paths, file storage, processes, CLI lookup, SQLite | CI passed |
| PR4 | `windows/04-application-refresh` | Shared provider refresh coordinator and macOS `UsageStore` bridge | CI passed |
| PR5 | `windows/05-application-history` | Shared history load, save, clear, and macOS bridge | CI passed |
| PR6 | `windows/06-application-growth` | Verified token observations and growth-ledger boundary | CI passed |
| PR7 | `windows/07-application-preferences` | Settings storage, alert policy, and macOS bridge | CI passed |
| PR8 | `windows/08-json-providers` | Copilot, Cline, Grok, Gemini paths and fixtures | CI passed |
| PR9 | `windows/09-cli-providers` | Codex and Claude executable/Windows CLI contracts | CI passed |
| PR10 | `windows/10-sqlite-providers` | Antigravity and OpenCode SQLite readers and fixtures | CI passed |
| PR11 | `windows/11-windows-runtime` | Windows core runtime/state transport boundary | CI passed |
| PR12 | `windows/12-windows-tray-ui` | Windows executable target, host lifecycle, and state-consumption seam | CI passed |
| PR13 | `windows/13-windows-tray-surface` | Win32 tray shell, usage presentation, and basic tooltip | CI passed |
| PR14 | `windows/14-settings-storage` | Windows file-backed settings and shared preference seam | In progress |
| PR15 | `windows/15-windows-services` | Windows notification, startup, and update adapters | Pending |
| PR16 | `windows/16-companion-overlay` | Pet overlay, monitors, click-through, accessibility | Pending |
| PR17 | `windows/17-packaging-ci` | Windows installer, CI, artifacts, release docs | Pending |
| PR18 | `windows/18-integration` | Final integration, macOS regression, Windows hardware validation | Pending |

PR8's Cline and Grok/Gemini workstreams have disjoint provider and test write sets, so
they were reviewed and prepared in parallel. Shared documentation and the release-note
fragment remain owned by the integration pass, and the work is submitted as one stack
layer to preserve review and verification order.

## Shared boundaries

### Reusable areas

- `Sources/TokeniCore/Models`
- Provider JSON, JSONL, and protocol parsers and aggregators
- `Sources/TokeniCore/History`
- Models, rules, and engines under `Sources/TokeniCore/Companion`
- Pricing, exchange-rate, and diagnostics calculations
- Bounded file enumeration and safe JSONL reading

### Platform protocols

- `ApplicationDirectoriesProviding`: app data, cache, and provider roots
- `ExecutableLocating`: CLI and `.exe`/`.cmd` lookup
- `ProcessRunning`: process execution, environment, cancellation, termination
- `ReadOnlySQLiteQuerying`: Antigravity/OpenCode database access
- `SettingsStoring`: macOS UserDefaults and Windows persistence
- `NotificationDelivering`: macOS notifications and Windows Toasts
- `LaunchAtLoginManaging`: macOS ServiceManagement and Windows startup registration
- `AppUpdateInstalling`: Homebrew relink and Windows installer/MSIX/winget
- `MotionSettingsProviding`: power and accessibility motion policy

The existing `ProcessRunning` abstraction remains, but providers must stop constructing
`Process` or `/usr/bin/sqlite3` directly. OS I/O is injected behind testable boundaries.

## Provider scope and risks

| Provider group | Main Windows work | Risk |
|---|---|---|
| Codex, Claude | CLI lookup, Windows PATH, bidirectional processes, auth/quota contract | High |
| Copilot, Cline, Grok, Gemini | `%APPDATA%`/`%LOCALAPPDATA%`, VS Code-family paths, JSONL fixtures | Medium |
| Antigravity, OpenCode | Windows SQLite executable or bundled reader, WAL validation | Very high |

Gemini and OpenCode have implementations and tests but are not currently in the default
`ProviderRegistry`. This path-porting stage preserves the existing provider exposure on
macOS; whether either provider enters the default registry is deferred to integration.

## Agent write sets

Shared files have one owner at a time.

- Platform foundation: `Package.swift`, `Sources/TokeniCore/Infrastructure`, and shared
  contracts under `Sources/TokeniCore/Updates`
- State extraction: `Sources/TokeniApplication` and `Sources/TokeniBar/UsageStore.swift`
- Provider agents: one provider directory plus its tests and fixtures
- Windows UI: the new `TokeniWindows` project/directory only
- Distribution: `packaging/windows`, PowerShell scripts, and the Windows CI job
- Integration owner: final `ProviderRegistry`/`Package.swift` edits and conflict resolution

`Package.swift`, `UsageStore.swift`, `ProviderRegistry`, and `.github/workflows` are not
edited concurrently by multiple agents.

## PR definition of done

Each PR must satisfy all applicable items:

1. It is one independently reviewable design or feature unit.
2. Relevant sanitized fixtures and tests are included.
3. `swift test` and `swift build` pass on macOS.
4. Windows changes pass core build/tests on a Windows runner.
5. Missing or stale provider data is never fabricated.
6. User-visible source or packaging changes include a unique bilingual `.changes` fragment.
7. This plan and affected README/operational documentation are current.
8. Only intended files are committed and the stacked PR base/head is correct.

## Decision log

- 2026-08-20: Split Windows work into 18 small stacked PRs. The broad `UsageStore` work
  was divided into provider refresh, history, growth, and preferences layers.
- 2026-08-20: Share TokeniCore calculations, parsers, and domain rules; isolate OS I/O
  and UI behind platform adapters.
- 2026-08-20: Split `UsageStore` into shared application state plus a macOS UI bridge
  instead of reusing it directly from the Windows UI.
- 2026-08-20: Submitted PR1 as stacked draft PR #31 on `main` and started PR2 on
  top of that branch.
- 2026-08-20: Because SwiftPM's `platforms` array declares platforms with deployment
  versions, Windows is provided through conditional targets rather than added as
  `.windows` in that array.
- 2026-08-20: Fixed PR2's release-note check and SwiftPM manifest issue, then passed
  macOS CI. Started PR3 on top of that branch.
- 2026-08-20: Added app paths, executable lookup, and SQLite infrastructure in PR3 and
  passed macOS CI. The original broad application-state PR was split into smaller
  provider-refresh, history, growth, and preferences/alerts layers.
- 2026-08-20: PR4's `TokeniApplication` provider refresh coordinator and macOS bridge
  passed macOS CI. PR5 starts with the history storage boundary only.
- 2026-08-20: PR5's shared history coordinator and macOS bridge passed macOS CI. PR6
  covers the growth-ledger persistence boundary separately from companion presentation
  and rewards.
- 2026-08-20: PR6's growth-ledger coordinator passed macOS CI. PR7 separates settings
  storage and alert policy from provider and companion UI code.
- 2026-08-20: PR7's settings contract, macOS adapter, and shared alert-preference model
  passed macOS CI.
- 2026-08-20: PR8 moves Cline's macOS-only application-support root behind an injectable
  platform boundary and makes Gemini and Grok user-data roots injectable. Copilot keeps
  its existing home-relative and environment-variable-based contract because it is
  already platform-neutral.
- 2026-08-20: PR8 provider tests, macOS app build, and bundle validation CI passed. PR9
  starts the Windows executable and process contracts for Codex and Claude CLI providers.
- 2026-08-20: Started PR9 on top of PR8. Codex and Claude providers have disjoint write
  sets for parallel review, while the shared CLI execution boundary remains with the
  integration owner.
- 2026-08-20: Integrated the PR9 provider changes. Codex and Claude now cover Windows
  executable discovery, PATH delimiters, official configuration-root overrides, and
  sanitized locator tests while preserving existing macOS CLI and local-fallback behavior.
- 2026-08-20: PR9 CLI provider tests, macOS app build, and bundle validation CI passed.
  PR10 starts the SQLite reader and Windows database-access boundary for Antigravity and
  OpenCode.
- 2026-08-20: PR10 adds shared SQLite executable discovery and a read-only query runner,
  then moves Antigravity and OpenCode readers behind injectable boundaries. If SQLite is
  unavailable on Windows, usage remains unavailable/failed rather than being fabricated.
- 2026-08-20: PR10 SQLite provider tests, macOS app build, and bundle validation CI passed.
  PR11 starts the runtime boundary for consuming shared application state from a Windows
  executable.
- 2026-08-20: PR11 adds `UsageApplicationRuntime` and `UsageApplicationState` so provider
  refresh, history, and growth-ledger transitions are separated from the UI. The macOS
  `UsageStore` now uses this boundary, and the Windows UI will consume the same state in
  the next layer.
- 2026-08-20: PR11's macOS tests, app build, and bundle validation CI passed. The next
  layer is the Windows tray UI that consumes this shared state boundary.
- 2026-08-20: The original PR12 scope combined the executable/host lifecycle with the
  actual tray surface, so PR12 is split into a host boundary first and the downstream
  layers are shifted by one. PR13 now owns the Win32 tray surface.
- 2026-08-20: PR12's shared application-session tests, macOS app build, and bundle
  validation CI passed. PR13 now implements the actual Win32 tray surface consuming
  this session.
- 2026-08-20: PR13 adds a presentation model that exposes only usable snapshot values
  and a Win32 notification-area shell boundary. The tray's settings, history, and
  diagnostics surfaces will build on this shell.
- 2026-08-20: PR13's macOS shared tests, app build, and bundle validation CI passed.
  Windows toolchain compilation will be added separately in the Windows CI layer.
- 2026-08-20: PR14's settings scope is separated from notifications, startup, and
  updates because those platform services require different Windows APIs and review
  risks. The file-backed settings boundary comes first.
