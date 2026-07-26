# Tokeni Bar

[한국어](README.md) | **English**

[![CI](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/90ms/tokeni-bar)](https://github.com/90ms/tokeni-bar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<img src="docs/tokeni-bar-icon.png" alt="Tokeni Bar icon" width="128">

A privacy-conscious macOS menu-bar app that keeps AI coding-agent quotas,
token activity, and API-equivalent cost estimates in one place.

<p align="center">
  <img src="docs/tokeni-bar.png" width="500" alt="Tokeni Bar showing Codex, Claude Code, and Gemini CLI usage" />
</p>

> The screenshot follows the current `main` UI and contains sample values only.
> It does not contain real account data.

Tokeni Bar reuses your existing CLI sign-ins. It does not store prompts,
responses, access tokens, refresh tokens, or cookies. Quota percentages always
mean **percent left**, and cost values are references—not subscription bills.

## What it does

- Shows Codex and Claude quota windows, reset times, and account status.
- Combines available account activity with local token and cost records.
- Displays the lowest remaining quota, a selected provider, or monthly cost in
  the menu bar.
- Detects active local sessions from file modification times without reading
  prompt or response content.
- Keeps 24-hour, 7-day, and 30-day aggregate history locally.
- Sends configurable low-quota and monthly budget alerts.
- Supports English and Korean, USD and KRW, compact mode, and launch at login.

## Install

### Requirements

- macOS 14 Sonoma or later
- Apple silicon
- At least one installed and signed-in CLI: Codex, Claude Code, Grok, Gemini
  CLI, or OpenCode

### Homebrew

```bash
brew install --cask 90ms/tap/tokeni-bar
open -a "Tokeni Bar"
```

The fully qualified install command adds the `90ms/tap` repository and trusts
only this Cask on Homebrew versions that require tap trust.

### Direct download

Download the ZIP from the [latest GitHub Release](https://github.com/90ms/tokeni-bar/releases/latest),
unzip it, and move `Tokeni Bar.app` to `/Applications`.

Releases are ad-hoc signed until Developer ID signing is configured. If macOS
blocks the first launch, approve the app in **System Settings → Privacy &
Security**. Do not disable Gatekeeper globally.

## First launch

1. Sign in through each CLI you want to monitor by running it once in Terminal.
2. Open Tokeni Bar and select its chart icon on the right side of the
   menu bar.
3. Open **Settings → General**, enable the providers you use, and choose the
   menu-bar display.
4. For Claude Code account quotas, select **Connect** under
   **Provider Connections** and approve the Keychain request.

Providers that are not installed, signed in, or supported by the current CLI
format remain unavailable instead of showing guessed values.

## Update and uninstall

```bash
# Update
brew update
brew upgrade --cask tokeni-bar

# Remove the app but keep settings and history
brew uninstall --cask tokeni-bar

# Remove the app, settings, and local aggregate history
brew uninstall --cask --zap tokeni-bar
```

The app checks GitHub Releases every six hours and links to a newer stable
release. Homebrew remains responsible for downloading and installing Homebrew
updates.

## Provider support

| Provider | Account quota | Token and cost data |
|---|---|---|
| Codex | Weekly and model-specific limits; available limit-reset credits | Latest daily, current-month, and lifetime account tokens through the experimental Codex app-server; rough API-equivalent reference |
| Claude Code | 5-hour, weekly, and model-scoped limits | Deduplicated local daily tokens with a cache-aware estimate |
| Grok | Not currently available | Current local session context; no cost estimate |
| Gemini CLI | Not currently available | Latest local session tokens; no cost estimate |
| OpenCode | Not currently available | Aggregate local tokens and recorded cost |

Codex and Claude account endpoints and local CLI file formats are not public
compatibility contracts and may change. When verified data cannot be loaded,
the app shows a stale or unavailable state rather than inventing a value.

See the [usage display guide](docs/usage.md) for Codex bucket behavior, Claude
menu-bar quota selection, and cost-estimation details.

## Privacy

- Prompts and model responses are never displayed or retained.
- Authentication tokens, refresh tokens, and cookies are never logged or
  written to app storage.
- Claude credentials obtained after explicit approval stay in memory only until
  expiry or app exit.
- Activity detection reads file metadata, not prompt or response content.
- History stores only aggregate percentages, token totals, and estimated cost
  for 30 days.
- Copyable diagnostics exclude credentials, provider details, and file paths.
- There is no analytics or telemetry.

## Troubleshooting

### A provider shows unavailable

Run its CLI once and confirm that it is installed and signed in. Disable
providers you do not use under **Settings → General**.

Claude Code may require an explicit **Connect** action because its OAuth
credential can be stored in macOS Keychain. Background refreshes never open a
Keychain approval dialog.

### The app is running but no window is visible

Tokeni Bar is a menu-bar app and does not appear in the Dock. Look for
the chart icon on the right side of the macOS menu bar.

### Homebrew reports an untrusted tap

Install with the fully qualified name shown above. To trust an already tapped
Cask explicitly:

```bash
brew trust --cask 90ms/tap/tokeni-bar
brew install --cask tokeni-bar
```

### Cost does not match a subscription bill

Cost is a rough API-price-equivalent reference calculated from the token detail
that each provider makes available. It is not an API invoice or a Codex,
ChatGPT, Claude, or Grok subscription charge.

## Build from source

```bash
git clone https://github.com/90ms/tokeni-bar.git
cd tokeni-bar
./Scripts/test.sh
swift build
./Scripts/package_app.sh
open "dist/Tokeni Bar.app"
```

`Scripts/package_app.sh` uses ad-hoc signing by default. Set
`APP_SIGN_IDENTITY` to another local signing identity.

See the [Homebrew distribution guide](docs/HOMEBREW.md) and
[contributor guide](AGENTS.md) for maintenance details.

## License

[MIT](LICENSE)
