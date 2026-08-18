#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
asset_root="$root/Sources/TokeniBar/CompanionAssets"
species_ids=(queryowl patchpanda loophare relayray kernelcrab)
stage_names=(hatchling junior adult)
stage_y=(48 360 672)
pose_x=(32 288 544 800 1024 1248)

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is required to regenerate generation-two sprites." >&2
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
        local pose="$1" column="$2" row="$3" dx="$4" dy="$5"
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
    add_frame 0 0 2 0 1
    add_frame 0 1 2 1 1
    add_frame 0 2 2 0 1
    add_frame 0 3 2 -1 1
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
    local input="$1" output="$2" filter="$3"
    local styled="$temporary_dir/$(basename "${output%.png}")-styled.png"
    ffmpeg -v error -y \
        -i "$input" \
        -vf "${filter},format=rgba" \
        -frames:v 1 \
        "$styled"

    # Keep action symbols, laptop props, eyes, and the cyan companion core
    # legible instead of tinting the whole frame indiscriminately.
    ffmpeg -v error -y \
        -i "$styled" \
        -i "$input" \
        -filter_complex \
        "[0:v]format=gbrap[styled];[1:v]format=gbrap[original];nullsrc=s=512x384,format=gray,geq=lum='if(lt(mod(X\\,64)\\,7)+gt(mod(X\\,64)\\,56)+lt(mod(Y\\,64)\\,7)+between(Y\\,64\\,127)*gt(mod(X\\,64)\\,27)\\,255\\,0)'[mask];[styled][original][mask]maskedmerge,format=rgba[out]" \
        -map "[out]" \
        -frames:v 1 \
        "$output"
}

rarity_filter() {
    local species="$1" rarity="$2"
    case "$species:$rarity" in
        queryowl:rare) echo "colorchannelmixer=rr=0.82:rb=0.12:gg=1.08:gb=0.08:br=0.06:bb=1.10,eq=contrast=1.08:brightness=0.02:saturation=1.28" ;;
        queryowl:epic) echo "colorchannelmixer=rr=0.92:rb=0.22:gg=0.80:gb=0.18:br=0.18:bb=1.20,eq=contrast=1.10:brightness=0.03:saturation=1.35" ;;
        patchpanda:rare) echo "colorchannelmixer=rr=1.05:gg=0.92:gb=0.06:bb=1.08,eq=contrast=1.08:brightness=0.02:saturation=1.18" ;;
        patchpanda:epic) echo "colorchannelmixer=rr=0.94:rb=0.18:gg=0.84:gb=0.14:br=0.16:bb=1.18,eq=contrast=1.10:brightness=0.025:saturation=1.25" ;;
        loophare:rare) echo "colorchannelmixer=rr=0.90:rg=0.08:gg=1.05:gb=0.06:bb=1.02,eq=contrast=1.08:brightness=0.02:saturation=1.28" ;;
        loophare:epic) echo "colorchannelmixer=rr=0.90:rb=0.18:gg=0.82:gb=0.16:br=0.18:bb=1.20,eq=contrast=1.10:brightness=0.03:saturation=1.36" ;;
        relayray:rare) echo "colorchannelmixer=rr=0.82:rg=0.08:gg=1.08:gb=0.06:br=0.08:bb=1.06,eq=contrast=1.08:brightness=0.02:saturation=1.30" ;;
        relayray:epic) echo "colorchannelmixer=rr=0.88:rb=0.22:gg=0.80:gb=0.18:br=0.20:bb=1.18,eq=contrast=1.10:brightness=0.03:saturation=1.35" ;;
        kernelcrab:rare) echo "colorchannelmixer=rr=1.08:rg=0.04:gg=0.88:gb=0.08:bb=1.04,eq=contrast=1.08:brightness=0.02:saturation=1.30" ;;
        kernelcrab:epic) echo "colorchannelmixer=rr=0.94:rb=0.18:gg=0.78:gb=0.16:br=0.16:bb=1.20,eq=contrast=1.10:brightness=0.03:saturation=1.38" ;;
        *:legendary) echo "colorchannelmixer=rr=1.08:rg=0.10:gg=1.10:gb=0.04:br=0.04:bg=0.08:bb=0.82,eq=contrast=1.06:brightness=0.07:saturation=1.02" ;;
        *) echo "eq=contrast=1.08:brightness=0.02:saturation=1.25" ;;
    esac
}

write_manifest() {
    local species="$1" display_name="$2" palette="$3"
    sed \
        -e "s/__ID__/$species/g" \
        -e "s/__DISPLAY_NAME__/$display_name/g" \
        -e "s/__PALETTE__/$palette/g" \
        "$root/Scripts/companion-manifest.template.json" \
        > "$asset_root/$species/manifest.json"
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
            # Remove the generated chroma background and turn any remaining
            # magenta fringe into the same fine navy contour as generation one.
            ffmpeg -v error -y \
                -i "$source_image" \
                -vf "crop=256:256:${pose_x[$pose]}:$y,colorkey=0xFF00FF:0.30:0.12,geq=r='if(gt(r(X,Y)+b(X,Y)-2*g(X,Y),180),7,r(X,Y))':g='if(gt(r(X,Y)+b(X,Y)-2*g(X,Y),180),20,g(X,Y))':b='if(gt(r(X,Y)+b(X,Y)-2*g(X,Y),180),38,b(X,Y))':a='alpha(X,Y)',scale=60:60:flags=neighbor,pad=64:64:2:2:color=black@0,format=rgba" \
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

write_manifest queryowl "QueryOwl" '"#071426", "#4267A8", "#8EB8E8", "#FFD76A", "#57F2E3"'
write_manifest patchpanda "PatchPanda" '"#071426", "#F1E7D2", "#34435B", "#FF829F", "#57F2E3"'
write_manifest loophare "LoopHare" '"#071426", "#D99AEF", "#704B9B", "#70E6C1", "#57F2E3"'
write_manifest relayray "RelayRay" '"#071426", "#5FB7C6", "#23637D", "#F3DA75", "#57F2E3"'
write_manifest kernelcrab "KernelCrab" '"#071426", "#E26D62", "#813D55", "#FFB65C", "#57F2E3"'

echo "Generated generation-two companion sprite sheets in $asset_root"
