# Tokeni Bar

[한국어](README.md) | **English**

[![CI](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/90ms/tokeni-bar)](https://github.com/90ms/tokeni-bar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<p align="center">
  <img src="packaging/AppIcon.png" width="144" alt="Tokeni Bar pixel-art app icon" />
</p>

A macOS menu-bar app for tracking AI coding-agent **tokens and quotas** while
raising the pixel companion **ByteBot** with real token usage.

## Quick install

```bash
brew install --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

| Requirement | Details |
|---|---|
| Operating system | macOS 14 Sonoma or later |
| Build tools | Current Xcode Command Line Tools (`xcode-select --install`) |
| Agent | At least one of Codex, Claude Code, Grok, Gemini CLI, or OpenCode |

The Formula builds and ad-hoc signs the app on your Mac. It requires neither an
Apple Developer ID nor the full Xcode app.

If Homebrew asks for trust, trust only the Formula rather than the whole tap:

```bash
brew trust --formula 90ms/tap/tokeni-bar
brew install --formula tokeni-bar
```

## What does it show?

| Area | Information |
|---|---|
| Menu bar | Lowest quota, selected provider, monthly cost, or ByteBot status |
| Usage | Remaining quota, reset time, tokens, and reference cost per provider |
| History | Local aggregates for the last 24 hours, 7 days, and 30 days |
| Alerts | Low remaining quota and monthly budget |
| ByteBot | Life stage, rarity, today's energy, bond, and behavior |
| Collection | 12 forms, completed generations, records, and guarantees |

Values that cannot be verified remain **unavailable** or **stale**. Quota
percentages always mean **percent left**, and costs are API-equivalent
references—not subscription bills.

## How ByteBot grows

### 1. Tokens become growth energy

For today's verified token total `T`:

```text
T = 0  → 0
T > 0  → floor(32 × log2(1 + T / 25,000))
```

| Tokens today | Growth energy today |
|---:|---:|
| 10,000 | 15 |
| 25,000 | 32 |
| 50,000 | 50 |
| 100,000 | 74 |
| 250,000 | 110 |
| 500,000 | 140 |
| 1,000,000 | 171 |

More tokens continue raising the daily energy target, although gains become
more gradual at high usage. The action-energy balance is capped at 320.
Refreshing the same cumulative value never pays twice, and 20% of the remaining
balance carries over when the date changes.

### 2. Four life stages

| Action | Energy spent | Result |
|---|---:|---|
| Hatch egg | 60 | Reveal the first rarity and become a Hatchling |
| Evolve to Junior | 100 | Keep or raise rarity and become a Junior |
| Evolve to Adult | 160 | Keep or raise rarity and become an Adult |
| Receive a new egg | 40 | Start the next generation as an ungraded egg |

Having enough energy never hatches or evolves automatically. The user must
click the action. Energy earned as an Adult fills action energy and also records
bond.

Working, low quota, patting, and long inactivity change ByteBot's behavior but
never add growth energy.

### 3. Rarity may rise at evolution

Rarity advances through `Normal → Rare → Epic → Legendary` and never drops.

| Current rarity | Stay | Rare | Epic | Legendary |
|---|---:|---:|---:|---:|
| Normal | 75.0% | 21.0% | 3.8% | 0.2% |
| Rare | 86.0% | - | 13.0% | 1.0% |
| Epic | 97.0% | - | - | 3.0% |
| Legendary | 100% | - | - | - |

An Adult hatched from an ungraded egg has this final distribution without
guarantees:

| Normal | Rare | Epic | Legendary |
|---:|---:|---:|---:|
| 42.2% | 40.9% | 15.5% | 1.4% |

### 4. Repeated low rarity activates guarantees

| Guaranteed rarity | Maximum completed generations |
|---|---:|
| Rare or higher | 3 |
| Epic or higher | 7 |
| Legendary | 16 |

Only finishing an Adult journey advances these counters. Restarting before
Adult keeps the existing guarantees but does not move them closer.

### 5. Collection and new eggs

| Choice | Result | What remains |
|---|---|---|
| Stay with an Adult | New energy becomes bond | Current form and all records |
| Finish an Adult journey | Archive rarity and bond, then start a new egg | Collection and guarantees |
| Leave before Adult | Spend 40 energy and start a new egg | Collection and existing guarantees |

The collection has 12 forms: four rarities for Hatchling, Junior, and Adult.
When a high rarity first appears late, its earlier forms also unlock as
**Lineage**.

Open the grid button in the menu or choose
**Settings → Tokeni → Open ByteBot Collection**. See
[ByteBot growth and collection](docs/bytebot.md) for the complete rules.

## Provider support

| Provider | Account quota | Token and cost display | ByteBot growth source |
|---|---|---|---|
| Codex | Weekly and model-scoped limits; reset credits | Daily, month, and lifetime tokens; reference cost | Confirmed daily total or session increases |
| Claude Code | 5-hour, weekly, and model-scoped limits | Local daily tokens; cache-aware reference cost | Confirmed daily total |
| Grok | Not available | Current local session context | Session increases after the first observation |
| Gemini CLI | Not available | Latest local session tokens | Session increases after the first observation |
| OpenCode | Not available | Local aggregate tokens and recorded cost | Aggregate increases after the first observation |

Session and lifetime counters establish a baseline first so existing usage is
not awarded as new growth. See
[usage display and growth accounting](docs/usage.md) for details.

## First use

| Step | Action |
|---:|---|
| 1 | Run and sign in to each CLI you want to use |
| 2 | Start Tokeni Bar and open the chart icon in the menu bar |
| 3 | Choose providers and the menu-bar display under **Settings → General** |
| 4 | For Claude account quotas, choose **Provider Connections → Connect** |
| 5 | Use an agent and watch ByteBot grow |

## Update and uninstall

| Task | Command or location |
|---|---|
| Update in the app | **Settings → General → App Updates → Install & Restart** |
| Update in Terminal | `brew update && brew upgrade --formula 90ms/tap/tokeni-bar` |
| Refresh the app link | `tokeni-bar --install-app` |
| Remove only the app | `tokeni-bar --uninstall-app` |
| Remove the Formula | `brew uninstall --formula tokeni-bar` |

The app checks for a stable release every six hours but never installs before
an explicit click. See
[Homebrew migration](docs/HOMEBREW.md#migrating-from-the-cask) for a previous
Cask installation.

For a direct installation, download the ZIP from the
[latest release](https://github.com/90ms/tokeni-bar/releases/latest). If macOS
blocks the first launch, approve it under
**System Settings → Privacy & Security**.

## Privacy

| Stored locally | Never stored |
|---|---|
| Aggregate quota, tokens, and estimated cost | Prompts and model responses |
| ByteBot stage, rarity, collection, and guarantees | Access tokens, refresh tokens, and cookies |
| Deduplication checkpoints | Account secrets and server telemetry |

Usage history stays on the Mac for 30 days. ByteBot state and token checkpoints
are separate, and there is no analytics or remote game server.

## Troubleshooting

| Symptom | What to check |
|---|---|
| No app window | Look for the chart icon on the right side of the menu bar, not the Dock |
| Provider unavailable | Confirm the CLI is installed and signed in, then run it once |
| Homebrew trust error | Run `brew trust --formula 90ms/tap/tokeni-bar` |
| Previous ByteBot progress is absent | Version 0.8.0 starts the token-powered game with a new egg; settings and usage history remain |

## Development

```bash
git clone https://github.com/90ms/tokeni-bar.git
cd tokeni-bar
./Scripts/test.sh
swift build
./Scripts/package_app.sh
open "dist/Tokeni Bar.app"
```

See [AGENTS.md](AGENTS.md) for contribution rules and
[Homebrew distribution](docs/HOMEBREW.md) for the release flow.

## License

[MIT](LICENSE)
