#!/usr/bin/env python3
"""
Generate distinct mutated sprite sheets for all companion species.
Applies species-specific morphological mutations (hypertrophy, extra limbs, void cores, etc.)
and distinctive cyber-neon/mutation accents.
"""

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_ROOT = os.path.join(ROOT, "Sources", "TokeniBar", "CompanionAssets")

SPECIES_LIST = [
    "bytebot",
    "cachecat",
    "stackfox",
    "promptpup",
    "nullslime",
    "queryowl",
    "patchpanda",
    "loophare",
    "relayray",
    "kernelcrab",
]

STAGE_CONFIGS = {
    "bytebot": [
        ("hatchling", "baby.png", "hatchling-mutated.png"),
        ("junior", "junior-normal.png", "junior-mutated.png"),
        ("adult", "adult.png", "adult-mutated.png"),
    ],
    "default": [
        ("hatchling", "hatchling-normal.png", "hatchling-mutated.png"),
        ("junior", "junior-normal.png", "junior-mutated.png"),
        ("adult", "adult-normal.png", "adult-mutated.png"),
    ],
}


def read_sheet(path):
    cmd = [
        "ffmpeg",
        "-v",
        "error",
        "-y",
        "-i",
        path,
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgba",
        "-",
    ]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    data, _ = p.communicate()
    if p.returncode != 0 or len(data) != 512 * 384 * 4:
        raise RuntimeError(f"Failed to read sheet: {path}")
    return bytearray(data)


def write_sheet(data, path):
    cmd = [
        "ffmpeg",
        "-v",
        "error",
        "-y",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgba",
        "-s",
        "512x384",
        "-i",
        "-",
        "-frames:v",
        "1",
        path,
    ]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    p.communicate(input=bytes(data))
    if p.returncode != 0:
        raise RuntimeError(f"Failed to write sheet: {path}")


class SheetBuffer:
    def __init__(self, data):
        self.data = data
        self.width = 512
        self.height = 384

    def get_pixel(self, x, y):
        if not (0 <= x < self.width and 0 <= y < self.height):
            return 0, 0, 0, 0
        idx = (y * self.width + x) * 4
        return (
            self.data[idx],
            self.data[idx + 1],
            self.data[idx + 2],
            self.data[idx + 3],
        )

    def set_pixel(self, x, y, r, g, b, a=255):
        if not (0 <= x < self.width and 0 <= y < self.height):
            return
        idx = (y * self.width + x) * 4
        self.data[idx] = r
        self.data[idx + 1] = g
        self.data[idx + 2] = b
        self.data[idx + 3] = a

    def blend_pixel(self, x, y, r, g, b, a):
        if not (0 <= x < self.width and 0 <= y < self.height):
            return
        br, bg, bb, ba = self.get_pixel(x, y)
        if ba == 0:
            self.set_pixel(x, y, r, g, b, a)
            return
        alpha = a / 255.0
        inv_a = 1.0 - alpha
        out_r = int(r * alpha + br * inv_a)
        out_g = int(g * alpha + bg * inv_a)
        out_b = int(b * alpha + bb * inv_a)
        out_a = max(ba, a)
        self.set_pixel(x, y, out_r, out_g, out_b, out_a)


