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
        queryowl)
            body="#4267A8"; detail="#8EB8E8"; accent="#FFD76A"
            shadow="#294675"; highlight="#B9D5F4"; soft="#E9F1DB"
            ;;
        patchpanda)
            body="#F1E7D2"; detail="#34435B"; accent="#FF829F"
            shadow="#C8BFAF"; highlight="#FFF8E8"; soft="#64748B"
            ;;
        loophare)
            body="#D99AEF"; detail="#704B9B"; accent="#70E6C1"
            shadow="#A969C4"; highlight="#F0C8FA"; soft="#FFE8F6"
            ;;
        relayray)
            body="#5FB7C6"; detail="#23637D"; accent="#F3DA75"
            shadow="#31899D"; highlight="#A4E3DF"; soft="#D8F5E8"
            ;;
        kernelcrab)
            body="#E26D62"; detail="#813D55"; accent="#FFB65C"
            shadow="#B84B50"; highlight="#FF9A7E"; soft="#FFE0A3"
            ;;
    esac
    case "$rarity" in
        rare)
            core="#9CFF5D"
            accent="#FF66D4"
            ;;
        epic)
            body="#7456B8"
            detail="#C190F2"
            shadow="#49377F"
            highlight="#E2C5FF"
            soft="#F6E9FF"
            core="#69F7FF"
            ;;
        legendary)
            body="#FFF3C4"
            detail="#8BE2E8"
            shadow="#D2B989"
            highlight="#FFFFFF"
            soft="#FFF8E8"
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
    local inset=2 head_top=7 body_bottom=28 wing_tip=5
    case "$stage" in
        junior) inset=1; head_top=5; body_bottom=29; wing_tip=3 ;;
        adult) inset=0; head_top=3; body_bottom=30; wing_tip=1 ;;
    esac
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        wing_tip=0
    fi
    # Layered feather fans replace the old rectangular wings.
    polygon "$wing_tip,17 $((7 + inset)),13 $((11 + inset)),17 $((10 + inset)),25 $((6 + inset)),28 $((3 + inset)),24" "$outline"
    polygon "$((wing_tip + 2)),18 $((8 + inset)),15 $((9 + inset)),18 $((8 + inset)),24 $((6 + inset)),26 $((5 + inset)),22" "$detail"
    polygon "$((32 - wing_tip)),17 $((25 - inset)),13 $((21 - inset)),17 $((22 - inset)),25 $((26 - inset)),28 $((29 - inset)),24" "$outline"
    polygon "$((30 - wing_tip)),18 $((24 - inset)),15 $((23 - inset)),18 $((24 - inset)),24 $((26 - inset)),26 $((27 - inset)),22" "$detail"
    polygon "$((9 + inset)),15 $((12 + inset)),13 $((20 - inset)),13 $((23 - inset)),15 $((24 - inset)),$((body_bottom - 4)) $((20 - inset)),$body_bottom $((12 + inset)),$body_bottom $((8 + inset)),$((body_bottom - 4))" "$outline"
    polygon "$((11 + inset)),16 $((13 + inset)),15 $((19 - inset)),15 $((21 - inset)),16 $((22 - inset)),$((body_bottom - 5)) $((19 - inset)),$((body_bottom - 2)) $((13 + inset)),$((body_bottom - 2)) $((10 + inset)),$((body_bottom - 5))" "$body"
    polygon "$((10 + inset)),$((head_top + 3)) $((12 + inset)),$head_top $((15 + inset)),$((head_top + 3)) $((17 - inset)),$((head_top + 3)) $((20 - inset)),$head_top $((22 - inset)),$((head_top + 3)) $((25 - inset)),$((head_top + 7)) $((24 - inset)),$((head_top + 13)) $((20 - inset)),$((head_top + 17)) $((12 + inset)),$((head_top + 17)) $((8 + inset)),$((head_top + 13)) $((7 + inset)),$((head_top + 7))" "$outline"
    polygon "$((11 + inset)),$((head_top + 4)) $((13 + inset)),$((head_top + 2)) $((15 + inset)),$((head_top + 4)) $((17 - inset)),$((head_top + 4)) $((19 - inset)),$((head_top + 2)) $((21 - inset)),$((head_top + 4)) $((23 - inset)),$((head_top + 7)) $((22 - inset)),$((head_top + 12)) $((19 - inset)),$((head_top + 15)) $((13 + inset)),$((head_top + 15)) $((10 + inset)),$((head_top + 12)) $((9 + inset)),$((head_top + 7))" "$body"
    rect $((11 + inset)) $((head_top + 7)) 5 5 "$soft"
    rect $((16 - inset)) $((head_top + 7)) 5 5 "$soft"
    rect $((12 + inset)) $((head_top + 8)) 3 3 "$outline"
    rect $((17 - inset)) $((head_top + 8)) 3 3 "$outline"
    rect $((13 + inset)) $((head_top + 8)) 1 1 "$core"
    rect $((18 - inset)) $((head_top + 8)) 1 1 "$core"
    polygon "14,$((head_top + 12)) 18,$((head_top + 12)) 16,$((head_top + 15))" "$accent"
    rect 11 $((head_top + 5)) 2 1 "$highlight"
    rect 14 21 4 5 "$outline"
    rect 15 22 2 3 "$core"
    rect 11 $((body_bottom - 1)) 4 2 "$accent"
    rect 18 $((body_bottom - 1)) 4 2 "$accent"
}

