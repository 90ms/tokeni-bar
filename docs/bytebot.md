# Tokeni pet growth and collection

[한국어](bytebot.ko.md) | **English**

Tokeni pets are local pixel companions powered by verified AI-agent token usage.
There is no game account or server; species, growth, rarity, collection, and pity are
stored on your Mac.

## Growth energy

For verified daily token increases `T` across providers, after preventing
replayed counters from paying twice, daily growth energy is:

```text
T = 0  → 0
T > 0  → floor(32 × log2(1 + T / 25,000))
```

More tokens continue to increase the daily target, while each additional energy
point costs more tokens at very high usage. The actual action-energy balance is
capped at 320.

| Tokens today | Energy today |
|---:|---:|
| 10,000 | 15 |
| 25,000 | 32 |
| 50,000 | 50 |
| 100,000 | 74 |
| 250,000 | 110 |
| 500,000 | 140 |
| 1,000,000 | 171 |

Refreshing the same cumulative value never pays twice. On each date change,
20% of the remaining balance carries over. If the app stays closed for multiple
days, the 20% carry is applied once for every elapsed day.

The collection's **Action energy** section shows reflected tokens per provider,
their combined total, today's energy target, and the additional tokens required
for the next energy point. CLIs without a complete daily total show only the
session or lifetime increase observed while Tokeni Bar is running. A provider
without a trustworthy value says **Waiting for data** instead of showing a
misleading zero.

Codex account daily totals may arrive the next day. A confirmed value within
the last three days is calculated against its original usage date and paid into
action energy on the day it is confirmed. Provider rows show the usage date
along with settled-today or today-pending status.

## Life stages

| Action | Energy spent |
|---|---:|
| Hatch egg | 60 |
| Evolve to Junior | 100 |
| Evolve to Adult | 160 |
| Finish an Adult journey and hatch again | 100 |
| Receive a new egg before Adult | 40 |

Every journey starts as an ungraded egg. Having enough energy never changes
the stage automatically: the user must click Hatch or Evolve. Energy earned as
an Adult fills action energy and that pet's **bond energy**.

During evolution, the previous form shrinks into a glow before the new stage
appears. Another evolution cannot start during the transition. Reduce Motion
and Low Power Mode use an immediate or short transition.

Working, quota warning, patting, and longer inactivity change the animation.
Activity detection drives behavior only and never fabricates growth energy.

## Rarity and evolution

Every species shares an unidentified mystery egg. Hatching independently
reveals the first rarity and one of five species:

| Species | Personality | Base odds |
|---|---|---:|
| ByteBot | Diligent little robot | 20% |
| CacheCat | Curious data cat | 20% |
| StackFox | Clever code fox | 20% |
| PromptPup | Optimistic prompt dog | 20% |
| NullSlime | Laid-back digital slime | 20% |

The revealed species stays the same through Junior and Adult. While any species
is missing, five consecutive duplicate hatches guarantee that the next egg
reveals an undiscovered species.

Later evolution
keeps or raises rarity through `Normal → Rare → Epic → Legendary` and never
drops it.

| Current | Stay | Rare | Epic | Legendary |
|---|---:|---:|---:|---:|
| Normal | 75.0% | 21.0% | 3.8% | 0.2% |
| Rare | 86.0% | - | 13.0% | 1.0% |
| Epic | 97.0% | - | - | 3.0% |
| Legendary | 100% | - | - | - |

Without pity, an Adult hatched from an ungraded egg ends Normal 42.2%, Rare
40.9%, Epic 15.5%, and Legendary 1.4%.

Completed Adults provide visible guarantees:

- Rare or higher within at most 3 completed journeys
- Epic or higher within at most 7 completed journeys
- Legendary within at most 16 completed journeys

The collection shows the maximum completed journeys remaining. Restarting
early keeps existing pity but does not advance it.

## Collection

The collection has 60 forms: five species, four rarities, and Hatchling,
Junior, and Adult.
The ungraded egg is not counted as a collectible form.

A form shown during evolution is marked **Met**. If a rarity first appears at a
later stage, its earlier-stage art unlocks as **Lineage**. A Legendary first
found as an Adult therefore also unlocks Legendary Hatchling and Junior art.

Open the grid button in the menu or choose **Settings → Tokeni → Open Pet
Collection** to see:

- discovery and hatch-encounter counts for all five species;
- all 60 form unlocks;
- Met versus Lineage unlocks;
- completed journeys, best rarity, and best bond;
- maximum completed journeys remaining for every guarantee.

