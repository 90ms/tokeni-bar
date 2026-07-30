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
growth energy = floor(T / 100,000)
```

Sub-100,000 token remainders and unspent action energy carry across dates.
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
**Legacy Violet** body colors that can be purchased again. Legendary maps
visually to Prismatic. Pre-redesign assets are settled through the reset and
refund flow below instead of being forced into the new collection.

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

Verified growth earned while an Adult also builds bond. Bond levels 1 through
5 begin at 0, 50, 150, 400, and 800 energy. Bond never falls and never creates
a growth or reward multiplier.

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

Cosmetic slots are Head, Aura, Background, and Body Color. Equipped cosmetics
appear in the menu popover, pet-management window, and on-screen pet.

| Slot | Items | Cost |
|---|---|---:|
| Aura | Sparkle Aura / Pixel Hearts | 60 / 80 |
| Body Color | Legacy Azure / Legacy Violet | 90 / 110 |
| Head | Developer Headphones / Star Crown / Wizard Hat | 100 / 120 / 140 |
| Background | Terminal Night / Cloud Garden | 160 / 220 |
| Aura | Night Ring | 200 |

The Customize screen filters by slot and ownership and distinguishes owned from
equipped items with explicit icons. The purchase sheet compares the current and
resulting full pet. Every cosmetic and body color is visual only and never
affects growth, rewards, or variant odds.

Pet management is organized as **My Pet, Collection, Companions, and
Customize**. Identity and Energy ledgers expand on demand. A completed
companion's detail sheet shows its name, personality, bond, and full memory
history.

## Pet asset reset and refund

A major pet-policy change never deletes owned assets silently. When pets,
collection records, or cosmetics need resetting, a refund card appears in the
menu popover, collection, and **Settings → Tokeni → Data & Migration**.

| Asset | Refund |
|---|---:|
| Egg | 0 Energy |
| Hatchling | 500 Energy |
| Juvenile | 1,300 Energy |
| Adult | 2,700 Energy |
| Completed pet | 2,700 Energy each |
| Owned cosmetic | Full registered price in Star Shards |

Collection records are shown in the quote but do not add separate currency.
Bond accumulated alongside growth Energy, while the journey-completion action
already granted a new hatch and rewards, so neither is paid twice.

Existing pets remain read-only until confirmation. Confirming resets pets,
names, personalities, bonds, memories, collection progress, guarantees, legacy
benefit state, and cosmetic ownership and selection. Unspent Energy, Star
Shards, attendance, and verified-growth settlement records remain.

The app first stores a local recovery record containing the source state and
fixed target balances. Each migration ID applies once; an interrupted write
resumes toward the same target instead of paying twice. Refunded Energy lives
in a separate migration reserve and is spent first, so the normal safety cap
cannot discard it. Receipts remain available in Settings and never expire.

## Behavior and on-screen pet

The pet reacts to work, recent activity, rest, quota warnings, and pats. These
are presentation states; they are not derived from network response content or
work content.

Enable the overlay under **Settings → Tokeni → Show pet on screen** and choose
its size, position lock, and click-through behavior. Reduce Motion, the app
animation setting, and Low Power Mode are respected.

## Storage and privacy

Species, stage, variant, name, personality, energy, bond, memories, collection,
and cosmetics remain on the Mac. Memories contain no provider name, token
total, prompt, response, or credential. There is no analytics SDK or remote
game server.

The asset-migration journal also stays on the Mac. It contains only the
migration ID, refund quote, source pet and reward state, fixed target state,
and receipt—never provider names, raw token totals, work content, or
credentials.

Unavailable or stale usage never fabricates growth. See
[Usage display and growth accounting](usage.md) for accounting details.
