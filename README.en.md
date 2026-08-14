# Tokeni Bar

[한국어](README.md) | **English**

[![CI](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/90ms/tokeni-bar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/90ms/tokeni-bar)](https://github.com/90ms/tokeni-bar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<p align="center">
  <img src="packaging/AppIcon.png" width="144" alt="Tokeni Bar pixel-art app icon" />
</p>

A macOS menu-bar app for tracking AI coding-agent **tokens and quotas** while
discovering and raising ten pixel-pet species across two generations with real
token usage.

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
| Tokeni pets | Level 100 cap, evolution appearances, a separate growth target, names, personalities, memories, behavior, and an optional desktop overlay |
| Pet manager, eggs, and rewards | Collection details and owned roster, duplicate XP, rare mutations, action previews, Starter Egg and Star Shard shop, level rewards, boosters, and cosmetics |

Values that cannot be verified remain **unavailable** or **stale**. Quota
percentages always mean **percent left**, and costs are API-equivalent
references—not subscription bills.

## How Tokeni pets grow

### 1. Verified tokens grow a pet to level 100

Every 600,000 verified cumulative tokens grant one Growth XP. A remainder below
600,000 carries across dates. Active time may change animation, but never creates
XP.

```text
cumulative XP at level L = round(500 × ((L - 1) / 99) ^ 1.7)
```

Level 100 requires 500 cumulative XP, or 300 million verified tokens. Early
levels arrive quickly and progression slows toward the cap.

The initial level cap is 100. At levels 10 and 25, the player can manually evolve the pet
into its Juvenile and Adult appearance without spending XP. Delaying evolution
does not stop level growth. The displayed companion and XP growth target can be
selected independently.

Starting at level 30, every ten levels grant 10 Star Shards so adult pets retain
a recurring goal.

### 2. Collect new pets through eggs

Level rewards arrive at 30 and 40, every five levels from 50, every three levels
from 60, and every level from 70. A full journey grants 460 shards. A level-100
growth target converts each 100 base Growth Energy into 20 shards repeatedly.

The first launch grants one non-sellable Starter Egg, which hatches for free.
Further pets come from the Egg Vault and shop without completing or replacing
the current pet.
Users who migrate an existing active pet receive one additional Homecoming Egg.

| Egg | Unlock or source | Purchase | Resale |
|---|---|---:|---:|
| Starter Egg | Once on first launch | Free | Not sellable |
| Homecoming Egg | Once when migrating an active pet | Not purchasable | Not sellable |
| Mystery Egg | Highest pet level 5 | 90 shards | 30 |
| Starlight Egg | First daily growth activity or discover 3 species | 180 shards | 60 |
| Prismatic Egg | Collection milestones | Not purchasable | 60 |

A Starlight Egg selects an undiscovered species when one remains and rolls a
10% Prismatic chance and 2% Mutation chance. A Prismatic Egg guarantees the
Prismatic variant. Discovering 5 and 10 species grants a Starlight Egg at each
milestone; discovering 5, 10, 20, and 30 species/variant combinations grants a
Prismatic Egg at each milestone.

Unopened eggs acquired before the update retain the generation-one species
pool. Eggs acquired after the update include all ten species at equal base
odds, so adding content cannot change an outcome already fixed by a saved seed.

Opening another egg never removes the current pet. The hatchling joins the
owned-pet roster; select one pet at a time to receive Growth XP and switch at any
time. Inactive pets can be sent to a new home for Star Shards. Their level does
not increase resale value, and collection discoveries remain recorded.

### 3. Manage the collection and owned pets

The pet manager keeps **Collection** and **Owned** in one screen. Collection records
discovered species, appearances, lifecycle forms, and rare mutations; Owned lists each
hatched pet with its level, name, personality, memories, switching, showcasing, and
resale actions. In the Owned view, choose a species from **View by pet** to show
only that species and see the displayed count or an empty-result explanation.

Select a collection card to inspect details, discovered growth stages, common
actions, and a mutation-only signature action with animated previews.

### 4. Discover ten species across two generations

Generation 1 contains ByteBot, CacheCat, StackFox, PromptPup, and NullSlime.
Generation 2, the **Signal Expedition**, contains QueryOwl, PatchPanda, LoopHare,
RelayRay, and KernelCrab. All ten have equal base odds in newly acquired eggs. While
any species is still missing, the next regular hatch after five duplicates is
chosen from undiscovered species.

Generation 2 is visually distinct through a visible signal core and behavior
mode shifts: wings, ears, fins, or shells change silhouette during work,
warning, and signature actions. It has no power advantage and maps to the same
five balanced benefits as generation 1. Finding three generation-two species
unlocks Hologram Platform; finding all five unlocks the Mini Drone sidekick.

| Variant | Base odds | Power |
|---|---:|---|
| Standard | 91% | Equal |
| Prismatic | 8% | Equal |
| Mutation | 1% | Equal |

After 11 consecutive Standard hatches, regular hatch 12 is Prismatic. The main
collection contains 30 combinations—ten species times Standard, Prismatic,
and Mutation—while evolution appearances are recorded in each combination's
growth album.

A normal egg has a 1% chance to hatch that species' rare Mutation appearance.
It changes the species sprite and adds a signature action without changing
power. Hatching the same `species + appearance` again grants the matching pet
25% of its next-level XP requirement instead of creating another pet. Mutation
appearances are registered in the collection with Standard and Prismatic.

### 5. Earn rewards from levels and activity

| Pet level | First-time reward |
|---:|---|
| 5 | 2x, 30-minute booster |
| 10 | 3x, 20-minute booster |
| 20 | Firefly Aura |
| 25 | 5x, 10-minute booster and Orbit Aura |

Cosmetics now include independent Ground and Sidekick slots alongside existing
auras, backgrounds, and palettes. Cloud Cushion, Hologram Platform, and Meadow
Patch sit beneath a pet; Pixel Chick, Star Sprite, and Mini Drone move beside it.

The first growth activity each day grants 100 Star Shards and one Starlight Egg.
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
fixed while the center content scrolls. The pet status card appears first,
followed by usage. Growable and max-level owned pets are separated by ordering,
badges, and color. Each provider card leads with its primary quota and reset time;
expand **Show details** for additional quotas, tokens, reference costs, and
source information, including in compact mode.

Enable **Settings → Tokeni → Show pet on screen** to keep a transparent pet
panel above other apps.

- Choose a Small, Medium, or Large display size.
- Click the pet to trigger its existing happy frames and a side-to-side hop.
- Drag the pet to a position that is restored on the next launch.
- Transparent space outside the visible pet passes clicks to the app below.
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
| Pet IDs, level/XP, stage, appearance, growth target, name, personality, egg inventory, owned roster, memories, collection, and guarantees | Access tokens, refresh tokens, and cookies |
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
| Cannot use a booster | Check inventory or shard balance. The same multiplier extends time; a different one replaces and discards the active boost's remaining time |
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
