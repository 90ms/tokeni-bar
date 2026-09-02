# Tokeni standalone pet application plan

[한국어](STANDALONE_PET_APP_PLAN.ko.md) | **English**

- Plan version: 1.0
- Created: 2026-09-02
- Status: in progress

## Progress

| Stage | Status | Result |
| --- | --- | --- |
| 0. Lock decisions | Complete | Added the bilingual plan and documentation index |
| 1. Standalone shell | Complete | Added Home, Pets, Usage, Settings link, summary-focused menu bar, and passed macOS CI |
| 2–5 | Pending | Continue with the dynamic-content foundation |

Changes authored in Docker use GitHub Actions as the macOS gate. `swift test`,
the release build, app packaging, and bundle metadata validation must pass
before the next stage uses a commit as its baseline.

This document defines the product structure, UX ownership, data boundaries, and
staged commit plan for expanding Tokeni from a menu-bar-centered utility into a
pet application with a standalone window.

## 1. Product core to preserve

Tokeni truthfully presents AI-agent usage and turns verified cumulative token
observations into pet growth. The following rules remain invariant:

- Growth XP comes only from verified cumulative token increases.
- Active time affects behavior and animation but cannot create growth.
- Unverifiable quota, cost, and growth values are never estimated.
- Pet state contains no provider names, raw token totals, prompts, responses, or credentials.
- The menu bar, main window, and desktop pet share one application state.
- Appearances, rarities, and external packs provide no growth multiplier or power advantage.

## 2. One owner for every feature

The same setting or management action must not be repeated across surfaces.

| Surface | Owns | Does not contain |
| --- | --- | --- |
| Menu bar | Current summary, refresh, caffeine, open main window, settings and quit entry points | Collection, egg shop, detailed settings, long usage lists |
| Home | Primary pet, growth target, today's usage state, and the next useful action | Full collection editing and every provider setting |
| Pets | Roster, growth target, primary pet, eggs, collection, cosmetics, and packs | Provider quota settings |
| Usage | Provider status, cost, history, and data freshness | Pet-management actions |
| macOS Settings window | Providers, display, notifications, caffeine, login item, and advanced options | Collection and roster management |
| Desktop pet | Primary-pet reactions and brief status | Persistent settings and economy actions |

When an action leaves the menu bar, it links to its exact main-window destination.
The main window does not duplicate menu-bar-only quick controls.

## 3. Main-window information architecture

The main window uses a macOS `NavigationSplitView`.

```text
Tokeni
├── Home
├── Pets
│   ├── Companion
│   ├── Roster
│   ├── Eggs
│   ├── Collection
│   ├── Cosmetics
│   └── Pet packs
├── Usage
└── Settings → open the macOS Settings window
```

The first stage safely relocates current screens. Later stages split the long
pet view into the destinations above. Every action has one canonical home.

### Home priority

1. Primary pet and current behavior
2. Growth target and next level or evolution
3. Usage freshness and refresh state
4. Available actions such as evolution, hatching, or rewards
5. Caffeine state and quick toggle

Home is not a dashboard that repeats every value. Detailed information links to
its owning destination.

## 4. Pet concepts and asset layers

Game instances and artwork packs are separate concepts.

- `CompanionInstance`: a game entity with UUID, Growth XP, stage, appearance, name, personality, and memories
- `CompanionDefinition`: stable species ID, presentation metadata, and supported capabilities
- `CompanionAssetPack`: animation frames plus source and license metadata
- `CompanionAssetSource`: bundled with the app or locally imported by the user
- `CompanionRoleSelection`: primary pet, growth target, and showcase selections

Species IDs become string-backed value objects. Built-in species remain static
constants, while external packs can register without rebuilding the app. Only
reviewed built-in species participate in egg odds and content-generation rules;
external packs do not change game probabilities by default.

## 5. External pet-pack policy

### Supported modes

- `Tokeni Native`: supplies Hatchling, Junior, and Adult art plus Tokeni behaviors and appearances
- `Codex Compatible`: uses a Codex Pets V1/V2 single-character animation as an appearance

Codex-compatible missing states use this fallback order:

| Tokeni behavior | Codex state | Fallback |
| --- | --- | --- |
| Idle | Idle | First valid frame |
| Working | Review | Running, Idle |
| Waiting | Waiting | Idle |
| Warning | Failed | Idle |
| Celebrate | Waving | Jumping, Idle |
| Signature | Waving | Idle |
| Sleep | None | Static Idle frame |

Because a Codex-compatible pack has no lifecycle art, it is presented as an
`external appearance` shared by all growth stages. Promotion to a full species
requires the Tokeni Native contract and review.

### Import safety

- The first release imports only a local `.codex-pet.zip` selected by the user.
- Core growth and startup never depend on an unstable remote gallery API.
- File count, compressed and expanded size, path traversal, and symlinks are checked before extraction.
- Executables and scripts are rejected; only `pet.json` and `spritesheet.webp` are accepted.
- V1 `1536×1872`, V2 `1536×2288`, and manifest-version agreement are validated.
- Invalid packs are not installed and produce actionable validation errors.
- Installation validates in an Application Support staging directory before atomic replacement.
- Removal preserves the game pet and falls back to a bundled appearance.

### Rights and provenance

