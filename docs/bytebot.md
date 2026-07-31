# Tokeni Pet Growth and Collection

[한국어](bytebot.ko.md) | **English**

Tokeni pets are local pixel companions that grow from token usage verified by
Tokeni Bar. There is no game account or server. Companion state never stores a
provider name, raw token total, prompt, or response content.

## Core loop

1. Verified cumulative token increases become action energy.
2. You manually hatch an egg and grow it through Hatchling, Juvenile, and Adult.
3. You name the individual and build personality, bond, and memories.
4. Completing an Adult journey archives that individual and starts a new egg.
5. You collect Standard and Prismatic looks for five species and style them.

There is no hunger, sickness, death, or punishment for days away. A pet simply
sleeps and waits while you rest.

## Growth energy

For deduplicated verified token growth `T` across providers:

```text
growth energy = floor(T / 50,000)
```

Sub-50,000 token remainders and unspent action energy carry across dates.
Only verified cumulative token observations create growth. Active time may
change animations but never creates growth.

| Action | Energy |
|---|---:|
| Hatch egg | 500 |
| Evolve to Juvenile | 800 |
| Evolve to Adult | 1,400 |
| Complete Adult journey and hatch again | 800 |
| Start a new egg before Adult | 300 |

Energy never evolves a pet automatically. You choose when each growth moment
and new encounter happens.

## Five species and visual variants

ByteBot, CacheCat, StackFox, PromptPup, and NullSlime currently have equal
base hatch chances. While a species remains undiscovered, five consecutive
duplicate hatches guarantee that the next egg is one of the missing species.

Ranked Normal, Rare, Epic, and Legendary grades are no longer gameplay. A new
individual hatches with one stable visual variant:

| Variant | Base chance | Power |
|---|---:|---|
| Standard | 92% | Equal |
| Prismatic | 8% | Equal |

After 11 consecutive Standard hatches, hatch 12 is guaranteed Prismatic.
Prismatic is a visual discovery and never improves growth, rewards, or odds.

Pre-update Rare and Epic sprites remain available as **Legacy Azure** and
**Legacy Violet** body colors. Legendary maps visually to Prismatic. “Legacy”
is the name of a current body-color asset, not a separate migration or refund
flow.

Variant definitions use string IDs and a registry so future looks can be added
without provider switches in shared UI or a new save format.

## Collection and journey albums

The main collection target is ten meaningful discoveries: five species times
Standard and Prismatic. Hatchling, Juvenile, and Adult sprites are recorded in
that variant's journey album instead of inflating the collection with 60
stage-grade combinations.

The collection shows:

- discovery state for five species;
- Standard and Prismatic discovery per species;
- growth stages actually seen for each variant;
- the nearest missing-species or Prismatic guarantee;
- completed individuals with their name, personality, bond, and memories.

## Name, personality, bond, and memories

Each hatch receives one presentation-only personality: Calm, Curious, Playful,
Dreamy, or Brave. You can give the individual a local name. Neither changes
stats.

Verified base growth earned while an Adult also builds bond. Bond levels 1 through
5 begin at 0, 50, 150, 400, and 800 energy. Bond never falls and never creates
a permanent growth or reward multiplier.

Each generation grants a first-time reward for reaching a bond level:

| Bond level | First-time reward |
|---:|---|
| 2 | One 2x, 30-minute Action Energy Booster |
| 3 | One 3x, 20-minute booster |
| 4 | Permanently unlock Firefly Aura |
| 5 | One 5x, 10-minute booster and permanently unlock Orbit Aura |

Action energy added by a booster does not add boosted bond.

The private memory timeline stores only content-free pet events:

- hatch;
- evolution;
- first pat;
- reaching a new bond level;
- completing an Adult journey.

A completed pet keeps its name, personality, final look, and bond in the
archive. Bringing it back as the visible companion does not redirect action
energy from the current growing journey and grants no stat bonus.

## Star Shards and cosmetics

Star Shards are a styling currency separate from growth energy.

| Condition | Star Shards |
|---|---:|
| Automatic activity check-in on first verified growth | 10 |
| First verified growth energy of the day | 5 |
| 3 / 5 / 7 active days in a week | 10 / 20 / 30 |
| 20 active days in a month | 50 |
| First discovery of a species | 20 |
| First Prismatic discovery | 50 |
| Complete an Adult journey | 25 |
| Discover 5 / 10 collection variants | 20 / 100 |
| First launch of a stable release | 20 |

Cosmetic slots are Aura, Background, and Body Color. Equipped cosmetics
appear in the menu popover, pet-management window, and on-screen pet.

| Slot | Items | Cost |
|---|---|---:|
| Aura | Sparkle / Pixel Hearts / Firefly / Orbit / Night Ring | 60 / 80 / 130 / 180 / 200 |
| Body Color | Legacy Azure / Legacy Violet | 90 / 110 |
| Background | Terminal Night / Cloud Garden / Sunset Grid / Pixel Forest | 160 / 220 / 240 / 260 |

The Customize screen filters by slot and ownership and distinguishes owned from
equipped items with explicit icons. The purchase sheet compares the current and
resulting full pet. Every cosmetic and body color is visual only and never
affects growth, rewards, or variant odds.

Pet management is organized as **My Pet, Collection, Companions, and
Customize**. Identity and Energy ledgers expand on demand. A completed
companion's detail sheet shows its name, personality, bond, and full memory
history.

## Action Energy Boosters

Boosters are consumable items purchased with Star Shards or earned from
first-time bond milestones.

| Booster | Duration | Price |
|---|---:|---:|
| 2x | 30 minutes | 80 Star Shards |
| 3x | 20 minutes | 150 Star Shards |
| 5x | 10 minutes | 280 Star Shards |

Only one booster can be active. It multiplies base action energy newly verified
during its active interval. Activation and expiration timestamps are persisted
locally, so quitting and reopening the app does not reset its duration. Bonus
Energy from another system is not multiplied again.

## Behavior and on-screen pet

The pet reacts to work, recent activity, rest, quota warnings, and pats. These
are presentation states; they are not derived from network response content or
work content.

Enable the overlay under **Settings → Tokeni → Show pet on screen** and choose
its size, position lock, and click-through behavior. Reduce Motion, the app
animation setting, and Low Power Mode are respected.

## Storage and privacy

Species, stage, variant, name, personality, energy, bond, memories, collection,
cosmetics, and boosters remain on the Mac. Memories contain no provider name, token
total, prompt, response, or credential. There is no analytics SDK or remote
game server.

Unavailable or stale usage never fabricates growth. See
[Usage display and growth accounting](usage.md) for accounting details.
