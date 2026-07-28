#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

while IFS= read -r workflow; do
    if grep -E '^[[:space:]]*uses:' "$workflow" \
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

echo "GitHub workflow security tests passed"
