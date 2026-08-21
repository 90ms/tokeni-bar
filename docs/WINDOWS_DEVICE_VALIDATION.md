# Windows physical-device validation runbook

Use this runbook to validate the current portable Windows ZIP on an interactive
Windows device. It complements hosted CI; it does not replace build, unit, or package
checks. Repeat the applicable cases for every release candidate and link the completed
record from its pull request or release issue.

Korean: [Windows 실기기 검증 runbook](WINDOWS_DEVICE_VALIDATION.ko.md)

## Safety and evidence rules

- Use a dedicated test account, disposable VM, or approved test device. Do not alter,
  rename, copy, or delete a user's provider database or usage logs to create a test state.
- Never collect credentials, cookies, prompts, responses, provider database contents,
  usage totals, quota percentages, costs, account names, email addresses, usernames,
  machine names, IP addresses, serial numbers, or device IDs.
- Do not attach screenshots or videos containing the dashboard, provider details, usage
  values, notifications, prompts, responses, or account UI. Record those results as
  sanitized text such as `available state shown; values not recorded`.
- An OS Settings screenshot is allowed only when it contains no user or device identifier
  and is cropped to the tested display setting. Prefer a text record.
- Do not attach raw logs, databases, settings files, crash dumps, registry exports, or
  process environment dumps. Record only the allowlisted evidence fields below.
- Do not automate Explorer termination. The Explorer recovery cases in this document are
  deliberate manual actions on an interactive test device.
- Stop and mark the case `Blocked` if the required state cannot be created without
  exposing or changing real user data.

## Result vocabulary

Use exactly one result for every applicable case:

- `Pass`: every expected result was observed and sanitized evidence was recorded.
- `Fail`: an expected result was not observed. Create or link an issue.
- `Blocked`: the case could not be executed safely or the required device/state was not
  available. Record the blocker and owner; do not report it as a pass.
- `N/A`: the case is outside the declared target matrix. Record the reason.

## What hosted CI proves

| Area | Hosted Windows CI proves | Physical-device validation still proves |
|---|---|---|
| Build and tests | Swift tests compile and run; release executable links | Behavior on the declared Windows edition, build, and device |
| Portable ZIP | Checksum, required files, resources, runtime DLL loading, offline smoke exit | Launch from Explorer, endpoint-policy warnings, tray discovery, normal exit |
| SQLite | Pinned executable hash/version, real read-only JSON round trip, database bytes unchanged | Packaged provider state on a clean PATH and a real approved provider installation |
| Dashboard | Deterministic presentation and non-interactive smoke | Open, hide, reopen, focus, refresh, keyboard navigation |
| Tray and Explorer | Native recovery code compiles and unit contracts pass | Visible icon, left/right click, and recovery after a manual Explorer restart |
| Display/accessibility | Geometry and formatting unit contracts | 100/150/200% scale, mixed-DPI monitors, keyboard and assistive technology |

A green hosted workflow must never be used as evidence that an interactive case passed.

## Test record header

Create one Markdown record per artifact and device. Do not include identifiers outside
this allowlist.

```text
Artifact version/tag:
Artifact SHA-256:
Source commit:
Test date (YYYY-MM-DD) and timezone:
Tester role or non-identifying alias:
Device alias (for example win11-vm-a; not the machine name):
Windows edition:
Windows version and OS build (transcribed from winver):
Architecture: x64
Installation type: portable ZIP
Endpoint warning observed: yes/no/not tested
Display matrix: monitor labels, resolutions, scale factors, relative arrangement
Input/accessibility tools: keyboard only / Narrator / other approved tool
Provider test profile: unavailable / approved test account / both
Related PR or release issue:
```

Verify the downloaded ZIP with `Get-FileHash -Algorithm SHA256` and compare it with the
published `.sha256` file. Record only the artifact hash, never a local path or username.
Extract into a new test directory. Do not reuse files from an older candidate.

## Core matrix

| ID | Scenario | Required matrix |
|---|---|---|
| ENV-01 | Target OS and artifact evidence | Every device/artifact |
| SMK-01 | Offline `--smoke-test` has no user-visible side effects | Every artifact |
| LIFE-01 | Clean launch and normal exit | Every device/artifact |
| TRAY-01 | Left click, hide/reopen, right click, refresh | Every device/artifact |
| EXP-01 | Explorer restart before dashboard was ever opened | Windows 10 and 11 targets |
| EXP-02 | Explorer restart while dashboard is hidden | Windows 10 and 11 targets |
| EXP-03 | Explorer restart while dashboard is open | Windows 10 and 11 targets |
| DPI-01 | Single-monitor 100%, 150%, and 200% scale | Each supported scale |
| DPI-02 | Mixed-DPI multi-monitor movement | At least one physical or virtual multi-monitor device |
| A11Y-01 | Keyboard-only tray and dashboard operation | Every target OS |
| A11Y-02 | Accessibility inspection | Windows 11 plus each supported accessibility baseline |
| SQL-01 | Provider unavailable with bundled SQLite and no PATH SQLite | Clean test profile |
| SQL-02 | Provider available with bundled SQLite and no PATH SQLite | Approved provider test profile |

