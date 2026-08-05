# Tokeni pet system policy

[한국어](companion-policy.ko.md) | **English**

- Policy version: 2.4.0
- Updated: 2026-08-05
- Status: implemented

This document defines the invariants for unbounded levels, evolution, the egg
economy, owned pets, the Mutation Lab, collection rewards, persistence, and
privacy.

## 1. Invariants

- Growth XP comes only from verified cumulative token increases.
- Active time may alter behavior but cannot create XP.
- Unverifiable usage is never estimated.
- Species, variants, personalities, eggs, and cosmetics create no growth,
  price, reward, or probability multipliers.
- Mutations are visual only and never affect Growth XP, hatch odds, stats, or
  resale value.
- Only timed boosters multiply newly verified base XP.
- Hunger, illness, death, streak loss, and limited-time FOMO are excluded.
- Pet state never stores provider names, raw token totals, prompts, responses,
  or credentials.

## 2. Growth and evolution

The standard conversion is one Growth XP per 25,000 verified tokens. Level is
derived from XP, is not stored independently, and has no product maximum.

```text
next-level XP = min(2 + floor((current level - 1) / 10), 15)
```

Hatchling, junior, and adult forms correspond to levels 1, 10, and 25.
Evolution is manual and does not spend XP. Passing a threshold does not change
the form until evolution is requested. Growth continues after level 25.
Starting at level 30, every ten levels grant 10 Star Shards.

## 3. Owned pets and eggs

New state contains one non-sellable Starter Egg. A migration that imports an
active pet grants one non-sellable Homecoming Egg. Hatched pets have UUIDs, one
pet is selected for growth, and another hatch adds to the roster without
deleting or completing the current pet. Switching preserves XP, form, name,
personality, and memories.

Egg definitions contain only a stable ID, buy and resale prices, unlock
requirements, species candidates, variant rules, guarantees, and sellability.
The Mystery Egg unlocks at highest pet level 5 for 90 shards. The Discovery Egg
unlocks after three species for 180 shards. Their resale values are 30 and 60.
There are no real-money purchases, limited-time offers, or player trading.

The active pet cannot be sent away. Inactive standard and prismatic pets return
30 and 60 shards. Level never increases resale value, and discoveries remain.

Exactly three inactive archived pets of the same species can be combined in the
Mutation Lab. The three source generations are consumed, and the current active
pet can never be used as a source.

## 4. Collection and guarantees

Five species have equal base odds. Five duplicate hatches guarantee an
undiscovered species while one remains. Standard and prismatic odds are 92% and
8%; the twelfth normal hatch after 11 standard results is prismatic.

The main collection has ten species/variant combinations. Forms remain in a
growth album. Five species grant a Discovery Egg; five and ten combinations
each grant one Prismatic Egg. Discovery and Prismatic Eggs guarantee their
documented result pools.

Each species has five visual mutations—Neon, Shadow, Crystal, Glitch, and
Aurora—for 25 mutation entries. The full collection denominator is 35: ten
Standard/Prismatic entries plus 25 mutations. Every third synthesis globally
guarantees an undiscovered mutation for the selected species while one remains.
Repeats strengthen resonance instead of adding an entry, and each first mutation
discovery grants 30 Star Shards once. Mutation entries do not count toward the
species/variant milestones that grant special eggs.

## 5. Level rewards and cosmetics

Each pet grants a 2x booster, 3x booster, Firefly aura, and the 5x booster plus
Orbit aura at levels 5, 10, 20, and 25. Legacy bond rewards suppress the matching
level reward so migration cannot duplicate grants.

Star Shards come from attendance, verified growth, discoveries, collection
milestones, and stable-version gifts. They buy eggs, boosters, and visual
cosmetics. Resale remains below purchase price and XP cannot become a repeatable
currency farm.

## 6. Identity and memories

Each pet has a UUID, species, variant, form, XP, local name, registered
personality ID, and creation date. An optional equipped mutation ID is stored on
the generation; discovered mutations and resonance are account-level collection
records. At most 40 content-free memories per pet and
2,000 across the account are kept.
Legacy hatch, evolution, pat, bond, and journey records remain after migration.
No work content or raw usage number enters a memory.

## 7. Persistence and transaction safety

Eggs have UUIDs and stable random seeds. Purchase and resale are first written
to a journal and use transaction UUIDs to reject duplicate pet and currency
processing; hatching is keyed by the egg ID
and its seed. State and guarantee counters are updated before reveal animation
so interruption cannot reroll an egg or duplicate a reward.

Schema v10 stores the active pet, inactive owned pets, acquisition egg source,
eggs, Growth XP, highest level, egg milestones, mutation records, synthesis
count, equipped mutation, mutation reward keys, and processed egg transactions.
The new fields are optional-compatible, so existing v10 files remain readable.
Corrupt data uses a recoverable backup or becomes unavailable rather than fabricated.

Provider JSONL is processed one line at a time without constructing a complete
file or event array. Companion sprite sheets load on demand under bounded sheet
and frame caches. Hiding the overlay releases its hosting view and animation
tasks.

## 8. Migration and compatibility

- Dedicated readers migrate schemas v2 through v9 into v10.
- Hatchling, junior, and adult states receive at least levels 1, 10, and 25.
- The greater useful legacy action balance or adult bond progress is added to
  XP, then the duplicate action balance is removed.
- Completed pets become inactive, sellable owned pets.
- An imported active pet receives one Homecoming Egg; a legacy empty egg state
  is restored with one Starter Egg.
- Imported pets do not backfill every passed level reward, but earn the next new
  milestone normally.
- Guarantees, identity, memories, shards, cosmetics, and boosters remain.
- Missing mutation records, synthesis count, equipped mutation, and mutation
  reward keys default to an empty collection, zero, none, and empty keys.

## 9. Adding content

1. Register stable species, variant, mutation, evolution, or egg IDs.
2. Add every required sprite and manifest entry for a new form.
3. Document egg price, resale, odds, guarantees, and unlock rules.
4. Declare collection denominator and special-egg milestone behavior.
5. Define mutation visuals and duplicate-synthesis guarantees; add round-trip,
   migration, duplicate-transaction, and probability tests.
6. Update Korean and English strings and documentation together.

## 10. Version 2.3.0 redesign

- Replaced spendable lifecycle growth with unbounded levels and level evolution.
- Increased early growth speed and capped next-level XP at 15.
- Removed adult completion and action-energy journey resets.
- Added Starter Eggs, the Egg Vault, a shard shop, resale, and special eggs.
- Unified current and completed companions into a switchable owned roster.
- Moved bond rewards to levels 5, 10, 20, and 25.
- Added 10 Star Shards every ten levels starting at level 30.

## 11. Version 2.4.0 Mutation Lab

- Added a Mutation Lab that consumes three inactive same-species duplicates.
- Added 25 visual mutation entries, five for each species, and an equip slot.
- Guaranteed an undiscovered mutation every third synthesis and awarded 30 Star
  Shards once per first discovery.
- Kept mutations separate from growth, odds, stats, and the special-egg milestones.
