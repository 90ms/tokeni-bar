#!/bin/bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
project_dir=$(cd "$script_dir/../.." && pwd)
temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/tokeni-release-notes-tests.XXXXXX")
trap 'rm -rf "$temporary_dir"' EXIT

validator="$project_dir/Scripts/validate_release_notes.sh"
renderer="$project_dir/Scripts/render_release_notes.sh"
output="$temporary_dir/release-notes.md"

"$validator" all

render_fixture="$temporary_dir/render-fixture"
mkdir -p "$render_fixture/Scripts" "$render_fixture/.changes"
cp "$validator" "$render_fixture/Scripts/validate_release_notes.sh"
cp "$renderer" "$render_fixture/Scripts/render_release_notes.sh"
git -C "$render_fixture" init -q
git -C "$render_fixture" config user.name "Release Notes Test"
git -C "$render_fixture" config user.email "release-notes-test@example.invalid"
git -C "$render_fixture" add Scripts
git -C "$render_fixture" commit -qm "Base"
git -C "$render_fixture" tag v1.0.0
printf '%s\n' \
    'category: improvement' \
    'scope: renderer' \
    'breaking: false' \
    'ko: 렌더러 테스트 기록입니다.' \
    'en: This renderer fixture is valid.' \
    > "$render_fixture/.changes/20260805-renderer-test.md"
git -C "$render_fixture" add .changes/20260805-renderer-test.md
git -C "$render_fixture" commit -qm "Add renderer fixture"
"$render_fixture/Scripts/render_release_notes.sh" 1.1.0 "$output"

grep -Fxq '# Tokeni Bar 1.1.0' "$output"
grep -Fxq '## 한국어' "$output"
grep -Fxq '## English' "$output"
grep -Fq '렌더러 테스트 기록입니다.' "$output"
grep -Fq 'This renderer fixture is valid.' "$output"

invalid="$temporary_dir/20260804-invalid.md"
printf '%s\n' \
    'category: improvement' \
    'scope: release' \
    'breaking: true' \
    'ko: 잘못된 테스트 조각입니다.' \
    'en: This fixture intentionally omits update actions.' \
    > "$invalid"
if "$validator" fragment "$invalid" >/dev/null 2>&1; then
    echo "A breaking fragment without update actions must be rejected." >&2
    exit 1
fi

fixture="$temporary_dir/changed-fixture"
mkdir -p "$fixture/Scripts" "$fixture/Sources/App" "$fixture/.changes"
cp "$validator" "$fixture/Scripts/validate_release_notes.sh"
git -C "$fixture" init -q
git -C "$fixture" config user.name "Release Notes Test"
git -C "$fixture" config user.email "release-notes-test@example.invalid"
printf '%s\n' 'let value = 1' > "$fixture/Sources/App/Feature.swift"
git -C "$fixture" add .
git -C "$fixture" commit -qm "Base"
base_sha=$(git -C "$fixture" rev-parse HEAD)
printf '%s\n' 'let value = 2' > "$fixture/Sources/App/Feature.swift"
git -C "$fixture" add .
git -C "$fixture" commit -qm "Product change without notes"
head_without_fragment=$(git -C "$fixture" rev-parse HEAD)
if "$fixture/Scripts/validate_release_notes.sh" changed \
    "$base_sha" "$head_without_fragment" >/dev/null 2>&1
then
    echo "A product change without a release-note fragment must be rejected." >&2
    exit 1
fi
printf '%s\n' \
    'category: improvement' \
    'scope: test' \
    'breaking: false' \
    'ko: 테스트 기능을 개선했습니다.' \
    'en: Improved the test feature.' \
    > "$fixture/.changes/20260804-test-feature.md"
git -C "$fixture" add .
git -C "$fixture" commit -qm "Add release note"
"$fixture/Scripts/validate_release_notes.sh" all
"$fixture/Scripts/validate_release_notes.sh" changed \
    "$base_sha" "$(git -C "$fixture" rev-parse HEAD)"

echo "Release-note validation and rendering tests passed"
