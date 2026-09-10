---
name: package-macos
description: Use this skill to build the macOS release bundle, run packaging smoke tests, and render Homebrew formulas.
---

# macOS App Packaging & Distribution

Guide to building the native macOS application bundle, validating package contents, and generating Homebrew distribution artifacts.

## When to Use

- Preparing a new application release or testing release packaging locally on macOS.
- Generating and updating Homebrew Cask or Formula specifications.

## Prerequisites

- macOS build host with Xcode Command Line Tools or Xcode.app installed.
- Standard tools: `swift`, `shasum`, `zip`.

## Workflow

### 1. Build and Package Application Bundle

Runs `swift build -c release`, assembles `TokeniBar.app`, and embeds resources:

```bash
./Scripts/package_app.sh
```

Artifacts created:
- `dist/TokeniBar.app`
- `dist/TokeniBar.zip`

### 2. Run Packaging Smoke Tests

Validates app bundle layout, executable permissions, `Info.plist`, and embedded resource integrity:

```bash
./Scripts/smoke_macos_package.sh
```

### 3. Generate Homebrew Distribution Files

Compute the SHA-256 checksum of the target archive and render updated Homebrew ruby definitions:

```bash
# Render Homebrew Formula
./Scripts/render_homebrew_formula.sh <version> <archive-sha256> Formula/tokeni-bar.rb

# Render Homebrew Cask
./Scripts/render_homebrew_cask.sh <version> <zip-sha256> Casks/tokeni-bar.rb
```

### 4. Render Release Notes

Before publishing or tagging:

```bash
./Scripts/render_release_notes.sh <version> dist/release-notes.md
```

Review both Korean and English sections carefully before finalizing the release.
