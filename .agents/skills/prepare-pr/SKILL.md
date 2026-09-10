---
name: prepare-pr
description: Use this skill whenever preparing, checking, or creating a Pull Request (PR), including branch naming, release fragment checks, pre-PR validation, and PR body formatting.
---

# Prepare & Create Pull Request

Runbook for preparing, verifying, and creating pull requests that comply with repository gates and review standards.

## When to Use

- When the user asks to "create a PR", "submit changes", or "prepare a PR".
- Before pushing branch changes for review.

## 1. Branch Naming & Scope Check

- **Never create a PR directly from `main`**.
- Branch naming convention:
  - `feature/<slug>` or `codex/<slug>`: New features, capabilities, or major enhancements.
  - `fix/<slug>`: Bug fixes and behavior corrections.
  - `docs/<slug>`: Documentation, skill, or runbook updates.
- Keep PRs focused on a single responsibility. Do not bundle unrelated changes.

## 2. Release Fragment Verification

If your branch touches `Sources/*`, `Package.swift`, or `packaging/*`, a unique `.changes/YYYYMMDD-slug.md` fragment is **strictly required**:

```bash
# Verify whether your changes require and contain a valid fragment
./Scripts/validate_release_notes.sh changed origin/main HEAD
```

If missing, use the `release-fragment` skill to create one before proceeding.

## 3. Pre-PR Validation Gate

Run the local validation suite to ensure CI will pass:

```bash
# Fast script verification
./Scripts/validate_localizations.sh
./Scripts/validate_companion_assets.sh
./Tests/Scripts/ReleaseNotesTests.sh
./Tests/Scripts/HomebrewCaskTests.sh
./Tests/Scripts/HomebrewFormulaTests.sh
./Tests/Scripts/LocalizationCatalogTests.sh
./Tests/Scripts/GitHubWorkflowTests.sh

# Swift compilation & tests (if Swift toolchain is available)
command -v swift >/dev/null && swift test && swift build
```

## 4. Push Branch & Create PR with GitHub CLI

1. Push your branch to origin:
   ```bash
   git push -u origin HEAD
   ```

2. Create the PR using `gh pr create` with standard structure:
   ```bash
   gh pr create --title "<type>: <concise description>" --body "$(cat << 'PR_BODY'
   ## Summary
   - Concise summary of changes.

   ## Affected Layers
   - [ ] TokeniCore (neutral models, parsers, companion rules)
   - [ ] TokeniApplication (refresh/growth coordination, preferences)
   - [ ] TokeniBar (macOS UI & popover)
   - [ ] TokeniWindows (Windows tray & overlay)
   - [ ] Packaging / Docs / Agents

   ## Verification
   - [x] Fast script test suite passed
   - [x] Localization key parity verified
   - [x] Companion assets validated
   - [x] Release notes fragment added (or not required)
   PR_BODY
   )"
   ```

3. Confirm CI checks are initiated:
   ```bash
   gh pr checks
   ```
