---
name: localization
description: Use this skill when adding or updating localized UI strings to maintain Korean and English parity.
---

# Localization Management

Workflow for maintaining bilingual Korean (`ko`) and English (`en`) user interface strings in Tokeni Bar.

## When to Use

- Adding new UI labels, menu items, settings options, or alerts.
- Updating or refactoring existing localized strings.

## File Locations

- Korean: `Sources/TokeniBar/Resources/ko.lproj/Localizable.strings`
- English: `Sources/TokeniBar/Resources/en.lproj/Localizable.strings`

## Parity Rules

1. **Exact Key Matching**: Every localization key defined in `en.lproj` MUST exist in `ko.lproj`, and vice versa.
2. **Format Specifiers**: Ensure matching format specifiers (e.g., `%@`, `%lld`, `%d`) across both languages for the same key.
3. **Natural Tone**:
   - Korean strings should use polite, natural macOS tone (e.g., `~했습니다`, `~설정`).
   - English strings should use clear, concise, active macOS conventions.

## Validation Commands

Run the localization validator and catalog test suite:

```bash
# Validate that all bilingual localization keys match
./Scripts/validate_localizations.sh

# Run the localization catalog test script
./Tests/Scripts/LocalizationCatalogTests.sh
```
