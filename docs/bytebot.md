# Tokeni pet growth and egg collection

[한국어](bytebot.ko.md) | **English**

Tokeni pets are local pixel companions that grow from verified agent token
usage. They require no game account or server. Pet state never contains a
provider name, raw token total, prompt, response, or credential.

## Core loop

1. The first launch grants one non-sellable Starter Egg.
2. Hatch it for free and choose one pet as the active growth pet.
3. Verified token increases become that pet's cumulative Growth XP.
4. Manually evolve at levels 10 and 25 to change its appearance.
5. Obtain more eggs from the Star Shard shop and collection milestones.
6. Switch among owned pets or send an inactive pet to a new home.
7. Combine three standard, mutation-free pets of one species in the Mutation Lab to create a mutation pet.

Levels continue without a cap after the adult form. Getting another pet never
requires completing or replacing the current pet or spending Growth XP.

## Unbounded levels

Every 25,000 verified tokens grant one Growth XP. Remainder tokens carry across
dates. Active time affects animation only and cannot create XP.

```text
next-level XP = min(2 + floor((current level - 1) / 10), 15)
```

Level 10 requires 18 cumulative XP and level 25 requires 66. At 100,000 verified
tokens per active day, the targets are about five and seventeen days. A
high-level pet never needs more than 15 XP for its next level. Starting at level
30, every ten levels grant 10 Star Shards.

Timed 2x, 3x, and 5x boosters apply only to newly verified base XP. Activity,
species, variants, personalities, and cosmetics do not create multipliers.

## Evolution and forms

| Level | Result |
|---:|---|
| 1 | Hatchling form |
| 10 | Junior evolution available |
| 25 | Adult evolution available |

Evolution is manual and never spends XP. Levels keep increasing if evolution is
deferred. Future appearances can be added through the evolution registry.

## Egg vault and shop

| Egg | Acquisition or unlock | Price | Resale |
|---|---|---:|---:|
| Starter Egg | First launch once | Free | No |
| Homecoming Egg | Once when migrating an active pet | Not sold | No |
| Mystery Egg | Highest pet level 5 | 90 shards | 30 |
| Discovery Egg | Discover three species | 180 shards | 60 |
| Prismatic Egg | Collection milestones | Not sold | 60 |

A Discovery Egg guarantees an undiscovered species while any remain. A
Prismatic Egg guarantees the prismatic variant. Eggs have stable IDs and seeds,
so a crash during the reveal cannot consume one twice or reroll its result.

The collection grants each reward once:

- Discover all five species: one Discovery Egg.
- Discover five species/variant combinations: one Prismatic Egg.
- Discover all ten combinations: one Prismatic Egg.

Resale is always below purchase price. There are no real-money purchases,
limited-time shops, or player-to-player trades.

## Owned pets and switching

Hatching adds a pet to the owned roster without replacing the current pet. One
pet receives Growth XP at a time, and the active pet can be changed freely.
Each pet retains its level, XP, form, name, personality, and memories.

The active pet and the last remaining pet cannot be sent away. Sending an
inactive standard pet to a new home grants 30 shards; a prismatic pet grants 60.
Value does not rise with level, preventing XP farming from becoming a currency
loop. Collection discoveries remain after an egg or pet is sold.

## Five species and variants

ByteBot, CacheCat, StackFox, PromptPup, and NullSlime have equal base odds. If
an undiscovered species remains, five consecutive duplicate hatches guarantee
that the next normal hatch uses the undiscovered pool.

| Variant | Base chance | Power |
|---|---:|---|
| Standard | 92% | Identical |
| Prismatic | 8% | Identical |

After 11 consecutive standard results, the twelfth normal hatch is prismatic.
The main collection is `5 species × standard/prismatic`, or ten combinations.
Lifecycle forms remain in each combination's growth album.

### Duplicate pets and the Mutation Lab

Only three inactive standard, mutation-free archived pets of the same species
can be combined. Prismatic pets and existing mutation pets are protected from
the material pool. The three source pets are consumed, and the result creates a
separate `standard + mutation` pet at hatchling stage and level 1 in the
archive. It can be raised, activated as the current pet, or assigned to a
companion lineup slot.

Each species has five mutations—Neon, Shadow, Crystal, Glitch, and Aurora—and
every third synthesis guarantees an undiscovered mutation for the selected
species. A repeat strengthens its resonance level and still creates a new
mutation pet. Mutations are visual-only gameplay elements: they never affect
Growth XP, hatch odds, stats, rewards, or resale value. The mutation collection
has `5 species × 5 mutations`, or 25 entries; together with the ten
Standard/Prismatic entries, the full collection contains 35 entries. Each
mutation grants 30 Star Shards once, on first discovery.

## Level rewards and Star Shards

| Level | First reward for each pet |
|---:|---|
| 5 | 2x booster for 30 minutes |
| 10 | 3x booster for 20 minutes |
| 20 | Firefly aura |
| 25 | 5x booster for 10 minutes and orbit aura |

Automatic activity attendance, first verified daily growth, weekly and monthly
activity, discoveries, and stable-version gifts still grant Star Shards. Shards
are shared by eggs, cosmetics, and boosters. There are no streak-loss penalties,
hunger, illness, or death.

## Behavior and on-screen pet

Pets react to work, recent activity, rest, quota warnings, and pats. These are
animations and do not create XP. Settings control the on-screen pet, size,
position lock, click-through, reduced motion, and low-power behavior.

## Storage and privacy

Pet UUIDs, species, variants, forms, Growth XP, eggs, names, personalities,
memories, collection state, mutation records and synthesis count, equipped
mutation, shards, cosmetics, and boosters stay on the Mac.
Pet state never stores provider names, raw token totals, prompts, responses, or
credentials. Unverified or stale usage never becomes XP. See
[usage display and growth accounting](usage.md) for aggregation details.
