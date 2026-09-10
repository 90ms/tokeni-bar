---
name: project-verify
description: Use this skill before handing off changes to run test suites, localization checks, asset validation, and release note linter.
---

# Project Verification Suite

Comprehensive verification runbook to validate changes before commit or handoff.

## When to Use

- Always execute before finishing any task or submitting changes.
- Ensure all automated checks and non-functional constraints pass.

## 1. SwiftPM Compilation & Tests (Native Environment)

If working in an environment with the Swift toolchain (e.g., macOS or Linux with Swift installed):

```bash
# Build the project
swift build

# Run unit tests and parser fixture tests
swift test
```

> **Note**: On macOS with standalone Command Line Tools, `./Scripts/test.sh` automatically configures search paths for `Testing.framework`.

## 2. Fast Script Test Suite

The repository contains standalone script-level test runners that validate configuration, packaging scripts, and release mechanics:

```bash
./Tests/Scripts/HomebrewCaskTests.sh
./Tests/Scripts/HomebrewFormulaTests.sh
./Tests/Scripts/ReleaseNotesTests.sh
./Tests/Scripts/GitHubWorkflowTests.sh
./Tests/Scripts/LocalizationCatalogTests.sh
```

## 3. Localization & Asset Validation

Ensure bilingual strings match and companion sprite assets conform to manifests:

```bash
# Check Korean (ko) and English (en) localization parity
./Scripts/validate_localizations.sh

# Validate companion asset directories, animations, and metadata
./Scripts/validate_companion_assets.sh
```

## 4. Release Notes Linter

If changes touch `Sources/`, `Package.swift`, or `packaging/`, verify that release fragments are valid:

```bash
# Validate all existing fragments in repository
./Scripts/validate_release_notes.sh all

# Check branch changes against main
./Scripts/validate_release_notes.sh changed origin/main HEAD
```

## 5. Architectural & Privacy Checklist

Verify manually or by code review:
- [ ] No credentials, access tokens, refresh tokens, or cookies are logged or persisted.
- [ ] No prompt text, completion text, or raw API response bodies are persisted or displayed in UI.
- [ ] Companion growth is derived strictly from verified cumulative token observations, never active minutes.
- [ ] Companion state does not contain provider names, token totals, prompts, or response content.
- [ ] All new provider parsers include sanitized test fixtures in `Tests/TokeniCoreTests/Fixtures/`.
