#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tokeni-formula-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

VERSION="0.6.0"
SHA256="4c2f8789e5ea52ed8bf5d0b82839e118afb0818125690b8e83cbf2c9a0278475"
OUTPUT="$TEST_ROOT/Formula/tokeni-bar.rb"

"$ROOT/Scripts/render_homebrew_formula.sh" "$VERSION" "$SHA256" "$OUTPUT"

grep -q "v$VERSION.tar.gz" "$OUTPUT"
grep -q "sha256 \"$SHA256\"" "$OUTPUT"
grep -q 'bin.install "Scripts/tokeni-bar"' "$OUTPUT"
if grep -q '__VERSION__\|__SHA256__' "$OUTPUT"; then
    echo "Formula placeholders were not fully rendered" >&2
    exit 1
fi
diff -u "$ROOT/Formula/tokeni-bar.rb" "$OUTPUT"

if "$ROOT/Scripts/render_homebrew_formula.sh" "not-a-version" "$SHA256" "$OUTPUT"; then
    echo "Invalid version unexpectedly succeeded" >&2
    exit 1
fi
if "$ROOT/Scripts/render_homebrew_formula.sh" "$VERSION" "bad-sha" "$OUTPUT"; then
    echo "Invalid SHA unexpectedly succeeded" >&2
    exit 1
fi

FAKE_APP="$TEST_ROOT/Cellar/tokeni-bar/$VERSION/libexec/Tokeni Bar.app"
mkdir -p "$FAKE_APP/Contents/MacOS"
touch "$FAKE_APP/Contents/MacOS/TokeniBar"
chmod +x "$FAKE_APP/Contents/MacOS/TokeniBar"
TOKENI_APP_PATH="$FAKE_APP" \
TOKENI_APPLICATIONS_DIR="$TEST_ROOT/Applications" \
    "$ROOT/Scripts/tokeni-bar" --install-app
test "$(readlink "$TEST_ROOT/Applications/Tokeni Bar.app")" = "$FAKE_APP"
TOKENI_APP_PATH="$FAKE_APP" \
TOKENI_APPLICATIONS_DIR="$TEST_ROOT/Applications" \
    "$ROOT/Scripts/tokeni-bar" --uninstall-app
test ! -e "$TEST_ROOT/Applications/Tokeni Bar.app"

echo "Homebrew Formula and launcher tests passed"