## New eggs and completed journeys

At Adult, keep the current pet and grow bond, or spend 100 energy to finish its
journey and immediately hatch a new pet. The 100 combines the 40-energy new-egg
cost and the 60-energy hatch cost. Completion archives final rarity and bond,
updates pity, and reveals the next pet's species and first rarity in one action.

Before Adult, you may spend 40 energy to part ways and restart:

- unlocked forms and existing pity remain;
- unspent action energy remains;
- an early restart does not count as a completed journey;
- energy already assigned that day cannot be reused by the new egg.

Completed Adults remain under **Completed Pets** in the collection. Choose
**Stay Together** to show one in the menu bar, Settings preview, and on-screen
pet; choose **Put Away** to return to the currently growing pet. A completed pet
is display-only and cannot evolve or finish another journey. Action energy and
rewards continue to apply only to the current journey.

## Star Shards and attendance

Star Shards are a reward currency separate from growth energy. Growth energy
continues to come only from verified token increases. Attendance and active
minutes never create growth energy.

| Condition | Star Shards |
|---|---:|
| Daily check-in | 10 |
| First verified growth energy of the day | 5 |
| 3 / 5 / 7 check-ins in the same week | 10 / 20 / 30 |
| 20 check-ins in the same month | 50 |
| First discovery of a pet species | 20 |
| First Rare / Epic / Legendary encounter | 10 / 25 / 50 |
| Completed Adult journey | 25 |
| 10 / 30 / 60 collection forms unlocked | 20 / 50 / 100 |
| First launch of a new stable release | 20 |

Attendance uses weekly and monthly cumulative counts rather than a fragile
streak. Missing a day does not reset existing progress. A local date can pay
only once. If the system date moves behind the latest claimed date, attendance
remains unavailable until the date is valid again.

Existing species discoveries, completed journeys, and collection milestones
are reconciled once when reward state first loads. Reading the same records
again never pays twice.

### Star Shard cosmetics

Spend Star Shards in the collection to permanently unlock:

| Slot | Cosmetic | Cost |
|---|---|---:|
| Aura | Sparkle Aura | 60 Star Shards |
| Aura | Pixel Hearts | 80 Star Shards |
| Head | Developer Headphones | 100 Star Shards |
| Head | Star Crown | 120 Star Shards |
| Head | Wizard Hat | 140 Star Shards |
| Background | Terminal Night | 160 Star Shards |
| Aura | Night Ring | 200 Star Shards |
| Background | Cloud Garden | 220 Star Shards |

Purchased cosmetics can be equipped or removed at any time, with one item each
in the Head, Aura, and Background slots. The selection appears in the menu
popover, current-pet collection view, Settings preview, and on-screen pet.
Cosmetics are visual only and never affect energy, rarity, evolution odds, or
pity.

## Menu bar and on-screen display

The native monochrome menu-bar status icon shows a red badge when action energy
is sufficient to hatch an egg or evolve a Hatchling or Junior. Adult journey
completion remains a separate choice and is not included in this badge.

Enable **Settings → Tokeni → Show pet on screen** to place the pet in a
transparent floating panel. Size, position lock, and click-through behavior are
configurable, and the dragged position is stored in local preferences. If the
pet is off-screen or the display arrangement changes, **Reset pet position**
returns it to the upper-right of the current screen.

## When tokens cannot be counted

Only token counters with known scope and reset behavior grant growth. Missing,
stale, or incompatible data remains unavailable instead of becoming guessed
energy.

- Complete Codex and Claude daily totals credit their confirmed usage date.
  A total confirmed up to three days late pays energy on the confirmation day.
- Gemini and Grok session totals and OpenCode lifetime totals establish a
  baseline first, then credit increases.
- If the app was closed across a date boundary, session and lifetime counters
  are not guessed across unknown days.
- An implausibly large jump must be observed again before it credits energy.

See the [usage display guide](usage.md) for detailed accounting and cost rules.

## Storage and privacy

Species, stage, rarity, energy, bond, collection, rewards, and on-screen pet
preferences stay on the Mac. Aggregate usage history is retained for 30 days.
If progress data is damaged, the app attempts recovery from retained local
copies.

Pet state contains no provider names or raw token totals. Prompts, responses,
authentication tokens, cookies, and account secrets are not stored. There is
no analytics or server telemetry.

Because this is a local app without a game server or account, progress data is
not a strong anti-cheat boundary. Consistency checks and recovery protect
against accidental damage and duplicate credit; they cannot guarantee that the
device owner will not intentionally modify local data.
