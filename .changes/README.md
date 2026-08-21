# Release-note fragments

Every user-visible product change must add one Markdown file to this directory.
Keep released fragments as immutable history: the release renderer selects only
files added or modified after the previous semantic-version tag.

Use a unique lowercase filename such as `20260804-companion-levels.md` and the
following one-line field format:

```text
category: improvement
scope: companion
breaking: false
ko: 펫 성장 속도와 레벨 진행을 개선했습니다.
en: Improved pet growth speed and level progression.
```

Allowed categories are:

- `feature`
- `improvement`
- `fix`
- `performance`
- `migration`
- `security`

`scope` must contain lowercase letters, numbers, and hyphens. Set `breaking` to
`true` only when users must take action, and then add both fields below:

```text
action_ko: 업데이트 후 다시 로그인해야 합니다.
action_en: Sign in again after updating.
```

Keep each Korean and English summary concise and user-facing. Do not include
credentials, paths, raw token totals, prompts, responses, internal stack traces,
or commit-only implementation details.

If a release workflow fails before publishing after its tag has been pushed, do
not move the tag or modify its fragments. For the next patch version, copy each
unpublished fragment into a uniquely named carry-forward fragment, add the new
fix fragments, then render and review the complete bilingual notes before tagging.
