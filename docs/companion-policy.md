# Tokeni pet system policy

[한국어](companion-policy.ko.md) | **English**

- Policy version: 3.3.0
- Updated: 2026-08-26
- Status: implemented

This document defines the product rules for level-100 growth, owned pets, egg
hatching, duplicate conversion, Mutation variants, the collection, and actions.

## 1. Invariants

- Growth XP comes only from verified cumulative token increases.
- Active time may change behavior and animation but cannot create XP.
- Unverifiable usage is never estimated.
- Species, appearances, mutations, personalities, eggs, and cosmetics create no
  growth multiplier or power advantage.
- Only timed boosters multiply newly verified base XP.
- Hunger, illness, death, streak loss, and limited-time FOMO are excluded.
- Pet state never stores provider names, raw token totals, prompts, responses,
  or credentials.

## 2. Levels and evolution

The standard conversion is one Growth XP per 600,000 verified tokens. Level is
derived from XP and is not stored independently. The initial maximum level is
100, reached at 500 cumulative XP. This is 300 million verified tokens. Actual
duration follows verified usage.

```text
cumulative XP at level L = round(500 × ((L - 1) / 99) ^ 1.7)
level range = 1...100
```

Every adjacent level is normalized to differ by at least one XP. Early levels
arrive quickly and progression slows toward level 100. Hatchling, junior, and
adult forms correspond to levels 1, 30, and 70. Evolution is manual and spends
no XP.

XP clamps to 500 at level 100 and overflow is not stored as XP. When the target
reaches level 100 and an unfinished owned pet exists, Tokeni randomly makes one
such pet both current and the new growth target. Only after every owned pet is
level 100 do verified tokens enter a separate repeatable conversion: every
100,000 verified tokens grant 10 Star Shards, with progress
toward the next conversion kept per pet. Booster multipliers do not apply. A
later cap increase changes the maximum-level and cumulative-XP policy values
together; hidden XP beyond the previous cap is never banked.

## 3. Displayed companion and growth target

The menu-bar companion and the pet receiving verified Growth XP are selected
independently through manual actions, but automatic rotation takes priority while
an unfinished owned pet remains. Selling or removing the target safely falls
back to the active pet or another owned pet.

At maximum level, the displayed pet may use its Hatchling, Junior, or Adult
sprite without changing its level, collection identity, or growth target.

The menu popover does not show a separate max-level conversation button. The
collection detail may still preview predefined localized pet messages; they
contain no usage content or token numbers.

## 4. Owned pets, eggs, and duplicates

New state contains one non-sellable Starter Egg. Hatch results are fixed by the
egg UUID and stable seed, and state is saved before presentation. A new
appearance creates an owned pet with its own UUID.

An egg also stores the latest content generation available at acquisition as
its species-pool ceiling. Older saved eggs without this field resolve to the
generation-one pool. Content additions therefore cannot change a saved seed's
result; newly acquired eggs include generation two at equal per-species base
odds.

A duplicate is the same `species + appearance`; name, personality, and growth
stage do not affect identity. A repeat hatch does not create another pet. It
grants the matching owned pet 25% of its current next-level requirement, rounded
up with a minimum of one XP. Duplicate XP also respects level 100. Collection
discovery and encounter counts are recorded before conversion.

While undiscovered species remain, five duplicate-species hatches guarantee
that the next normal hatch chooses an undiscovered species. The active pet
cannot be sold, and resale never exceeds purchase cost.

## 5. Mutation variants

The Mutation Lab, three-pet synthesis, and undiscovered-mutation guarantee are
removed. A normal egg has a 1% seeded chance to hatch the selected species'
mutation appearance. Mutation has no synthesis pity counter.

A mutation is a species-specific intrinsic body variation instead of an
equipable aura. Dedicated Mutation sheets are the target asset format; until
those reviewed sheets replace the temporary renderer, displayed frames derive
a restrained trait from the Standard animation. Mutation never
changes XP, benefits, resale value, or other odds. The existing Prismatic
appearance and its guarantee rules remain a separate appearance.

Schema v11 discards legacy synthesis records, counts, and inactive synthesized
mutation pets. An active legacy mutation decoration is cleared while the pet
remains safely available in its standard appearance. New mutations use the
stable `mutated` appearance ID.

## 6. Collection and details

The collection unit is `species + collectible appearance`. Standard,
Prismatic, and Mutation are currently collectible. Growth stages remain inside
each card's journey album and do not inflate the denominator. A mutation hatch
is registered immediately.

Selecting a collection card shows:

