#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGLISH="${1:-$ROOT/Sources/TokeniBar/Resources/en.lproj/Localizable.strings}"
KOREAN="${2:-$ROOT/Sources/TokeniBar/Resources/ko.lproj/Localizable.strings}"

fail() {
    echo "Localization validation failed: $*" >&2
    exit 1
}

for catalog in "$ENGLISH" "$KOREAN"; do
    [[ -f "$catalog" ]] || fail "catalog not found: $catalog"
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

extract_catalog() {
    local catalog="$1"
    local prefix="$2"
    awk -v keys="$TMP_DIR/$prefix.keys" \
        -v formats="$TMP_DIR/$prefix.formats" '
        function placeholders(value, result, i, j, k, c, token, count, allPositioned, swap) {
            result = ""
            count = 0
            allPositioned = 1
            for (i = 1; i <= length(value); i++) {
                if (substr(value, i, 1) != "%") continue
                if (substr(value, i + 1, 1) == "%") {
                    i++
                    continue
                }
                # Standalone percentages in prose are followed by whitespace.
                if (substr(value, i + 1, 1) ~ /[[:space:]]/) continue
                token = "%"
                for (j = i + 1; j <= length(value); j++) {
                    c = substr(value, j, 1)
                    token = token c
                    if (c ~ /[@diuoxXfFeEgGaAcCsSp]/) {
                        tokens[++count] = token
                        if (token !~ /^%[0-9]+\$/) allPositioned = 0
                        i = j
                        break
                    }
                    if (c !~ /[0-9$+# .lhLzjtq*-]/) break
                }
            }
            if (allPositioned) {
                for (i = 1; i <= count; i++) {
                    for (j = i + 1; j <= count; j++) {
                        if (tokens[i] > tokens[j]) {
                            swap = tokens[i]
                            tokens[i] = tokens[j]
                            tokens[j] = swap
                        }
                    }
                }
            }
            for (k = 1; k <= count; k++) {
                result = result (result == "" ? "" : ",") tokens[k]
                delete tokens[k]
            }
            return result
        }
        /^[[:space:]]*"[^"]+"[[:space:]]*=/ {
            line = $0
            sub(/^[[:space:]]*"/, "", line)
            key = line
            sub(/".*/, "", key)
            counts[key]++
            print key >> keys
            value = $0
            sub(/^[^=]*=[[:space:]]*"/, "", value)
            sub(/";[[:space:]]*$/, "", value)
            print key "\t" placeholders(value) >> formats
        }
        END {
            for (key in counts) {
                if (counts[key] > 1) {
                    print key > "/dev/stderr"
                    duplicate = 1
                }
            }
            if (duplicate) exit 2
        }
    ' "$catalog" || fail "duplicate key in $catalog"
    LC_ALL=C sort -o "$TMP_DIR/$prefix.keys" "$TMP_DIR/$prefix.keys"
    LC_ALL=C sort -o "$TMP_DIR/$prefix.formats" "$TMP_DIR/$prefix.formats"
}

extract_catalog "$ENGLISH" en
extract_catalog "$KOREAN" ko

if ! diff -u "$TMP_DIR/en.keys" "$TMP_DIR/ko.keys"; then
    fail "English and Korean key sets differ"
fi

if ! diff -u "$TMP_DIR/en.formats" "$TMP_DIR/ko.formats"; then
    fail "English and Korean format placeholders differ"
fi

echo "Validated $(wc -l < "$TMP_DIR/en.keys" | tr -d ' ') bilingual localization keys."
