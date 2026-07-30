# Tokeni Companion System Policy

[한국어](companion-policy.ko.md) | **English**

- Policy version: 2.0.0
- Updated: 2026-07-30
- Status: implemented

This document is the source of truth for pet growth, variants, individual
identity, collection, rewards, and cosmetics.

## 1. Invariants

- Growth comes only from verified cumulative token increases.
- Active time may drive animation but never growth.
- Unavailable usage is never estimated.
- Pet choice, personality, variant, and cosmetics never multiply growth, cost,
  rewards, or odds.
- There is no hunger, sickness, death, lost streak progress, or expiring FOMO.
- Companion state stores no provider name, raw token total, prompt, response,
  or credential.

## 2. Extensible registries

Species and variants are registered for shared UI; do not add species or
variant switches to feature screens.

A variant definition contains only:

- a stable string ID;
- its bundled sprite palette;
- whether it contributes to the main collection;
- whether it is a special visual variant.

Variants have no rank or power. Unknown future IDs must fail soft without
damaging existing saves.

## 3. Growth and hatching

The standard conversion is `floor(verified tokens / 100,000)`. Action costs are
500 to hatch, 800 for Juvenile, 1,400 for Adult, 800 to complete and hatch
again, and 300 to start a new egg early.

Five current species have equal base odds. While one remains missing, five
duplicate hatches make the next hatch choose from missing species.

New hatches are 92% Standard and 8% Prismatic. After 11 Standard hatches, hatch
12 is Prismatic. A variant is fixed at hatch and never changes during
evolution.

Legacy ranked rolls, Adult rarity pity, lucky rerolls, and action discounts do
not participate in new rules.

## 4. Collection

Main completion is `registered species × collectible variants`. Generation one
is five species times Standard and Prismatic, for ten discoveries.

Life stages form a journey album under that discovery instead of separate
completion cells. Legacy colors remain preserved and displayable without
inflating the new denominator.

Only two guarantees remain:

- missing species;
- Prismatic variant.

The UI leads with whichever guarantee is nearer.

## 5. Individual identity and memories

Current and completed individuals are identified by UUID and may contain:

- a local name of at most 24 characters;
- a registered personality ID;
- species, variant, and life stage;
- bond energy and level;
- creation and completion timestamps.

Personality is presentation-only. Bond levels begin at 0, 50, 150, 400, and
800 energy.

At most 400 structured, content-free memories are retained:

- hatch;
- evolution;
- first pat;
- bond level;
- journey completion.

Memories never include work content or usage numbers.

## 6. Rewards and cosmetics

Star Shards remain separate from growth energy. Sources are automatic activity
check-in, first verified growth, species and Prismatic discovery, 5/10 variant
collection milestones, completed journeys, and stable-release gifts.

Cosmetic slots are Head, Aura, Background, and Body Color. One item per slot
can be active. All cosmetics are visual. Do not add paid random boxes or expiry
dates.

Legacy Rare and Epic sprites migrate to Legacy Azure and Legacy Violet body
colors. Previous owners unlock those colors automatically. Legendary sprites
migrate to Prismatic.

## 7. Migration and compatibility

- Companion schemas v2 through v6 migrate to the current schema.
- Species, stage, energy, bond, collection, and completed pets are preserved.
- Original looks map to a variant or body-color cosmetic.
- Nameless individuals remain nameless; migrated personalities use a safe
  default.
- Legacy benefit-state files do not participate in new growth or rewards.
- Damaged state uses recoverable backups or is quarantined.

## 8. Adding content

1. Register a stable species or variant ID.
2. Add every life-stage sprite and manifest entry.
3. Verify normal, compact, Low Power, and Reduce Motion rendering.
4. Declare whether it changes the collection denominator or guarantee.
5. Add persistence round-trip and migration tests.
6. Update Korean and English strings and docs together.

Differentiate new content through silhouette, motion, personality expression,
and cosmetic compatibility—not numerical superiority.

## 9. Version 2.0.0 redesign

- Removed the Normal/Rare/Epic/Legendary hierarchy and evolution rank rolls.
- Added Standard/Prismatic variants and one transparent Prismatic guarantee.
- Replaced the 60-cell stage-rarity matrix with ten species-variant discoveries
  and journey albums.
- Disabled growth, cost, odds, and reward effects from traits and passives.
- Added names, personalities, five bond levels, and private memories.
- Preserved legacy grade assets as variants and body-color cosmetics.
