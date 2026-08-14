#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
asset_root="$root/Sources/TokeniBar/CompanionAssets"
expected_species=(
    bytebot cachecat stackfox promptpup nullslime
    queryowl patchpanda loophare relayray kernelcrab
)
signature_ids=(
    bytebot.reassemble cachecat.data-chase stackfox.afterimage
    promptpup.command-trail nullslime.reform queryowl.signal-scan
    patchpanda.pixel-mend loophare.recursive-dash relayray.packet-wave
    kernelcrab.core-open
)
localizations=(
    "$root/Sources/TokeniBar/Resources/en.lproj/Localizable.strings"
    "$root/Sources/TokeniBar/Resources/ko.lproj/Localizable.strings"
)
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

fail() {
    echo "Companion asset validation failed: $*" >&2
    exit 1
}

manifest_count="$(find "$asset_root" -mindepth 2 -maxdepth 2 \
    -name manifest.json -type f | wc -l | tr -d ' ')"
[[ "$manifest_count" == "${#expected_species[@]}" ]] \
    || fail "expected ${#expected_species[@]} manifests, found $manifest_count"

for index in "${!expected_species[@]}"; do
    species="${expected_species[$index]}"
    signature_id="${signature_ids[$index]}"
    directory="$asset_root/$species"
    manifest="$directory/manifest.json"
    [[ -f "$manifest" ]] || fail "missing $species manifest"
    grep -q "\"id\": \"$species\"" "$manifest" \
        || fail "$species manifest has the wrong id"
    for behavior in idle working waiting warning celebrate signature sleep; do
        grep -q "\"$behavior\"" "$manifest" \
            || fail "$species manifest is missing $behavior"
    done

    referenced_files="$temporary_dir/$species-files.txt"
    sed -n 's/.*: "\([^"]*\.png\)".*/\1/p' "$manifest" \
        | sort -u > "$referenced_files"
    [[ -s "$referenced_files" ]] \
        || fail "$species manifest references no sprite sheets"
    reference_count="$(wc -l < "$referenced_files" | tr -d ' ')"
    expected_reference_count=12
    [[ "$species" == bytebot ]] && expected_reference_count=13
    [[ "$reference_count" == "$expected_reference_count" ]] \
        || fail "$species references $reference_count sprite sheets; expected $expected_reference_count"
    while IFS= read -r file_name; do
        sprite="$directory/$file_name"
        [[ -f "$sprite" ]] || fail "$species is missing $file_name"
        dimensions="$(od -An -tu1 -j 16 -N 8 "$sprite")"
        set -- $dimensions
        [[ "$#" == 8 ]] \
            || fail "$species/$file_name has an invalid PNG header"
        width=$((
            $1 * 16777216 + $2 * 65536 + $3 * 256 + $4))
        height=$((
            $5 * 16777216 + $6 * 65536 + $7 * 256 + $8))
        [[ "$width" == 512 && "$height" == 384 ]] \
            || fail "$species/$file_name is not a 512x384 PNG sheet"
    done < "$referenced_files"

    for localization in "${localizations[@]}"; do
        grep -q "\"companion.species.$species.name\"" "$localization" \
            || fail "$species name is missing from $(basename "$(dirname "$localization")")"
        grep -q "\"companion.species.$species.personality\"" "$localization" \
            || fail "$species description is missing from $(basename "$(dirname "$localization")")"
        grep -q "\"companion.specialAction.$signature_id\"" "$localization" \
            || fail "$signature_id is missing from $(basename "$(dirname "$localization")")"
    done
done

echo "Validated ${#expected_species[@]} companion asset, action, and localization sets."
