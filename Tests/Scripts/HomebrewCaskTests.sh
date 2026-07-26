#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agents-status-cask-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

VERSION="0.5.1"
SHA256="968d7845bef67db6d185822ffe588c7cede5c4049f61d076fc308f72e2ee5032"
OUTPUT="$TEST_ROOT/Casks/agents-status-bar.rb"

"$ROOT/Scripts/render_homebrew_cask.sh" "$VERSION" "$SHA256" "$OUTPUT"

grep -q "version \"$VERSION\"" "$OUTPUT"
grep -q "sha256 \"$SHA256\"" "$OUTPUT"
grep -q "releases/download/v#{version}/AgentsStatusBar-#{version}.zip" "$OUTPUT"
if grep -q '__VERSION__\|__SHA256__' "$OUTPUT"; then
    echo "Cask placeholders were not fully rendered" >&2
    exit 1
fi
diff -u "$ROOT/Casks/agents-status-bar.rb" "$OUTPUT"

if "$ROOT/Scripts/render_homebrew_cask.sh" "not-a-version" "$SHA256" "$OUTPUT"; then
    echo "Invalid version unexpectedly succeeded" >&2
    exit 1
fi
if "$ROOT/Scripts/render_homebrew_cask.sh" "$VERSION" "bad-sha" "$OUTPUT"; then
    echo "Invalid SHA unexpectedly succeeded" >&2
    exit 1
fi

echo "Homebrew Cask renderer tests passed"
