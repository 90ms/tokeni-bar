#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
asset_root="$root/Sources/TokeniBar/CompanionAssets"
species_ids=(queryowl patchpanda loophare relayray kernelcrab)
stage_names=(hatchling junior adult)
rarities=(normal rare epic legendary)

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is required to regenerate generation-two sprites." >&2
    exit 1
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

rect() {
    printf '<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' \
        "$1" "$2" "$3" "$4" "$5"
}

polygon() {
    printf '<polygon points="%s" fill="%s"/>' "$1" "$2"
}

palette_for() {
    local species="$1"
    local rarity="$2"
    outline="#071426"
    core="#57F2E3"
    case "$species" in
        queryowl) body="#4267A8"; detail="#8EB8E8"; accent="#FFD76A" ;;
        patchpanda) body="#F1E7D2"; detail="#34435B"; accent="#FF829F" ;;
        loophare) body="#D99AEF"; detail="#704B9B"; accent="#70E6C1" ;;
        relayray) body="#5FB7C6"; detail="#23637D"; accent="#F3DA75" ;;
        kernelcrab) body="#E26D62"; detail="#813D55"; accent="#FFB65C" ;;
    esac
    case "$rarity" in
        rare)
            core="#9CFF5D"
            accent="#FF66D4"
            ;;
        epic)
            body="#7456B8"
            detail="#C190F2"
            core="#69F7FF"
            ;;
        legendary)
            body="#FFF3C4"
            detail="#8BE2E8"
            accent="#FF86C8"
            core="#FFFFFF"
            ;;
    esac
}

signal_marks() {
    local behavior="$1"
    local frame="$2"
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        rect $((2 + frame % 2)) 7 2 1 "$core"
        rect $((28 - frame % 2)) 10 2 1 "$core"
        rect 3 4 1 1 "$accent"
        rect 28 5 1 1 "$accent"
    elif [[ "$behavior" == warning ]]; then
        rect 2 4 2 2 "#FF5D72"
        rect 28 4 2 2 "#FF5D72"
    elif [[ "$behavior" == sleep ]]; then
        rect 25 5 2 1 "$detail"
        rect 27 3 2 1 "$detail"
        rect 28 0 3 1 "$detail"
    fi
}

variant_marks() {
    local species="$1"
    local rarity="$2"
    local behavior="$3"
    case "$rarity" in
        rare)
            case "$species" in
                queryowl)
                    polygon "5,7 8,2 10,8" "$accent"
                    polygon "27,7 24,2 22,8" "$accent"
                    ;;
                patchpanda)
                    rect 4 13 3 2 "$core"
                    rect 25 17 3 3 "$accent"
                    ;;
                loophare)
                    rect 4 4 4 2 "$core"
                    rect 24 4 4 2 "$accent"
                    ;;
                relayray)
                    polygon "3,15 0,12 1,18" "$accent"
                    polygon "29,15 32,12 31,18" "$core"
                    ;;
                kernelcrab)
                    rect 3 10 3 3 "$core"
                    rect 26 8 3 5 "$accent"
                    ;;
            esac
            ;;
        epic)
            rect 3 3 2 2 "$core"
            rect 27 6 1 1 "$accent"
            ;;
        legendary)
            rect 4 3 2 1 "#FF6B8A"
            rect 7 2 2 1 "#FFD75E"
            rect 10 3 2 1 "#6EF1A8"
            rect 20 3 2 1 "#62D8FF"
            rect 23 2 2 1 "#9B83FF"
            rect 26 3 2 1 "#FF7DDA"
            if [[ "$behavior" == signature ]]; then
                rect 1 16 2 1 "#FFD75E"
                rect 29 16 2 1 "#62D8FF"
            fi
            ;;
    esac
}

