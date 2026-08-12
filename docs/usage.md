# Usage display and growth accounting

[한국어](usage.ko.md) | **English**

## Menu popover

Each provider card shows its primary quota, remaining percentage, and reset
time by default. Expand **Show details** for additional quota windows, token
totals, API-equivalent reference costs, data source, and update time. The
header and footer actions stay fixed while the center scrolls when many
providers or expanded details need more room.
The pet status card comes first, followed by provider usage cards. Compact
mode keeps the same path to expanded provider details.

**Usage History** in the footer opens the 30-day local aggregate window
directly; settings and quit remain available as right-side icon actions.

## Tokeni token-growth accounting

Tokeni growth uses only **verified increases** in token counters reported by
providers. Usage-file modification times drive working and sleeping animation
only; they never create Growth XP.

Verified increases across providers are combined after preventing replayed
counters from paying twice. Every 600,000 tokens grant one Growth XP.
Unconverted remainder tokens carry across dates, and refreshing the same
cumulative value never pays twice.

When a booster is active, its 2x, 3x, or 5x multiplier applies to the base
Growth XP produced by the ledger. The award creation time determines
whether the booster is active, and an already-applied award ID never pays
again. Booster-added XP is never treated as another base award and does not
multiply other bonus XP again.
Using another booster with the same multiplier extends the current expiry by
its full duration. A different multiplier replaces the active booster after a
confirmation that its remaining time will not be restored.

Counter scope differs by provider:

- **Daily counters:** confirmed dated Codex and Claude totals credit that date.
- **Session counters:** Gemini and Grok establish a baseline on first
  observation and credit only later increases in that session.
- **Lifetime counters:** OpenCode establishes a baseline first and credits only
  later increases.
- Codex uses current-session increases the same way when a daily total is
  unavailable.

A counter drop or reset never removes awarded XP. Session and lifetime
increases are not guessed across a date boundary while the app was closed.
An implausibly large increase must be confirmed by a later observation before
it credits. Complete daily totals that arrive late may credit up to three
recent days.

The collection's combined total and target use today's usage-date ledger.
Provider rows separately show each provider's newest confirmed usage date and
token total. When an earlier daily bucket is first confirmed today, it says
**Settled today**, and its XP is included in today's earned amount. A
provider without a trustworthy value remains **Waiting for data** rather than
becoming a misleading zero.

The app uses local progress-validation data to keep the same usage from being
credited again. If a write is interrupted or part of the data is damaged,
retained recovery copies are checked first.

See [Tokeni pet growth and eggs](bytebot.md) for levels, evolution, and eggs.

## Resource and memory management

Codex and Claude local JSONL files are decoded one line at a time from 64 KiB
chunks instead of retaining the complete file and every event in memory. Files
over the safety limit and symbolic links are rejected; a file that grows past
the limit while being read is discarded as well.

Sprite manifests are checked at launch, but image sheets load lazily only for
the species, form, and variant being displayed. Cropped frames are detached
from their source sheet, with an 8 MiB sheet-cache cost limit and a 12 MiB
frame-cache cost limit. Disabling the on-screen pet releases its SwiftUI
hosting view and animation tasks.

Provider directories are checked every ten seconds for activity animation.
While activity continues, pet-state persistence is limited to once per minute
except for a date rollover. macOS may retain released allocations in process
RSS for reuse, so the displayed footprint does not always fall immediately.
Memory that keeps increasing independently of log refreshes or newly displayed
sprites should be reported with diagnostics and reproduction steps.

## Codex account token activity

Codex account activity reuses the existing sign-in from the installed Codex
CLI. A dated total may arrive after its calendar day ends, and its settlement
delay and boundary time are not guaranteed.

The popover shows:

- **Latest daily (`yyyy-MM-dd`)**: valid bucket totals for the newest date
- **This month**: valid returned buckets in the current local calendar month
- **Lifetime**: the account-service lifetime total

The popover distinguishes **Today's usage confirmed** from
**Today pending · confirmed through yyyy-MM-dd**. If the newest confirmed bucket
arrives within three days, the provider and usage date form an idempotent
settlement key. A later increase to that bucket credits only the difference.

