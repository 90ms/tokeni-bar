# Tokeni Bar

[한국어](README.md) | **English**

[![CI](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/90ms/tokeni-bar)](https://github.com/90ms/tokeni-bar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<p align="center">
  <img src="packaging/AppIcon.png" width="144" alt="Tokeni Bar pixel-art app icon" />
</p>

A macOS menu-bar app for tracking AI coding-agent **tokens and quotas** while
discovering and raising five pixel-pet species with real token usage.

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
| Menu bar | Native monochrome status icon, lowest quota, selected provider, monthly cost or pet status, and a growth-ready badge |
| Usage | Remaining quota, reset time, tokens, and reference cost per provider |
| History | Local aggregates for the last 24 hours, 7 days, and 30 days |
| Alerts | Remaining usage, quota reset, monthly budget, connection failures, quiet hours, and grouped delivery |
| Tokeni pets | Unbounded levels, evolution appearances, owned-pet switching, names, personalities, memories, behavior, and an optional desktop overlay |
| Eggs, collection, and rewards | Starter egg, Star Shard egg shop, ten core discoveries, special eggs, level rewards, boosters, and cosmetics |

Values that cannot be verified remain **unavailable** or **stale**. Quota
percentages always mean **percent left**, and costs are API-equivalent
references—not subscription bills.

## How Tokeni pets grow

### 1. Verified tokens become unbounded levels

Every 25,000 verified cumulative tokens grant one Growth XP. A remainder below
25,000 carries across dates. Active time may change animation, but never creates
XP.

```text
XP for next level = min(2 + floor((current level - 1) / 10), 15)
```

| Goal | Cumulative Growth XP | At 100,000 tokens/day |
|---|---:|---:|
| Level 10 | 18 | About 5 days |
| Level 25 | 66 | About 17 days |
| Each high level | At most 15 | At most about 4 days |

Levels have no cap. At levels 10 and 25, the player can manually evolve the pet
into its Juvenile and Adult appearance without spending XP. Delaying evolution
does not stop level growth.

Starting at level 30, every ten levels grant 10 Star Shards so adult pets retain
a recurring goal.

### 2. Collect new pets through eggs

The first launch grants one non-sellable Starter Egg, which hatches for free.
Further pets come from the Egg Vault and shop without completing or replacing
the current pet.
Users who migrate an existing active pet receive one additional Homecoming Egg.

| Egg | Unlock or source | Purchase | Resale |
|---|---|---:|---:|
| Starter Egg | Once on first launch | Free | Not sellable |
| Homecoming Egg | Once when migrating an active pet | Not purchasable | Not sellable |
| Mystery Egg | Highest pet level 5 | 90 shards | 30 |
| Discovery Egg | Discover 3 different species | 180 shards | 60 |
| Prismatic Egg | Collection milestones | Not purchasable | 60 |

A Discovery Egg selects an undiscovered species when one remains. A Prismatic
Egg guarantees the Prismatic variant. Discovering all five species grants one
Discovery Egg, and discovering 5 and 10 species/variant combinations grants one
Prismatic Egg at each milestone.

Opening another egg never removes the current pet. The hatchling joins the
owned-pet roster; select one pet at a time to receive Growth XP and switch at any
time. Inactive pets can be sent to a new home for Star Shards. Their level does
not increase resale value, and collection discoveries remain recorded.

### 3. Discover five species and their variants

ByteBot, CacheCat, StackFox, PromptPup, and NullSlime have equal base odds. While
any species is still missing, the next regular hatch after five duplicates is
chosen from undiscovered species.

| Variant | Base odds | Power |
|---|---:|---|
| Standard | 92% | Equal |
| Prismatic | 8% | Equal |

After 11 consecutive Standard hatches, regular hatch 12 is Prismatic. The main
collection contains ten combinations—five species times Standard and
Prismatic—while evolution appearances are recorded in each combination's
growth album.

### 4. Earn rewards from levels and activity

| Pet level | First-time reward |
|---:|---|
| 5 | 2x, 30-minute booster |
| 10 | 3x, 20-minute booster |
| 20 | Firefly Aura |
| 25 | 5x, 10-minute booster and Orbit Aura |

Automatic activity attendance, the first verified growth of a day, weekly and
monthly activity, species and variant discoveries, and stable-release gifts
also grant Star Shards. Shards are shared across eggs, cosmetics, and boosters.
There are no real-money purchases, limited-time shops, player trading, or lost
login streaks.

See [Tokeni pet growth and eggs](docs/bytebot.md) for player-facing rules and
the [companion system policy](docs/companion-policy.md) for extensibility and
balance records.

## Menu bar and on-screen pet

Every menu-bar display mode uses a native monochrome status icon. A red badge
appears when an egg can be opened or a level 10 or 25 evolution is ready.

The menu popover keeps its header and history, settings, and quit actions
fixed while the center content scrolls. Usage appears before an always-visible
pet card. Each provider card leads with its primary quota and reset time;
expand **Show details** for additional quotas, tokens, reference costs, and
source information, including in compact mode.

Enable **Settings → Tokeni → Show pet on screen** to keep a transparent pet
panel above other apps.

- Choose a Small, Medium, or Large display size.
- Click the pet to trigger its existing happy frames and a side-to-side hop.
- Drag the pet to a position that is restored on the next launch.
- Lock the position to prevent accidental movement.
- Click-through sends pointer input to the app beneath the pet. Patting and
  moving the pet are unavailable until click-through is turned off.
- Reset position returns the pet to the upper-right of the current screen.
- The panel joins every desktop Space and supported full-screen apps.

## Provider support

| Provider | Account quota | Token and cost display | Pet growth source |
|---|---|---|---|
| Codex | Weekly and model-scoped limits; reset credits | Latest confirmed daily, month, and lifetime tokens; aggregation state; reference cost | Confirmed daily totals arriving within three days, or session increases |
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
| 2 | Start Tokeni Bar and open its status icon in the menu bar |
| 3 | Choose providers and the menu-bar display under **Settings → General** |
| 4 | For Claude account quotas, choose **Providers → Connect** |
| 5 | Use an agent; the first growth activity checks in automatically, then grow the pet, try Star Shard cosmetics, and optionally enable the on-screen pet |

## Update and uninstall

| Task | Command or location |
|---|---|
| Update in the app | **Settings → General → App Updates → Install & Restart** |
| Update in Terminal | `brew update && brew upgrade --formula 90ms/tap/tokeni-bar` |
| Refresh the app link | `tokeni-bar --install-app` |
| Remove only the app | `tokeni-bar --uninstall-app` |
| Remove the Formula | `brew uninstall --formula tokeni-bar` |

The app checks for a stable release every six hours but never installs before
an explicit click. See [Homebrew installation](docs/HOMEBREW.md) for
installation-specific details.

GitHub ZIPs are published as ad-hoc signed builds without Apple Developer ID
signing or notarization. For a direct installation, download the ZIP from the
[latest release](https://github.com/90ms/tokeni-bar/releases/latest).

Verify the build provenance and checksum of a directly downloaded release ZIP:

```bash
gh attestation verify TokeniBar-<version>.zip --repo 90ms/tokeni-bar
shasum -a 256 -c TokeniBar-<version>.zip.sha256
```

## Privacy

| Stored locally | Never stored |
|---|---|
| Aggregate quota, tokens, and estimated cost | Prompts and model responses |
| Pet IDs, level/XP, stage, variant, name, personality, egg inventory, owned roster, memories, collection, and guarantees | Access tokens, refresh tokens, and cookies |
| Star Shards, egg transaction IDs, attendance dates, purchased cosmetics, boosters, and awarded milestone IDs | Account secrets and server telemetry |
| On-screen pet preferences and last position | Screen captures and input content |
| Local progress-validation data | Remote game accounts and analytics telemetry |

Usage history stays on the Mac for 30 days. If progress data is damaged, the
app attempts recovery from retained local copies. Copied diagnostics exclude
token totals and model identifiers by default; prompts, responses,
credentials, cookies, and file paths are always excluded. There is no
analytics or remote game server.

## Troubleshooting

| Symptom | What to check |
|---|---|
| No app window | Look for the Tokeni Bar app icon on the right side of the menu bar, not the Dock |
| Cannot move the on-screen pet | Turn off position lock and click-through under **Settings → Tokeni** |
| Cannot find the on-screen pet | Choose **Settings → Tokeni → Reset pet position** |
| Provider unavailable | Confirm the CLI is installed and signed in, then run it once |
| Claude password prompt repeats after unlock | Update the app and connect once under **Settings → General → Providers**. Background refreshes never open authentication UI |
| Homebrew trust error | Run `brew trust --formula 90ms/tap/tokeni-bar` |
| Pet progress cannot be read | Restart the app to retry local recovery, then review diagnostics if the issue continues |
| Cannot use a booster | Check whether another booster is active and whether you own one or have enough Star Shards to buy it |
| Memory use is temporarily high | Check whether a large provider log just refreshed or a new pet sprite appeared for the first time. Disable the on-screen pet when unused; if memory keeps growing, restart and report diagnostics with reproduction steps |

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
[Homebrew installation](docs/HOMEBREW.md) for install and update guidance.

## License

[MIT](LICENSE)