draw_patchpanda() {
    local stage="$1" behavior="$2" frame="$3"
    local inset=2 top=7 bottom=29
    case "$stage" in
        junior) inset=1; top=5; bottom=30 ;;
        adult) inset=0; top=3; bottom=31 ;;
    esac
    polygon "$((7 + inset)),$((top + 3)) $((8 + inset)),$top $((12 + inset)),$((top - 1)) $((14 + inset)),$((top + 3))" "$outline"
    polygon "$((25 - inset)),$((top + 3)) $((24 - inset)),$top $((20 - inset)),$((top - 1)) $((18 - inset)),$((top + 3))" "$outline"
    rect $((9 + inset)) $((top + 1)) 3 3 "$detail"
    rect $((20 - inset)) $((top + 1)) 3 3 "$detail"
    polygon "$((9 + inset)),18 $((12 + inset)),16 $((20 - inset)),16 $((23 - inset)),18 $((25 - inset)),25 $((22 - inset)),$bottom $((10 + inset)),$bottom $((7 + inset)),25" "$outline"
    polygon "$((11 + inset)),18 $((13 + inset)),17 $((19 - inset)),17 $((21 - inset)),18 $((23 - inset)),25 $((20 - inset)),$((bottom - 2)) $((12 + inset)),$((bottom - 2)) $((9 + inset)),25" "$detail"
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        polygon "9,18 3,19 2,22 9,23 13,21" "$outline"
        polygon "23,18 29,19 30,22 23,23 19,21" "$outline"
        rect 4 20 6 2 "$detail"
        rect 22 20 6 2 "$detail"
    else
        polygon "$((9 + inset)),19 $((6 + inset)),21 $((7 + inset)),27 $((11 + inset)),26" "$outline"
        polygon "$((23 - inset)),19 $((26 - inset)),21 $((25 - inset)),27 $((21 - inset)),26" "$outline"
    fi
    polygon "$((8 + inset)),$((top + 4)) $((11 + inset)),$((top + 2)) $((21 - inset)),$((top + 2)) $((24 - inset)),$((top + 4)) $((26 - inset)),$((top + 10)) $((24 - inset)),$((top + 16)) $((20 - inset)),$((top + 19)) $((12 + inset)),$((top + 19)) $((8 + inset)),$((top + 16)) $((6 + inset)),$((top + 10))" "$outline"
    polygon "$((10 + inset)),$((top + 4)) $((12 + inset)),$((top + 3)) $((20 - inset)),$((top + 3)) $((22 - inset)),$((top + 4)) $((24 - inset)),$((top + 10)) $((22 - inset)),$((top + 15)) $((19 - inset)),$((top + 17)) $((13 + inset)),$((top + 17)) $((10 + inset)),$((top + 15)) $((8 + inset)),$((top + 10))" "$body"
    polygon "$((10 + inset)),$((top + 8)) $((13 + inset)),$((top + 6)) $((16 + inset)),$((top + 9)) $((14 + inset)),$((top + 13)) $((11 + inset)),$((top + 12))" "$detail"
    polygon "$((22 - inset)),$((top + 8)) $((19 - inset)),$((top + 6)) $((16 - inset)),$((top + 9)) $((18 - inset)),$((top + 13)) $((21 - inset)),$((top + 12))" "$detail"
    rect $((12 + inset)) $((top + 9)) 2 2 "$outline"
    rect $((18 - inset)) $((top + 9)) 2 2 "$outline"
    rect $((13 + inset)) $((top + 9)) 1 1 "$core"
    rect $((18 - inset)) $((top + 9)) 1 1 "$core"
    polygon "14,$((top + 13)) 18,$((top + 13)) 17,$((top + 15)) 15,$((top + 15))" "$outline"
    rect 15 $((top + 13)) 2 1 "$soft"
    polygon "12,20 16,18 20,20 19,26 16,28 13,26" "$accent"
    rect 14 21 4 5 "$outline"
    rect 15 22 2 3 "$core"
    rect $((9 + inset)) $((bottom - 2)) 6 2 "$detail"
    rect $((17 - inset)) $((bottom - 2)) 6 2 "$detail"
}

