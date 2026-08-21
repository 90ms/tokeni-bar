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
| PR14 | `windows/14-settings-storage` | Windows file-backed settings and shared preference seam | CI passed |
| PR15 | `windows/15-memory-lifecycle` | Fix existing macOS usage-refresh memory growth | CI passed |
| PR16 | `windows/16-claude-reset-time` | Verified Claude five-hour quota reset propagation/display | CI passed |
| PR17 | `windows/17-windows-services` | Windows notification and startup adapters | CI passed |
| PR18 | `windows/18-windows-updates` | Windows update-install contract and safe unsupported state | CI passed |
| PR19 | `windows/19-companion-overlay` | Pet overlay, monitors, click-through, accessibility | CI passed |
| PR20 | `windows/20-packaging-ci` | Windows installer, CI, artifacts, release docs | CI passed |
| PR21 | `windows/21-tray-details` | Windows tray detail surface, reset times, and refresh/quit actions | CI passed |
| PR22 | `windows/22-windows-services-ui` | Settings, notifications, and launch-at-login tray actions | CI passed |
| PR23 | `windows/23-companion-integration` | Companion state, overlay lifecycle, and native fallback renderer | CI passed |
| PR24 | `windows/24-companion-assets-validation` | Packaged sprite parity, final macOS regression, and Windows hardware validation | CI passed; hardware validation pending |
| PR25 | `windows/25-release-artifact` | Versioned Windows ZIP, checksum, attestation, and unified GitHub Release | CI passed; tag validation pending |
| PR26 | `release/0.26.1-readiness` | Claude auth compatibility plus Windows CLI, companion, and CI release-readiness fixes | CI passed; v0.26.1 release pending |

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
3. `swift test` and `swift build` pass on macOS when the scope detector marks macOS as affected; the final integration layer also performs a macOS regression run.
4. Windows changes pass core build/tests on a Windows runner.
5. Missing or stale provider data is never fabricated.
6. User-visible source or packaging changes include a unique bilingual `.changes` fragment.
7. This plan and affected README/operational documentation are current.
8. Only intended files are committed and the stacked PR base/head is correct.

## Decision log

- 2026-08-20: Split Windows work and regression fixes into 21 small stacked PRs. The broad `UsageStore` work
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
- 2026-08-20: PR14's macOS tests, app build, and bundle validation CI passed. The
  observed existing-app memory growth and missing Claude reset time are kept independent
  from the Windows services layer as dedicated regression-fix PRs.
- 2026-08-20: PR15 removed the companion overlay retain cycle and bounded repeated
  persistence work; its macOS tests, app build, and bundle validation CI passed. PR16
  connects reset lines to their Claude five-hour usage window when the CLI response is
  split across multiple lines.
- 2026-08-20: PR16's Claude parser tests, macOS app build, and bundle validation CI passed.
  Windows notifications/startup and update installation are split into PR17 and PR18
  because they have different API, permission, and distribution risks.
- 2026-08-20: PR17 moved Win32 notification balloons and per-user HKCU startup
  registration behind the shared contracts, and its macOS tests, app build, and bundle
  validation CI passed. PR18 starts with a safe update boundary that does not pretend to
  install updates before the Windows package contract exists.
- 2026-08-20: PR18 keeps `AppUpdateInstalling` explicitly unsupported until the
  Windows package format, signing, and install command are defined. It avoids arbitrary
  downloads and `winget` execution while leaving an injection point for the real package
  strategy in PR20.
- 2026-08-20: PR18's safe update boundary and Windows-only tests passed the macOS
  test, app-build, and bundle-validation CI. PR19 keeps companion state and rendering
  shared while isolating the Win32 overlay window, multi-monitor placement, and
  click-through behavior behind a separate boundary.
- 2026-08-20: PR19 does not duplicate companion assets or state; it first isolates
  the transparent Win32 overlay lifecycle, multi-monitor frame clamping, and
  click-through behavior. Shared companion state and rendering assets will be connected
  in the Windows packaging and final integration layers.
- 2026-08-20: PR19's Win32 overlay boundary and native fallback checks passed the
  macOS test, app-build, and bundle-validation CI. PR20 starts the distribution layer
  for Windows SDK builds, tests, artifacts, and the installer contract.
