#!/usr/bin/env python3
"""
Generate complete Generation 3 companion sprite sheets and manifests.
Species:
  - agentolotl (AgentAxolotl)
  - vectordragon (VectorDrake)
  - tensorchilla (TensorChilla)
  - synapsesloth (SynapseSloth)
  - gitgecko (GitGecko)
"""

import os
import json
import subprocess
import math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_ROOT = os.path.join(ROOT, "Sources", "TokeniBar", "CompanionAssets")

GEN3_SPECIES = {
    "agentolotl": {
        "displayName": "AgentAxolotl",
        "palette": ["#071426", "#FF94B8", "#E63980", "#FFE6EE", "#57F2E3"],
        "body_color": (255, 148, 184),
        "accent_color": (230, 57, 128),
        "highlight_color": (255, 230, 238),
        "core_color": (87, 242, 227),
        "outline_color": (7, 20, 38),
    },
    "vectordragon": {
        "displayName": "VectorDrake",
        "palette": ["#071426", "#4A3E8F", "#8E72E8", "#D1C4E9", "#57F2E3"],
        "body_color": (74, 62, 143),
        "accent_color": (142, 114, 232),
        "highlight_color": (209, 196, 233),
        "core_color": (87, 242, 227),
        "outline_color": (7, 20, 38),
    },
    "tensorchilla": {
        "displayName": "TensorChilla",
        "palette": ["#071426", "#7D8C99", "#C5D1D9", "#FFB347", "#57F2E3"],
        "body_color": (125, 140, 153),
        "accent_color": (255, 179, 71),
        "highlight_color": (197, 209, 217),
        "core_color": (87, 242, 227),
        "outline_color": (7, 20, 38),
    },
    "synapsesloth": {
        "displayName": "SynapseSloth",
        "palette": ["#071426", "#3A5A40", "#A3B18A", "#DAD7CD", "#57F2E3"],
        "body_color": (58, 90, 64),
        "accent_color": (163, 177, 138),
        "highlight_color": (218, 215, 205),
        "core_color": (87, 242, 227),
        "outline_color": (7, 20, 38),
    },
    "gitgecko": {
        "displayName": "GitGecko",
        "palette": ["#071426", "#0081A7", "#00AFB9", "#FED9B7", "#57F2E3"],
        "body_color": (0, 129, 167),
        "accent_color": (0, 175, 185),
        "highlight_color": (254, 217, 183),
        "core_color": (87, 242, 227),
        "outline_color": (7, 20, 38),
    },
}

STAGE_SCALES = {
    "hatchling": 0.65,
    "junior": 0.85,
    "adult": 1.05,
}

ANIMATION_DEF = {
    "idle": {"row": 0, "frameCount": 4, "fps": 2, "loops": True},
    "working": {"row": 1, "frameCount": 6, "fps": 6, "loops": True},
    "waiting": {"row": 2, "frameCount": 4, "fps": 2, "loops": True},
    "warning": {"row": 3, "frameCount": 4, "fps": 8, "loops": True},
    "celebrate": {"row": 4, "frameCount": 6, "fps": 8, "loops": True},
    "signature": {"row": 4, "frameCount": 6, "fps": 8, "loops": True},
    "sleep": {"row": 5, "frameCount": 4, "fps": 1, "loops": True},
}


class FrameCanvas:
    def __init__(self):
        self.pixels = {}  # (x, y) -> (r, g, b, a)

    def set(self, x, y, color):
        if 0 <= x < 64 and 0 <= y < 64:
            self.pixels[(int(x), int(y))] = color

    def fill_rect(self, x1, y1, x2, y2, color):
        for y in range(int(y1), int(y2) + 1):
            for x in range(int(x1), int(x2) + 1):
                self.set(x, y, color)

    def fill_ellipse(self, cx, cy, rx, ry, color):
        rx = max(rx, 1.0)
        ry = max(ry, 1.0)
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, color)

    def stroke_ellipse(self, cx, cy, rx, ry, color):
        rx = max(rx, 1.0)
        ry = max(ry, 1.0)
        for y in range(int(cy - ry - 2), int(cy + ry + 3)):
            for x in range(int(cx - rx - 2), int(cx + rx + 3)):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if 0.75 <= d <= 1.35:
                    self.set(x, y, color)


