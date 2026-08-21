# Windows multi-agent development workflow

This document is the execution standard for parallel Windows feature-parity work.
Preserve technical boundaries and completed history in the
[Windows porting plan](WINDOWS_PORTING_PLAN.md). Update this document with the order,
ownership, pull requests, and verification status of future work.

## Goals

- Deliver macOS product capabilities through shared application services and
  Windows-specific UI and platform adapters.
- Give every agent an isolated worktree and a short-lived branch.
- Avoid concurrent edits to shared files and merge only small PRs that pass CI.
- Start each new wave from the latest `main` after its dependencies merge.
- Never infer unverified provider values or platform behavior.

## Operating rules

1. Never develop or commit directly on `main`.
2. Prefix every branch with `codex/`.
3. Keep each PR limited to one independent feature or structural change.
4. Run at most four agents concurrently, including the coordinator.
5. Only the coordinator edits `Package.swift`, application entry points, shared
   registries, workflows, and shared planning documents.
6. Never edit `UsageStore.swift` concurrently in two branches.
7. Start dependent work in a new worktree from the latest `main`; do not reuse a stale
   long-lived branch.
8. Do not modify or commit existing user changes or out-of-scope files.

## Roles and write sets

| Role | Responsibility | Default write set |
|---|---|---|
| Coordinator | Decomposition, shared files, integration, CI and review monitoring, merge | `Package.swift`, entry points, shared registries, planning documents |
| Application agent | Platform-neutral state and use cases, thin macOS bridge | `Sources/TokeniApplication`, approved `UsageStore.swift` sections, application tests |
| Windows UI agent | Dashboard, settings, history, companion UI, Win32/WinUI adapters | `Sources/TokeniWindows`, `Sources/TokeniWindowsNative`, Windows UI tests |
| Validation agent | Windows provider contracts, SQLite, CI, packaging, device verification | Assigned providers and fixtures, `Tests`, `Scripts`, `packaging/windows` |

A PR-specific write set overrides the generic role. If two agents need the same file,
the coordinator extracts a prerequisite PR or assigns that file to one agent only.

## Worktrees and branches

Create worktrees in a dedicated directory outside the primary checkout. Each worktree
owns exactly one branch.

```powershell
git fetch origin
git switch main
git pull --ff-only origin main
git worktree add <worktree-root>\application-services `
  -b codex/windows-application-services origin/main
git worktree add <worktree-root>\windows-ui `
  -b codex/windows-ui-shell origin/main
git worktree add <worktree-root>\windows-validation `
  -b codex/windows-validation origin/main
