#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
asset_root="$root/Sources/TokeniBar/CompanionAssets"
species_ids=(cachecat stackfox promptpup nullslime)
stage_names=(hatchling junior adult)
stage_y=(97 388 657)
pose_x=(76 302 527 754 980 1207)

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is required to regenerate companion sprite sheets." >&2
    exit 1
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

render_sheet() {
    local species="$1"
    local stage="$2"
    local output="$3"
    local input_args=()
    local filters=""
    local previous="[0:v]"
    local input_index=1

    add_frame() {
        local pose="$1"
        local column="$2"
        local row="$3"
        local dx="$4"
        local dy="$5"
        local next="[layer$input_index]"
        input_args+=(-i "$temporary_dir/${species}-${stage}-${pose}.png")
        filters+="${previous}[${input_index}:v]overlay=x=$((column * 64 + dx)):y=$((row * 64 + dy)):format=auto${next};"
        previous="$next"
        input_index=$((input_index + 1))
    }

    add_frame 0 0 0 0 1
    add_frame 0 1 0 0 0
    add_frame 0 2 0 0 1
    add_frame 0 3 0 0 2
    add_frame 1 0 1 0 1
    add_frame 1 1 1 0 0
    add_frame 1 2 1 0 1
    add_frame 1 3 1 0 0
    add_frame 1 4 1 0 1
    add_frame 1 5 1 0 0
    add_frame 4 0 2 0 1
    add_frame 4 1 2 1 1
    add_frame 4 2 2 0 1
    add_frame 4 3 2 -1 1
    add_frame 2 0 3 -1 1
    add_frame 2 1 3 1 1
    add_frame 2 2 3 -1 1
    add_frame 2 3 3 1 1
    add_frame 3 0 4 0 2
    add_frame 3 1 4 0 0
    add_frame 3 2 4 0 -2
    add_frame 3 3 4 0 0
    add_frame 3 4 4 0 2
    add_frame 3 5 4 0 1
    add_frame 5 0 5 0 1
    add_frame 5 1 5 0 1
    add_frame 5 2 5 0 2
    add_frame 5 3 5 0 2

    filters="${filters%;}"
    ffmpeg -v error -y \
        -f lavfi \
        -i "color=c=black@0:s=512x384:d=1,format=rgba" \
        "${input_args[@]}" \
        -filter_complex "$filters" \
        -map "$previous" \
        -frames:v 1 \
        "$output"
}

add_rarity_style() {
    local input="$1"
    local output="$2"
    local filter="$3"
    ffmpeg -v error -y \
        -i "$input" \
        -vf "${filter},format=rgba" \
        -frames:v 1 \
        "$output"
}

write_manifest() {
    local species="$1"
    local display_name="$2"
    local palette="$3"
    local output="$asset_root/$species/manifest.json"
    sed \
        -e "s/__ID__/$species/g" \
        -e "s/__DISPLAY_NAME__/$display_name/g" \
        -e "s/__PALETTE__/$palette/g" \
        "$root/Scripts/companion-manifest.template.json" > "$output"
}

for species in "${species_ids[@]}"; do
    asset_dir="$asset_root/$species"
    source_image="$asset_dir/source/lifecycle-reference.png"
    if [[ ! -f "$source_image" ]]; then
        echo "Missing lifecycle source: $source_image" >&2
        exit 1
    fi

    for stage_index in "${!stage_names[@]}"; do
        stage="${stage_names[$stage_index]}"
        y="${stage_y[$stage_index]}"
        for pose in "${!pose_x[@]}"; do
            ffmpeg -v error -y \
                -i "$source_image" \
                -vf "crop=256:256:${pose_x[$pose]}:$y,colorkey=0xFF00FF:0.12:0,scale=60:60:flags=neighbor,pad=64:64:2:2:color=black@0,format=rgba" \
                -frames:v 1 \
                "$temporary_dir/${species}-${stage}-${pose}.png"
        done

        normal="$asset_dir/${stage}-normal.png"
        render_sheet "$species" "$stage" "$normal"
        add_rarity_style "$normal" "$asset_dir/${stage}-rare.png" \
            "eq=saturation=1.15:brightness=0.02"
        add_rarity_style "$normal" "$asset_dir/${stage}-epic.png" \
            "hue=h=12:s=1.25,eq=brightness=0.04"
        add_rarity_style "$normal" "$asset_dir/${stage}-legendary.png" \
            "hue=h=25:s=1.40,eq=brightness=0.07"
    done
done

write_manifest cachecat "CacheCat" '"#091A35", "#17345C", "#F0A832", "#FFE08A"'
write_manifest stackfox "StackFox" '"#0A1834", "#E85F18", "#FF9B2F", "#FFF0B3"'
write_manifest promptpup "PromptPup" '"#073B42", "#218C78", "#7CDBA7", "#F4F3C1"'
write_manifest nullslime "NullSlime" '"#171347", "#6331B5", "#A468FF", "#54E5F2"'

echo "Generated companion sprite sheets in $asset_root"