## Procedures

### ENV-01 — target evidence and clean extraction

1. Record the allowlisted header fields. Transcribe edition, version, and build from
   `winver`; do not capture its screenshot if it displays identifying information.
2. Verify the ZIP SHA-256 against the published checksum.
3. Extract the candidate into a new directory and confirm these files exist:
   `TokeniWindows.exe`, `Tools\sqlite3.exe`, `Tools\sqlite-tools.json`,
   `THIRD-PARTY-NOTICES.txt`, and `Resources\CompanionAssets`.
4. Confirm Task Manager shows no existing `TokeniWindows.exe` process.

Pass when the artifact hash matches, required files exist, and the remaining matrix can
be attributed to the recorded OS/device configuration.

### SMK-01 — side-effect-free package smoke

1. Use a clean test profile or record the pre-existing presence and modification time of
   the Tokeni Bar application-data directory without opening file contents.
2. From the extracted directory run `TokeniWindows.exe --smoke-test` and record only the
   exit code and the stable `TOKENI_WINDOWS_SMOKE_OK` marker.
3. Confirm no tray icon, dashboard, notification, or companion overlay appeared.
4. Confirm no `TokeniWindows.exe` process remains and no Tokeni Bar settings/history file
   was created or modified.
5. Confirm no provider login or authorization UI appeared. Do not inspect provider files.

Pass when the command exits successfully with the marker and has no listed side effect.

### LIFE-01 — clean launch and normal exit

1. Launch `TokeniWindows.exe` from the extracted directory once.
2. Confirm exactly one process remains and one Tokeni Bar icon appears in the notification
   area or its overflow panel. A SmartScreen or endpoint warning may be recorded only as
   `observed` or `not observed`.
3. Open the tray context menu and select `Quit Tokeni Bar`.
4. Confirm the tray icon disappears, the process exits within ten seconds, and no error
   dialog remains.
5. Launch and quit again to confirm the previous exit did not damage the portable
   directory or leave stale process state.

### TRAY-01 — dashboard and tray controls

1. Left-click the tray icon. Confirm one modeless dashboard opens and receives focus.
2. Close or hide the dashboard using its normal close control. Confirm the tray process
   remains active.
3. Left-click again. Confirm the same dashboard behavior returns without a duplicate
   window or duplicate tray icon.
4. Right-click the tray icon. Confirm the context menu opens, can be dismissed, and does
   not block the dashboard.
5. Select `Refresh now`. Confirm the UI enters and leaves its refresh state without
   freezing, duplicating windows, or fabricating unavailable values.
6. Repeat left-click and refresh once while the dashboard is already open.

Do not record displayed usage values. Record only state transitions and responsiveness.

### EXP-01/02/03 — manual Explorer restart recovery

Run all three cases in separate clean app launches:

- `EXP-01`: launch Tokeni Bar but never open the dashboard.
- `EXP-02`: open the dashboard once, then hide/close it while the app remains running.
- `EXP-03`: leave the dashboard visible and focused.

For each state:

1. Confirm exactly one Tokeni Bar process and tray icon before the action.
2. Open Task Manager, select `Windows Explorer`, and use Task Manager's manual `Restart`
   action. Do not run a script or command that terminates Explorer.
3. Wait for the taskbar and notification area to return.
4. Confirm the Tokeni Bar tray icon returns without restarting Tokeni Bar and no duplicate
   icon or process appears.
5. Left-click and right-click the recovered icon. Confirm the dashboard can open/focus and
   the context menu works.
6. For `EXP-02`, confirm the dashboard remains hidden until requested. For `EXP-03`, record
   whether the visible dashboard remains visible and usable through recovery.
7. Quit normally and confirm clean process termination.

Any missing/duplicate icon, inaccessible menu, duplicate dashboard, crash, or changed
visibility state is a failure and requires an issue link.

### DPI-01 — single-monitor scale

Repeat at 100%, 150%, and 200%. Apply the Windows display setting using the supported OS
flow, then start a fresh Tokeni Bar process.

1. Open the dashboard from the tray at the tested scale.
2. Confirm text, icons, controls, focus indicators, and borders are sharp and not clipped.
3. Confirm the dashboard is fully inside the work area and can be moved to every edge.
4. Hide and reopen it; confirm size and hit targets remain usable.
5. Open the tray context menu and confirm its anchor and selection targets are correct.
6. If the companion overlay is enabled for this candidate, verify only geometry,
   click-through, and rendering; do not capture provider or usage content.