Availability for download does not imply permission to redistribute.

- External packs are not bundled with the application by default.
- Author, source URL, license identifier, and notice can be stored and displayed.
- Missing licenses are shown as `unspecified · local use`.
- Official packs require separate review of redistribution and derivative-work rights.
- Packs based on public figures, brands, or protected characters are not placed in the official catalog without permission.

## 6. Multiple-pet rules

- The `primary pet` appears on Home, in the menu bar, and as the desktop pet.
- Exactly one `growth target` receives newly verified Growth XP.
- Future `showcase pets` may share activity animations in a pet home but receive no duplicated XP.
- Primary and growth-target selections are independent.
- Existing safe rotation remains when a target reaches maximum level or is removed.
- One observation never grants the same growth to multiple pets.

## 7. State and lifecycle

`UsageStore` functionality is not copied per screen. Existing persistence and
coordinators remain during the transition, while thin presentation models isolate UI state.

- Startup does not depend on the menu-bar label appearing.
- Opening the main window and menu bar together still runs one refresh loop.
- Closing the window leaves the menu-bar service and desktop pet active until quit.
- A setting is written once and reflected immediately on every surface.
- Pet-pack metadata stores no usage or provider information.

## 8. Accessibility and performance

- VoiceOver reads pet name, role, stage, level, and available action in order.
- Sidebar, roster, import flow, and confirmation dialogs work with the keyboard.
- Reduce Motion and Low Power Mode use static frames and non-motion feedback.
- Large preview animations pause when their window is not visible.
- External sheets load lazily and retain current cache bounds and memory-pressure cleanup.
- Errors distinguish unavailable, stale, and corrupt states without fabricating values.

## 9. Staged commit plan

Each commit includes relevant tests and documentation and should build independently.
Every user-visible change adds a unique bilingual `.changes` fragment.

### Stage 0 — Lock decisions

1. `docs: plan standalone pet application`
   - Add this plan, its Korean counterpart, and the documentation index entry

### Stage 1 — Standalone shell and deduplication

2. `feat: add standalone application shell`
   - Main `WindowGroup`, stable window ID, and startup lifecycle
   - Home, Pets, and Usage sidebar plus a macOS Settings-window link
   - Navigation-selection and presentation tests
3. `refactor: focus menu bar on quick controls`
   - Limit the menu bar to summary, refresh, caffeine, open app, settings, and quit
   - Route collection and management actions to main-window destinations
   - Regression tests for duplicate actions and menu ownership
4. `docs: document application navigation`
   - Update Korean and English READMEs, usage docs, and screen flows

### Stage 2 — Dynamic content foundation

5. `refactor: introduce extensible companion identifiers`
   - String-backed species and pack IDs plus built-in constants
   - Lossless current-save decoding and round-trip tests
6. `feat: add companion definition registry`
   - Built-in definitions, game eligibility, and asset provenance
   - Remove direct UI dependence on `allCases`
7. `refactor: separate companion asset sources`
   - Bundled/imported loaders and a common render contract
   - Missing, corrupt, and memory-pressure tests

### Stage 3 — Local Codex-compatible imports

8. `feat: validate Codex-compatible pet packs`
   - Pure V1/V2 manifest, dimension, row, and frame validator
   - Sanitized valid and invalid fixture tests
9. `feat: install local companion asset packs`
   - Safe extraction, atomic installation, listing, and removal
   - Path-traversal, oversized-file, and corrupt-recovery tests
10. `feat: render imported companion packs`
    - Behavior mapping, non-square frame aspect ratio, fallbacks, and accessibility
11. `feat: add companion pack management`
    - File import, validation result, provenance/license, and removal UI
12. `docs: publish companion pack guide`
    - User import guide and creator-facing Tokeni Native/Codex-compatible contracts

### Stage 4 — Multiple-pet home

13. `feat: model companion display roles`
    - Primary, growth, and showcase roles plus persistence migration
    - Growth-deduplication and removal-fallback tests
14. `feat: add companion home experience`
    - Primary-pet-focused Home, actionable items, and detail links
15. `feat: add pet roster management`
    - Search, filters, role selection, and explicit destructive confirmation

### Stage 5 — Finish and release preparation

16. `refactor: consolidate application settings`
    - Remove duplicate settings and verify one owning surface per option
17. `fix: complete accessibility and power behavior`
    - VoiceOver, keyboard, Reduce Motion, Low Power Mode, and offscreen animations
18. `docs: finalize standalone application documentation`
    - Align policy version, READMEs, usage, pet, and packaging documentation
19. `test: verify standalone pet application release`
    - Full Swift test/build, packaged resources, and manual macOS checklist

Commits may split or combine to preserve testable boundaries, but the stage order
and ownership boundaries remain fixed.

## 10. Stage completion criteria

A stage is complete only when all conditions hold:

- Domain and UI tests for the stage pass.
- `swift test` and `swift build` pass.
- Korean and English user documentation matches behavior.
- Every user-visible change has a bilingual release fragment.
- Existing saved data opens without loss.
- Growth invariants and privacy boundaries remain intact.
- The same management function is not duplicated in the menu bar and main window.

Before release, manually verify clean install, upgrade, corrupt external packs,
external-pack removal, offline startup, and every-provider-unavailable states.
