---
name: release-fragment
description: Use this skill whenever adding, updating, or validating user-visible release-note fragments in .changes/.
---

# Release Note Fragment Management

Create and validate bilingual release note fragments required for any user-facing product, UI, CLI, or packaging change.

## When to Use

- Every user-visible source, UI, CLI, or packaging change (`Sources/*`, `Package.swift`, `packaging/*`).
- Do NOT use for internal refactoring, test-only updates, or internal scripts unless accompanied by a user-facing change.

## Rules & Constraints

1. **Immutability**: Never edit or delete an already-released fragment. The release renderer selects only fragments added or modified after the previous semantic-version tag.
2. **Confidentiality & Cleanliness**:
   - Write concise user-facing Korean and English summaries.
   - Do NOT copy commit messages, internal implementation details, secrets, paths, prompts, responses, or raw token totals into release notes.
3. **Naming**:
   - File format: `.changes/YYYYMMDD-lowercase-slug.md` (e.g., `.changes/20260910-unified-agent-skills.md`).
   - Use current UTC/local date and lowercase hyphenated words.

## Fragment Format

Each fragment uses a strict one-line key-value format:

```text
category: improvement
scope: companion
breaking: false
ko: 펫 성장 속도와 레벨 진행을 개선했습니다.
en: Improved pet growth speed and level progression.
```

### Allowed Categories
- `feature`
- `improvement`
- `fix`
- `performance`
- `migration`
- `security`

### Scope
- Lowercase alphanumeric string with hyphens (e.g., `companion`, `provider`, `menubar`, `packaging`, `settings`, `documentation`).

### Breaking Changes
- Set `breaking: true` ONLY when users must take explicit action upon updating.
- If `breaking: true`, you MUST include both `action_ko` and `action_en`:
  ```text
  breaking: true
  action_ko: 업데이트 후 다시 로그인해야 합니다.
  action_en: Sign in again after updating.
  ```

## Verification

After creating or modifying a fragment, always validate it using:

```bash
# Validate the specific fragment
./Scripts/validate_release_notes.sh fragment .changes/YYYYMMDD-lowercase-slug.md

# Validate all fragments in repository
./Scripts/validate_release_notes.sh all
```
