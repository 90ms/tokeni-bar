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
    local styled="$temporary_dir/$(basename "${output%.png}")-styled.png"
    ffmpeg -v error -y \
        -i "$input" \
        -vf "${filter},format=rgba" \
        -frames:v 1 \
        "$styled"

    # Keep behavioral symbols and the working prop in their original colors.
    # Rarity belongs to the pet body; the outer eight pixels of each frame and
    # the right-hand prop area in the working row are restored from Normal.
    ffmpeg -v error -y \
        -i "$styled" \
        -i "$input" \
        -filter_complex \
        "[0:v]format=gbrap[styled];[1:v]format=gbrap[original];nullsrc=s=512x384,format=gray,geq=lum='if(lt(mod(X\\,64)\\,8)+gt(mod(X\\,64)\\,55)+lt(mod(Y\\,64)\\,8)+between(Y\\,88\\,127)*gt(mod(X\\,64)\\,28)\\,255\\,0)'[mask];[styled][original][mask]maskedmerge,format=rgba[out]" \
        -map "[out]" \
        -frames:v 1 \
        "$output"
}

rarity_filter() {
    local species="$1"
    local rarity="$2"

    case "$species:$rarity" in
        cachecat:rare)
            echo "colorchannelmixer=rr=1.08:gg=0.78:gb=0.08:br=0.05:bb=1.18,eq=contrast=1.12:brightness=0.025:saturation=1.38"
            ;;
        cachecat:epic)
            echo "colorchannelmixer=rr=0.90:rb=0.28:gg=0.78:gb=0.18:br=0.22:bb=1.25,eq=contrast=1.14:brightness=0.035:saturation=1.48"
            ;;
        cachecat:legendary)
            echo "colorchannelmixer=rr=1.10:rg=0.12:gg=1.12:bb=0.68,eq=contrast=1.08:brightness=0.08:saturation=1.05"
            ;;
        stackfox:rare)
            echo "colorchannelmixer=rr=1.22:gg=0.68:bb=0.82,eq=contrast=1.12:brightness=0.02:saturation=1.45"
            ;;
        stackfox:epic)
            echo "colorchannelmixer=rr=0.98:rb=0.24:gg=0.88:gb=0.16:br=0.18:bg=0.08:bb=1.18,eq=contrast=1.14:brightness=0.035:saturation=1.48"
            ;;
        stackfox:legendary)
            echo "colorchannelmixer=rr=1.10:rg=0.12:gg=1.12:bb=0.68,eq=contrast=1.08:brightness=0.08:saturation=1.05"
            ;;
        promptpup:rare)
            echo "colorchannelmixer=rr=0.72:gg=1.08:gb=0.05:br=0.04:bg=0.12:bb=1.04,eq=contrast=1.12:brightness=0.02:saturation=1.42"
            ;;
        promptpup:epic)
            echo "colorchannelmixer=rr=0.88:rb=0.22:gg=0.90:gb=0.16:br=0.20:bg=0.10:bb=1.22,eq=contrast=1.14:brightness=0.035:saturation=1.48"
            ;;
        promptpup:legendary)
            echo "colorchannelmixer=rr=1.08:rg=0.10:gg=1.16:bb=0.72,eq=contrast=1.08:brightness=0.07:saturation=1.12"
            ;;
        nullslime:rare)
            echo "colorchannelmixer=rr=1.18:gg=0.72:bb=0.92,eq=contrast=1.12:brightness=0.02:saturation=1.45"
            ;;
        nullslime:epic)
            echo "colorchannelmixer=rr=0.82:rb=0.20:gg=0.86:gb=0.16:br=0.16:bg=0.12:bb=1.26,eq=contrast=1.16:brightness=0.035:saturation=1.52"
            ;;
        nullslime:legendary)
            echo "colorchannelmixer=rr=1.14:rg=0.12:gg=1.06:gb=0.05:br=0.05:bg=0.10:bb=0.82,eq=contrast=1.10:brightness=0.07:saturation=1.18"
            ;;
        *)
            echo "eq=contrast=1.10:brightness=0.02:saturation=1.35"
            ;;
    esac
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
            "$(rarity_filter "$species" rare)"
        add_rarity_style "$normal" "$asset_dir/${stage}-epic.png" \
            "$(rarity_filter "$species" epic)"
        add_rarity_style "$normal" "$asset_dir/${stage}-legendary.png" \
            "$(rarity_filter "$species" legendary)"
    done
done

write_manifest cachecat "CacheCat" '"#091A35", "#17345C", "#F0A832", "#FFE08A"'
write_manifest stackfox "StackFox" '"#0A1834", "#E85F18", "#FF9B2F", "#FFF0B3"'
write_manifest promptpup "PromptPup" '"#073B42", "#218C78", "#7CDBA7", "#F4F3C1"'
write_manifest nullslime "NullSlime" '"#171347", "#6331B5", "#A468FF", "#54E5F2"'

"$root/Scripts/generate_generation_two_assets.sh"

echo "Generated all companion sprite sheets in $asset_root"
