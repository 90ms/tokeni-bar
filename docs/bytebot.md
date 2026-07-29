# Tokeni pet growth and collection

[한국어](bytebot.ko.md) | **English**

Tokeni pets are local pixel companions powered by verified AI-agent token usage.
There is no game account or server; species, growth, rarity, collection, and pity are
stored on your Mac.

## Growth energy

For verified token increases `T` across providers, after preventing replayed
counters from paying twice, growth energy is:

```text
Growth energy = floor(T / 100,000)
```

| Verified tokens | Growth energy |
|---:|---:|
| 100,000 | 1 |
| 1,000,000 | 10 |
| 10,000,000 | 100 |
| 100,000,000 | 1,000 |
| 300,000,000 | 3,000 |

The exchange rate stays constant at every usage level. A remainder below
100,000 tokens remains in the ledger across dates, and all unspent action
energy is retained. The action-energy wallet has a 100,000 safety limit.
Refreshing the same cumulative value never pays twice.

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
| Hatch egg | 500 |
| Evolve to Juvenile | 800 |
| Evolve to Adult | 1,400 |
| Finish an Adult journey and hatch again | 800 |
| Receive a new egg before Adult | 300 |

Every journey starts as an ungraded egg. Having enough energy never changes
the stage automatically: the user must click Hatch or Evolve. Energy earned as
an Adult fills action energy and that pet's **bond energy**.

During evolution, the previous form shrinks into a glow before the new stage
appears. Another evolution cannot start during the transition. Reduce Motion
and Low Power Mode use an immediate or short transition.

Working uses the work animation. The existing waiting animation runs for two
minutes after recent activity ends, then the pet returns to idle with an
occasional subtle shift and sleeps after ten inactive minutes. Quota warnings
and patting use higher-priority animations. Waiting is an inference from recent
activity, not a claim that a network response is pending.

When verified tokens actually credit growth energy, the pet briefly grows and
sparkles. Activity detection and every visual reaction are cosmetic and never
create growth energy. Reduce Motion, the app's animation toggle, and Low Power
Mode disable the additional movement.

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

The revealed species stays the same through Juvenile and Adult. While any species
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

Generation one has 60 forms: five species, four rarities, and Hatchling,
Juvenile, and Adult.
The ungraded egg is not counted as a collectible form.

Only the exact stage and rarity shown during growth is marked **Met**. For
example, evolving from a Normal Hatchling into a Rare Juvenile records those
two forms; the unseen Rare Hatchling remains locked.

Open the grid button in the menu or choose **Settings → Tokeni → Open Pet
Collection** to see:

- discovery and hatch-encounter counts for all five species;
- all 60 form unlocks;
- stages and rarities actually encountered;
- completed journeys, best rarity, and best bond;
- maximum completed journeys remaining for every guarantee.

## New eggs and completed journeys

At Adult, keep the current pet and grow bond, or spend 800 energy to finish its
journey and immediately hatch a new pet. The 800 combines the 300-energy
new-egg cost and the 500-energy hatch cost. Completion archives final rarity and bond,
updates pity, and reveals the next pet's species and first rarity in one action.

Before Adult, you may spend 300 energy to part ways and restart:

- unlocked forms and existing pity remain;
- unspent action energy remains;
- an early restart does not count as a completed journey;
- energy already assigned that day cannot be reused by the new egg.

Completed Adults remain under **Completed Pets** in the collection. Choose
**Stay Together** to show one in the menu bar, Settings preview, and on-screen
pet; choose **Put Away** to return to the currently growing pet. A completed pet
cannot evolve or finish another journey. Action energy continues to feed the
current journey, while the completed pet's active trait takes effect.

## Traits and passives

One active trait comes from the pet selected with **Stay Together**. Completed,
archived pets can also occupy passive slots. One slot is available initially;
additional slots unlock permanently after meeting 30, 60, 90, and 120 actual
collection forms. The same species cannot occupy multiple passive slots.

ByteBot and CacheCat are active species in generation one. StackFox, PromptPup,
and NullSlime are passive species. See the
[companion system policy](companion-policy.md) for rarity values, processing
order, privacy constraints, and the generation-extension checklist.

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
is sufficient to hatch an egg or evolve a Hatchling or Juvenile. Adult journey
completion remains a separate choice and is not included in this badge.

Enable **Settings → Tokeni → Show pet on screen** to place the pet in a
transparent floating panel. Size, position lock, and click-through behavior are
configurable, and the dragged position is stored in local preferences. If the
pet is off-screen or the display arrangement changes, **Reset pet position**
returns it to the upper-right of the current screen.
With click-through off, clicking the pet triggers its happy animation and a
side-to-side hop. With click-through on, the underlying app receives input, so
patting and dragging the pet are unavailable.

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
