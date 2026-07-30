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
| Tokeni pets | Life stage, species, visual variant, name, personality, bond, memories, behavior, and an optional desktop overlay |
| Collection and rewards | Ten core discoveries and journey albums, automatic activity check-in, animated Star Shard cosmetics, and the nearest guarantee |

Values that cannot be verified remain **unavailable** or **stale**. Quota
percentages always mean **percent left**, and costs are API-equivalent
references—not subscription bills.

## How Tokeni pets grow

### 1. Tokens become growth energy

For today's verified token total `T`:

```text
Growth energy = floor(T / 100,000)
```

| Tokens today | Growth energy today |
|---:|---:|
| 100,000 | 1 |
| 1,000,000 | 10 |
| 10,000,000 | 100 |
| 100,000,000 | 1,000 |
| 300,000,000 | 3,000 |

Every 100,000 verified tokens always grant one energy. A remainder below
100,000 tokens and all unspent action energy carry across date changes. The
regular wallet has a 100,000-energy safety limit to contain invalid data, and
refreshing the same cumulative value never pays twice. Redesign refunds return
previously spent Energy into a separate migration reserve, so that safety cap
cannot discard them.

The collection's **Action energy** section separates tokens reflected in
growth by provider and shows their combined total, today's energy target, and the
additional tokens needed for the next energy point. CLIs without a complete
daily total show only observed session or lifetime increases. Providers that
do not yet have a trustworthy baseline remain **Waiting for data**.

Codex daily account buckets combine usage from every PC signed into the same
account, but the current-day bucket may not be available yet. Tokeni Bar accepts
the newest confirmed bucket for up to three days, calculates growth for its
original usage date, and settles the energy on the day it is confirmed. The
collection shows the usage date plus **Settled today** or **Today pending**.

### 2. Four life stages

| Action | Energy spent | Result |
|---|---:|---|
| Hatch egg | 500 | Reveal the species and Standard or Prismatic variant, then become a Hatchling |
| Evolve to Juvenile | 800 | Keep the same variant and become a Juvenile |
| Evolve to Adult | 1,400 | Keep the same variant and become an Adult |
| Finish an Adult journey and hatch again | 800 | Archive the Adult and immediately hatch a new pet |
| Receive a new egg before Adult | 300 | Restart with a mystery egg |

Having enough energy never hatches or evolves automatically. The user must
click the action. Energy earned as an Adult fills action energy and also records
bond. Evolution shows the previous form entering a glow before the new stage
appears; Reduce Motion and Low Power Mode use a short transition.

Working, a short waiting period after recent activity, low quota, patting, and
long inactivity change the pet's behavior. The pet briefly sparkles when
verified tokens credit growth energy and occasionally shifts while idle. These
visual reactions never add growth energy.

Every species shares the same mystery egg. Hatching reveals ByteBot, CacheCat,
StackFox, PromptPup, or NullSlime at equal 20% base odds. While any species is
still missing, five duplicate hatches guarantee an undiscovered species from
the next egg.

### 3. Collect Standard and Prismatic variants

A pet's variant is decided once at hatch and never changes while evolving.

| Variant | Hatch odds | Rule |
|---|---:|---|
| Standard | 92% | Each species' signature look |
| Prismatic | 8% | A special visual variant with no stat advantage |

After 11 consecutive Standard hatches, hatch 12 is Prismatic. This can combine
with the missing-species guarantee, and the collection leads with whichever
guarantee is nearer. Legacy Rare and Epic looks are preserved as body-color
cosmetic options, and Legendary maps visually to Prismatic. Pets and cosmetics
owned before the redesign are refunded through the one-time asset migration
below before the new collection begins.

### 4. Collection, individual records, and new eggs

| Choice | Result | What remains |
|---|---|---|
| Stay with an Adult | New energy becomes bond | Current form and all records |
| Finish an Adult journey | Spend 800 energy, archive it, and hatch immediately | Collection and variant/species guarantees |
| Leave before Adult | Spend 300 energy and start a new egg | Collection and existing guarantees |

Generation one has ten core discoveries: five species times Standard and
Prismatic. Hatchling, Juvenile, and Adult forms actually encountered remain in
a separate **journey album** under each discovery.

The current pet can have a local name up to 24 characters, a presentation-only
personality, five bond levels, and memories for hatching, evolution, first pat,
bond levels, and journey completion. Memories never contain work content or
usage numbers. Completed pets remain under **Completed Pets**, where their
identity is retained and they can be shown again. No pet grants numerical
growth, cost, odds, or reward advantages.