draw_queryowl() {
    local stage="$1" behavior="$2" frame="$3"
    local head_x=8 head_y=7 head_w=16 body_x=10 body_y=16 body_w=12
    local wing_left=6 wing_right=23 wing_w=4
    case "$stage" in
        junior)
            head_x=7; head_y=6; head_w=18; body_x=9; body_y=15; body_w=14
            wing_left=4; wing_right=23; wing_w=5
            ;;
        adult)
            head_x=6; head_y=5; head_w=20; body_x=8; body_y=14; body_w=16
            wing_left=2; wing_right=24; wing_w=6
            ;;
    esac
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        wing_left=0; wing_right=25; wing_w=7
    fi
    polygon "$wing_left,16 $((wing_left + wing_w)),13 $((wing_left + wing_w)),25 $wing_left,22" "$outline"
    polygon "$((wing_left + 1)),17 $((wing_left + wing_w - 1)),15 $((wing_left + wing_w - 1)),23 $((wing_left + 1)),21" "$detail"
    polygon "$wing_right,13 $((wing_right + wing_w)),16 $((wing_right + wing_w)),22 $wing_right,25" "$outline"
    polygon "$((wing_right + 1)),15 $((wing_right + wing_w - 1)),17 $((wing_right + wing_w - 1)),21 $((wing_right + 1)),23" "$detail"
    rect "$body_x" "$body_y" "$body_w" 11 "$outline"
    rect $((body_x + 1)) $((body_y + 1)) $((body_w - 2)) 9 "$body"
    polygon "$head_x,$((head_y + 4)) $((head_x + 3)),$head_y $((head_x + 6)),$((head_y + 4))" "$outline"
    polygon "$((head_x + head_w)),$((head_y + 4)) $((head_x + head_w - 3)),$head_y $((head_x + head_w - 6)),$((head_y + 4))" "$outline"
    rect "$head_x" $((head_y + 3)) "$head_w" 11 "$outline"
    rect $((head_x + 1)) $((head_y + 4)) $((head_w - 2)) 9 "$body"
    rect $((head_x + 3)) $((head_y + 6)) 4 4 "$detail"
    rect $((head_x + head_w - 7)) $((head_y + 6)) 4 4 "$detail"
    rect $((head_x + 4)) $((head_y + 7)) 2 2 "$core"
    rect $((head_x + head_w - 6)) $((head_y + 7)) 2 2 "$core"
    polygon "15,$((head_y + 10)) 17,$((head_y + 10)) 16,$((head_y + 12))" "$accent"
    rect 14 19 4 4 "$outline"
    rect 15 20 2 2 "$core"
    rect 9 27 5 2 "$outline"
    rect 18 27 5 2 "$outline"
}

draw_patchpanda() {
    local stage="$1" behavior="$2" frame="$3"
    local head_x=8 head_y=7 head_w=16 body_x=10 body_y=17 body_w=12
    case "$stage" in
        junior) head_x=7; head_y=6; head_w=18; body_x=8; body_y=17; body_w=16 ;;
        adult) head_x=6; head_y=5; head_w=20; body_x=7; body_y=16; body_w=18 ;;
    esac
    rect "$head_x" "$head_y" 5 5 "$outline"
    rect $((head_x + head_w - 5)) "$head_y" 5 5 "$outline"
    rect "$body_x" "$body_y" "$body_w" 11 "$outline"
    rect $((body_x + 1)) $((body_y + 1)) $((body_w - 2)) 9 "$body"
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        rect 3 18 8 4 "$outline"
        rect 4 19 7 2 "$detail"
        rect 21 18 8 4 "$outline"
        rect 21 19 7 2 "$detail"
    else
        rect $((body_x - 2)) 19 3 7 "$outline"
        rect $((body_x + body_w - 1)) 19 3 7 "$outline"
    fi
    rect "$head_x" $((head_y + 3)) "$head_w" 12 "$outline"
    rect $((head_x + 1)) $((head_y + 4)) $((head_w - 2)) 10 "$body"
    rect $((head_x + 3)) $((head_y + 7)) 5 4 "$detail"
    rect $((head_x + head_w - 8)) $((head_y + 7)) 5 4 "$detail"
    rect $((head_x + 5)) $((head_y + 8)) 1 2 "$core"
    rect $((head_x + head_w - 6)) $((head_y + 8)) 1 2 "$core"
    rect 14 $((head_y + 11)) 4 2 "$detail"
    rect 14 20 4 4 "$outline"
    rect 15 21 2 2 "$core"
    rect $((body_x + 1)) 27 5 2 "$detail"
    rect $((body_x + body_w - 6)) 27 5 2 "$detail"
}

