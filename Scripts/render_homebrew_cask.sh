#!/bin/bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
    echo "Usage: $0 <version> <release-zip-sha256> <output-file>" >&2
    exit 2
fi

VERSION="$1"
SHA256="$2"
OUTPUT_FILE="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/packaging/homebrew/agents-status-bar.rb.template"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid semantic version: $VERSION" >&2
    exit 2
fi
if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Invalid SHA-256: $SHA256" >&2
    exit 2
fi
if [[ "$OUTPUT_FILE" == "$TEMPLATE" ]]; then
    echo "Refusing to overwrite the Cask template" >&2
    exit 2
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
sed \
    -e "s/__VERSION__/$VERSION/g" \
    -e "s/__SHA256__/$SHA256/g" \
    "$TEMPLATE" > "$OUTPUT_FILE"

echo "Rendered Homebrew Cask: $OUTPUT_FILE"