```

Before removal, verify that the worktree is clean and its PR branch is pushed. Use
`git worktree remove`, not recursive filesystem deletion. Delete a merged branch only
after removing its worktree.

## Preparation decisions

- Wave 1 keeps the existing Swift application/core and Win32 host. Its first surface is
  a modeless dashboard built from standard Win32 controls. Reassess WinUI 3 after a
  stable host-neutral API exists.
- Development and CI keep the existing portable ZIP. Define the production installer,
  app identity, signing, and automatic-update contract together in Wave 4; do not enable
  automatic installation before then.
- GitHub-hosted Windows runners gate only non-interactive executable and package smoke.
  Keep tray, notification, overlay, DPI, and virtual-desktop behavior in an interactive
  self-hosted or physical-device test matrix. Execute and record that matrix with the
  [Windows physical-device validation runbook](WINDOWS_DEVICE_VALIDATION.md).
- SQLite providers must not silently depend on the user's PATH. Choose a bundled
  executable or linked library in a separate distribution PR, and preserve a verified
  `unavailable` state until that work is complete.
- Wave 1 starts with three independent PRs: provider preferences, modeless dashboard,
  and packaged smoke. Only the coordinator may make follow-up shared entry-point or
  manifest changes.

## Work waves

### Preparation

- Decide the Windows UI technology and Swift core integration model.
- Define the boundary between portable development artifacts and production installers.
- Document the Windows behavior contract and unsupported OS behaviors.
- Prepare the local Windows toolchain and an executable smoke test.

### Wave 1 — Shared foundation and dashboard

| Track | Scope | Dependency |
|---|---|---|
| Application | Move settings, budget, notification, and companion use cases from `UsageStore` into `TokeniApplication` | Preparation |
| Windows UI | Dashboard opened from the tray, navigation, and state presentation shell | Shared presentation contract |
| Validation | Provider paths, SQLite strategy, executable start/stop smoke CI | Preparation |

Wave 1 is integrated when a user can open a Windows dashboard from the tray, inspect
usage and provider state, and terminate the app cleanly.

### Wave 2 — Main user features

| Track | Scope |
|---|---|
| Application | Settings, history, diagnostics, cost, and budget services |
| Windows UI | Usage details, provider selection, history, diagnostics, and localization UI |
| Validation | Windows device contracts for Codex, Claude, Copilot, Cline, Antigravity, and other providers |

### Wave 3 — Companion features

| Track | Scope |
|---|---|
| Application | Companion management, hatch, evolution, sale, collection, shop, rewards, and booster use cases |
| Windows UI | Companion management, collection, shop UI, and animations |
| Native | Overlay movement, sizing, locking, click-through, DPI, monitors, and accessibility |

If public Windows APIs cannot reproduce the macOS all-Spaces behavior, document the
guarantee for the current virtual desktop and do not depend on private shell APIs.

### Wave 4 — Distribution and productization

| Track | Scope |
|---|---|
| Notification | Windows App Notifications, click activation, preferences, and deduplication |
| Distribution | Signing, installer, update and rollback contract, x64 and ARM64 |
| Quality | UI automation, install and update E2E, device matrix, and release gates |

## PR lifecycle

1. Create the worktree and branch from the latest `origin/main`.
2. Record scope, write set, dependencies, and verification plan in the PR body.
3. Modify only assigned files and add relevant fixtures and tests.
4. Add a unique bilingual `.changes` fragment for user-visible source or packaging work.
5. Run `swift test` and `swift build`; verify Windows changes on a Windows runner.
6. Stage only explicit changed paths, then commit and push.
7. Open a draft PR and inspect its diff and CI results.
8. Mark it ready after verification completes.
9. Address failed checks and review requests on the same branch.
10. Merge with the repository's default policy only after every gate passes.
11. Run `git pull --ff-only origin main` in the primary checkout.
12. Remove the merged worktree and branch; start the next task from the new `main`.

Reuse an existing PR with the same base and head instead of opening a duplicate. Do not
continue new work on a branch whose PR has merged.

## Automatic merge gates

The coordinator may merge only when all of the following are true:

- Required checks and affected-platform CI are green.
- `swift test` and `swift build` passed locally, or equivalent Windows CI results are
  available when the local environment cannot run them.
- No unresolved review thread or change request remains.
- The PR is current with its base, conflict-free, and mergeable.
- Sanitized fixtures, privacy constraints, and provider-neutral growth rules are intact.
- Required `.changes` fragments and documentation updates are present.
- No out-of-scope user changes or files owned by another agent are included.

Never bypass human approval, branch protection, signing keys, external accounts, or
deployment permissions. Keep the PR ready and request only the missing authority. Do not
rerun failed CI without understanding the failure; rerun only verified transient failures.

## Synchronization and conflicts

- Merge `origin/main` into an active PR branch only when a base update is necessary. Do
  not force-push a shared PR branch.
- The coordinator resolves conflicts after reading both behaviors and tests.
- If two branches are likely to conflict in the same file, stop parallel work and split
  them into prerequisite and follow-up PRs.
- After a merge, remaining agents reassess their diff against the new base instead of
  applying stale patches automatically.
- Prefer independent changes, then shared application contracts, UI integration, and
  packaging, unless actual dependencies require another order.

## Status board

Use `Pending`, `In progress`, `PR`, `CI`, `Merged`, or `Blocked`. The coordinator updates
this table and the decision log when opening or merging a PR.

| Wave | Track | Branch/PR | Status | Next gate |
|---|---|---|---|---|
| Preparation | Technology and distribution contract | `codex/windows-preparation-decisions` / #64 | Merged | Execute Wave 1 |
| 1 | Provider preferences | `codex/windows-provider-preferences` / #65 | Merged | Session bridge |
| 1 | Packaged smoke CI | `codex/windows-package-smoke` / #66 | Merged | Physical-device package validation |
| 1 | Windows dashboard | `codex/windows-dashboard` / #67 | Merged | Physical-device DPI validation |
| 1 | Provider preference session | `codex/windows-provider-preference-session` / #68 | Merged | Windows host wiring |
| 1 | Explorer tray recovery | `codex/windows-explorer-tray-recovery` / #69 | Merged | Interactive Explorer restart validation |
| 1 | Bundled SQLite | `codex/windows-bundled-sqlite` / #70 | Merged | Physical-device provider validation |
| 1 | Windows host preference wiring | `codex/windows-provider-preference-host` / #72 | Merged | Provider-selection UI |
| 1 | Dashboard initial DPI and focus | `codex/windows-dashboard-initial-dpi` / #73 | Merged | Target-device validation |
| 1 | Interactive validation runbook | `codex/windows-device-validation-runbook` / #74 | Merged | Run the matrix on target devices |
| 1 | Provider-selection UI | `codex/windows-provider-selection-ui` / PR TBD | In progress | Pass CI, merge, then run SEL-01/02/03 |

## Decision log

- 2026-08-21: Adopted short-lived wave worktrees and PRs instead of long-lived stacked
  branches.
- 2026-08-21: Assigned one coordinator and up to three implementation agents, using file
  write sets and shared-file ownership to prevent conflicts.
- 2026-08-21: Every PR starts as draft, advances to ready and merge only after CI and
  review, and the next wave starts from the updated `main`.
- 2026-08-21: Wave 1 keeps the Swift+Win32 host and portable ZIP. Reassess WinUI 3 and a
  production installer/app identity after the shared API and deployment contract mature.
- 2026-08-21: Hosted runners own non-interactive package smoke; physical-device testing
  owns interactive tray, overlay, and DPI behavior.
- 2026-08-21: Merged preparation PR #64, initial Wave 1 PRs #65–#67, the session
  bridge in #68, and Explorer tray recovery in #69.
- 2026-08-21: While bundled SQLite PR #70 runs CI, deferred follow-up changes to the
  shared `TokeniWindowsApp.swift`. Start Windows host preference wiring from updated
  `main` only after #70 merges.
- 2026-08-21: Successful hosted CI does not complete interactive validation of Explorer
  restart recovery, per-monitor DPI, or target Windows devices.
- 2026-08-21: Merged bundled SQLite PR #70 and defined one privacy-safe physical-device
  runbook for tray, Explorer recovery, DPI, accessibility, and provider validation.
