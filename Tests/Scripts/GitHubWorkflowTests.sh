#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

while IFS= read -r workflow; do
    if grep -E '^[[:space:]]*uses:' "$workflow" \
        | grep -Ev 'uses:[[:space:]]+\./' \
        | grep -Ev '@[0-9a-f]{40}([[:space:]]+#.*)?$' >/dev/null
    then
        echo "Workflow actions must be pinned to full commit SHAs: $workflow" >&2
        exit 1
    fi
done < <(find "$ROOT/.github/workflows" -type f -name '*.yml' -print)

release="$ROOT/.github/workflows/release.yml"
grep -q 'attestations: write' "$release"
grep -q 'id-token: write' "$release"
grep -q 'uses: actions/attest@f7c74d28b9d84cb8768d0b8ca14a4bac6ef463e6' "$release"
grep -q 'subject-path: dist/TokeniBar-${{ steps.version.outputs.value }}.zip' "$release"
grep -q 'workflow_dispatch:' "$release"
grep -q 'APP_SIGN_IDENTITY: "-"' "$release"
grep -q 'Scripts/render_release_notes.sh' "$release"
grep -q -- '--notes-file "dist/release-notes.md"' "$release"
grep -q 'ad-hoc signed' "$ROOT/Scripts/render_release_notes.sh"
if grep -q -- '--generate-notes' "$release"; then
    echo "GitHub releases must use the validated structured notes file" >&2
    exit 1
fi
if grep -Eq 'notarytool|CERTIFICATE_P12_BASE64|DEVELOPER_ID_APPLICATION' "$release"; then
    echo "GitHub releases must not require Apple signing or notarization" >&2
    exit 1
fi

echo "GitHub workflow security tests passed"
