#!/bin/bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
project_dir=$(cd "$script_dir/.." && pwd)
changes_dir="$project_dir/.changes"

fail() {
    echo "Release-note validation failed: $*" >&2
    exit 1
}

field_value() {
    local field="$1"
    local file="$2"
    awk -v prefix="$field: " '
        index($0, prefix) == 1 {
            count += 1
            value = substr($0, length(prefix) + 1)
        }
        END {
            if (count != 1 || value == "") {
                exit 1
            }
            print value
        }
    ' "$file"
}

optional_field_value() {
    local field="$1"
    local file="$2"
    awk -v prefix="$field: " '
        index($0, prefix) == 1 {
            count += 1
            value = substr($0, length(prefix) + 1)
        }
        END {
            if (count > 1) {
                exit 1
            }
            if (count == 1) {
                print value
            }
        }
    ' "$file"
}

validate_fragment() {
    local file="$1"
    [[ -f "$file" ]] || fail "fragment not found: $file"
    [[ "$(basename "$file")" =~ ^[0-9]{8}-[a-z0-9][a-z0-9-]*\.md$ ]] \
        || fail "fragment filename must be YYYYMMDD-lowercase-slug.md: $file"

    local category scope breaking ko en action_ko action_en
    category=$(field_value category "$file") \
        || fail "category must appear exactly once in $file"
    scope=$(field_value scope "$file") \
        || fail "scope must appear exactly once in $file"
    breaking=$(field_value breaking "$file") \
        || fail "breaking must appear exactly once in $file"
    ko=$(field_value ko "$file") \
        || fail "ko must appear exactly once in $file"
    en=$(field_value en "$file") \
        || fail "en must appear exactly once in $file"
    action_ko=$(optional_field_value action_ko "$file") \
        || fail "action_ko appears more than once in $file"
    action_en=$(optional_field_value action_en "$file") \
        || fail "action_en appears more than once in $file"

    case "$category" in
        feature|improvement|fix|performance|migration|security) ;;
        *) fail "unsupported category '$category' in $file" ;;
    esac
    [[ "$scope" =~ ^[a-z0-9][a-z0-9-]*$ ]] \
        || fail "invalid scope '$scope' in $file"
    [[ "$breaking" == "true" || "$breaking" == "false" ]] \
        || fail "breaking must be true or false in $file"
    [[ "$ko" != *TODO* && "$ko" != *TBD* && "$en" != *TODO* && "$en" != *TBD* ]] \
        || fail "placeholder text is not allowed in $file"
    if [[ -z "$action_ko" && -n "$action_en" ]] \
        || [[ -n "$action_ko" && -z "$action_en" ]]
    then
        fail "action_ko and action_en must be provided together in $file"
    fi
    if [[ "$breaking" == "true" ]]; then
        [[ -n "$action_ko" && -n "$action_en" ]] \
            || fail "breaking fragments require Korean and English actions: $file"
    fi

    local unknown_fields
    unknown_fields=$(awk -F ': ' '
        /^[a-z_]+: / && $1 !~ /^(category|scope|breaking|ko|en|action_ko|action_en)$/ {
            print $1
        }
    ' "$file")
    [[ -z "$unknown_fields" ]] \
        || fail "unknown fields in $file: $unknown_fields"
}

validate_all() {
    local found=false
    local file
    for file in "$changes_dir"/*.md; do
        [[ -e "$file" ]] || continue
        [[ "$(basename "$file")" == "README.md" ]] && continue
        found=true
        validate_fragment "$file"
    done
    [[ "$found" == "true" ]] || fail "no release-note fragments found"
}

validate_changed() {
    local base_sha="$1"
    local head_sha="$2"
    if [[ -z "$base_sha" || "$base_sha" =~ ^0+$ ]]; then
        echo "Release-note change check skipped because no base commit is available."
        return
    fi
    git -C "$project_dir" rev-parse --verify "$base_sha^{commit}" >/dev/null \
        || fail "base commit is unavailable: $base_sha"
    git -C "$project_dir" rev-parse --verify "$head_sha^{commit}" >/dev/null \
        || fail "head commit is unavailable: $head_sha"

    local changed_files
    changed_files=$(git -C "$project_dir" diff --name-only \
        "$base_sha...$head_sha")
    local product_changed=false
    local fragment_changed=false
    local path
    while IFS= read -r path; do
        case "$path" in
            Sources/*|Package.swift|packaging/*) product_changed=true ;;
        esac
        case "$path" in
            .changes/*.md)
                [[ "$path" == ".changes/README.md" ]] \
                    || fragment_changed=true
                ;;
        esac
    done <<< "$changed_files"

    if [[ "$product_changed" == "true" && "$fragment_changed" != "true" ]]; then
        fail "user-visible source or packaging changes require a .changes fragment"
    fi
}

validate_release() {
    local version="$1"
    local file="$2"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || fail "release version must use x.y.z"
    [[ -f "$file" ]] || fail "rendered release notes not found: $file"
    grep -Fxq "# Tokeni Bar $version" "$file" \
        || fail "release-note title does not match $version"
    grep -Fxq "## 한국어" "$file" \
        || fail "Korean release-note section is missing"
    grep -Fxq "## English" "$file" \
        || fail "English release-note section is missing"
    grep -Fxq "### 업데이트 및 설치" "$file" \
        || fail "Korean update instructions are missing"
    grep -Fxq "### Update and installation" "$file" \
        || fail "English update instructions are missing"
    if grep -Eq 'TODO|TBD|작성 예정|to be written' "$file"; then
        fail "rendered release notes contain placeholder text"
    fi
}

case "${1:-}" in
    fragment)
        [[ $# -eq 2 ]] || fail "usage: $0 fragment <file>"
        validate_fragment "$2"
        ;;
    all)
        [[ $# -eq 1 ]] || fail "usage: $0 all"
        validate_all
        ;;
    changed)
        [[ $# -eq 3 ]] || fail "usage: $0 changed <base-sha> <head-sha>"
        validate_changed "$2" "$3"
        ;;
    release)
        [[ $# -eq 3 ]] || fail "usage: $0 release <version> <file>"
        validate_release "$2" "$3"
        ;;
    *)
        fail "usage: $0 {fragment <file>|all|changed <base> <head>|release <version> <file>}"
        ;;
esac