draw_loophare() {
    local stage="$1" behavior="$2" frame="$3"
    local head_x=9 head_y=10 head_w=14 body_x=10 body_y=19 body_w=12 ear_top=2
    case "$stage" in
        junior) head_x=8; head_y=9; head_w=16; body_x=8; body_y=18; body_w=16; ear_top=1 ;;
        adult) head_x=7; head_y=8; head_w=18; body_x=7; body_y=17; body_w=18; ear_top=0 ;;
    esac
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        rect 2 4 9 4 "$outline"
        rect 3 5 7 2 "$body"
        rect 21 4 9 4 "$outline"
        rect 22 5 7 2 "$body"
        rect 7 6 4 7 "$outline"
        rect 21 6 4 7 "$outline"
    else
        rect $((head_x + 2)) "$ear_top" 4 $((head_y - ear_top + 2)) "$outline"
        rect $((head_x + 3)) $((ear_top + 1)) 2 $((head_y - ear_top)) "$accent"
        rect $((head_x + head_w - 6)) "$ear_top" 4 $((head_y - ear_top + 2)) "$outline"
        rect $((head_x + head_w - 5)) $((ear_top + 1)) 2 $((head_y - ear_top)) "$accent"
    fi
    rect "$body_x" "$body_y" "$body_w" 9 "$outline"
    rect $((body_x + 1)) $((body_y + 1)) $((body_w - 2)) 7 "$body"
    rect "$head_x" "$head_y" "$head_w" 11 "$outline"
    rect $((head_x + 1)) $((head_y + 1)) $((head_w - 2)) 9 "$body"
    rect $((head_x + 3)) $((head_y + 4)) 2 2 "$core"
    rect $((head_x + head_w - 5)) $((head_y + 4)) 2 2 "$core"
    rect 15 $((head_y + 7)) 2 2 "$accent"
    rect 14 21 4 4 "$outline"
    rect 15 22 2 2 "$core"
    rect $((body_x - 2)) 27 7 2 "$outline"
    rect $((body_x + body_w - 5)) 27 7 2 "$outline"
}

draw_relayray() {
    local stage="$1" behavior="$2" frame="$3"
    local left=6 right=26 top=9 bottom=23 tail=29
    case "$stage" in
        hatchling) left=8; right=24; top=11; bottom=22; tail=28 ;;
        junior) left=5; right=27; top=9; bottom=23; tail=29 ;;
        adult) left=2; right=30; top=7; bottom=24; tail=31 ;;
    esac
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        top=$((top - 2)); left=0; right=32
    fi
    polygon "$left,15 16,$top $right,15 20,$bottom 16,$((bottom - 2)) 12,$bottom" "$outline"
    polygon "$((left + 2)),15 16,$((top + 2)) $((right - 2)),15 20,$((bottom - 2)) 16,$((bottom - 4)) 12,$((bottom - 2))" "$body"
    polygon "15,$((bottom - 2)) 17,$((bottom - 2)) 18,$tail 16,$((tail - 2)) 14,$tail" "$detail"
    rect 10 14 3 2 "$detail"
    rect 19 14 3 2 "$detail"
    rect 11 14 1 1 "$core"
    rect 20 14 1 1 "$core"
    rect 14 17 4 4 "$outline"
    rect 15 18 2 2 "$core"
    if [[ "$behavior" == waiting ]]; then
        rect 7 22 2 1 "$accent"
        rect 23 22 2 1 "$accent"
    fi
}

