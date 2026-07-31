# Tokeni Companion System Policy

[한국어](companion-policy.ko.md) | **English**

- Policy version: 2.2.0
- Updated: 2026-07-31
- Status: implemented

This document is the source of truth for pet growth, variants, individual
identity, collection, rewards, and cosmetics.

## 1. Invariants

- Growth comes only from verified cumulative token increases.
- Active time may drive animation but never growth.
- Unavailable usage is never estimated.
- Pet choice, personality, variant, and cosmetics never multiply growth, cost,
  rewards, or odds.
- Only a timed booster may apply its declared multiplier to verified base
  action energy.
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

The standard conversion is `floor(verified tokens / 50,000)`. Action costs are
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
completion cells. Legacy colors remain available as store cosmetics without
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

Each generation grants a one-time reward at a bond level: level 2 grants a 2x
booster, level 3 a 3x booster, level 4 Firefly Aura, and level 5 a 5x booster
plus Orbit Aura. Booster-added Energy does not add boosted bond.

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

Cosmetic slots are Aura, Background, and Body Color. One item per slot
can be active. All cosmetics are visual. Do not add paid random boxes or expiry
dates.

Legacy Rare and Epic sprites become Legacy Azure and Legacy Violet store
assets. Legendary art can serve Prismatic. “Legacy” names a current color
asset; it does not imply a live migration policy.

Boosters are separate consumable reward-state items. The catalog provides 2x
for 30 minutes, 3x for 20 minutes, and 5x for 10 minutes at 80, 150, and 280
Star Shards. Only one may be active. Persist an absolute expiration time and
apply the multiplier only to newly verified base action energy, never to bonus
Energy or bond.

## 7. Migration and compatibility

- Companion schemas v2 through v7 load through dedicated read-only decoders.
- Unknown JSON fields in the current schema are ignored, but removing an enum
  ID must not cause the entire reward save to reset.
- Compatible field additions use safe defaults automatically.
- Refund quotes, asset resets, migration reserves, recovery journals, and
  receipts are not current features and are never written to new state.
- Damaged state uses recoverable backups or remains unavailable.
- Removing compatibility code requires an explicit minimum direct-upgrade
  version change and save-fixture coverage.

## 8. Adding content

1. Register a stable species or variant ID.
2. Add every life-stage sprite and manifest entry.
3. Verify normal, compact, Low Power, and Reduce Motion rendering.
4. Declare whether it changes the collection denominator or guarantee.
5. Add persistence round-trip and old-save fixture tests.
6. Update Korean and English strings and docs together.

Differentiate new content through silhouette, motion, personality expression,
and cosmetic compatibility—not numerical superiority.

## 9. Version 2.2.0 policy

- Changed base action energy to one per 50,000 verified tokens.
- Removed the Head cosmetic slot and expanded species-neutral Aura and
  Background items.
- Added timed 2x, 3x, and 5x boosters and one-time bond-level rewards.
- Removed refund, asset-reset, migration-reserve, journal, and receipt policy
  from the current system.
- Made the popover companion card always visible.

## 10. Version 2.0.0 redesign

- Removed the Normal/Rare/Epic/Legendary hierarchy and evolution rank rolls.
- Added Standard/Prismatic variants and one transparent Prismatic guarantee.
- Replaced the 60-cell stage-rarity matrix with ten species-variant discoveries
  and journey albums.
- Disabled growth, cost, odds, and reward effects from traits and passives.
- Added names, personalities, five bond levels, and private memories.
- Reused legacy grade assets as variants and body-color cosmetics.
