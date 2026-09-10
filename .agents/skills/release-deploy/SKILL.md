---
name: release-deploy
description: Use this skill when executing a release, tagging a semantic version on main, verifying the GitHub Release workflow, and completing Homebrew distribution.
---

# Release & Deployment Runbook

Complete procedure for creating a formal release, publishing GitHub Release artifacts, and updating the Homebrew distribution tap.

## When to Use

- When the user instructs to "release", "deploy", or "publish a new version".
- Only execute after target PRs have merged into `main` and main-branch CI has passed.

## Reference

- Normative policy: `docs/RELEASING.md` (`docs/RELEASING.ko.md`)
- Homebrew policy: `docs/HOMEBREW.md` (`docs/HOMEBREW.ko.md`)

## Step 1: Pre-Release Gate Checks

1. Verify working directory is clean and up to date on `main`:
   ```bash
   git switch main
   git pull --ff-only origin main
   ```

2. Confirm `main` CI passed:
   - Both `macOS required gate` and `Windows required gate` must be green.
   - Never tag or deploy without a successful `main` merge commit run.

## Step 2: Render and Review Release Notes

Determine the next semantic version (e.g., `0.30.0` or `0.29.1`):

```bash
# Render release notes from pending fragments
./Scripts/render_release_notes.sh <version> dist/release-notes.md

# Validate the rendered release notes format
./Scripts/validate_release_notes.sh release <version> dist/release-notes.md
```

Review `dist/release-notes.md`:
- Check both Korean and English summaries.
- Check user action instructions if breaking changes are present.
- Verify installation instructions (`brew install --formula tokeni-bar`).

## Step 3: Create and Push Annotated Git Tag

Create an annotated tag on the validated `main` merge commit:

```bash
git tag -a v<version> -m "Tokeni Bar <version>" HEAD
git push origin v<version>
```

> **Warning**: Never move or delete an already pushed release tag. If a workflow fails due to code issues, carry forward the fragments to a new patch version as described in `.changes/README.md`.

## Step 4: Monitor GitHub Release Workflow

Monitor the triggered GitHub Actions release pipeline:

```bash
gh run list --workflow=release.yml
gh run watch <run-id>
```

The release workflow automatically:
1. Runs full macOS and Windows release test suites.
2. Builds and ad-hoc signs `TokeniBar.app`.
3. Builds Windows portable zip.
4. Generates GitHub build attestations for artifacts.
5. Publishes the official GitHub Release with `--notes-file`.
6. Opens an automated PR to `90ms/homebrew-tap`.

## Step 5: Finalize Homebrew Tap Distribution

1. Check the automated PR on `90ms/homebrew-tap`:
   ```bash
   gh pr list --repo 90ms/homebrew-tap
   ```
2. Verify all tap CI checks pass (Formula build, Cask install & audit).
3. Merge the tap PR using standard merge commit:
   ```bash
   gh pr merge <pr-number> --repo 90ms/homebrew-tap --merge
   ```
4. Perform smoke check:
   ```bash
   brew update
   brew info --formula tokeni-bar
   brew info --cask tokeni-bar
   ```