def render_species_frame(species_id, stage, row, col, variant):
    canvas = FrameCanvas()
    spec = GEN3_SPECIES[species_id]
    scale = STAGE_SCALES[stage]
    
    body = spec["body_color"]
    accent = spec["accent_color"]
    highlight = spec["highlight_color"]
    core = spec["core_color"]
    outline = spec["outline_color"]

    if variant == "legendary":
        # Prismatic gold / aura tint
        body = (min(255, int(body[0] * 1.1 + 40)), min(255, int(body[1] * 1.1 + 30)), int(body[2] * 0.7))
        accent = (255, 215, 106)
        highlight = (255, 245, 200)

    # Base positioning
    cx = 32.0
    cy = 34.0
    bounce_y = 0.0
    eye_closed = False
    working_prop = False

    if row == 0:  # idle
        bounce_y = 1.0 if col in (1, 2) else 0.0
    elif row == 1:  # working
        bounce_y = 0.5 if col % 2 == 0 else 0.0
        working_prop = True
    elif row == 2:  # waiting
        bounce_y = 0.0
        if col == 2:
            eye_closed = True
    elif row == 3:  # warning
        bounce_y = -1.0 if col % 2 == 1 else 0.0
    elif row == 4:  # celebrate / signature
        bounce_y = -4.0 if col in (2, 3) else (-2.0 if col in (1, 4) else 0.0)
    elif row == 5:  # sleep
        bounce_y = 4.0
        eye_closed = True

    cy += bounce_y

    # Draw body silhouette based on species
    if species_id == "agentolotl":
        # Axolotl: wide round head, stubby body, 6 external gills (or 8 in mutated), tail
        head_rx = 11.0 * scale
        head_ry = 9.0 * scale
        body_rx = 8.0 * scale
        body_ry = 7.0 * scale

        # Tail
        tail_dir = 1.0 if (col % 2 == 0) else -1.0
        canvas.fill_ellipse(cx + 8.0 * scale * tail_dir, cy + 8.0 * scale, 5.0 * scale, 3.0 * scale, accent)
        
        # Body
        canvas.fill_ellipse(cx, cy + 6.0 * scale, body_rx, body_ry, body)
        canvas.fill_ellipse(cx, cy + 6.0 * scale, body_rx * 0.6, body_ry * 0.6, highlight)
        
        # Head
        canvas.fill_ellipse(cx, cy - 2.0 * scale, head_rx, head_ry, body)

        # Gills
        gill_count = 4 if variant == "mutated" else 3
        for side in (-1.0, 1.0):
            for i in range(gill_count):
                gy = cy - 6.0 * scale + (i * 4.0 * scale)
                gx = cx + side * (head_rx + 2.0 * scale + (i * 1.5 * scale))
                gill_col = (87, 242, 227) if (variant == "mutated" and i == 3) else accent
                canvas.fill_ellipse(gx, gy, 3.0 * scale, 1.8 * scale, gill_col)
                canvas.set(gx + side, gy, outline)

        # Limbs
        canvas.fill_ellipse(cx - 7.0 * scale, cy + 9.0 * scale, 2.5 * scale, 2.0 * scale, body)
        canvas.fill_ellipse(cx + 7.0 * scale, cy + 9.0 * scale, 2.5 * scale, 2.0 * scale, body)

        # Face
        if eye_closed:
            canvas.fill_rect(cx - 5.0 * scale, cy - 2.0 * scale, cx - 3.0 * scale, cy - 2.0 * scale, outline)
            canvas.fill_rect(cx + 3.0 * scale, cy - 2.0 * scale, cx + 5.0 * scale, cy - 2.0 * scale, outline)
        else:
            eye_col = (87, 242, 227) if variant == "mutated" else outline
            canvas.fill_rect(cx - 6.0 * scale, cy - 3.0 * scale, cx - 3.0 * scale, cy - 1.0 * scale, eye_col)
            canvas.fill_rect(cx + 3.0 * scale, cy - 3.0 * scale, cx + 6.0 * scale, cy - 1.0 * scale, eye_col)
            canvas.set(cx - 4.0 * scale, cy - 3.0 * scale, (255, 255, 255))
            canvas.set(cx + 4.0 * scale, cy - 3.0 * scale, (255, 255, 255))

        # Core
        canvas.fill_ellipse(cx, cy + 4.0 * scale, 2.2 * scale, 2.2 * scale, core)

        if variant == "mutated":
            # Floating terminal hologram near hands
            canvas.fill_rect(cx - 10.0, cy + 2.0, cx - 6.0, cy + 6.0, (87, 242, 227))
            canvas.fill_rect(cx - 9.0, cy + 3.0, cx - 7.0, cy + 5.0, (11, 58, 99))

    elif species_id == "vectordragon":
        # Vector Drake: horns, sleek dragon body, wings, vector arrow tail
        head_rx = 9.0 * scale
        head_ry = 8.0 * scale
        body_rx = 7.0 * scale
        body_ry = 9.0 * scale

        # Wings
        wing_span = 14.0 * scale if row == 4 else 10.0 * scale
        canvas.fill_ellipse(cx - wing_span * 0.7, cy + 1.0 * scale, wing_span * 0.6, 4.0 * scale, accent)
        canvas.fill_ellipse(cx + wing_span * 0.7, cy + 1.0 * scale, wing_span * 0.6, 4.0 * scale, accent)

        # Body
        canvas.fill_ellipse(cx, cy + 5.0 * scale, body_rx, body_ry, body)
        canvas.fill_ellipse(cx, cy + 5.0 * scale, body_rx * 0.5, body_ry * 0.7, highlight)

        # Tail with Arrow
        canvas.fill_ellipse(cx + 9.0 * scale, cy + 10.0 * scale, 6.0 * scale, 3.0 * scale, body)
        canvas.fill_rect(cx + 13.0 * scale, cy + 9.0 * scale, cx + 15.0 * scale, cy + 11.0 * scale, accent)

        # Head & Horns
        canvas.fill_ellipse(cx, cy - 3.0 * scale, head_rx, head_ry, body)
        horn_size = 6.0 * scale if variant == "mutated" else 3.5 * scale
        horn_col = (87, 242, 227) if variant == "mutated" else highlight
        canvas.fill_rect(cx - 6.0 * scale, cy - 8.0 * scale - (horn_size * 0.5), cx - 4.0 * scale, cy - 4.0 * scale, horn_col)
        canvas.fill_rect(cx + 4.0 * scale, cy - 8.0 * scale - (horn_size * 0.5), cx + 6.0 * scale, cy - 4.0 * scale, horn_col)

        # Eyes
        if eye_closed:
            canvas.fill_rect(cx - 5.0 * scale, cy - 3.0 * scale, cx - 2.0 * scale, cy - 3.0 * scale, outline)
            canvas.fill_rect(cx + 2.0 * scale, cy - 3.0 * scale, cx + 5.0 * scale, cy - 3.0 * scale, outline)
        else:
            canvas.fill_rect(cx - 5.0 * scale, cy - 4.0 * scale, cx - 2.0 * scale, cy - 2.0 * scale, (255, 215, 106))
            canvas.fill_rect(cx + 2.0 * scale, cy - 4.0 * scale, cx + 5.0 * scale, cy - 2.0 * scale, (255, 215, 106))
            canvas.set(cx - 3.0 * scale, cy - 3.0 * scale, outline)
            canvas.set(cx + 3.0 * scale, cy - 3.0 * scale, outline)

        # Core
        canvas.fill_ellipse(cx, cy + 3.0 * scale, 2.2 * scale, 2.2 * scale, core)

        if variant == "mutated":
            # 3 orbiting vector nodes
            canvas.fill_rect(cx - 12.0, cy - 6.0, cx - 10.0, cy - 4.0, (87, 242, 227))
            canvas.fill_rect(cx + 10.0, cy - 6.0, cx + 12.0, cy - 4.0, (87, 242, 227))
            canvas.fill_rect(cx, cy - 14.0, cx + 2.0, cy - 12.0, (255, 215, 106))

    elif species_id == "tensorchilla":
        # Tensor Chilla: fluffy round body, round ears, big plush tail, holding tensor cube
        body_r = 11.0 * scale
        canvas.fill_ellipse(cx, cy + 3.0 * scale, body_r, body_r * 0.9, body)
        canvas.fill_ellipse(cx, cy + 4.0 * scale, body_r * 0.6, body_r * 0.7, highlight)

        # Huge plush tail
        tail_r = 10.0 * scale if variant == "mutated" else 7.0 * scale
        canvas.fill_ellipse(cx + 10.0 * scale, cy + 6.0 * scale, tail_r, tail_r * 0.8, highlight)
        canvas.fill_ellipse(cx + 10.0 * scale, cy + 6.0 * scale, tail_r * 0.6, tail_r * 0.5, body)

        # Big round ears
        canvas.fill_ellipse(cx - 7.0 * scale, cy - 9.0 * scale, 4.5 * scale, 5.0 * scale, body)
        canvas.fill_ellipse(cx - 7.0 * scale, cy - 9.0 * scale, 2.5 * scale, 3.0 * scale, highlight)
        canvas.fill_ellipse(cx + 7.0 * scale, cy - 9.0 * scale, 4.5 * scale, 5.0 * scale, body)
        canvas.fill_ellipse(cx + 7.0 * scale, cy - 9.0 * scale, 2.5 * scale, 3.0 * scale, highlight)

        # Eyes & Nose
        if eye_closed:
            canvas.fill_rect(cx - 5.0 * scale, cy - 1.0 * scale, cx - 2.0 * scale, cy - 1.0 * scale, outline)
            canvas.fill_rect(cx + 2.0 * scale, cy - 1.0 * scale, cx + 5.0 * scale, cy - 1.0 * scale, outline)
        else:
            canvas.fill_rect(cx - 5.0 * scale, cy - 2.0 * scale, cx - 2.0 * scale, cy, outline)
            canvas.fill_rect(cx + 2.0 * scale, cy - 2.0 * scale, cx + 5.0 * scale, cy, outline)
            canvas.set(cx - 4.0 * scale, cy - 2.0 * scale, (255, 255, 255))
            canvas.set(cx + 4.0 * scale, cy - 2.0 * scale, (255, 255, 255))
        canvas.set(cx, cy, (255, 179, 71))  # cute nose

        # Core
        canvas.fill_ellipse(cx, cy + 5.0 * scale, 2.2 * scale, 2.2 * scale, core)

        # Tensor cube prop in hands
        cube_y = cy + 2.0 * scale + (0.5 if col % 2 == 0 else -0.5)
        canvas.fill_rect(cx - 3.0, cube_y, cx + 3.0, cube_y + 5.0, accent)
        canvas.set(cx - 1.0, cube_y + 1.0, (255, 255, 255))

        if variant == "mutated":
            # Floating rotating matrix above head
            canvas.fill_rect(cx - 6.0, cy - 16.0, cx - 3.0, cy - 13.0, (87, 242, 227))
            canvas.fill_rect(cx + 3.0, cy - 16.0, cx + 6.0, cy - 13.0, (255, 179, 71))
            canvas.fill_rect(cx - 1.5, cy - 14.0, cx + 1.5, cy - 11.0, (164, 104, 255))

    elif species_id == "synapsesloth":
        # Synapse Sloth: curved body, hanging claws, sleepy mask face, neural synapse lines
        body_rx = 9.0 * scale
        body_ry = 10.0 * scale
        canvas.fill_ellipse(cx, cy + 4.0 * scale, body_rx, body_ry, body)

        # Sloth face mask
        canvas.fill_ellipse(cx, cy - 2.0 * scale, 7.0 * scale, 5.5 * scale, highlight)
        canvas.fill_rect(cx - 5.0 * scale, cy - 3.0 * scale, cx - 2.0 * scale, cy - 1.0 * scale, accent)
        canvas.fill_rect(cx + 2.0 * scale, cy - 3.0 * scale, cx + 5.0 * scale, cy - 1.0 * scale, accent)

        # Eyes
        if eye_closed:
            canvas.fill_rect(cx - 4.0 * scale, cy - 2.0 * scale, cx - 2.0 * scale, cy - 2.0 * scale, outline)
            canvas.fill_rect(cx + 2.0 * scale, cy - 2.0 * scale, cx + 4.0 * scale, cy - 2.0 * scale, outline)
        else:
            eye_col = (87, 242, 227) if variant == "mutated" else outline
            canvas.set(cx - 3.0 * scale, cy - 2.0 * scale, eye_col)
            canvas.set(cx + 3.0 * scale, cy - 2.0 * scale, eye_col)

        # Claws / Arms
        canvas.fill_ellipse(cx - 8.0 * scale, cy + 7.0 * scale, 3.0 * scale, 4.0 * scale, body)
        canvas.fill_ellipse(cx + 8.0 * scale, cy + 7.0 * scale, 3.0 * scale, 4.0 * scale, body)
        canvas.fill_rect(cx - 9.0 * scale, cy + 10.0 * scale, cx - 7.0 * scale, cy + 12.0 * scale, highlight)
        canvas.fill_rect(cx + 7.0 * scale, cy + 10.0 * scale, cx + 9.0 * scale, cy + 12.0 * scale, highlight)

        # Core
        canvas.fill_ellipse(cx, cy + 4.0 * scale, 2.2 * scale, 2.2 * scale, core)

        # Synapse branch lines
        if variant == "mutated":
            for br in (-1.0, 1.0):
                canvas.fill_rect(cx + br * 8.0, cy - 6.0, cx + br * 12.0, cy - 5.0, (87, 242, 227))
                canvas.set(cx + br * 13.0, cy - 7.0, (164, 104, 255))
                canvas.set(cx + br * 13.0, cy - 4.0, (87, 242, 227))

    elif species_id == "gitgecko":
        # Git Gecko: agile lizard silhouette, wide eye, nano-pad toes, branched commit tail
        head_rx = 7.5 * scale
        head_ry = 6.5 * scale
        body_rx = 6.0 * scale
        body_ry = 9.0 * scale

        # Body
        canvas.fill_ellipse(cx, cy + 3.0 * scale, body_rx, body_ry, body)
        canvas.fill_ellipse(cx, cy + 3.0 * scale, body_rx * 0.6, body_ry * 0.7, highlight)

        # Head
        canvas.fill_ellipse(cx, cy - 4.0 * scale, head_rx, head_ry, body)

        # Big curious gecko eyes on side of head
        if eye_closed:
            canvas.fill_rect(cx - 7.0 * scale, cy - 5.0 * scale, cx - 5.0 * scale, cy - 5.0 * scale, outline)
            canvas.fill_rect(cx + 5.0 * scale, cy - 5.0 * scale, cx + 7.0 * scale, cy - 5.0 * scale, outline)
        else:
            canvas.fill_ellipse(cx - 6.0 * scale, cy - 5.0 * scale, 2.5 * scale, 2.5 * scale, (254, 217, 183))
            canvas.fill_ellipse(cx + 6.0 * scale, cy - 5.0 * scale, 2.5 * scale, 2.5 * scale, (254, 217, 183))
            canvas.set(cx - 6.0 * scale, cy - 5.0 * scale, outline)
            canvas.set(cx + 6.0 * scale, cy - 5.0 * scale, outline)

        # Nano-pad legs
        for side in (-1.0, 1.0):
            canvas.fill_ellipse(cx + side * 8.0 * scale, cy + 1.0 * scale, 3.0 * scale, 2.0 * scale, accent)
            canvas.fill_ellipse(cx + side * 8.0 * scale, cy + 8.0 * scale, 3.0 * scale, 2.0 * scale, accent)

        # Tail: branched with commit dots
        tail_split = 3 if variant == "mutated" else 1
        for t in range(tail_split):
            tx_off = (t - 1) * 4.0 if tail_split > 1 else 0.0
            canvas.fill_ellipse(cx + tx_off, cy + 12.0 * scale + (t * 2.0), 3.0 * scale, 4.0 * scale, body)
            # Commit node dot
            canvas.set(cx + tx_off, cy + 14.0 * scale + (t * 2.0), core)

        # Core
        canvas.fill_ellipse(cx, cy + 2.0 * scale, 2.2 * scale, 2.2 * scale, core)

    # Add laptop / working prop in working animation (Row 1)
    if working_prop and col in (1, 2, 3, 4):
        prop_x = cx + 10.0 * scale
        prop_y = cy + 4.0 * scale
        canvas.fill_rect(prop_x - 3.0, prop_y - 2.0, prop_x + 3.0, prop_y + 3.0, (11, 58, 99))
        canvas.fill_rect(prop_x - 2.0, prop_y - 1.0, prop_x + 2.0, prop_y + 1.0, (87, 242, 227))

    # Add sleep Z in sleep animation (Row 5)
    if row == 5:
        zx = cx + 8.0 * scale
        zy = cy - 8.0 * scale - (col * 1.5)
        canvas.fill_rect(zx, zy, zx + 3.0, zy, (87, 242, 227))
        canvas.set(zx + 2.0, zy + 1.0, (87, 242, 227))
        canvas.set(zx + 1.0, zy + 2.0, (87, 242, 227))
        canvas.fill_rect(zx, zy + 3.0, zx + 3.0, zy + 3.0, (87, 242, 227))

    return canvas


