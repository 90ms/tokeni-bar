# Usage display and growth accounting

[한국어](usage.ko.md) | **English**

## Menu popover

Each provider card shows its primary quota, remaining percentage, and both the
local clock time and time remaining for a verified reset by default. Expand
**Show details** for additional quota windows, token
totals, API-equivalent reference costs, data source, and update time. The
header and footer actions stay fixed while the center scrolls when many
providers or expanded details need more room.
The pet status card comes first, followed by provider usage cards. Compact
mode keeps the same path to expanded provider details.

**Usage History** in the footer opens the 30-day local aggregate window directly.
The coffee button prevents idle system sleep for the current app session; settings
and quit remain available beside it. Selected-provider menu-bar mode saves space by
showing only the provider brand icon and remaining percentage.

## Tokeni token-growth accounting

Tokeni growth uses only **verified increases** in token counters reported by
providers. Usage-file modification times drive working and sleeping animation
only; they never create Growth XP.

Verified increases across providers are combined after preventing replayed
counters from paying twice. Every 600,000 tokens grant one Growth XP.
Unconverted remainder tokens carry across dates, and refreshing the same
cumulative value never pays twice.

The current level's UI maps its internal XP interval to **0–100 Growth Energy**.
For the growth target, verified token remainder awaiting conversion contributes
fractional progress without changing stored XP or the level curve. The Today
summary shows verified tokens instead of a small raw-XP number.

When a booster is active, its 2x, 3x, or 5x multiplier applies to the base
Growth XP produced by the ledger. The award creation time determines
whether the booster is active, and an already-applied award ID never pays
again. Booster-added XP is never treated as another base award and does not
multiply other bonus XP again.
Using another booster with the same multiplier extends the current expiry by
its full duration. A different multiplier replaces the active booster after a
confirmation that its remaining time will not be restored.

Codex, Claude Code, GitHub Copilot, Cline, Antigravity, and Grok Build all
produce a **daily counter** from timestamped local observations. Codex derives
same-day deltas from its cumulative session events, including sessions that
cross midnight. Duplicate or incomplete records never increase the counter.

A counter drop or reset never removes awarded XP. Changes without a
trustworthy timestamp are not guessed across a date boundary.
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

Codex, Claude, Copilot, and Grok Build JSONL files are decoded one line at a
time from 64 KiB chunks instead of retaining the complete file and every event
in memory. Files over the safety limit and symbolic links are rejected; a file
that grows past the limit while being read is discarded as well.

Each refresh also caps the combined JSONL scan at 128 MiB. If the selected
session set is larger, the provider keeps its previous/stale state instead of
building a partial total. Temporary Foundation objects are released after each
line so repeated refreshes do not accumulate parser autorelease allocations.

Unchanged local session files are not parsed again on every refresh; a bounded
result cache keyed by file size and modification time is reused. When a CLI is
missing or fails, Tokeni Bar also backs off repeated process launches briefly,
so an authentication or launch problem does not keep increasing CPU and memory
pressure.

Sprite manifests are checked at launch, but image sheets load lazily only for
the species, form, and variant being displayed. Cropped frames are detached
from their source sheet, with an 8 MiB sheet-cache cost limit and a 12 MiB
frame-cache cost limit. Disabling the on-screen pet releases its SwiftUI
hosting view and animation tasks.

Provider directories are checked every ten seconds for activity animation.
While activity continues, pet-state persistence is limited to once per minute
except for a date rollover, and overlapping background state saves are
coalesced. Unchanged history samples are not re-encoded. macOS may retain
released allocations in process RSS for reuse, so the displayed footprint does
not always fall immediately.
Memory that keeps increasing independently of log refreshes or newly displayed
sprites should be reported with diagnostics and reproduction steps.

## Local daily provider sources

- **Copilot:** the preferred source is the official OTel JSONL file selected by
  `COPILOT_OTEL_FILE_EXPORTER_PATH`. OTel is opt-in. If it is not available,
  only completed CLI sessions that began today are used.

  ```bash
  mkdir -p "$HOME/.copilot/otel"
  COPILOT_OTEL_FILE_EXPORTER_PATH="$HOME/.copilot/otel/usage.jsonl" copilot
  ```

  Keeping the file under `~/.copilot/otel` lets Tokeni Bar discover it even
  when the menu-bar app does not inherit the terminal environment. Copilot's
  message-content capture remains off unless the user enables it separately.
- **Cline:** timestamped `api_req_started` usage records are read from Cline's
  VS Code, VS Code Insiders, VSCodium, Cursor, and standalone local task data.
- **Antigravity:** timestamped usage metadata is read from current SQLite
  conversation databases. Antigravity's own Google sign-in is sufficient;
  Tokeni Bar does not require or store a separate provider credential.
- **Grok Build:** completed `turn_completed` records are read from the current
  `updates.jsonl` format. Incomplete usage and partial cost are rejected.

## Codex account token activity

Codex account activity reuses the existing sign-in from the installed Codex
CLI. A dated total may arrive after its calendar day ends, and its settlement
delay and boundary time are not guaranteed.

The main token row uses cumulative local Codex session events to show **Today**
without waiting for the account service. The account detail still shows:

- **Latest daily (`yyyy-MM-dd`)**: valid bucket totals for the newest date
- **This month**: valid returned buckets in the current local calendar month
- **Lifetime**: the account-service lifetime total

When a local Today total exists while the account bucket is still delayed, the
popover says **Local usage today · account total pending**. Each turn reported by
the latest Codex log is added to the local daily observation and drives growth
immediately. Delayed prior-day and account totals remain visible only for historical
account context and never create growth energy.

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

### Claude Code CLI connection

Claude account quotas are queried through the installed Claude Code CLI's
non-interactive `/usage` command. Tokeni Bar never reads Claude Code's
credential files or Keychain item, and never copies or separately persists a
token.

When the CLI reports a reset as a full date, a time-only value, a weekday and
time, or a relative countdown, Tokeni Bar converts it to the verified reset
instant and shows both local clock time and time remaining under the five-hour
quota. If the CLI omits the reset time, Tokeni Bar leaves it unavailable instead
of estimating.

- App startup and automatic refreshes reuse the CLI's existing sign-in without
  opening a password or login prompt.
- Even when launched from Finder, the CLI receives the user's home directory and
  common Homebrew, npm, nvm, fnm, and mise runtime paths used by terminal installs.
- **Settings → General → Providers → Connect Claude Code** runs the same
  non-interactive command with a fresh result. It does not start a separate
  authentication flow.
- If the CLI is missing or not signed in, the app keeps local session usage and
  leaves account quotas unavailable. Run `claude` once in Terminal to install,
  sign in, or update the CLI, then try Connect again.

Connection failures now identify the observed cause—missing executable, sign-in
required, expired session, launch failure, or timeout—when the CLI reports one.
Pressing **Connect** after signing in bypasses the failure backoff and checks the
CLI immediately.

The connection row distinguishes **Connected to account usage**, **Using local
usage only**, **CLI sign-in required**, **Session expired**, and **Connection
status unavailable**.

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

Codex and Claude use model-specific public API prices where the local log has a
complete token split. Cline and Grok Build prefer complete costs recorded by
the provider. Copilot and Antigravity remain without a USD amount when their
local data does not provide a trustworthy currency value. Codex account
daily, monthly, and lifetime totals still use a versioned reference profile
because those account totals have no historical model or token-category split.

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
