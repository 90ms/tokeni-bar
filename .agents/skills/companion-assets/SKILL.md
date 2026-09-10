---
name: companion-assets
description: Use this skill to generate, validate, and manage companion pet sprite assets, palettes, and manifests.
---

# Companion Assets & Manifest Management

Procedures for managing companion pet sprites, species palettes, animation frames, and companion pack manifests.

## When to Use

- Adding or updating companion pet sprite frames or animations.
- Generating species palette variants or generation-two assets.
- Modifying `Scripts/companion-manifest.template.json` or companion asset packs.

## Core Rules & Normative Policies

1. **Growth Independence**: Growth is provider-neutral and derives only from verified cumulative token observations (600,000 verified tokens = 1 Growth XP). Active minutes may drive animations, but never growth.
2. **State Isolation**: Companion state must NEVER contain provider names, token totals, prompts, or response content.
3. **Supported Cosmetic Slots**: Aura, Background, Palette, Ground, Sidekick, Frame, Scene.

## Verification & Generation Commands

### 1. Validate Existing Assets

Verifies all companion asset sets, action frame counts, species manifests, and bilingual localizations:

```bash
./Scripts/validate_companion_assets.sh
```

### 2. Generate Companion Assets

Use the project generation scripts to produce consistent pixel-art sprite sets:

```bash
# Generate base bytebot companion assets
./Scripts/generate_bytebot_assets.sh

# Generate species palette variations
./Scripts/generate_companion_species_assets.sh

# Generate generation-two companion assets
./Scripts/generate_generation_two_assets.sh
```

### 3. Check Windows Companion Asset Compatibility

When changing companion formats, ensure Windows compatibility:

```bash
# PowerShell script for Windows validation
pwsh ./Scripts/validate_windows_companion_assets.ps1
```
