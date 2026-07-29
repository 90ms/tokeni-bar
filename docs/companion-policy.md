# Tokeni Companion System Policy

**English** | [한국어](companion-policy.ko.md)

> Policy version: 1.0.0
> Updated: 2026-07-29
> Status: Tokeni Bar v0.14.0 release baseline

This is the source of truth for companion generations, species, growth, rarity,
active benefits, passive loadouts, and reward economy. Update this document before
shipping a new generation or changing benefit values, then record the change below.

## Invariants

- Growth energy comes only from verified cumulative token observations.
- Activity time may animate companions but never creates growth energy.
- Companion state never stores provider names, token totals, prompts, responses,
  credentials, cookies, or account identifiers.
- The collection contains only species-stage-rarity forms actually encountered.
- Bonus energy never feeds another benefit calculation.
- The same species and the same effect group never stack.
- Existing encounters, archived companions, and purchased cosmetics survive policy changes.

## Extensible model

Content generation is an asset release group, independent of a player's journey number.
Generation one contains five species and 60 forms. Generation two is planned to add
five species and 60 forms. UI totals must be derived from registered definitions.

| Activation | Requirement | Concurrent effects |
|---|---|---:|
| Active | Selected with “Live together” | 1 |
| Passive | Archived adult assigned to an unlocked slot | slot count |

Passive slots are permanently unlocked at 0, 30, 60, 90, and 120 actual forms,
for a total of one through five slots. One archived companion and one species may
appear in only one passive slot.

## Generation-one registry

| Species | Mode | Benefit | Normal / Rare / Epic / Legendary |
|---|---|---|---|
| ByteBot | Active | Bonus energy per verified base energy | 5 / 4 / 3 / 2 base energy per +1; daily caps 10 / 15 / 25 / 40 |
| CacheCat | Active | Periodic star shard | every 12h / 8h / 6h / 4h; daily caps 2 / 3 / 4 / 6 |
| StackFox | Passive | Companion action cost discount | 3% / 5% / 8% / 12% |
| PromptPup | Passive | One-tier upgrade when the base roll does not improve | 3% / 6% / 10% / 15% |
| NullSlime | Passive | Eligible collection and journey shard bonus | 5% / 8% / 12% / 15% |

NullSlime excludes attendance, daily verified-growth rewards, release gifts, and
CacheCat grants. Fractional bonuses accumulate in basis points.

## Processing order

One hatch, evolution, or completion snapshots its loadout and performs:

1. validate slots and archived companions;
2. apply StackFox cost discount;
3. spend energy;
4. make the base species and rarity roll;
5. apply PromptPup;
6. apply adult pity;
7. record actual encounters and completion;
8. create base shard rewards;
9. apply NullSlime to eligible rewards.

ByteBot consumes verified base-energy units, not token totals, and its bonus cannot
recurse. CacheCat uses a separate time-settlement path with rollback protection and
at most one offline interval.

## State and privacy

`companion-benefits.json` may contain archived generation UUIDs, permanently unlocked
slot count, base-energy progress, benefit time progress, daily grant counts/date keys,
and fractional reward basis points. It must contain no provider or content data.

## Extension checklist

1. Register a species ID and content generation.
2. Choose active or passive activation.
3. Define all four rarity values, caps, and stacking group.
4. Review growth and privacy invariants.
5. Update this policy and localization first.
6. Add registry data, engine tests, and state migration.
7. Validate economy impact and daily caps.
8. Add a policy and app-release entry below.

## Implementation plan

- [x] Actual-encounter-only collection
- [x] Content generation and archived adults
- [x] Benefit registry
- [x] Recoverable benefit state and store
- [x] Passive slot unlock and loadout engine
- [x] Five generation-one benefits
- [x] Active-benefit and passive-loadout UI
- [x] Migration, targeted tests, and README synchronization
- [x] Full test and build pass in the v0.14.0 macOS release CI

## Policy and release-record rules

Policy versions use `major.minor.patch`: major for incompatible state or semantic
changes, minor for generations/species/benefits/slots/reward sources, and patch for
balance, copy, and compatible fixes. Copy this block for every companion release:

```markdown
### Policy version · date · app version

- Status: proposed / implementing / released
- Added: generation, species, benefit, and UI changes
- Balance: before → after, with rationale
- Storage: schema version and migration behavior
- Privacy: newly persisted fields and prohibited-field review
- Verification: engine, migration, and UI tests
- Rollback: user data that must survive a downgrade
```

A value change must update both policy languages, registry data, localized copy,
and test expectations in the same change.

## Policy release notes

### 1.0.1 · 2026-07-29 · unreleased

- Status: implementing
- Clarified current-companion traits and passive-slot assignments in the menu
  popover and collection UI.
- Split the collection into Home, Collection, Pet Setup, and Rewards & Style.
- Reserved external aura and background layers for cosmetics; rarity is
  represented only within the pet sprite.
- Added registry-derived generation, discovery, activation, and rarity filters
  for future species expansion.
- Added direct passive assignment to completed-pet cards.
- Preserved behavior symbols and working props in their Normal colors while
  applying species-specific rarity palettes to pet sprites.

### 1.0.0 · 2026-07-29 · Tokeni Bar v0.14.0

- Status: released
- Split benefits into active and passive activation.
- Set permanent passive-slot thresholds at 0 / 30 / 60 / 90 / 120 forms.
- Defined generation-one benefits and all rarity values.
- Defined registry-based expansion and privacy constraints for future generations.
- Implemented the registry, dedicated state store, loadout engine, five benefits,
  and collection UI.
- Added migration from lineage unlocks to actual encounters only.
- Passed macOS CI Swift tests, release build, and app-bundle validation.
- Published GitHub release and Homebrew Cask/Formula 0.14.0.