draw_loophare() {
    local stage="$1" behavior="$2" frame="$3"
    local inset=2 head_top=11 ear_top=3 bottom=29
    case "$stage" in
        junior) inset=1; head_top=9; ear_top=1; bottom=30 ;;
        adult) inset=0; head_top=8; ear_top=0; bottom=31 ;;
    esac
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        polygon "13,10 8,9 3,5 1,6 6,12 12,14" "$outline"
        polygon "19,10 24,9 29,5 31,6 26,12 20,14" "$outline"
        polygon "12,11 8,10 4,7 6,11 11,13" "$accent"
        polygon "20,11 24,10 28,7 26,11 21,13" "$accent"
    else
        polygon "$((9 + inset)),$((head_top + 3)) $((8 + inset)),$((ear_top + 3)) $((10 + inset)),$ear_top $((14 + inset)),$((ear_top + 2)) $((15 + inset)),$((head_top + 4))" "$outline"
        polygon "$((23 - inset)),$((head_top + 3)) $((24 - inset)),$((ear_top + 3)) $((22 - inset)),$ear_top $((18 - inset)),$((ear_top + 2)) $((17 - inset)),$((head_top + 4))" "$outline"
        polygon "$((10 + inset)),$((head_top + 1)) $((10 + inset)),$((ear_top + 3)) $((11 + inset)),$((ear_top + 2)) $((13 + inset)),$((ear_top + 3)) $((13 + inset)),$head_top" "$accent"
        polygon "$((22 - inset)),$((head_top + 1)) $((22 - inset)),$((ear_top + 3)) $((21 - inset)),$((ear_top + 2)) $((19 - inset)),$((ear_top + 3)) $((19 - inset)),$head_top" "$accent"
    fi
    polygon "$((10 + inset)),19 $((13 + inset)),17 $((20 - inset)),18 $((24 - inset)),22 $((24 - inset)),27 $((21 - inset)),$bottom $((11 + inset)),$bottom $((7 + inset)),27 $((8 + inset)),22" "$outline"
    polygon "$((12 + inset)),20 $((14 + inset)),19 $((19 - inset)),20 $((22 - inset)),22 $((22 - inset)),26 $((19 - inset)),$((bottom - 2)) $((12 + inset)),$((bottom - 2)) $((9 + inset)),26 $((10 + inset)),22" "$body"
    polygon "$((9 + inset)),$((head_top + 3)) $((12 + inset)),$head_top $((20 - inset)),$head_top $((23 - inset)),$((head_top + 3)) $((24 - inset)),$((head_top + 9)) $((21 - inset)),$((head_top + 14)) $((17 - inset)),$((head_top + 16)) $((12 + inset)),$((head_top + 14)) $((8 + inset)),$((head_top + 10)) $((8 + inset)),$((head_top + 5))" "$outline"
    polygon "$((11 + inset)),$((head_top + 3)) $((13 + inset)),$((head_top + 2)) $((19 - inset)),$((head_top + 2)) $((21 - inset)),$((head_top + 4)) $((22 - inset)),$((head_top + 9)) $((19 - inset)),$((head_top + 13)) $((16 - inset)),$((head_top + 14)) $((13 + inset)),$((head_top + 12)) $((10 + inset)),$((head_top + 9)) $((10 + inset)),$((head_top + 5))" "$body"
    rect $((12 + inset)) $((head_top + 6)) 2 3 "$outline"
    rect $((18 - inset)) $((head_top + 6)) 2 3 "$outline"
    rect $((13 + inset)) $((head_top + 6)) 1 1 "$core"
    rect $((18 - inset)) $((head_top + 6)) 1 1 "$core"
    rect 15 $((head_top + 10)) 2 2 "$accent"
    rect 12 $((head_top + 11)) 2 1 "$highlight"
    rect 14 22 4 5 "$outline"
    rect 15 23 2 3 "$core"
    polygon "$((7 + inset)),$((bottom - 3)) $((12 + inset)),$((bottom - 5)) $((16 + inset)),$((bottom - 2)) $((15 + inset)),$bottom $((6 + inset)),$bottom" "$outline"
    polygon "$((25 - inset)),$((bottom - 3)) $((20 - inset)),$((bottom - 5)) $((16 - inset)),$((bottom - 2)) $((17 - inset)),$bottom $((26 - inset)),$bottom" "$outline"
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
    polygon "$left,15 $((left + 3)),13 $((left + 5)),10 11,$((top + 2)) 14,$top 16,$((top - 2)) 18,$top 21,$((top + 2)) $((right - 5)),10 $((right - 3)),13 $right,15 $((right - 2)),19 $((right - 6)),21 22,$bottom 19,$((bottom + 1)) 16,$((bottom - 1)) 13,$((bottom + 1)) 10,$bottom $((left + 6)),21 $((left + 2)),19" "$outline"
    polygon "$((left + 2)),15 $((left + 5)),13 $((left + 7)),11 12,$((top + 3)) 16,$top 20,$((top + 3)) $((right - 7)),11 $((right - 5)),13 $((right - 2)),15 $((right - 4)),18 $((right - 7)),19 21,$((bottom - 1)) 18,$bottom 16,$((bottom - 2)) 14,$bottom 11,$((bottom - 1)) $((left + 7)),19 $((left + 4)),18" "$body"
    polygon "$((left + 4)),15 13,$((top + 3)) 16,$((top + 1)) 19,$((top + 3)) $((right - 4)),15 20,$((top + 5)) 12,$((top + 5))" "$highlight"
    polygon "14,$((bottom - 1)) 18,$((bottom - 1)) 19,$((tail - 3)) 17,$tail 16,$((tail - 1)) 15,$tail 13,$((tail - 3))" "$outline"
    polygon "15,$bottom 17,$bottom 17,$((tail - 3)) 16,$((tail - 1)) 15,$((tail - 3))" "$detail"
    rect 11 14 3 3 "$outline"
    rect 18 14 3 3 "$outline"
    rect 12 15 1 1 "$core"
    rect 19 15 1 1 "$core"
    rect 15 17 2 1 "$outline"
    rect 14 19 4 5 "$outline"
    rect 15 20 2 3 "$core"
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
    polygon "$((shell_x + 2)),$((shell_y + 6)) 7,11 4,13 7,17 $((shell_x + 2)),$((shell_y + 11))" "$outline"
    polygon "$((shell_x + shell_w - 2)),$((shell_y + 6)) 25,11 28,13 25,17 $((shell_x + shell_w - 2)),$((shell_y + 11))" "$outline"
    polygon "7,15 $((5 - claw / 2)),14 1,11 0,7 3,5 $((claw + 2)),6 $((claw + 3)),9 $((claw + 1)),11 8,12" "$outline"
    polygon "5,13 3,12 2,10 2,8 4,7 $((claw + 1)),8 $((claw + 1)),9 4,10 6,11" "$accent"
    polygon "25,15 $((27 + claw / 2)),14 31,11 32,7 29,5 $((30 - claw)),6 $((29 - claw)),9 $((31 - claw)),11 24,12" "$outline"
    polygon "27,13 29,12 30,10 30,8 28,7 $((31 - claw)),8 $((31 - claw)),9 28,10 26,11" "$accent"
    polygon "$shell_x,$((shell_y + 5)) $((shell_x + 2)),$((shell_y + 1)) $((shell_x + 6)),$shell_y $((shell_x + shell_w - 6)),$shell_y $((shell_x + shell_w - 2)),$((shell_y + 1)) $((shell_x + shell_w)),$((shell_y + 5)) $((shell_x + shell_w - 1)),$((shell_y + 12)) $((shell_x + shell_w - 5)),$((shell_y + 15)) $((shell_x + 5)),$((shell_y + 15)) $((shell_x + 1)),$((shell_y + 12))" "$outline"
    polygon "$((shell_x + 2)),$((shell_y + 5)) $((shell_x + 3)),$((shell_y + 3)) $((shell_x + 7)),$((shell_y + 2)) $((shell_x + shell_w - 7)),$((shell_y + 2)) $((shell_x + shell_w - 3)),$((shell_y + 3)) $((shell_x + shell_w - 2)),$((shell_y + 6)) $((shell_x + shell_w - 3)),$((shell_y + 11)) $((shell_x + shell_w - 6)),$((shell_y + 13)) $((shell_x + 6)),$((shell_y + 13)) $((shell_x + 3)),$((shell_y + 11))" "$body"
    rect $((shell_x + 4)) $((shell_y + 3)) $((shell_w - 8)) 2 "$highlight"
    if [[ "$behavior" == working || "$behavior" == signature ]]; then
        polygon "$((shell_x + 2)),$((shell_y + 7)) 13,$((shell_y + 5)) 16,$((shell_y + 7)) 19,$((shell_y + 5)) $((shell_x + shell_w - 2)),$((shell_y + 7)) $((shell_x + shell_w - 4)),$((shell_y + 12)) 19,$((shell_y + 14)) 13,$((shell_y + 14)) $((shell_x + 4)),$((shell_y + 12))" "$detail"
        rect 12 $((shell_y + 7)) 8 7 "$outline"
        rect 14 $((shell_y + 9)) 4 3 "$core"
    else
        polygon "12,$((shell_y + 6)) 16,$((shell_y + 4)) 20,$((shell_y + 6)) 19,$((shell_y + 12)) 16,$((shell_y + 14)) 13,$((shell_y + 12))" "$detail"
        rect 13 $((shell_y + 7)) 6 6 "$outline"
        rect 15 $((shell_y + 9)) 2 2 "$core"
    fi
    rect $((shell_x + 3)) $((shell_y + 6)) 2 2 "$outline"
    rect $((shell_x + shell_w - 5)) $((shell_y + 6)) 2 2 "$outline"
    rect $((shell_x + 4)) $((shell_y + 6)) 1 1 "$soft"
    rect $((shell_x + shell_w - 4)) $((shell_y + 6)) 1 1 "$soft"
    polygon "10,23 7,24 5,27 2,28 2,30 8,30 11,27 13,27" "$outline"
    polygon "22,23 25,24 27,27 30,28 30,30 24,30 21,27 19,27" "$outline"
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