- species, appearance, discovery state, and discovered growth stages;
- ownership and current level;
- previews for idle, working, waiting, warning, celebrate, and sleep;
- the discovered mutation pet's species-specific signature action;
- the level-100 speech action; and
- an action to select any owned pet as the growth target.

Undiscovered appearances remain silhouettes and do not reveal their actions.

## 7. Actions

Every pet has idle, working, waiting, warning, celebrate, and sleep actions.
Activity state selects an action but cannot create growth. Each species'
mutation appearance adds one signature action:

- ByteBot: Reassemble
- CacheCat: Data Chase
- StackFox: Afterimage Split
- PromptPup: Command Trail
- NullSlime: Reform
- QueryOwl: Signal Scan
- PatchPanda: Pixel Mend
- LoopHare: Recursive Dash
- RelayRay: Packet Wave
- KernelCrab: Core Open

The initial signature slot points at a bundled species animation row and can be
replaced with independent frames later while preserving its stable action ID.
Reduce Motion, disabled animations, and Low Power Mode remain respected.

Generation 2, the **Signal Expedition**, contains QueryOwl, PatchPanda,
LoopHare, RelayRay, and KernelCrab. Every growth stage has an independent
Standard and Prismatic sprite; dedicated Mutation sheets are in progress. A
persistent signal core and behavior-specific wing, ear,
fin, and shell mode shifts distinguish it from generation 1. Its benefit
mappings reuse the five generation-one active and passive values and add no
higher tier.

## 8. Rewards and benefits

Existing one-time boosters and cosmetics at levels 5, 10, 20, and 25 remain.
Shard rewards occur at levels 30 and 40, every five levels from 50, every three
levels from 60, and every level from 70. The complete level journey grants 460
shards. Level 100 grants 50 of that total. First mutation discovery is handled once as an appearance
discovery. A mutation appearance never grants stronger benefits than Standard.

The first verified growth activity of each local day grants 300 shards and one
Starlight Egg. Weekly attendance grants another 100, 200, and 300 shards on
days 3, 5, and 7, and monthly attendance grants another 500 shards on day 20.
Booster items of the same multiplier extend the active expiry by
their full duration. Activating a different multiplier replaces the active
booster and discards its remaining time after explicit confirmation.

Each stable app version offers a 300-shard update reward. It pays only after the
player explicitly uses the Customize-tab button. The most recently claimed
version prevents duplicate claims and claims after downgrading.

Collection milestones grant one Prismatic Egg at 5, 10, 20, and 30 discovered
species/appearance combinations, and one Starlight Egg at 5 and 10 distinct
species. Finding three generation-two species unlocks Hologram Scanlines;
finding all five unlocks the Mini Drone sidekick. Aura, Background, Sidekick,
Frame, and Scene Effect are independent cosmetic slots. Frames and scene effects
use the full companion canvas, and legacy Body Color and Ground items migrate to
their corresponding replacements.

## 9. Persistence and safety

Schema v11 stores XP normalized to level 100, an optional growth-target UUID,
and the max-level pet UUID and growth stage selected for on-screen display.
Reward schema v10 stores only per-pet progress toward the next max-level
conversion and processed award IDs without storing raw token totals. Previous
energy remainders migrate at the new rate.
Version 10 loads into v11, discarding synthesis data and XP beyond the cap. The
growth target must refer to the active pet or an owned inactive pet.

Egg purchases and sales use a transaction journal and UUIDs to reject duplicate
processing. Corrupt data uses a recoverable backup or becomes unavailable.
Collection and speech state contain no work content or raw usage values.

## 10. Adding content

These requirements apply unchanged to every future pet generation; a new
generation may extend the roster but must not relax the art or asset contract.

1. Register stable species, appearance, action, or egg IDs.
2. Design Hatchling, Junior, and Adult as recognizably related but structurally
   distinct forms; scaling one drawing is not an evolution.
3. Preserve the species' defining anatomy, palette, pixel density, outline,
   behavior poses, particles, and props across every stage and animation frame.
4. Add separate Standard, Prismatic, and Mutation PNG sheets for every growth
   stage. Mutation must grow from species anatomy, not from pasted blocks,
   generic horns, auras, or accessories.
5. Keep the 8-column × 6-row transparent sprite-sheet contract and validate
   every manifest reference before registration.
6. Document egg odds, price, resale, and unlock rules.
7. Declare duplicate identity and collection-denominator behavior.
8. Add probability-boundary, duplicate-XP, asset-contract, round-trip, and
   migration tests.
9. Update Korean and English strings, policy docs, and a change fragment.