Negative, future-dated, and otherwise invalid values are discarded. If there
is no valid daily bucket, the app leaves it unavailable instead of inventing a
zero. Missing CLI, sign-in required, unsupported CLI, and query failure are
reported separately.

### Checking the Codex CLI connection

A menu-bar app may run with a more limited `PATH` than an interactive shell.
Tokeni Bar also checks common package-manager and user installation locations.
If **Codex CLI not found** or **Account token query failed** still appears, run
`codex` once in Terminal to verify sign-in and update the CLI, then restart
Tokeni Bar. Tokeni Bar never copies or separately stores Codex credentials or
tokens.

## Claude menu-bar quota

Choose **Selected provider remaining** and **Claude Code** under
**Settings → General → Menu Bar** to show the **Claude quota** picker:

- **5-hour:** session quota
- **Weekly:** account weekly quota
- **Fable:** model-scoped weekly quota

Fable is the default and the selection is stored locally. If the selected
window is absent from the account response, Claude remains unavailable instead
of silently substituting another quota.

### Claude Keychain connection

Claude account quotas reuse the existing OAuth sign-in that Claude Code stores
in the macOS Keychain. Tokeni Bar never copies or separately persists the
token.

- App startup and automatic refreshes never query Claude Code's Keychain item.
  They use local Claude session logs without opening a password prompt.
- Start the initial connection explicitly under **Settings → General →
  Providers → Connect Claude Code**. Choosing **Always Allow** in
  the macOS dialog enables account quota refreshes for the current app session.
- After restarting Tokeni Bar, Claude returns to local-only usage until the
  player explicitly connects account quotas again.

Unlocking the Mac alone does not initiate interactive authentication. When
connection approval is unavailable, the app leaves account quotas unavailable
rather than inventing values and continues showing local-session usage.

The connection row distinguishes **Connected to account usage**, **Using local
usage only**, **Keychain approval required**, **Session expired**, and
**Connection status unavailable**.

## Usage notifications

**Settings → Alerts** separates usage, reset, system-status, and delivery
settings. Low remaining usage, one-hour reset reminders, monthly budget alerts,
and provider connection failures can be enabled independently.

- Multiple provider warnings from one refresh are grouped into one
  notification.
- A quota that is about to reset does not also send a duplicate low-remaining
  alert.
- Quiet hours retain the banner and silence only its sound.
- Depletion risk is included only after an actual decrease has been observed
  for at least 15 minutes. Insufficient history produces no prediction.
- Clicking an alert opens the Alerts settings tab. The collapsed **Recent
  notification decisions** section explains delivery or exclusion reasons.

No reset reminder is created when the provider does not report a reset time.
Each provider, quota window, and reset cycle can notify only once.

## Cost estimates, exchange rates, and history

Cost is an API-price-equivalent reference for the available token data. It is
not an API invoice or a subscription bill.

Codex account activity does not include the historical model, input/output,
cache, or reasoning-token split needed for exact API pricing. Daily, monthly,
and lifetime estimates therefore use a versioned reference profile bundled
with the app. Token totals remain authoritative.

- USD/KRW is checked once per Seoul calendar day through
  [Frankfurter](https://frankfurter.dev/) using its ECB provider.
- The model-price catalog is checked daily. Invalid schemas, unsafe prices,
  untrusted sources, and downgrades are rejected.
- Aggregate quota, token, and estimated-cost samples are stored locally every
  15 minutes and retained for 30 days.
- Unknown models remain without a cost instead of receiving a guessed price.

The history window shows its sample count and latest timestamp and gives the
chart a VoiceOver summary. Clearing history requires confirmation of the local
record count.

## Diagnostics

Open **Settings → Privacy → Provider Diagnostics** to review a report before
copying it. Token totals and model identifiers are excluded by default and
appear only when explicitly enabled; an on-screen warning then asks the user to
review before sharing. Prompts, responses, credentials, cookies, and file paths
are always excluded.
