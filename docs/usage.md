# Usage display guide

## Codex account token activity

Codex account activity comes from the experimental `codex app-server`
`account/usage/read` method. The response contains dated daily buckets and a
lifetime total. Daily buckets can arrive after their calendar day has ended.

The popover therefore shows:

- **Latest daily (`yyyy-MM-dd`)**: the sum of all valid buckets for the newest
  date returned by the account service. It stays visible when the local date
  changes.
- **This month**: the sum of valid returned buckets in the current local
  calendar month.
- **Lifetime**: the account-service lifetime total.

Invalid, negative, and future-dated buckets are discarded. If no valid daily
bucket exists, the latest-daily value remains unavailable rather than being
fabricated. API-equivalent costs are rough references based on aggregate token
totals, not actual subscription charges.

## Claude menu-bar quota

Choose **Selected provider remaining** and select **Claude Code** under
**Settings → General → Menu Bar**. A **Claude quota** picker then offers:

- **5-hour**: the `five-hour` session window.
- **Weekly**: the `seven-day` account window.
- **Fable**: the model-scoped `scoped-weekly-fable` window.

Fable is the default for existing behavior. The selection is stored locally. If
the selected window is not present in the current account response, the menu bar
shows Claude as unavailable instead of substituting a different quota.

## Cost estimates, exchange rates, and history

Cost is a reference estimate of what the available account or local token total
might cost at published API prices. It is not an API invoice or a Codex,
ChatGPT, Claude, or Grok subscription charge.

Codex account activity supplies aggregate token totals without the historical
model, input/output, cache, or reasoning-token split needed for exact API
pricing. Its daily, month, and lifetime costs use a versioned reference profile
based on the validated `gpt-5-codex` catalog price and an assumed 80% uncached
input / 20% output mix. Token totals are the authoritative value.

- USD/KRW is checked once per Seoul calendar day through
  [Frankfurter](https://frankfurter.dev/) using its ECB provider.
- The versioned model-price catalog is checked once per day. Invalid schemas,
  unsafe prices, untrusted sources, and downgrades are rejected.
- Aggregate quota, token, and estimated-cost samples are stored locally every
  15 minutes and retained for 30 days.
- Unknown models remain without a cost instead of being mapped to a guessed
  price.
