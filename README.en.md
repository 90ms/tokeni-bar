# Tokeni Bar

[한국어](README.md) | **English**

[![CI](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/90ms/tokeni-bar)](https://github.com/90ms/tokeni-bar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<img src="docs/tokeni-bar-icon.png" alt="Tokeni Bar icon" width="128">

A macOS menu-bar app for seeing AI coding-agent token and quota status at a
glance—and raising the pixel companion **ByteBot** with real token usage.

<p align="center">
  <img src="docs/bytebot.png" width="160" alt="Tokeni Bar pixel companion ByteBot" />
</p>

<p align="center">
  <img src="docs/tokeni-bar.png" width="500" alt="Tokeni Bar showing multiple AI coding-agent usage sources" />
</p>

> The sample screen contains no real account data.

## Install

### Requirements

- macOS 14 Sonoma or later
- Current Xcode Command Line Tools (`xcode-select --install`)
- At least one of Codex, Claude Code, Grok, Gemini CLI, or OpenCode

### Homebrew

```bash
brew install --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

The Formula builds and ad-hoc signs the app on your Mac, then links it at
`~/Applications/Tokeni Bar.app`. It does not require an Apple Developer ID or
the full Xcode app.

If Homebrew requires tap trust, trust only the Formula:

```bash
brew trust --formula 90ms/tap/tokeni-bar
brew install --formula tokeni-bar
```

### GitHub Release

You may instead unzip the [latest release](https://github.com/90ms/tokeni-bar/releases/latest)
and move `Tokeni Bar.app` to `/Applications`. Releases are currently ad-hoc
signed. If macOS blocks the first launch, approve it under
**System Settings → Privacy & Security**.

## First use

1. Run each CLI you want to monitor once in Terminal and sign in.
2. Start Tokeni Bar and open its chart icon on the right side of the menu bar.
3. Choose providers and the menu-bar display under **Settings → General**.
4. For Claude account quotas, select **Connect** under
   **Provider Connections** and approve the Keychain request.
5. Use an agent; verified token increases become ByteBot growth energy.

Unsupported or unverifiable values remain unavailable or stale instead of
being estimated.

## Highlights

- Codex and Claude account quota windows and reset times
- Local token and cost records from supported CLIs
- Lowest quota, selected provider, monthly cost, or ByteBot status in the menu bar
- Local 24-hour, 7-day, and 30-day history plus quota and budget alerts
- Token-powered ByteBot with four life stages and four rarity tiers
- A 13-form collection, guaranteed evolutions, and best bond records
- English and Korean, USD and KRW, compact mode, and launch at login

## Raising ByteBot

ByteBot gains more growth energy as today's verified token total rises. There
is no daily hard cap, though gains become more gradual at very high usage.

| Tokens today | Growth energy |
|---:|---:|
| 10,000 | 15 |
| 25,000 | 32 |
| 100,000 | 74 |
| 500,000 | 140 |
| 1,000,000 | 171 |

It hatches at `80` energy, becomes a Junior at `280`, and an Adult at `800`.
Each evolution may raise rarity through
`Normal → Rare → Epic → Legendary`; rarity never drops. Completing Adults
advances visible guarantees for Rare, Epic, and Legendary evolutions.

Keep an Adult and build bond, or finish its journey to receive a new egg. You
may restart before Adult, but current energy is lost and guarantees do not
advance. Collection unlocks and existing guarantees remain.

Open the grid button in the menu or
**Settings → Tokeni → Open ByteBot Collection** to see forms, completed
generations, best rarity, bond, and evolution guarantees.

See [ByteBot growth and collection](docs/bytebot.md) for the formula, rarity
odds, and accounting rules.

## Provider support

| Provider | Account quota | Token and cost display | ByteBot growth source |
|---|---|---|---|
| Codex | Weekly and model-scoped limits; reset credits | Latest daily, month, and lifetime account tokens; API-equivalent reference | Confirmed daily total, or current-session increases as fallback |
| Claude Code | 5-hour, weekly, and model-scoped limits | Deduplicated local daily tokens; cache-aware estimate | Confirmed daily total |
| Grok | Not available | Current local session context | Session increases after the first observation |
| Gemini CLI | Not available | Latest local session tokens | Session increases after the first observation |
| OpenCode | Not available | Local aggregate tokens and recorded cost | Aggregate increases after the first observation |

Session and lifetime counters establish a baseline first so existing usage is
not mistaken for new growth. See the [usage display guide](docs/usage.md) for
details.

## Update and uninstall

```bash
# Update
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app

# Remove the app but retain settings and history
tokeni-bar --uninstall-app
brew uninstall --formula tokeni-bar
```

The app checks for a stable release every six hours. Formula installations can
choose **Settings → General → App Updates → Install & Restart** to refresh
Homebrew, rebuild, replace the app, and restart. Installation never starts
before an explicit click.

See [Homebrew distribution](docs/HOMEBREW.md#migrating-from-the-cask) to migrate
from the previous Cask.

## Privacy

- Prompts and model responses are never displayed or retained.
- Authentication tokens, refresh tokens, and cookies are never logged or
  written to app storage.
- History stores only aggregate quota, token, and estimated-cost values locally
  for 30 days.
- ByteBot state and token checkpoints are separate; neither contains prompt or
  response content.
- There is no analytics or server telemetry.

Tokeni Bar reuses existing CLI sign-ins. Quota percentages always mean
**percent left**, and costs are API-equivalent references—not subscription
bills.

## Troubleshooting

### The app is running but no window is visible

It runs in the menu bar, not the Dock. Look for the chart icon on the right side
of the macOS menu bar.

### A provider shows unavailable

Run its CLI once and confirm that it is installed and signed in. Disable unused
providers under **Settings → General**.

### Selecting the menu exits the app

Installations before `v0.7.2` had a resource-packaging issue. Update in Terminal:

```bash
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

### Previous ByteBot progress disappeared

Version `v0.8.0` replaces the active-time prototype with the token-powered game.
The old pet state is intentionally not converted, so ByteBot starts from a new
egg. Settings and usage history remain.

## Development

```bash
git clone https://github.com/90ms/tokeni-bar.git
cd tokeni-bar
./Scripts/test.sh
swift build
./Scripts/package_app.sh
open "dist/Tokeni Bar.app"
```

See [AGENTS.md](AGENTS.md) for project structure and contribution rules, and
[Homebrew distribution](docs/HOMEBREW.md) for the release flow.

## License

[MIT](LICENSE)