Record the scale and resolution, plus sanitized defect measurements if failed.

### DPI-02 — mixed-DPI and multi-monitor movement

Use at least two monitors with different scales, preferably one at 100% and one at 150%
or 200%. Include a layout where a secondary monitor is left of or above the primary so
the virtual desktop has negative coordinates.

1. Launch on the primary monitor and open the dashboard.
2. Move the dashboard slowly across each monitor boundary and fully onto every monitor.
3. Confirm it rescales once per boundary, stays sharp, preserves usable dimensions, and
   never jumps off-screen or becomes unreachable.
4. Hide/reopen from a tray located on each available taskbar configuration.
5. Disconnect/reconnect a secondary display or change the primary display if the device
   safely supports it. Confirm the dashboard remains reachable in a valid work area.
6. Repeat context-menu and normal-exit checks after movement.

Record generic monitor labels, resolution, scale, and relative arrangement only.

### A11Y-01/02 — keyboard and accessibility

1. Without a mouse, use `Win+B` and arrow keys to reach the Tokeni Bar tray icon. Use
   `Enter` and the keyboard context-menu command to open the dashboard and tray menu.
2. In the dashboard, use `Tab` and `Shift+Tab` through all interactive controls. Confirm
   a visible focus indicator, logical order, no trap, and keyboard activation.
3. Confirm standard close/hide and reopen flows work without a pointer.
4. With Narrator or the approved accessibility inspector, check that the dashboard,
   provider rows, refresh control, and tray menu expose meaningful names, roles, states,
   and enabled/disabled status.
5. At 200% text/display scale and an approved high-contrast theme, confirm important
   controls remain visible and distinguishable.

Record only missing labels/roles and navigation behavior. Do not record spoken or visible
provider values.

### SQL-01 — packaged SQLite with provider unavailable

Use a clean test profile with no Antigravity conversation database. Do not remove an
existing database to create this condition.

1. Confirm `Tools\sqlite3.exe` matches the hash in `Tools\sqlite-tools.json`.
2. Record whether `where.exe sqlite3` finds another executable. The preferred matrix has
   no PATH result; do not modify a user's PATH to achieve it.
3. Launch Tokeni Bar and refresh.
4. Confirm the database-backed provider reports an unavailable state, exposes no
   fabricated quota/cost/usage value, and does not crash or request credentials.
5. Confirm the app remains responsive and exits normally.

### SQL-02 — packaged SQLite with provider available

Use only an approved provider test account/profile containing sanitized test activity.
Never copy its database, prompts, responses, or values into evidence.

1. Confirm the packaged executable hash as in `SQL-01` and prefer a device where
   `where.exe sqlite3` has no PATH result.
2. Start the approved provider normally and create only pre-approved non-sensitive test
   activity. Close it or leave it in the state required by the locking test plan.
3. Launch Tokeni Bar and refresh.
4. Confirm the provider reaches `available` and the dashboard remains responsive. Record
   only `available state shown; values not recorded`.
5. Refresh while the provider is closed, then while it is running if safe. A database
   lock must result in a truthful unavailable/stale/failure state rather than fabricated
   values or a crash.
6. Exit Tokeni Bar normally and confirm the provider database remains usable by its owner.

Mark `Blocked` if an approved sanitized provider profile is unavailable.

## Case result and issue template

Copy this block once per case:

```text
Case ID:
Result: Pass / Fail / Blocked / N/A
Artifact SHA-256:
Device alias and OS build:
Display/input configuration:
Start state:
Observed state transitions (no values or identifiers):
Evidence: sanitized text / allowed OS-setting crop / none
Issue: owner/repository#number, or `none` for Pass
Blocker and owner (Blocked only):
Retest artifact/commit and result:
Notes (privacy-reviewed):
```

For a failure, the linked issue must include the case ID, expected versus observed state,
reproduction frequency, target OS/build, display configuration, and the first known bad
artifact if available. Apply the same privacy rules to the issue.

## Completion gate

Physical-device validation is complete only when:

- every required case has `Pass`, or an explicitly accepted `N/A` with rationale;
- every `Fail` has an issue and release disposition;
- every `Blocked` has an owner and is not represented as coverage;
- artifact hash, source commit, target OS/build, architecture, display matrix, and input
  matrix are recorded;
- the evidence has been reviewed for prohibited content; and
- the completed record is linked from the coordinating PR or release issue.

Do not use this runbook as authorization to publish a release. The repository release
workflow and its required main-branch CI remain separate gates.