draw_kernelcrab() {
    local stage="$1" behavior="$2" frame="$3"
    local shell_x=9 shell_y=12 shell_w=14 claw=4
    case "$stage" in
        junior) shell_x=7; shell_y=10; shell_w=18; claw=5 ;;
        adult) shell_x=6; shell_y=8; shell_w=20; claw=6 ;;
    esac
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        shell_y=$((shell_y - 2))
    fi
    rect 1 10 "$claw" 7 "$outline"
    rect 2 11 $((claw - 2)) 5 "$accent"
    rect $((31 - claw)) 10 "$claw" 7 "$outline"
    rect $((32 - claw)) 11 $((claw - 2)) 5 "$accent"
    rect "$shell_x" "$shell_y" "$shell_w" 14 "$outline"
    rect $((shell_x + 1)) $((shell_y + 1)) $((shell_w - 2)) 12 "$body"
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        rect $((shell_x + 2)) $((shell_y + 6)) $((shell_w - 4)) 2 "$outline"
        rect 13 $((shell_y + 7)) 6 6 "$outline"
        rect 14 $((shell_y + 8)) 4 4 "$core"
    else
        rect 14 $((shell_y + 6)) 4 4 "$outline"
        rect 15 $((shell_y + 7)) 2 2 "$core"
    fi
    rect $((shell_x + 3)) $((shell_y + 3)) 2 2 "$detail"
    rect $((shell_x + shell_w - 5)) $((shell_y + 3)) 2 2 "$detail"
    rect 5 24 5 2 "$outline"
    rect 2 27 7 2 "$outline"
    rect 22 24 5 2 "$outline"
    rect 23 27 7 2 "$outline"
}

render_frame() {
    local species="$1" stage="$2" rarity="$3" behavior="$4" frame="$5"
    local column="$6" row="$7"
    local dx=0 dy=0
    case "$behavior" in
        idle|waiting) dy=$((frame % 2)) ;;
        working) dy=$((frame % 2 == 0 ? 1 : 0)) ;;
        warning) dx=$((frame % 2 == 0 ? -1 : 1)) ;;
        signature) dy=$((frame % 3 == 1 ? -2 : 0)) ;;
        sleep) dy=2 ;;
    esac
    printf '<g transform="translate(%s %s) scale(2) translate(%s %s)" shape-rendering="crispEdges">' \
        $((column * 64)) $((row * 64)) "$dx" "$dy"
    signal_marks "$behavior" "$frame"
    case "$species" in
        queryowl) draw_queryowl "$stage" "$behavior" "$frame" ;;
        patchpanda) draw_patchpanda "$stage" "$behavior" "$frame" ;;
        loophare) draw_loophare "$stage" "$behavior" "$frame" ;;
        relayray) draw_relayray "$stage" "$behavior" "$frame" ;;
        kernelcrab) draw_kernelcrab "$stage" "$behavior" "$frame" ;;
    esac
    variant_marks "$species" "$rarity" "$behavior"
    printf '</g>'
}

render_sheet() {
    local species="$1" stage="$2" rarity="$3" output="$4"
    local svg="$temporary_dir/$species-$stage-$rarity.svg"
    local behaviors=(idle working waiting warning signature sleep)
    local frame_counts=(4 6 4 4 6 4)
    palette_for "$species" "$rarity"
    {
        printf '%s' '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="384" viewBox="0 0 512 384">'
        for row in 0 1 2 3 4 5; do
            behavior="${behaviors[$row]}"
            count="${frame_counts[$row]}"
            for ((column = 0; column < count; column += 1)); do
                render_frame \
                    "$species" "$stage" "$rarity" "$behavior" "$column" \
                    "$column" "$row"
            done
        done
        printf '%s' '</svg>'
    } > "$svg"
    ffmpeg -v error -y -i "$svg" -vf "format=rgba" -frames:v 1 "$output"
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
    mkdir -p "$asset_root/$species"
    for stage in "${stage_names[@]}"; do
        for rarity in "${rarities[@]}"; do
            render_sheet \
                "$species" "$stage" "$rarity" \
                "$asset_root/$species/$stage-$rarity.png"
        done
    done
done

write_manifest queryowl "QueryOwl" '"#071426", "#4267A8", "#8EB8E8", "#FFD76A", "#57F2E3"'
write_manifest patchpanda "PatchPanda" '"#071426", "#F1E7D2", "#34435B", "#FF829F", "#57F2E3"'
write_manifest loophare "LoopHare" '"#071426", "#D99AEF", "#704B9B", "#70E6C1", "#57F2E3"'
write_manifest relayray "RelayRay" '"#071426", "#5FB7C6", "#23637D", "#F3DA75", "#57F2E3"'
write_manifest kernelcrab "KernelCrab" '"#071426", "#E26D62", "#813D55", "#FFB65C", "#57F2E3"'

echo "Generated generation-two companion sprite sheets in $asset_root"
