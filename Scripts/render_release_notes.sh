#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <version> <output-file>" >&2
    exit 1
fi

version="$1"
output_file="$2"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must use x.y.z format: $version" >&2
    exit 1
fi

script_dir=$(cd "$(dirname "$0")" && pwd)
project_dir=$(cd "$script_dir/.." && pwd)
validator="$script_dir/validate_release_notes.sh"
release_tag="v$version"
target_ref="HEAD"
target_is_tag=false
if git -C "$project_dir" rev-parse --verify \
    "refs/tags/$release_tag^{commit}" >/dev/null 2>&1
then
    target_ref="$release_tag"
    target_is_tag=true
fi

previous_tag=""
while IFS= read -r candidate; do
    [[ "$candidate" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    [[ "$candidate" == "$release_tag" ]] && continue
    if git -C "$project_dir" merge-base --is-ancestor \
        "$candidate^{commit}" "$target_ref^{commit}"
    then
        previous_tag="$candidate"
        break
    fi
done < <(git -C "$project_dir" tag --list 'v*' --sort=-version:refname)

fragment_files=()
while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    [[ "$file" == ".changes/README.md" ]] && continue
    fragment_files+=("$file")
done < <(
    if [[ -n "$previous_tag" ]]; then
        git -C "$project_dir" diff --name-only --diff-filter=AM \
            "$previous_tag^{commit}" "$target_ref^{commit}" -- '.changes/*.md'
    else
        git -C "$project_dir" ls-tree -r --name-only \
            "$target_ref^{commit}" -- '.changes/*.md'
    fi
    if [[ "$target_is_tag" != "true" ]]; then
        git -C "$project_dir" diff --name-only --diff-filter=AM \
            "$target_ref^{commit}" -- '.changes/*.md'
        git -C "$project_dir" ls-files --others --exclude-standard \
            -- '.changes/*.md'
    fi
)

if [[ ${#fragment_files[@]} -eq 0 ]]; then
    echo "No release-note fragments were added after ${previous_tag:-the repository start}." >&2
    exit 1
fi

sorted_fragments=()
while IFS= read -r file; do
    [[ -n "$file" ]] && sorted_fragments+=("$file")
done < <(printf '%s\n' "${fragment_files[@]}" | LC_ALL=C sort -u)

for file in "${sorted_fragments[@]}"; do
    "$validator" fragment "$project_dir/$file"
done

field() {
    local name="$1"
    local file="$2"
    awk -v prefix="$name: " '
        index($0, prefix) == 1 {
            print substr($0, length(prefix) + 1)
            exit
        }
    ' "$file"
}

category_heading() {
    local language="$1"
    local category="$2"
    if [[ "$language" == "ko" ]]; then
        case "$category" in
            feature) echo "새로운 기능" ;;
            improvement) echo "주요 개선" ;;
            fix) echo "수정 사항" ;;
            performance) echo "성능 및 안정성" ;;
            migration) echo "데이터 이전 및 호환성" ;;
            security) echo "보안 및 개인정보" ;;
        esac
    else
        case "$category" in
            feature) echo "New features" ;;
            improvement) echo "Improvements" ;;
            fix) echo "Fixes" ;;
            performance) echo "Performance and stability" ;;
            migration) echo "Migration and compatibility" ;;
            security) echo "Security and privacy" ;;
        esac
    fi
}

render_categories() {
    local language="$1"
    local category file fragment_category scope summary found
    for category in feature improvement fix performance migration security; do
        found=false
        for file in "${sorted_fragments[@]}"; do
            fragment_category=$(field category "$project_dir/$file")
            [[ "$fragment_category" == "$category" ]] || continue
            if [[ "$found" != "true" ]]; then
                printf '### %s\n\n' "$(category_heading "$language" "$category")"
                found=true
            fi
            scope=$(field scope "$project_dir/$file")
            summary=$(field "$language" "$project_dir/$file")
            printf -- '- **%s:** %s\n' "$scope" "$summary"
        done
        if [[ "$found" == "true" ]]; then
            printf '\n'
        fi
    done
}

render_actions() {
    local language="$1"
    local action_field="action_$language"
    local file action found=false
    for file in "${sorted_fragments[@]}"; do
        action=$(field "$action_field" "$project_dir/$file")
        [[ -n "$action" ]] || continue
        printf -- '- %s\n' "$action"
        found=true
    done
    if [[ "$found" != "true" ]]; then
        if [[ "$language" == "ko" ]]; then
            printf -- '- 별도 작업이 필요하지 않습니다.\n'
        else
            printf -- '- No additional action is required.\n'
        fi
    fi
}

mkdir -p "$(dirname "$output_file")"
{
    printf '# Tokeni Bar %s\n\n' "$version"
    printf '## 한국어\n\n'
    render_categories ko
    printf '### 업데이트 후 확인 사항\n\n'
    render_actions ko
    printf '\n### 업데이트 및 설치\n\n'
    printf '```bash\n'
    printf 'brew update\n'
    printf 'brew upgrade --formula 90ms/tap/tokeni-bar\n'
    printf 'tokeni-bar --install-app\n'
    printf '```\n\n'
    printf 'GitHub ZIP은 ad-hoc 서명된 빌드입니다. 함께 게시된 SHA-256과 GitHub 빌드 증명을 확인하세요.\n\n'
    printf '%s\n\n' '---'
    printf '## English\n\n'
    render_categories en
    printf '### After updating\n\n'
    render_actions en
    printf '\n### Update and installation\n\n'
    printf '```bash\n'
    printf 'brew update\n'
    printf 'brew upgrade --formula 90ms/tap/tokeni-bar\n'
    printf 'tokeni-bar --install-app\n'
    printf '```\n\n'
    printf 'The GitHub ZIP is ad-hoc signed. Verify its published SHA-256 checksum and GitHub artifact attestation.\n'
} > "$output_file"

"$validator" release "$version" "$output_file"
echo "Rendered release notes from ${#sorted_fragments[@]} fragment(s): $output_file"
