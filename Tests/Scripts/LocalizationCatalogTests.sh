#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VALIDATOR="$ROOT/Scripts/validate_localizations.sh"

"$VALIDATOR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

expect_failure() {
    if "$VALIDATOR" "$1" "$2" >/dev/null 2>&1; then
        echo "Expected localization validation to fail." >&2
        exit 1
    fi
}

printf '%s\n' '"one" = "Value %d";' > "$TMP_DIR/en.strings"
printf '%s\n' '"one" = "값 %d";' > "$TMP_DIR/ko.strings"
"$VALIDATOR" "$TMP_DIR/en.strings" "$TMP_DIR/ko.strings" >/dev/null

printf '%s\n' '"one" = "Value %d";' '"one" = "Again %d";' \
    > "$TMP_DIR/duplicate.strings"
expect_failure "$TMP_DIR/duplicate.strings" "$TMP_DIR/ko.strings"

printf '%s\n' '"two" = "값 %d";' > "$TMP_DIR/missing.strings"
expect_failure "$TMP_DIR/en.strings" "$TMP_DIR/missing.strings"

printf '%s\n' '"one" = "값 %@";' > "$TMP_DIR/format.strings"
expect_failure "$TMP_DIR/en.strings" "$TMP_DIR/format.strings"

echo "Localization catalog validator tests passed"
