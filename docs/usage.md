# Usage display and growth accounting

[한국어](usage.ko.md) | **English**

## Menu popover

Each provider card shows its primary quota, remaining percentage, and reset
time by default. Expand **Show details** for additional quota windows, token
totals, API-equivalent reference costs, data source, and update time. The
header and footer actions stay fixed while the center scrolls when many
providers or expanded details need more room.

**Usage History** in the footer opens the 30-day local aggregate window
directly; settings and quit remain available as right-side icon actions.

## ByteBot token-growth accounting

ByteBot growth uses only **verified increases** in token counters reported by
providers. Usage-file modification times drive working and sleeping animation
only; they never create growth energy.

For verified daily token increases `T` across providers, after preventing
replayed counters from paying twice, energy is
`floor(32 × log2(1 + T / 25,000))`. There is no hard cap, and refreshing the
same cumulative value never pays twice.

Counter scope differs by provider:

- **Daily counters:** confirmed dated Codex and Claude totals credit that date.
- **Session counters:** Gemini and Grok establish a baseline on first
  observation and credit only later increases in that session.
- **Lifetime counters:** OpenCode establishes a baseline first and credits only
  later increases.
- Codex uses current-session increases the same way when a daily total is
  unavailable.

A counter drop or reset never removes awarded energy. Session and lifetime
increases are not guessed across a date boundary while the app was closed.
An implausibly large increase must be confirmed by a later observation before
it credits. Complete daily totals that arrive late may credit up to three
recent days.

Deduplication checkpoints live separately in `usage-growth-ledger.json`. The
app saves a pending award, applies it to ByteBot state, and then marks it
complete, preventing double payment if the app exits between writes.

See [ByteBot growth and collection](bytebot.md) for life stages and rarity.

## Codex account token activity

Codex account activity comes from the experimental `codex app-server`
`account/usage/read` method. Its response contains dated daily buckets and a
lifetime total. A daily bucket may arrive after its calendar day ends.

The popover shows:

- **Latest daily (`yyyy-MM-dd`)**: valid bucket totals for the newest date
- **This month**: valid returned buckets in the current local calendar month
- **Lifetime**: the account-service lifetime total

Negative, future-dated, and otherwise invalid values are discarded. If there
is no valid daily bucket, the app leaves it unavailable instead of inventing a
value.

## Claude menu-bar quota

Choose **Selected provider remaining** and **Claude Code** under
**Settings → General → Menu Bar** to show the **Claude quota** picker:

- **5-hour:** the `five-hour` session window
- **Weekly:** the `seven-day` account window
- **Fable:** the model-scoped `scoped-weekly-fable` window

Fable is the default and the selection is stored locally. If the selected
window is absent from the account response, Claude remains unavailable instead
of silently substituting another quota.

### Claude Keychain connection

Claude account quotas reuse the existing OAuth sign-in that Claude Code stores
in the macOS Keychain. Tokeni Bar never copies or separately persists the
token.

- Automatic refreshes prohibit authentication UI. If access is unavailable or
  the Mac is locked, the app falls back to local Claude usage without opening a
  password prompt.
- Start the initial connection explicitly under **Settings → General →
  Provider Connections → Connect Claude Code**. Choosing **Always Allow** in
  the macOS dialog prevents repeat prompts while the same app identity and
  Keychain item remain in place.
- A source-built Formula update can change the app signature, and Claude Code
  can replace its Keychain item. macOS may require approval again in either
  case; reconnect from Settings.

Unlocking the Mac alone does not initiate interactive authentication. When
connection approval is unavailable, the app leaves account quotas unavailable
rather than inventing values and continues showing local-session usage.

## Cost estimates, exchange rates, and history

Cost is an API-price-equivalent reference for the available token data. It is
not an API invoice or a subscription bill.

Codex account activity does not include the historical model, input/output,
cache, or reasoning-token split needed for exact API pricing. Daily, monthly,
and lifetime estimates therefore use a versioned reference profile based on
the validated `gpt-5-codex` price and an assumed 80% uncached input / 20%
output mix. Token totals remain authoritative.

- USD/KRW is checked once per Seoul calendar day through
  [Frankfurter](https://frankfurter.dev/) using its ECB provider.
- The model-price catalog is checked daily. Invalid schemas, unsafe prices,
  untrusted sources, and downgrades are rejected.
- Aggregate quota, token, and estimated-cost samples are stored locally every
  15 minutes and retained for 30 days.
- Unknown models remain without a cost instead of receiving a guessed price.