def build_sheet(species_id, stage, variant):
    raw = bytearray(512 * 384 * 4)

    for row_name, anim in ANIMATION_DEF.items():
        row = anim["row"]
        frame_count = anim["frameCount"]
        for col in range(frame_count):
            canvas = render_species_frame(species_id, stage, row, col, variant)
            ox = col * 64
            oy = row * 64
            for (lx, ly), (r, g, b) in canvas.pixels.items():
                if 0 <= lx < 64 and 0 <= ly < 64:
                    idx = ((oy + ly) * 512 + (ox + lx)) * 4
                    raw[idx] = r
                    raw[idx + 1] = g
                    raw[idx + 2] = b
                    raw[idx + 3] = 255

    return raw


def write_png(raw, path):
    cmd = [
        "ffmpeg", "-v", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgba",
        "-s", "512x384", "-i", "-",
        "-frames:v", "1", path
    ]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    p.communicate(input=bytes(raw))
    if p.returncode != 0:
        raise RuntimeError(f"Failed to write PNG: {path}")


def write_manifest(species_id, spec, dir_path):
    palette_json = json.dumps(spec["palette"])
    # Read template
    with open(os.path.join(ROOT, "Scripts", "companion-manifest.template.json"), "r") as f:
        template = f.read()
    manifest_content = template.replace("__ID__", species_id)\
                               .replace("__DISPLAY_NAME__", spec["displayName"])\
                               .replace("__PALETTE__", palette_json[1:-1])  # strip brackets
    with open(os.path.join(dir_path, "manifest.json"), "w") as f:
        f.write(manifest_content)


def main():
    for species_id, spec in GEN3_SPECIES.items():
        species_dir = os.path.join(ASSET_ROOT, species_id)
        os.makedirs(species_dir, exist_ok=True)

        for stage in ("hatchling", "junior", "adult"):
            for variant in ("normal", "legendary", "mutated"):
                filename = f"{stage}-{variant}.png"
                out_path = os.path.join(species_dir, filename)
                raw = build_sheet(species_id, stage, variant)
                write_png(raw, out_path)
                print(f"Generated {species_id}/{filename}")

        write_manifest(species_id, spec, species_dir)
        print(f"Generated {species_id}/manifest.json")


if __name__ == "__main__":
    main()
