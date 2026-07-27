# ByteBot growth and collection

[한국어](bytebot.ko.md) | **English**

ByteBot is a local pixel companion powered by verified AI-agent token usage.
There is no game account or server; growth, rarity, collection, and pity are
stored on your Mac.

## Growth energy

For verified daily token increases `T` across providers, after preventing
replayed counters from paying twice, daily growth energy is:

```text
T = 0  → 0
T > 0  → floor(32 × log2(1 + T / 25,000))
```

More tokens continue to increase the daily target, while each additional energy
point costs more tokens at very high usage. The actual action-energy balance is
capped at 320.

| Tokens today | Energy today |
|---:|---:|
| 10,000 | 15 |
| 25,000 | 32 |
| 50,000 | 50 |
| 100,000 | 74 |
| 250,000 | 110 |
| 500,000 | 140 |
| 1,000,000 | 171 |

Refreshing the same cumulative value never pays twice. On each date change,
20% of the remaining balance carries over. If the app stays closed for multiple
days, the 20% carry is applied once for every elapsed day.

## Life stages

| Action | Energy spent |
|---|---:|
| Hatch egg | 60 |
| Evolve to Junior | 100 |
| Evolve to Adult | 160 |
| Receive a new egg or restart | 40 |

Every generation starts as an ungraded egg. Having enough energy never changes
the stage automatically: the user must click Hatch or Evolve. Energy earned as
an Adult fills action energy and that ByteBot's **bond energy**.

Working, quota warning, patting, and longer inactivity change the animation.
Activity detection drives behavior only and never fabricates growth energy.

## Rarity and evolution

The first rarity is revealed when the user hatches the egg. Later evolution
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

- Rare or higher within at most 3 generations
- Epic or higher within at most 7 generations
- Legendary within at most 16 generations

The collection shows the maximum completed generations remaining. Restarting
early keeps existing pity but does not advance it.

## Collection

The collection has 12 forms: four rarities for Hatchling, Junior, and Adult.
The ungraded egg is not counted as a collectible form.

A form shown during evolution is marked **Met**. If a rarity first appears at a
later stage, its earlier-stage art unlocks as **Lineage**. A Legendary first
found as an Adult therefore also unlocks Legendary Hatchling and Junior art.

Open the grid button in the menu or choose **Settings → Tokeni → Open ByteBot
Collection** to see:

- all 12 form unlocks;
- Met versus Lineage unlocks;
- completed generations, best rarity, and best bond;
- maximum generations remaining for every guarantee.

## New eggs and completed journeys

At Adult, keep the current ByteBot and grow bond, or spend 40 energy to finish
its journey and receive a new ungraded egg. Completion archives final rarity
and bond and updates pity.

Before Adult, you may spend 40 energy to part ways and restart:

- unlocked forms and existing pity remain;
- unspent action energy remains;
- an early restart does not count as a completed generation;
- energy already assigned that day cannot be reused by the new egg.

## When tokens cannot be counted

Only token counters with known scope and reset behavior grant growth. Missing,
stale, or incompatible data remains unavailable instead of becoming guessed
energy.

- Complete Codex and Claude daily totals can credit their confirmed date.
- Gemini and Grok session totals and OpenCode lifetime totals establish a
  baseline first, then credit increases.
- If the app was closed across a date boundary, session and lifetime counters
  are not guessed across unknown days.
- An implausibly large jump must be observed again before it credits energy.

See the [usage display guide](usage.md) for detailed accounting and cost rules.

## Storage and privacy

- `companion-state.json`: stage, rarity, energy, bond, collection, pity, and interactions
- `usage-growth-ledger.json`: scoped token checkpoints and daily credited energy
- `usage-history.json`: 30 days of aggregate usage, quota, and cost history

Companion state contains no provider names or raw token totals. No prompt,
response, authentication token, cookie, or account secret is stored in the
growth ledger. There is no analytics or server telemetry.
