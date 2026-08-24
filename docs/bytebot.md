# Tokeni pet growth and egg collection

[한국어](bytebot.ko.md) | **English**

Tokeni pets are local pixel companions that grow from cumulative token usage
verified by Tokeni Bar. There is no separate game account or server, and pet
state contains no provider name, raw token total, prompt, or response.

## Core loop

1. Hatch the free Starter Egg.
2. Gain one Growth XP per 600,000 verified tokens.
3. Manually evolve at levels 10 and 25.
4. Collect new species and appearances from eggs.
5. Convert an identical hatch into XP for the existing pet.
6. Inspect pet details and action animations in the collection.
7. At level 100, keep converting verified base Growth Energy into Star Shards.

## Growth to level 100

The initial maximum is level 100 at 500 cumulative XP.

```text
cumulative XP at level L = round(500 × ((L - 1) / 99) ^ 1.7)
```

Level 100 requires 300 million verified tokens. Early levels arrive quickly and
growth slows toward 100. Evolution is manual and spends no XP. XP stops at
level 100 and overflow is not stored as XP. A level-100 growth target instead
converts every 100 verified base Growth Energy into 20 Star Shards. Booster
multipliers do not affect this conversion.

The displayed companion and growth target are independent. A favorite max-level
pet can stay visible while another owned pet receives Growth XP, or remain the
growth target for repeatable shard conversion.

## Eggs and duplicate pets

Tokeni supports Starter, Homecoming, Mystery, Starlight, and Prismatic Eggs.
Each egg has a UUID and stable seed so interruption cannot reroll its result.
The first verified growth activity each local day grants one Starlight Egg and
300 Star Shards. Weekly attendance grants another 100, 200, and 300 shards on
days 3, 5, and 7, and monthly attendance grants another 500 shards on day 20.
The available content generation is frozen when an egg is acquired. Eggs saved
before the update keep the generation-one pool; newly acquired eggs include
generation two without changing an older seed's outcome.

Duplicate identity is `species + appearance`. A repeat hatch creates no new
pet; it grants the matching pet 25% of its current next-level XP requirement,
rounded up. Name, personality, and growth stage do not affect identity, and the
collection encounter record still increases.

## Rare mutations

Three-pet synthesis and shared mutation auras are removed. Normal hatch
appearance odds are:

| Appearance | Base odds | Power |
|---|---:|---|
| Standard | 91% | Equal |
| Prismatic | 8% | Equal |
| Mutation | 1% | Equal |

Mutation changes species-specific sprite colors and features without changing
power. It enters the collection on hatch and provides a signature action:

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

## Generation 2: Signal Expedition

Generation 2 contains QueryOwl, PatchPanda, LoopHare, RelayRay, and KernelCrab.
Every growth stage and Standard, Prismatic, and Mutation appearance has its own
sprite. A visible signal core persists across modes, while wings, ears, fins,
and shells shift during working, warning, and signature actions.

Benefits are not stronger than generation 1. QueryOwl and RelayRay reuse the
active benefits of ByteBot and CacheCat. KernelCrab, LoopHare, and PatchPanda
reuse the passive benefits of StackFox, PromptPup, and NullSlime at identical
values. Finding three generation-two species unlocks Hologram Platform; finding
all five unlocks the Mini Drone sidekick.

## Collection and actions

The collection target is 30 combinations: ten species times Standard,
Prismatic, and Mutation. Hatchling, Junior, and Adult remain inside each card's
growth album. Selecting a card previews discovered stages, owned level, and the
idle, working, waiting, warning, celebrate, and sleep animations. Mutation-only
and level-100 speech actions remain in collection details. The menu popover has
no separate max-level talk button.

In Settings, the **Pets** screen combines the current companion, growth status,
Collection, and Owned sections. Collection shows every species in separate
Generation 1 and Generation 2 sections without a search or generation filter.
Owned can still be narrowed with **View by pet**.

## Level rewards and boosters

Shard rewards occur at levels 30 and 40, every five levels from 50, every three
levels from 60, and every level from 70. One pet grants 460 level-reward shards
by level 100. Reusing the same booster multiplier extends its expiry by the
booster's full duration. Choosing a different multiplier replaces the active
booster and discards its remaining time after confirmation.

Collection milestones grant one Prismatic Egg at 5, 10, 20, and 30 discovered
species/appearance combinations, and one Starlight Egg at 5 and 10 distinct
species. Ground and Sidekick cosmetics use independent slots, so they can be
equipped alongside an aura, background, and palette.

Each stable app version shows a one-time update-reward button in the Customize
tab. Claiming it manually grants 300 Star Shards, and the claimed version is
recorded in local reward state so it cannot pay twice.

## Persistence and privacy

Schema v11 stores pet UUIDs, species, appearance, Growth XP normalized to the
500-XP cap, growth target, eggs, names, personalities, memories, collection,
and local rewards. Reward schema v8 stores max-level conversion remainders and
processed award IDs, never raw token totals. Migration removes v10 synthesis records and inactive
synthesized mutation pets. Unverifiable or stale usage never becomes XP. See
the [pet system policy](companion-policy.md) and [usage display guide](usage.md)
for details.
