# AI Agent Skills & Workflow Guide

Tokeni Bar standardizes AI coding assistant workflows across Claude Code, Codex CLI, and Antigravity CLI using an open, unified **`.agents/` specification**.

## 1. Architecture & Cross-CLI Compatibility

```text
tokeni-bar/
├── AGENTS.md                         # [SSOT] Project guidelines and normative rules for all agents
├── CLAUDE.md -> AGENTS.md            # Compatibility symlink for Claude Code
├── .agents/
│   └── skills/                       # Standardized Agent Skills directory
│       ├── release-fragment/         # Release note fragment (.changes/) management
│       ├── project-verify/           # Full test suite and lint verification
│       ├── add-provider/             # New AI provider adapter guide
│       ├── package-macos/            # macOS packaging and Homebrew distribution
│       ├── companion-assets/         # Pet sprite assets and manifest management
│       └── localization/             # Bilingual (ko/en) UI localization parity
└── .claude/
    └── skills -> ../.agents/skills   # Symlink for Claude Code skill discovery
```

### CLI Interoperability

- **Antigravity CLI**: Automatically discovers `AGENTS.md` and `.agents/skills/`. Descriptions in YAML frontmatter enable dynamic, on-demand loading (**Progressive Disclosure**) to preserve model context.
- **Codex CLI**: Natively reads `AGENTS.md` and discovers `.agents/skills/` for procedural runbooks.
- **Claude Code**: Discovers constraints and conventions via `CLAUDE.md` (symlinked to `AGENTS.md`) and accesses skill runbooks through `.claude/skills`.

---

## 2. Core Skills Catalog

### 1. `release-fragment`
- **Path**: `.agents/skills/release-fragment/SKILL.md`
- **Purpose**: Create and validate bilingual `.changes/` fragments for any user-facing product, UI, CLI, or packaging changes.
- **Validation**:
  ```bash
  ./Scripts/validate_release_notes.sh fragment .changes/<file>.md
  ./Scripts/validate_release_notes.sh all
  ```

### 2. `project-verify`
- **Path**: `.agents/skills/project-verify/SKILL.md`
- **Purpose**: Comprehensive verification runbook covering builds, unit tests, script test runners, localization parity, companion assets, and release note linting.
- **Validation**:
  ```bash
  # SwiftPM build & test (native Swift environment)
  swift test && swift build
  # Script tests
  ./Tests/Scripts/ReleaseNotesTests.sh
  ./Tests/Scripts/HomebrewCaskTests.sh
  ./Tests/Scripts/HomebrewFormulaTests.sh
  ./Tests/Scripts/LocalizationCatalogTests.sh
  ./Tests/Scripts/GitHubWorkflowTests.sh
  # Localizations and assets
  ./Scripts/validate_localizations.sh
  ./Scripts/validate_companion_assets.sh
  # Release notes
  ./Scripts/validate_release_notes.sh all
  ```

### 3. `add-provider`
- **Path**: `.agents/skills/add-provider/SKILL.md`
- **Purpose**: Implement or update AI provider usage scanners (Claude, Codex, Gemini, Antigravity, etc.).
- **Key Rules**:
  - Keep parsers isolated in `Sources/TokeniCore/Providers/<Name>/`.
  - Register in `ProviderRegistry.defaultProviders()`; do not add provider switches to shared UI.
  - Never log or persist credentials, tokens, cookies, prompts, or responses.
  - Provide sanitized test fixtures in `Tests/TokeniCoreTests/Fixtures/`.

### 4. `package-macos`
- **Path**: `.agents/skills/package-macos/SKILL.md`
- **Purpose**: Build `TokeniBar.app` bundles, execute package smoke tests, and render Homebrew Cask and Formula recipes.
- **Key Commands**:
  ```bash
  ./Scripts/package_app.sh
  ./Scripts/smoke_macos_package.sh
  ./Scripts/render_homebrew_formula.sh <version> <sha256> Formula/tokeni-bar.rb
  ./Scripts/render_homebrew_cask.sh <version> <sha256> Casks/tokeni-bar.rb
  ```

### 5. `companion-assets`
- **Path**: `.agents/skills/companion-assets/SKILL.md`
- **Purpose**: Validate, generate, and maintain pet sprite assets, palette mutations, and companion pack manifests.
- **Key Rules**:
  - Growth derives strictly from verified cumulative tokens (600,000 tokens = 1 XP).
  - Companion state must not contain provider names, token totals, prompts, or response content.
- **Key Commands**:
  ```bash
  ./Scripts/validate_companion_assets.sh
  ./Scripts/generate_companion_species_assets.sh
  ```

### 6. `localization`
- **Path**: `.agents/skills/localization/SKILL.md`
- **Purpose**: Maintain exact 1:1 key parity between Korean (`ko.lproj`) and English (`en.lproj`) string catalogs.
- **Validation**:
  ```bash
  ./Scripts/validate_localizations.sh
  ./Tests/Scripts/LocalizationCatalogTests.sh
  ```

### 7. `prepare-pr`
- **Path**: `.agents/skills/prepare-pr/SKILL.md`
- **Purpose**: Branch isolation checks, release fragment validation, pre-PR gate verification, and structured PR generation via GitHub CLI (`gh pr create`).
- **Key Commands**:
  ```bash
  ./Scripts/validate_release_notes.sh changed origin/main HEAD
  gh pr create --title "<type>: <description>" --body "<structured body>"
  ```

### 8. `release-deploy`
- **Path**: `.agents/skills/release-deploy/SKILL.md`
- **Purpose**: Complete release lifecycle: annotated git tagging on main, release notes rendering, GitHub Release monitoring, and Homebrew tap PR merge.
- **Key Commands**:
  ```bash
  ./Scripts/render_release_notes.sh <version> dist/release-notes.md
  ./Scripts/validate_release_notes.sh release <version> dist/release-notes.md
  git tag -a v<version> -m "Tokeni Bar <version>" HEAD
  git push origin v<version>
  ```

---


## 3. Adding New Skills

To add a new skill to the repository:

1. Create a subdirectory under `.agents/skills/<skill-name>/` (lowercase, hyphenated).
2. Create `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: <skill-name>
   description: Describe what the skill does and when the agent should use it (written in 3rd person).
   ---
   ```
3. Provide step-by-step terminal commands, prerequisites, and explicit verification steps.
4. Keep the main `SKILL.md` concise. Place reference manuals or bulky documentation under `references/` for progressive disclosure.
