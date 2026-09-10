---
name: package-windows
description: Use this skill when building, packaging, and smoke-testing the Windows portable distribution and native binaries.
---

# Windows Packaging & Smoke Testing

Procedures for building native Windows binaries, packaging the portable release zip archive, and running headless smoke tests.

## When to Use

- Packaging a Windows release or testing Windows portable artifacts locally or in CI.
- Running headless runtime smoke tests on Windows binaries.

## Reference Documentation

- [Windows Development Workflow](../../../docs/WINDOWS_DEVELOPMENT_WORKFLOW.ko.md)
- [Windows Porting Plan](../../../docs/WINDOWS_PORTING_PLAN.ko.md)
- [Windows Device Validation Runbook](../../../docs/WINDOWS_DEVICE_VALIDATION.ko.md)

## Prerequisites

- Windows build environment with Swift 6.2+ toolchain.
- PowerShell 7+ (`pwsh`).
- Visual Studio build tools (MSVC linker, Windows SDK).

## Workflow

### 1. Acquire Bundled SQLite Executable

Download or verify the bundled standalone `sqlite3.exe` for isolated database querying:

```powershell
pwsh ./Scripts/acquire_windows_sqlite.ps1
```

### 2. Validate Windows Companion Assets

Ensure Windows companion asset directory structure and manifests match specifications:

```powershell
pwsh ./Scripts/validate_windows_companion_assets.ps1
```

### 3. Build & Assemble Portable Windows Package

Build the release executable and package with all dependencies:

```powershell
# Build Windows binaries
swift build -c release --product TokeniWindows

# Assemble portable release archive
pwsh ./Scripts/package_windows.ps1 `
  -Version <version> `
  -BuildDirectory .build/release `
  -OutputDirectory dist `
  -SQLiteExecutable <path-to-sqlite3.exe>
```

Artifact created: `dist/Tokeni-Bar-Windows-<version>.zip`

### 4. Execute Smoke Tests on Portable Archive

Runs the headless smoke verification process, asserting clean startup, exit codes, and dependency resolution:

```powershell
pwsh ./Scripts/smoke_windows_package.ps1 `
  -ArchivePath dist/Tokeni-Bar-Windows-<version>.zip `
  -TimeoutSeconds 20
```

### 5. Interactive & Device Validation

For UI items not covered by headless runners (tray icon, DPI scaling, notifications, click-through overlay):
- Follow the test matrix in `docs/WINDOWS_DEVICE_VALIDATION.ko.md`.
