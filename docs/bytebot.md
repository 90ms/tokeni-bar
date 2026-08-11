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
7. At level 100, unlock a speech action asking you to raise another friend.

## Growth to level 100

The initial maximum is level 100 at 500 cumulative XP.

```text
cumulative XP at level L = round(500 × ((L - 1) / 99) ^ 1.7)
```

Level 100 requires 300 million verified tokens. Early levels arrive quickly and
growth slows toward 100. Evolution is manual and spends no XP. XP stops at
level 100 and overflow is not stored.

The displayed companion and growth target are independent. A favorite max-level
pet can stay visible while another owned pet receives Growth XP.

## Eggs and duplicate pets

Tokeni supports Starter, Homecoming, Mystery, Starlight, and Prismatic Eggs.
Each egg has a UUID and stable seed so interruption cannot reroll its result.

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

## Collection and actions

The collection target is 15 combinations: five species times Standard,
Prismatic, and Mutation. Hatchling, Junior, and Adult remain inside each card's
growth album. Selecting a card previews discovered stages, owned level, and the
idle, working, waiting, warning, celebrate, and sleep animations. Mutation-only
and level-100 speech actions appear when their requirements are met.

## Max-level speech

On first reaching level 100, a pet speaks one randomly selected, predefined
localized message. Players can talk to the max-level pet again. Selecting the
bubble opens the collection to choose another owned pet for growth. Messages
contain no work content or usage values.

## Persistence and privacy

Schema v11 stores pet UUIDs, species, appearance, Growth XP normalized to the
500-XP cap, growth target, eggs, names, personalities, memories, collection,
and local rewards. Migration removes v10 synthesis records and inactive
synthesized mutation pets. Unverifiable or stale usage never becomes XP. See
the [pet system policy](companion-policy.md) and [usage display guide](usage.md)
for details.
