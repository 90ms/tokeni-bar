# Tokeni pet growth and egg collection

[한국어](bytebot.ko.md) | **English**

Tokeni pets are local pixel companions that grow from cumulative token usage
verified by Tokeni Bar. There is no separate game account or server, and pet
state contains no provider name, raw token total, prompt, or response.

## Core loop

1. Hatch the free Starter Egg.
2. Gain one Growth XP per 600,000 verified tokens.
3. Manually evolve at levels 30 and 70.
4. Collect new species and appearances from eggs.
5. Convert an identical hatch into XP for the existing pet.
6. Inspect pet details and action animations in the collection.
7. At level 100, keep converting verified tokens into Star Shards.

## Growth to level 100

The initial maximum is level 100 at 500 cumulative XP.

```text
cumulative XP at level L = round(500 × ((L - 1) / 99) ^ 1.7)
```

Level 100 requires 300 million verified tokens. Early levels arrive quickly and
growth slows toward 100. Evolution is manual and spends no XP. XP stops at
level 100 and overflow is not stored as XP. On reaching level 100, Tokeni
randomly activates an owned pet below level 100 and makes it the new growth
target. Only when every owned pet is level 100 does the current target convert
every 100,000 verified tokens into 10 Star Shards. Progress toward the next
conversion is preserved per pet, and booster multipliers do not apply.

Visible next-level progress maps each level's actual XP interval to 0–100
Growth Energy. For example, one XP appears as 25 Growth Energy when that level
requires four XP. Verified remainder below one XP advances only the growth
target's bar; internal XP and level rules do not change.

The displayed companion and growth target can be selected independently, but
automatic rotation takes priority while an unfinished owned pet remains.
At level 100, the on-screen form can be switched among Hatchling, Junior, and
Adult without changing growth or collection progress.

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

## Mutation variants

Three-pet synthesis and shared mutation auras are removed. Normal hatch
appearance odds are:

| Appearance | Base odds | Power |
|---|---:|---|
| Standard | 91% | Equal |
| Prismatic | 8% | Equal |
| Mutation | 1% | Equal |

Mutation is a species-specific intrinsic body variation rather than an
equipable decoration. The current app derives a restrained trait by recoloring
only existing body pixels with the sprite palette. It adds no detached
decoration or particle and preserves the Standard silhouette and alpha exactly.
Reviewed dedicated Mutation sheets may replace it later.
It enters the collection on hatch without changing power and provides a
signature action:

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
Every growth stage has independent Standard and Prismatic sprites, while its
Mutation appearance uses a trait integrated into the original body. Reviewed
dedicated Mutation sheets may replace it later. A visible signal core persists across modes,
while wings, ears, fins,
and shells shift during working, warning, and signature actions.

Benefits are not stronger than generation 1. QueryOwl and RelayRay reuse the
active benefits of ByteBot and CacheCat. KernelCrab, LoopHare, and PatchPanda
reuse the passive benefits of StackFox, PromptPup, and NullSlime at identical
values. Finding three generation-two species unlocks Hologram Scanlines; finding
all five unlocks the Mini Drone sidekick.

## Collection and actions

The collection target is 30 combinations: ten species times Standard,
Prismatic, and Mutation. Hatchling, Junior, and Adult remain inside each card's
growth album. Selecting a card previews discovered stages, owned level, and the
idle, working, waiting, warning, celebrate, and sleep animations. Mutation-only
and level-100 speech actions remain in collection details. The menu popover has
no separate max-level talk button.

**Open Tokeni → Pets** combines the current companion, growth status,
Collection, and Owned sections. **Settings → Tokeni** contains only pet-display
and on-screen-pet preferences. Collection shows every species in separate
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
species. Aura, Background, Sidekick, Frame, and Scene Effect cosmetics can be
equipped independently. Frames and scene effects use the full companion canvas;
legacy Body Color and Ground items migrate to corresponding new items.

Each stable app version shows a one-time update-reward button in the Customize
tab. Claiming it manually grants 300 Star Shards, and the claimed version is
recorded in local reward state so it cannot pay twice.

## Persistence and privacy

Schema v11 stores pet UUIDs, species, appearance, Growth XP normalized to the
500-XP cap, growth target, displayed growth stage, eggs, names, personalities,
memories, collection, and local rewards. Reward schema v10 stores only per-pet progress toward the next
max-level conversion and processed award IDs, never raw token totals. Previous
energy remainders migrate at the new rate. Migration also removes v10 synthesis
records and inactive synthesized mutation pets. Unverifiable or stale usage
never becomes XP. See the [pet system policy](companion-policy.md) and
[usage display guide](usage.md) for details.