def mutate_cell(buf, col, row, species, stage):
    ox = col * 64
    oy = row * 64

    # 1. Analyze opaque pixels in the 64x64 cell
    opaque_pixels = []
    min_x, max_x = 64, -1
    min_y, max_y = 64, -1

    for ly in range(64):
        for lx in range(64):
            _, _, _, a = buf.get_pixel(ox + lx, oy + ly)
            if a > 20:
                opaque_pixels.append((lx, ly))
                min_x = min(min_x, lx)
                max_x = max(max_x, lx)
                min_y = min(min_y, ly)
                max_y = max(max_y, ly)

    if len(opaque_pixels) < 25:
        return  # empty frame

    cx = (min_x + max_x) // 2
    cy = (min_y + max_y) // 2

    # Apply species specific mutation
    if species == "bytebot":
        # 1) Triple Antenna: Find antenna top, add diagonal sub-antennae
        antenna_tips = [
            (lx, ly)
            for (lx, ly) in opaque_pixels
            if ly <= min_y + 2 and abs(lx - cx) <= 3
        ]
        if antenna_tips:
            tip_x = sum(lx for lx, ly in antenna_tips) // len(antenna_tips)
            tip_y = min(ly for lx, ly in antenna_tips)
            # Left sub-antenna
            for d in range(1, 4):
                buf.set_pixel(ox + tip_x - d - 1, oy + tip_y + d - 1, 11, 58, 99)
            buf.set_pixel(ox + tip_x - 5, oy + tip_y + 2, 164, 104, 255)
            buf.set_pixel(ox + tip_x - 6, oy + tip_y + 2, 87, 242, 227)
            # Right sub-antenna
            for d in range(1, 4):
                buf.set_pixel(ox + tip_x + d + 1, oy + tip_y + d - 1, 11, 58, 99)
            buf.set_pixel(ox + tip_x + 5, oy + tip_y + 2, 164, 104, 255)
            buf.set_pixel(ox + tip_x + 6, oy + tip_y + 2, 87, 242, 227)

        # 2) 4-Arm (Sub-arms): Add upper robotic arms above shoulders
        shoulder_y = cy - (2 if stage == "adult" else 1)
        arm_left_x = min_x - (3 if stage == "adult" else 2)
        if arm_left_x >= 2:
            buf.set_pixel(ox + arm_left_x, oy + shoulder_y - 2, 87, 242, 227)
            buf.set_pixel(ox + arm_left_x + 1, oy + shoulder_y - 2, 8, 107, 130)
            buf.set_pixel(ox + arm_left_x, oy + shoulder_y - 1, 8, 169, 174)
            buf.set_pixel(ox + arm_left_x + 1, oy + shoulder_y, 7, 27, 53)
        arm_right_x = max_x + (3 if stage == "adult" else 2)
        if arm_right_x <= 61:
            buf.set_pixel(ox + arm_right_x, oy + shoulder_y - 2, 87, 242, 227)
            buf.set_pixel(ox + arm_right_x - 1, oy + shoulder_y - 2, 8, 107, 130)
            buf.set_pixel(ox + arm_right_x, oy + shoulder_y - 1, 8, 169, 174)
            buf.set_pixel(ox + arm_right_x - 1, oy + shoulder_y, 7, 27, 53)

        # 3) Overclocked Visor / Eye tint: recolor cyan/yellow pixels to violet/neon pulse
        for lx, ly in opaque_pixels:
            r, g, b, a = buf.get_pixel(ox + lx, oy + ly)
            if g > 180 and r > 100:  # yellow
                buf.set_pixel(ox + lx, oy + ly, 255, 113, 99, a)
            elif g > 170 and b > 170:  # bright cyan
                buf.set_pixel(ox + lx, oy + ly, 164, 104, 255, a)

    elif species == "cachecat":
        # 1) Twin-tail (Nekomata Data Tails)
        tail_pixels = [
            (lx, ly)
            for (lx, ly) in opaque_pixels
            if lx >= max_x - 6 and ly <= cy + 4
        ]
        if tail_pixels:
            for lx, ly in tail_pixels:
                buf.set_pixel(ox + lx - 1, oy + ly - 4, 164, 104, 255)
                buf.set_pixel(ox + lx, oy + ly - 5, 240, 168, 50)
                buf.set_pixel(ox + lx + 1, oy + ly - 5, 87, 242, 227)
        # 2) Radar Ears: extend ear tips
        ear_tips = [
            (lx, ly)
            for (lx, ly) in opaque_pixels
            if ly <= min_y + 1 and (lx <= cx - 3 or lx >= cx + 3)
        ]
        for lx, ly in ear_tips:
            buf.set_pixel(ox + lx, oy + ly - 1, 23, 52, 92)
            buf.set_pixel(ox + lx, oy + ly - 2, 87, 242, 227)
        # 3) Eye glow: bright emerald
        for lx, ly in opaque_pixels:
            r, g, b, a = buf.get_pixel(ox + lx, oy + ly)
            if r > 200 and g > 200 and b > 120:
                if ly <= cy:
                    buf.set_pixel(ox + lx, oy + ly, 87, 242, 227, a)

    elif species == "stackfox":
        # 1) Stack Overflow 3-Tails: Multiply tail layers
        tail_pixels = [
            (lx, ly)
            for (lx, ly) in opaque_pixels
            if lx >= max_x - 8 and ly >= min_y + 3
        ]
        if tail_pixels:
            for lx, ly in tail_pixels:
                buf.blend_pixel(ox + lx - 2, oy + ly - 5, 232, 95, 24, 230)
                buf.blend_pixel(ox + lx, oy + ly - 6, 255, 155, 47, 255)
                buf.blend_pixel(ox + lx - 1, oy + ly + 4, 164, 104, 255, 220)
        # 2) Floating Stack Cubes
        if max_x <= 58:
            buf.set_pixel(ox + max_x + 2, oy + cy - 4, 255, 240, 179)
            buf.set_pixel(ox + max_x + 3, oy + cy - 4, 232, 95, 24)
            buf.set_pixel(ox + max_x + 2, oy + cy - 3, 164, 104, 255)
            buf.set_pixel(ox + max_x + 3, oy + cy - 3, 87, 242, 227)

    elif species == "promptpup":
        # 1) Winged Ears: Expand ears outward
        ear_pixels = [
            (lx, ly)
            for (lx, ly) in opaque_pixels
            if ly >= min_y + 2 and ly <= cy and (lx <= min_x + 3 or lx >= max_x - 3)
        ]
        for lx, ly in ear_pixels:
            if lx <= min_x + 3:
                buf.set_pixel(ox + lx - 3, oy + ly - 1, 33, 140, 120)
                buf.set_pixel(ox + lx - 4, oy + ly - 1, 124, 219, 167)
            else:
                buf.set_pixel(ox + lx + 3, oy + ly - 1, 33, 140, 120)
                buf.set_pixel(ox + lx + 4, oy + ly - 1, 124, 219, 167)
        # 2) Prompt Cursor Tail: Square block `>_` at tail tip
        tail_tips = [
            (lx, ly)
            for (lx, ly) in opaque_pixels
            if (lx <= min_x + 2 or lx >= max_x - 2) and ly <= cy - 1
        ]
        if tail_tips:
            tx, ty = tail_tips[0]
            buf.set_pixel(ox + tx - 2, oy + ty - 2, 87, 242, 227)
            buf.set_pixel(ox + tx - 1, oy + ty - 2, 87, 242, 227)
            buf.set_pixel(ox + tx - 2, oy + ty - 1, 87, 242, 227)
            buf.set_pixel(ox + tx - 1, oy + ty - 1, 7, 59, 66)

    elif species == "nullslime":
        # 1) Void Core: Punch a hollow hole right in the center
        hole_radius = 3 if stage == "hatchling" else 4
        for dy in range(-hole_radius, hole_radius + 1):
            for dx in range(-hole_radius, hole_radius + 1):
                dist_sq = dx * dx + dy * dy
                px, py = ox + cx + dx, oy + cy + dy
                if dist_sq < (hole_radius - 1) ** 2:
                    buf.set_pixel(px, py, 0, 0, 0, 0)
                elif dist_sq <= hole_radius**2:
                    buf.set_pixel(px, py, 84, 229, 242, 255)
        # 2) Crystalline Spikes
        top_pixels = [
            (lx, ly) for (lx, ly) in opaque_pixels if ly <= min_y + 1
        ]
        for lx, ly in top_pixels[::2]:
            buf.set_pixel(ox + lx, oy + ly - 2, 164, 104, 255)
            buf.set_pixel(ox + lx, oy + ly - 3, 84, 229, 242)

    elif species == "queryowl":
        # 1) Quad-Wing: Secondary wing layer
        wing_pixels = [
            (lx, ly)
            for (lx, ly) in opaque_pixels
            if (lx <= min_x + 3 or lx >= max_x - 3) and ly >= cy
        ]
        for lx, ly in wing_pixels:
            if lx <= min_x + 3:
                buf.blend_pixel(ox + lx - 2, oy + ly + 3, 66, 103, 168, 220)
                buf.blend_pixel(ox + lx - 3, oy + ly + 4, 87, 242, 227, 255)
            else:
                buf.blend_pixel(ox + lx + 2, oy + ly + 3, 66, 103, 168, 220)
                buf.blend_pixel(ox + lx + 3, oy + ly + 4, 87, 242, 227, 255)
        # 2) Third Eye / Tri-Sensor
        eye_y = min_y + (4 if stage == "adult" else 3)
        buf.set_pixel(ox + cx, oy + eye_y - 1, 255, 215, 106)
        buf.set_pixel(ox + cx, oy + eye_y, 87, 242, 227)
        buf.set_pixel(ox + cx - 1, oy + eye_y, 7, 20, 38)
        buf.set_pixel(ox + cx + 1, oy + eye_y, 7, 20, 38)

    elif species == "patchpanda":
        # 1) Frankenstein Pixel Stitch
        for ly in range(min_y + 3, max_y - 2, 4):
            buf.set_pixel(ox + cx - 1, oy + ly, 255, 130, 159)
            buf.set_pixel(ox + cx, oy + ly, 7, 20, 38)
            buf.set_pixel(ox + cx + 1, oy + ly, 255, 130, 159)
            buf.set_pixel(ox + cx, oy + ly - 1, 87, 242, 227)
            buf.set_pixel(ox + cx, oy + ly + 1, 87, 242, 227)
        # 2) Chimeric contrast
        for lx, ly in opaque_pixels:
            if lx < cx:
                r, g, b, a = buf.get_pixel(ox + lx, oy + ly)
                if r > 200 and g > 200 and b > 180:
                    buf.set_pixel(ox + lx, oy + ly, 180, 150, 220, a)

    elif species == "loophare":
        # 1) Mobius Infinity Ears
        ear_tips = [
            (lx, ly) for (lx, ly) in opaque_pixels if ly <= min_y + 2
        ]
        if len(ear_tips) >= 2:
            left_ear_x = min(lx for lx, ly in ear_tips)
            right_ear_x = max(lx for lx, ly in ear_tips)
            top_y = min(ly for lx, ly in ear_tips)
            for x in range(left_ear_x, right_ear_x + 1):
                arch_y = top_y - 2 if abs(x - cx) < 3 else top_y - 1
                buf.set_pixel(ox + x, oy + arch_y, 217, 154, 239)
                buf.set_pixel(ox + x, oy + arch_y - 1, 87, 242, 227)
        # 2) Foot dashes
        for lx, ly in opaque_pixels:
            if ly >= max_y - 1:
                buf.blend_pixel(ox + lx, oy + ly + 1, 112, 230, 193, 200)

    elif species == "relayray":
        # 1) Stealth Fin Segments
        wing_edges = [
            (lx, ly)
            for (lx, ly) in opaque_pixels
            if (lx <= min_x + 2 or lx >= max_x - 2)
        ]
        for lx, ly in wing_edges[::2]:
            if lx <= min_x + 2:
                buf.set_pixel(ox + lx - 2, oy + ly - 1, 35, 99, 125)
                buf.set_pixel(ox + lx - 3, oy + ly - 1, 87, 242, 227)
            else:
                buf.set_pixel(ox + lx + 2, oy + ly - 1, 35, 99, 125)
                buf.set_pixel(ox + lx + 3, oy + ly - 1, 87, 242, 227)
        # 2) Tail Packet Spike
        tail_tips = [
            (lx, ly) for (lx, ly) in opaque_pixels if ly >= max_y - 1
        ]
        if tail_tips:
            tx, ty = tail_tips[0]
            buf.set_pixel(ox + tx, oy + ty + 2, 243, 218, 117)
            buf.set_pixel(ox + tx - 1, oy + ty + 2, 87, 242, 227)
            buf.set_pixel(ox + tx + 1, oy + ty + 2, 87, 242, 227)

    elif species == "kernelcrab":
        # 1) Hypertrophied Claw: Enlarge left claw
        left_claw = [
            (lx, ly)
            for (lx, ly) in opaque_pixels
            if lx <= min_x + 6 and ly <= cy + 2
        ]
        for lx, ly in left_claw:
            buf.blend_pixel(ox + lx - 3, oy + ly - 2, 226, 109, 98, 255)
            buf.blend_pixel(ox + lx - 4, oy + ly - 2, 255, 182, 92, 255)
            buf.blend_pixel(ox + lx - 3, oy + ly - 3, 87, 242, 227, 200)
        # 2) Exposed Core Vent
        for ly in range(cy - 2, cy + 3):
            buf.set_pixel(ox + cx, oy + ly, 87, 242, 227)
            buf.set_pixel(ox + cx - 1, oy + ly, 7, 20, 38)
            buf.set_pixel(ox + cx + 1, oy + ly, 7, 20, 38)


def process_sheet(src_path, dst_path, species, stage):
    data = read_sheet(src_path)
    buf = SheetBuffer(data)

    for row in range(6):
        for col in range(8):
            mutate_cell(buf, col, row, species, stage)

    write_sheet(buf.data, dst_path)
    print(f"Generated {species}/{os.path.basename(dst_path)}")


def main():
    for species in SPECIES_LIST:
        stages = STAGE_CONFIGS.get(species, STAGE_CONFIGS["default"])
        species_dir = os.path.join(ASSET_ROOT, species)
        for stage, src_file, dst_file in stages:
            src_path = os.path.join(species_dir, src_file)
            dst_path = os.path.join(species_dir, dst_file)
            if not os.path.exists(src_path):
                print(f"Warning: source file not found: {src_path}", file=sys.stderr)
                continue
            process_sheet(src_path, dst_path, species, stage)


if __name__ == "__main__":
    main()
