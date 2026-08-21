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
| Preparation | Technology and distribution contract | TBD | Pending | Decide UI host and deployment model |
| 1 | Application services | TBD | Pending | Merge preparation work |
| 1 | Windows dashboard | TBD | Pending | Finalize presentation contract |
| 1 | Provider and smoke CI | TBD | Pending | Finalize toolchain and test matrix |

## Decision log

- 2026-08-21: Adopted short-lived wave worktrees and PRs instead of long-lived stacked
  branches.
- 2026-08-21: Assigned one coordinator and up to three implementation agents, using file
  write sets and shared-file ownership to prevent conflicts.
- 2026-08-21: Every PR starts as draft, advances to ready and merge only after CI and
  review, and the next wave starts from the updated `main`.
