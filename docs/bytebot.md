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

There is no daily hard cap. More tokens continue to increase energy, while each
additional energy point costs more tokens at very high usage.

| Tokens today | Energy today |
|---:|---:|
| 10,000 | 15 |
| 25,000 | 32 |
| 50,000 | 50 |
| 100,000 | 74 |
| 250,000 | 110 |
| 500,000 | 140 |
| 1,000,000 | 171 |

Refreshing the same cumulative value never pays twice. If a provider counter
drops or resets, earned energy and pet progress are never taken away.

## Life stages

| Stage | Total energy required |
|---|---:|
| Egg | 0 |
| Hatchling | 80 |
| Junior | 280 |
| Adult | 800 |

Energy earned after Adult becomes that ByteBot's **bond energy**. Bond does not
improve rarity odds; it remains as a personal collection record when the
journey is completed.

Working, quota warning, patting, and longer inactivity change the animation.
Activity detection drives behavior only and never fabricates growth energy.

## Rarity and evolution

Rarity rises through `Normal → Rare → Epic → Legendary` and never drops.
Hatching, Junior evolution, and Adult evolution each roll at or above the
current rarity.

| Current | Stay | Rare | Epic | Legendary |
|---|---:|---:|---:|---:|
| Normal | 75.0% | 21.0% | 3.8% | 0.2% |
| Rare | 86.0% | - | 13.0% | 1.0% |
| Epic | 97.0% | - | - | 3.0% |
| Legendary | 100% | - | - | - |

Without pity, an Adult starting from a Normal egg ends Normal 42.2%, Rare
40.9%, Epic 15.5%, and Legendary 1.4%.

Completed Adults provide visible guarantees:

- Rare or higher within at most 3 generations
- Epic or higher within at most 7 generations
- Legendary within at most 16 generations

The collection shows the maximum completed generations remaining. Restarting
early keeps existing pity but does not advance it.

## Collection

The first collection has 13 forms:

- one shared egg;
- four rarities for Hatchling, Junior, and Adult.

A form shown during evolution is marked **Met**. If a rarity first appears at a
later stage, its earlier-stage art unlocks as **Lineage**. A Legendary first
found as an Adult therefore also unlocks Legendary Hatchling and Junior art.

Open the grid button in the menu or choose **Settings → Tokeni → Open ByteBot
Collection** to see:

- all 13 form unlocks;
- Met versus Lineage unlocks;
- completed generations, best rarity, and best bond;
- maximum generations remaining for every guarantee.

## New eggs and completed journeys

At Adult, keep the current ByteBot and grow bond, or finish its journey and
receive a new Normal egg. Completion archives final rarity and bond and updates
pity.

Before Adult, you may part ways and restart:

- unlocked forms and existing pity remain;
- current growth energy is lost;
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