- 2026-08-20: PR20 uses the official Windows Swift installation path and the runner's
  Windows SDK to test and release-build `TokeniWindows`, then emits a portable ZIP
  artifact before code signing. MSIX, signing, and automatic updates remain separate
  distribution contracts rather than implicit install commands.
- 2026-08-20: PR20's Windows build, portable-package creation, and artifact upload passed
  on the Windows runner. Platform-scope detector jobs now skip the expensive macOS or
  Windows build when a pull request does not touch that platform's shared or native
  paths; shared `TokeniCore` and application changes still run both validations. A later
  release-readiness audit found that normal Windows pull requests skipped their test
  step; PR26 makes the full Windows suite mandatory whenever Windows scope is detected.
- 2026-08-20: The remaining integration scope is split into smaller layers. PR21
  makes the tray useful for daily inspection by showing provider details and verified
  reset times and by handling refresh/quit actions. PR22 owns the Windows settings,
  notification, and startup controls while keeping automatic installation explicitly
  unsupported. PR23 connects companion state to the overlay lifecycle and adds a native
  fallback renderer. PR24 owns packaged sprite parity and final macOS and Windows
  validation.
- 2026-08-20: PR21's Windows tray detail formatter, native tray actions, macOS tests,
  macOS app bundle validation, and Windows release package passed CI. The Windows
  detail surface shows verified quota windows and leaves reset information absent when
  the provider does not report it.
- 2026-08-20: PR22 connected the Windows tray to the user-scoped startup registry,
  Windows notification delivery, and the JSON settings store. Its Windows build and
  package passed CI while the macOS build was correctly skipped because the change is
  Windows-only. Automatic update installation remains explicitly unsupported until the
  signed package contract is defined.
- 2026-08-20: PR23 is split from final validation because the existing Win32 overlay
  boundary had no renderer. It will consume shared companion state without copying
  provider or token data, keep the overlay lifecycle platform-specific, and provide a
  small native fallback surface before PR24 adds packaged sprite parity.
- 2026-08-20: PR23's Windows companion lifecycle, native fallback renderer, and portable
  package passed the Windows CI run. The macOS build was canceled after scope detection
  identified Windows-only changes; the detector now ignores `Package.swift` edits that
  are confined to the Windows conditional block and logs the decision. macOS CI remains
  required for shared or macOS-specific changes and can still be started manually.
- 2026-08-20: Started PR24 on top of PR23. It will package the existing companion asset
  catalog into the Windows artifact, validate manifests and PNG dimensions on the
  Windows runner, and document the remaining real-device checks without moving provider
  or token data into the companion boundary.
- 2026-08-20: PR24's Windows executable build, portable ZIP creation, and post-extraction
  companion manifest/PNG validation passed. The macOS build was skipped because the
  changes are Windows-only; real Windows display, tray, and overlay interaction checks
  remain for a Windows device or dedicated hardware runner.
- 2026-08-21: Started PR25 after publishing the macOS v0.26.0 release. The unified
  release workflow builds and validates the Windows package before publishing, then
  attaches its versioned ZIP, SHA-256 file, and build attestation alongside macOS.
- 2026-08-21: PR25's macOS regression, Windows release build, portable ZIP validation,
  and generated SHA-256 verification passed CI. Publishing the unified asset set remains
  gated on the next semantic-version tag; real-device validation and signing remain open.
- 2026-08-21: The v0.26.1 readiness work separates Claude authentication checks from
  usage-text parsing and strengthens Windows batch CLI execution, companion growth,
  tray concurrency, and pull-request test gates. The first real unified-release tag and
  Windows device/signing validation remain assigned to the release run and follow-up
  distribution contract respectively.
- 2026-08-21: PR26's complete Windows test suite, release executable build, portable ZIP,
  companion asset validation, macOS regression suite, and app-bundle validation passed.
  Windows batch argument handling, update-cache persistence fallback, and refresh-loop
  shutdown were corrected from the first full-suite run; v0.26.1 publishing remains gated
  on the main-branch CI run.