### 5. Activity and collection achievements award Star Shards

Growth energy continues to come only from verified token usage. Attendance and
collection activity award a separate currency called **Star Shards**.

| Condition | Star Shards |
|---|---:|
| Automatic activity check-in with the first verified growth | 10 |
| First verified growth of the day | 5 |
| 3 / 5 / 7 check-ins in a week | 10 / 20 / 30 |
| 20 check-ins in a month | 50 |
| First discovery of a species | 20 |
| First Prismatic discovery | 50 |
| Completed Adult journey | 25 |
| 5 / 10 variant discoveries | 20 / 100 |
| First launch of a new stable release | 20 |

There is no separate check-in button. The first verified growth observation of
the day records activity attendance automatically. Missing a day does not reset weekly or monthly cumulative progress. Duplicate
claims for the same local date are rejected. If the system date moves behind
the latest claimed date, new attendance remains unavailable until the date is
valid again.

Spend Star Shards on permanent cosmetics in the collection:

| Slot | Cosmetics | Star Shards |
|---|---|---:|
| Aura | Sparkle Aura / Pixel Hearts / Night Ring | 60 / 80 / 200 |
| Head | Developer Headphones / Star Crown / Wizard Hat | 100 / 120 / 140 |
| Background | Terminal Night / Cloud Garden | 160 / 220 |
| Body Color | Legacy Azure / Legacy Violet | 90 / 110 |

The purchase sheet compares the current combination with the result before
spending shards. Cosmetics appear in the menu popover, pet-management window,
and on-screen pet and can be filtered by slot and ownership. One item per slot
can be equipped at the same time. A completed companion's detail sheet shows
its full identity and memory history.
Its decoration scales with the Small, Medium, or Large pet size setting. Every
item has its own motion; intensity can be Off, Gentle, or Full, and aura
contrast adapts on bright backgrounds.
Cosmetics never affect growth energy, variants, guarantees, or rewards. Pet
play focuses on collecting, individual histories, animation, and styling
combinations rather than numerical superiority.

### 6. Major redesigns reset only after a reviewed refund

After updating, users with existing pet assets first see a refund quote in the
menu popover or under **Settings → Tokeni → Data & Migration**. The current pet
is valued at 0 Energy for an Egg, 500 for a Hatchling, 1,300 for a Juvenile,
and 2,700 for an Adult. Every completed pet returns 2,700 Energy. Owned
cosmetics return their full registered price in Star Shards.

Existing pets remain read-only until the user chooses **Reset and receive
refund**. Confirmation resets pets, names, memories, collection progress,
guarantees, legacy benefit state, and cosmetics. Existing Energy, Star Shards,
attendance, and verified-growth accounting remain intact. Refunded Energy uses
a separate migration reserve, so the normal 100,000 safety cap cannot discard
it.

The app creates a local recovery record first and applies each migration ID
once. If the app exits midway, it resumes toward the recorded final balances
instead of paying twice. The completed receipt remains in Settings. Users with
no resettable assets migrate silently.

Open the grid button in the menu or choose
**Settings → Tokeni → Open Pet Collection**. See
[Tokeni pet growth and collection](docs/bytebot.md) for player-facing rules and
the [companion system policy](docs/companion-policy.md) for extensibility and
balance records.

## Menu bar and on-screen pet

Every menu-bar display mode uses a native monochrome status icon. A red badge
appears when there is enough energy to hatch an egg or evolve a Hatchling or
Juvenile. Adult journey completion is not included in this badge.

The menu popover keeps its header and history, settings, and quit actions
fixed while the center content scrolls. Usage appears before the collapsed pet
summary. Each provider card leads with its primary quota and reset time;
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

GitHub ZIPs are published only after Developer ID signing and Apple
notarization. For a direct installation, download the ZIP from the
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
| Pet species, stage, variant, name, personality, bond, memories, collection, and guarantees | Access tokens, refresh tokens, and cookies |
| Star Shards, attendance dates, purchased cosmetics, and awarded milestone IDs | Account secrets and server telemetry |
| Pet migration quotes, local recovery records, and receipts | Remote migration services and payment data |
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
| Pet controls are unavailable | Review the pending asset refund under **Settings → Tokeni → Data & Migration**. Existing pets are read-only until confirmation |
| The app exits during a refund | Relaunch to resume toward the same journaled target balances, then review the receipt in Settings |

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
