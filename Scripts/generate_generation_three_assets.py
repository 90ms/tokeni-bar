#!/usr/bin/env python3
"""
Generate Generation 3 companion sprite sheets and manifests.

Species:
  - agentolotl (AgentAxolotl)
  - vectordragon (VectorDrake)
  - tensorchilla (TensorChilla)
  - synapsesloth (SynapseSloth)
  - gitgecko (GitGecko)

The output follows the same visual contract as the generation 1/2 sheets that
were sliced from hand-drawn lifecycle references:

  - 64px cells on an 8x6 transparent sheet (512x384), one row per behavior.
  - Adult sprites fill roughly 52x50px of the cell, juniors ~40x42, hatchlings
    ~28x32, and every stage is a structurally different body (not a resize).
  - A 1px black outline around every body part, three-tone body shading with
    light from the upper left, and a cream belly/face patch.
  - Frames are drawn at 2x and box-filtered down so edges carry the same soft
    anti-aliased mix of colors as the downscaled reference art.
  - Row props match the older species: a laptop in the working row, a yellow
    "!" in warning, sparkles in celebrate, and rising "z" glyphs in sleep.
  - Mutations grow out of each species' own body features (extra gill fronds,
    longer horns, split tails) instead of detached accessories.

No third-party tools are required: PNGs are encoded with zlib directly.
"""

import json
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_ROOT = os.path.join(ROOT, "Sources", "TokeniBar", "CompanionAssets")

CELL = 64
SS = 3  # supersample factor
SHEET_W, SHEET_H = 512, 384

BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
CYAN = (87, 242, 227)
GOLD = (255, 215, 106)
CREAM_GOLD = (255, 245, 200)
LAPTOP_BODY = (11, 58, 99)
LAPTOP_SCREEN = (30, 90, 138)
WARN_YELLOW = (255, 215, 106)
SPARK_YELLOW = (255, 224, 138)
SPARK_PINK = (255, 155, 210)
SLEEP_PINK = (255, 143, 200)

GEN3_SPECIES = {
    "agentolotl": {
        "displayName": "AgentAxolotl",
        "palette": ["#071426", "#FF94B8", "#E63980", "#FFE6EE", "#57F2E3"],
        "body": (255, 148, 184),
        "accent": (230, 57, 128),
        "belly": (255, 230, 238),
        "eye": (30, 18, 40),
    },
    "vectordragon": {
        "displayName": "VectorDrake",
        "palette": ["#071426", "#4A3E8F", "#8E72E8", "#D1C4E9", "#57F2E3"],
        "body": (92, 78, 168),
        "accent": (142, 114, 232),
        "belly": (209, 196, 233),
        "eye": (255, 215, 106),
    },
    "tensorchilla": {
        "displayName": "TensorChilla",
        "palette": ["#071426", "#7D8C99", "#C5D1D9", "#FFB347", "#57F2E3"],
        "body": (136, 150, 163),
        "accent": (255, 179, 71),
        "belly": (216, 224, 230),
        "eye": (30, 24, 34),
    },
    "synapsesloth": {
        "displayName": "SynapseSloth",
        "palette": ["#071426", "#3A5A40", "#A3B18A", "#DAD7CD", "#57F2E3"],
        "body": (96, 128, 94),
        "accent": (163, 177, 138),
        "belly": (218, 215, 205),
        "eye": (38, 30, 28),
    },
    "gitgecko": {
        "displayName": "GitGecko",
        "palette": ["#071426", "#0081A7", "#00AFB9", "#FED9B7", "#57F2E3"],
        "body": (0, 141, 178),
        "accent": (0, 175, 185),
        "belly": (254, 217, 183),
        "eye": (24, 22, 30),
    },
}

STAGES = ("hatchling", "junior", "adult")
STAGE_SCALE = {"hatchling": 1.0, "junior": 0.88, "adult": 1.0}
GROUND_Y = 56.0

ANIMATION_DEF = {
    "idle": {"row": 0, "frameCount": 4, "fps": 2, "loops": True},
    "working": {"row": 1, "frameCount": 6, "fps": 6, "loops": True},
    "waiting": {"row": 2, "frameCount": 4, "fps": 2, "loops": True},
    "warning": {"row": 3, "frameCount": 4, "fps": 8, "loops": True},
    "celebrate": {"row": 4, "frameCount": 6, "fps": 8, "loops": True},
    "signature": {"row": 4, "frameCount": 6, "fps": 8, "loops": True},
    "sleep": {"row": 5, "frameCount": 4, "fps": 1, "loops": True},
}


# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------

def clamp(v):
    return max(0, min(255, int(round(v))))


def mix(a, b, t):
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, f):
    return tuple(clamp(v * f) for v in c)


def tones(base):
    """Shadow / base / light tones for three-step shading."""
    return shade(base, 0.68), base, mix(base, WHITE, 0.30)


def variant_colors(spec, variant):
    body, accent, belly, eye = spec["body"], spec["accent"], spec["belly"], spec["eye"]
    if variant == "legendary":
        body = mix(body, GOLD, 0.42)
        accent = mix(accent, GOLD, 0.30)
        belly = mix(belly, CREAM_GOLD, 0.55)
    elif variant == "mutated":
        eye = CYAN
    return body, accent, belly, eye


# ---------------------------------------------------------------------------
# Supersampled frame canvas
# ---------------------------------------------------------------------------

class Canvas:
    def __init__(self):
        self.n = CELL * SS
        self.px = bytearray(self.n * self.n * 4)
        # Stage transform: scale about the ground anchor (32, GROUND_Y).
        self.scale = 1.0
        self.dx = 0.0
        self.dy = 0.0

    def tx(self, x, y):
        return (32.0 + (x - 32.0) * self.scale + self.dx,
                GROUND_Y - (GROUND_Y - y) * self.scale + self.dy)

    def _set(self, ix, iy, color):
        if 0 <= ix < self.n and 0 <= iy < self.n:
            o = (iy * self.n + ix) * 4
            self.px[o] = color[0]
            self.px[o + 1] = color[1]
            self.px[o + 2] = color[2]
            self.px[o + 3] = 255

    def ellipse(self, cx, cy, rx, ry, color, raw=False):
        if not raw:
            cx, cy = self.tx(cx, cy)
            rx *= self.scale
            ry *= self.scale
        rx = max(rx, 0.55)
        ry = max(ry, 0.55)
        cx *= SS; cy *= SS; rx *= SS; ry *= SS
        for iy in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for ix in range(int(cx - rx) - 1, int(cx + rx) + 2):
                u = (ix + 0.5 - cx) / rx
                v = (iy + 0.5 - cy) / ry
                if u * u + v * v <= 1.0:
                    self._set(ix, iy, color)

    def rect(self, x1, y1, x2, y2, color, raw=False):
        if not raw:
            x1, y1 = self.tx(x1, y1)
            x2, y2 = self.tx(x2, y2)
        x1, x2 = sorted((x1, x2)); y1, y2 = sorted((y1, y2))
        for iy in range(int(y1 * SS), int(math.ceil(y2 * SS))):
            for ix in range(int(x1 * SS), int(math.ceil(x2 * SS))):
                self._set(ix, iy, color)

    def line(self, x1, y1, x2, y2, w, color):
        x1, y1 = self.tx(x1, y1)
        x2, y2 = self.tx(x2, y2)
        w *= self.scale
        steps = int(max(abs(x2 - x1), abs(y2 - y1)) * SS * 2) + 1
        for i in range(steps + 1):
            t = i / steps
            self.ellipse(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, w / 2, w / 2, color, raw=True)

    # -- shaded body parts ------------------------------------------------

    def blob(self, cx, cy, rx, ry, base, outline=True, light=True):
        """An outlined ellipse with upper-left lighting."""
        sh, bs, lt = tones(base)
        if outline:
            self.ellipse(cx, cy, rx + 1.0, ry + 1.0, BLACK)
        self.ellipse(cx, cy, rx, ry, sh)
        self.ellipse(cx - rx * 0.12, cy - ry * 0.16, rx * 0.90, ry * 0.86, bs)
        if light:
            self.ellipse(cx - rx * 0.36, cy - ry * 0.42, rx * 0.40, ry * 0.34, lt)

    def patch(self, cx, cy, rx, ry, color):
        """Unoutlined belly / face patch with a soft rim."""
        self.ellipse(cx, cy, rx, ry, shade(color, 0.90))
        self.ellipse(cx - rx * 0.1, cy - ry * 0.12, rx * 0.82, ry * 0.8, color)

    def eye(self, cx, cy, size, mode, color):
        """mode: open | closed | happy | wide"""
        if mode == "closed":
            self.line(cx - size * 1.1, cy, cx + size * 1.1, cy, 1.1, BLACK)
        elif mode == "happy":
            self.line(cx - size * 1.1, cy + size * 0.3, cx, cy - size * 0.6, 1.1, BLACK)
            self.line(cx, cy - size * 0.6, cx + size * 1.1, cy + size * 0.3, 1.1, BLACK)
        else:
            r = size * (1.18 if mode == "wide" else 1.0)
            self.ellipse(cx, cy, r * 0.85, r * 1.15, BLACK)
            if color != BLACK:
                self.ellipse(cx, cy + r * 0.15, r * 0.55, r * 0.8, color)
            self.ellipse(cx - r * 0.35, cy - r * 0.5, r * 0.32, r * 0.36, WHITE)

    # -- shared props -----------------------------------------------------

    def laptop(self, cx, top_y, w, screen_on):
        h = w * 0.46
        self.rect(cx - w / 2 - 1, top_y - 1, cx + w / 2 + 1, top_y + h + 1, BLACK)
        self.rect(cx - w / 2, top_y, cx + w / 2, top_y + h, LAPTOP_BODY)
        self.rect(cx - w / 2 + 1.5, top_y + 1.2, cx + w / 2 - 1.5, top_y + h * 0.62, LAPTOP_SCREEN)
        glow = CYAN if screen_on else mix(CYAN, LAPTOP_SCREEN, 0.55)
        self.rect(cx - w / 2 + 3, top_y + 2.4, cx - 1, top_y + 3.6, glow)
        self.rect(cx - w / 2 + 3, top_y + 4.6, cx + w * 0.22, top_y + 5.6, glow)
        self.rect(cx - w / 2 + 2, top_y + h * 0.72, cx + w / 2 - 2, top_y + h * 0.9, shade(LAPTOP_BODY, 1.5))

    def exclaim(self, cx, cy):
        self.rect(cx - 1.6, cy - 1, cx + 1.6, cy + 6.5, BLACK)
        self.rect(cx - 0.8, cy, cx + 0.8, cy + 4.2, WARN_YELLOW)
        self.rect(cx - 0.8, cy + 5, cx + 0.8, cy + 5.8, WARN_YELLOW)

    def sparkle(self, cx, cy, size, color):
        self.rect(cx - 0.55, cy - size, cx + 0.55, cy + size, color)
        self.rect(cx - size, cy - 0.55, cx + size, cy + 0.55, color)

    def zee(self, cx, cy, size, color):
        self.rect(cx - size, cy - size, cx + size, cy - size + 1, color)
        self.line(cx + size - 0.5, cy - size + 0.5, cx - size + 0.5, cy + size - 0.5, 1.0, color)
        self.rect(cx - size, cy + size - 1, cx + size, cy + size, color)

    # -- output ------------------------------------------------------------

    def downsample(self):
        out = bytearray(CELL * CELL * 4)
        n = self.n
        for y in range(CELL):
            for x in range(CELL):
                r = g = b = a = 0
                for sy in range(SS):
                    for sx in range(SS):
                        o = ((y * SS + sy) * n + (x * SS + sx)) * 4
                        pa = self.px[o + 3]
                        if pa:
                            r += self.px[o] * pa
                            g += self.px[o + 1] * pa
                            b += self.px[o + 2] * pa
                            a += pa
                oo = (y * CELL + x) * 4
                if a:
                    out[oo] = r // a
                    out[oo + 1] = g // a
                    out[oo + 2] = b // a
                    out[oo + 3] = a // (SS * SS)
        return out


# ---------------------------------------------------------------------------
# Pose selection per behavior row
# ---------------------------------------------------------------------------

def pose_for(row, col):
    p = {"dy": 0.0, "dx": 0.0, "eyes": "open", "arms": "rest", "laptop": False,
         "screen_on": False, "exclaim": False, "sparkle": False, "sleep": False,
         "zees": 0, "spread": 0.0, "tail_dir": 1.0 if col % 2 == 0 else -1.0}
    if row == 0:  # idle
        p["dy"] = (0.0, -1.0, 0.0, 1.0)[col]
    elif row == 1:  # working
        p["dy"] = 0.0 if col % 2 else -0.6
        p["laptop"] = True
        p["screen_on"] = col % 2 == 0
        p["arms"] = "laptop"
        p["eyes"] = "down"
    elif row == 2:  # waiting
        p["dx"] = (0.0, 1.0, 0.0, -1.0)[col]
        p["eyes"] = "happy" if col in (1, 2) else "open"
        p["arms"] = "together"
    elif row == 3:  # warning
        p["dx"] = (-1.0, 1.0, -1.0, 1.0)[col]
        p["eyes"] = "wide"
        p["exclaim"] = True
        p["exclaim_dy"] = -1.5 if col % 2 else 0.0
    elif row == 4:  # celebrate / signature
        p["dy"] = (0.0, -2.0, -4.0, -4.0, -2.0, 0.0)[col]
        p["arms"] = "up"
        p["eyes"] = "happy" if col in (2, 3) else "open"
        p["sparkle"] = True
        p["spread"] = 1.0
        p["phase"] = col % 2
    elif row == 5:  # sleep
        p["sleep"] = True
        p["eyes"] = "closed"
        p["zees"] = 1 + (col % 3)
        p["zee_dy"] = -col * 1.2
    return p


# ---------------------------------------------------------------------------
# Species renderers.  All geometry is in adult design space; the canvas
# transform scales it about the ground line per stage, and each stage also
# changes the body structure (hatchling = fused egg body, junior = short
# limbs, adult = full limbs and features).
# ---------------------------------------------------------------------------

def draw_feet(cv, body, cx, y, spread, stage):
    if stage == "hatchling":
        return
    r = 4.2 if stage == "adult" else 3.2
    cv.blob(cx - spread, y, r, 2.4, body, light=False)
    cv.blob(cx + spread, y, r, 2.4, body, light=False)


def draw_arms(cv, body, cx, shoulder_y, arms, stage, reach=11.0, size=3.4):
    if stage == "hatchling":
        # tiny nubs
        cv.blob(cx - 9.0, shoulder_y + 4.0, 2.2, 2.0, body, light=False)
        cv.blob(cx + 9.0, shoulder_y + 4.0, 2.2, 2.0, body, light=False)
        return
    if arms == "up":
        cv.blob(cx - reach, shoulder_y - 7.0, size, 4.6, body, light=False)
        cv.blob(cx + reach, shoulder_y - 7.0, size, 4.6, body, light=False)
    elif arms == "laptop":
        cv.blob(cx - 6.0, shoulder_y + 8.5, size, 2.6, body, light=False)
        cv.blob(cx + 6.0, shoulder_y + 8.5, size, 2.6, body, light=False)
    elif arms == "together":
        cv.blob(cx - 3.2, shoulder_y + 7.0, size, 2.8, body, light=False)
        cv.blob(cx + 3.2, shoulder_y + 7.0, size, 2.8, body, light=False)
    else:
        cv.blob(cx - reach, shoulder_y + 2.0, size, 5.0, body, light=False)
        cv.blob(cx + reach, shoulder_y + 2.0, size, 5.0, body, light=False)


def face(cv, eye, cx, cy, gap, size, mode, mouth=True):
    m = "open" if mode == "down" else mode
    dy = 1.0 if mode == "down" else 0.0
    cv.eye(cx - gap, cy + dy, size, m, eye)
    cv.eye(cx + gap, cy + dy, size, m, eye)
    if mouth and m != "closed":
        cv.line(cx - 1.4, cy + size * 2.2, cx + 1.4, cy + size * 2.2, 0.9, shade(eye, 1.4) if eye != CYAN else BLACK)


# -- AgentAxolotl -----------------------------------------------------------

def draw_agentolotl(cv, stage, pose, variant, colors):
    body, accent, belly, eye = colors
    cx = 32.0
    fronds = 4 if variant == "mutated" else 3
    if pose["sleep"]:
        cv.blob(cx + 12.0, 51.0, 8.0, 3.2, accent, light=False)  # tail
        cv.blob(cx, 49.0, 15.0, 7.5, body)                        # lying body
        cv.blob(cx - 8.0, 44.0, 10.5, 8.0, body)                  # head
        for i in range(fronds):
            gy = 38.0 + i * 3.2
            tip = CYAN if (variant == "mutated" and i == fronds - 1) else accent
            cv.blob(cx - 18.0 - i * 1.2, gy, 4.2 - i * 0.4, 1.6, tip, light=False)
        cv.patch(cx - 8.0, 47.0, 5.5, 3.0, belly)
        cv.eye(cx - 12.0, 43.0, 1.5, "closed", eye)
        cv.eye(cx - 4.5, 43.0, 1.5, "closed", eye)
        return
    if stage == "hatchling":
        cv.blob(cx + 10.0 * pose["tail_dir"], 52.0, 5.5, 2.6, accent, light=False)
        cv.blob(cx, 41.0, 12.5, 14.5, body)
        for side in (-1, 1):
            for i in range(2):
                cv.blob(cx + side * (12.0 + i * 0.8), 33.5 + i * 4.5, 3.0, 1.8, accent, light=False)
        cv.patch(cx, 49.5, 7.0, 4.2, belly)
        cv.ellipse(cx, 46.0, 2.2, 2.2, BLACK)
        cv.ellipse(cx, 46.0, 1.7, 1.7, CYAN)
        face(cv, eye, cx, 37.5, 4.8, 2.7, pose["eyes"])
        return
    head_y, head_rx, head_ry = (23.0, 13.0, 10.5) if stage == "adult" else (26.0, 12.0, 10.2)
    body_y, body_rx, body_ry = (42.0, 10.5, 11.0) if stage == "adult" else (43.0, 9.6, 10.5)
    # tail
    tail_len = 9.0 if stage == "adult" else 7.0
    cv.blob(cx + (body_rx + tail_len * 0.6) * pose["tail_dir"], body_y + 7.0, tail_len * 0.7, 3.2, accent, light=False)
    if variant == "mutated":
        cv.ellipse(cx + (body_rx + tail_len * 1.1) * pose["tail_dir"], body_y + 7.0, 2.0, 1.6, CYAN)
    draw_feet(cv, body, cx, 54.0, 6.0, stage)
    cv.blob(cx, body_y, body_rx, body_ry, body)
    cv.patch(cx, body_y + 3.0, body_rx * 0.62, body_ry * 0.62, belly)
    draw_arms(cv, body, cx, body_y - 6.0, pose["arms"], stage, reach=body_rx + 2.5)
    # external gills (the species' core organ)
    for side in (-1, 1):
        for i in range(fronds):
            gy = head_y - 6.0 + i * 4.2
            gx = cx + side * (head_rx + 1.5 + i * 1.6)
            length = (5.2 - i * 0.5) if stage == "adult" else (4.2 - i * 0.4)
            tip = CYAN if (variant == "mutated" and i == fronds - 1) else accent
            cv.blob(gx + side * length * 0.5, gy, length, 1.8, tip, light=False)
    cv.blob(cx, head_y, head_rx, head_ry, body)
    cv.patch(cx, head_y + 4.5, head_rx * 0.55, head_ry * 0.42, belly)
    # core on the chest
    cv.ellipse(cx, body_y - 3.0, 2.6, 2.6, BLACK)
    cv.ellipse(cx, body_y - 3.0, 2.0, 2.0, CYAN)
    face(cv, eye, cx, head_y + 0.5, 5.0, 2.7, pose["eyes"])


# -- VectorDrake ------------------------------------------------------------

def draw_vectordragon(cv, stage, pose, variant, colors):
    body, accent, belly, eye = colors
    cx = 32.0
    horn = CYAN if variant == "mutated" else mix(belly, WHITE, 0.3)
    if pose["sleep"]:
        cv.blob(cx - 14.0, 46.0, 7.0, 3.0, accent, light=False)  # wing
        cv.blob(cx + 13.0, 51.5, 7.5, 3.0, body, light=False)    # tail
        cv.line(cx + 18.0, 49.0, cx + 21.0, 51.5, 2.4, accent)
        cv.line(cx + 21.0, 51.5, cx + 18.0, 54.0, 2.4, accent)
        cv.blob(cx, 49.0, 14.0, 7.5, body)
        cv.blob(cx - 7.0, 43.0, 10.0, 8.0, body)
        cv.rect(cx - 12.0, 36.0, cx - 10.0, 40.0, horn)
        cv.rect(cx - 6.0, 35.0, cx - 4.0, 39.0, horn)
        cv.patch(cx - 7.0, 46.0, 5.0, 3.0, belly)
        cv.eye(cx - 11.0, 42.5, 1.5, "closed", eye)
        cv.eye(cx - 3.5, 42.5, 1.5, "closed", eye)
        return
    if stage == "hatchling":
        cv.blob(cx + 10.0 * pose["tail_dir"], 52.0, 5.5, 2.4, body, light=False)
        cv.blob(cx - 11.5, 45.0, 4.2, 2.6, accent, light=False)
        cv.blob(cx + 11.5, 45.0, 4.2, 2.6, accent, light=False)
        cv.blob(cx, 41.5, 12.0, 14.0, body)
        for side in (-1, 1):
            hx = cx + side * 5.5
            cv.line(hx, 30.0, hx + side * 1.0, 25.0, 3.6, BLACK)
            cv.line(hx, 30.0, hx + side * 1.0, 25.0, 2.0, horn)
        cv.patch(cx, 49.5, 7.0, 4.2, belly)
        cv.ellipse(cx, 46.0, 2.2, 2.2, BLACK)
        cv.ellipse(cx, 46.0, 1.7, 1.7, CYAN)
        face(cv, eye, cx, 38.0, 4.8, 2.6, pose["eyes"])
        return
    head_y, head_rx, head_ry = (23.0, 11.5, 10.5) if stage == "adult" else (26.0, 10.6, 10.2)
    body_y, body_rx, body_ry = (42.0, 10.0, 11.5) if stage == "adult" else (43.0, 9.0, 10.5)
    # wings (spread wider on celebrate; larger when mutated)
    span = (12.0 if stage == "adult" else 9.0) * (1.35 if variant == "mutated" else 1.0)
    span *= 1.0 + 0.35 * pose["spread"]
    lift = -3.0 * pose["spread"]
    for side in (-1, 1):
        wx = cx + side * (body_rx * 0.55 + span * 0.55)
        cv.blob(wx, body_y - 4.0 + lift, span * 0.6, 4.2 + pose["spread"], accent, light=False)
        if variant == "mutated":
            cv.line(wx - side * span * 0.2, body_y - 4.0 + lift, wx + side * span * 0.5, body_y - 6.0 + lift, 1.1, CYAN)
    # arrow tail (the vector)
    tdir = pose["tail_dir"]
    tail_len = 11.0 if stage == "adult" else 8.0
    tx = cx + tdir * (body_rx + tail_len * 0.55)
    cv.blob(tx, body_y + 8.0, tail_len * 0.6, 2.8, body, light=False)
    ax = tx + tdir * tail_len * 0.6
    cv.line(ax, body_y + 8.0, ax - tdir * 3.5, body_y + 4.8, 2.6, BLACK)
    cv.line(ax, body_y + 8.0, ax - tdir * 3.5, body_y + 11.2, 2.6, BLACK)
    cv.line(ax, body_y + 8.0, ax - tdir * 3.2, body_y + 5.3, 1.3, accent)
    cv.line(ax, body_y + 8.0, ax - tdir * 3.2, body_y + 10.7, 1.3, accent)
    draw_feet(cv, body, cx, 54.0, 5.5, stage)
    cv.blob(cx, body_y, body_rx, body_ry, body)
    cv.patch(cx, body_y + 2.5, body_rx * 0.6, body_ry * 0.66, belly)
    draw_arms(cv, body, cx, body_y - 6.0, pose["arms"], stage, reach=body_rx + 2.0, size=3.0)
    # horns grow with stage and mutation
    horn_h = (6.0 if stage == "adult" else 4.5) * (1.6 if variant == "mutated" else 1.0)
    for side in (-1, 1):
        hx = cx + side * head_rx * 0.5
        base_y = head_y - head_ry + 2.5
        tip_y = head_y - head_ry - horn_h
        cv.line(hx, base_y, hx + side * 1.8, tip_y, 5.0, BLACK)
        cv.ellipse(hx + side * 1.8, tip_y, 1.4, 1.4, BLACK)
        cv.line(hx, base_y, hx + side * 1.2, (base_y + tip_y) / 2, 3.2, horn)
        cv.line(hx + side * 1.2, (base_y + tip_y) / 2, hx + side * 1.8, tip_y, 1.8, horn)
    cv.blob(cx, head_y, head_rx, head_ry, body)
    cv.patch(cx, head_y + 4.0, head_rx * 0.5, head_ry * 0.36, belly)
    cv.ellipse(cx, body_y - 3.5, 2.6, 2.6, BLACK)
    cv.ellipse(cx, body_y - 3.5, 2.0, 2.0, CYAN)
    face(cv, eye, cx, head_y + 0.5, 4.8, 2.6, pose["eyes"])


# -- TensorChilla -----------------------------------------------------------

def draw_tensorchilla(cv, stage, pose, variant, colors):
    body, accent, belly, eye = colors
    cx = 32.0
    inner = CYAN if variant == "mutated" else mix(accent, WHITE, 0.35)
    if pose["sleep"]:
        cv.blob(cx + 12.0, 48.0, 10.0, 6.5, belly)  # plush tail
        cv.blob(cx + 12.0, 48.0, 6.0, 3.8, body, outline=False, light=False)
        cv.blob(cx - 2.0, 49.0, 13.0, 7.5, body)
        cv.blob(cx - 9.0, 43.0, 9.5, 8.0, body)
        for side in (-1, 1):
            ex = cx - 9.0 + side * 6.5
            cv.blob(ex, 35.5, 3.6, 3.8, body, light=False)
            cv.ellipse(ex, 35.8, 2.0, 2.2, inner)
        cv.patch(cx - 9.0, 46.0, 5.0, 3.0, belly)
        cv.eye(cx - 13.0, 43.0, 1.4, "closed", eye)
        cv.eye(cx - 5.0, 43.0, 1.4, "closed", eye)
        cv.ellipse(cx - 9.0, 45.6, 0.9, 0.7, accent)
        return
    if stage == "hatchling":
        cv.blob(cx + 11.0, 47.0, 7.0, 6.0, belly)
        cv.blob(cx, 42.0, 12.5, 13.5, body)
        for side in (-1, 1):
            cv.blob(cx + side * 8.0, 30.0, 4.4, 4.6, body, light=False)
            cv.ellipse(cx + side * 8.0, 30.3, 2.4, 2.7, inner)
        cv.patch(cx, 50.0, 7.0, 4.0, belly)
        cv.ellipse(cx, 46.5, 2.2, 2.2, BLACK)
        cv.ellipse(cx, 46.5, 1.7, 1.7, CYAN)
        face(cv, eye, cx, 38.5, 4.8, 2.6, pose["eyes"], mouth=False)
        cv.ellipse(cx, 42.5, 1.1, 0.9, accent)
        return
    head_y, head_rx, head_ry = (24.0, 12.0, 10.5) if stage == "adult" else (26.5, 11.0, 10.2)
    body_y, body_rx, body_ry = (42.5, 11.5, 10.5) if stage == "adult" else (43.5, 10.0, 10.0)
    # huge plush tail behind (hypertrophied when mutated)
    tr = (10.0 if stage == "adult" else 7.5) * (1.3 if variant == "mutated" else 1.0)
    tdir = pose["tail_dir"]
    cv.blob(cx + tdir * (body_rx + tr * 0.5), body_y - 2.0, tr, tr * 0.85, belly)
    cv.blob(cx + tdir * (body_rx + tr * 0.5), body_y - 1.0, tr * 0.55, tr * 0.5, body, outline=False, light=False)
    draw_feet(cv, body, cx, 54.0, 5.5, stage)
    cv.blob(cx, body_y, body_rx, body_ry, body)
    cv.patch(cx, body_y + 2.0, body_rx * 0.6, body_ry * 0.62, belly)
    # big round ears
    ear = 5.0 if stage == "adult" else 4.2
    for side in (-1, 1):
        ex = cx + side * head_rx * 0.72
        ey = head_y - head_ry * 0.75
        cv.blob(ex, ey, ear, ear * 1.05, body, light=False)
        cv.ellipse(ex, ey + 0.3, ear * 0.55, ear * 0.6, inner)
    cv.blob(cx, head_y, head_rx, head_ry, body)
    cv.patch(cx, head_y + 4.0, head_rx * 0.48, head_ry * 0.4, belly)
    cv.ellipse(cx, body_y - 3.0, 2.6, 2.6, BLACK)
    cv.ellipse(cx, body_y - 3.0, 2.0, 2.0, CYAN)
    face(cv, eye, cx, head_y + 0.5, 4.8, 2.6, pose["eyes"], mouth=False)
    cv.ellipse(cx, head_y + 4.2, 1.1, 0.8, accent)  # nose
    # tensor cube held in the paws (orange, cyan when mutated)
    if pose["arms"] in ("rest", "together") and not pose["laptop"]:
        cube = CYAN if variant == "mutated" else accent
        s = 3.2 if stage == "adult" else 2.6
        cy = body_y + 3.5
        cv.rect(cx - s - 1, cy - s - 1, cx + s + 1, cy + s + 1, BLACK)
        cv.rect(cx - s, cy - s, cx + s, cy + s, shade(cube, 0.75))
        cv.rect(cx - s, cy - s, cx + s * 0.4, cy + s * 0.4, cube)
        cv.rect(cx - s * 0.6, cy - s * 0.6, cx - s * 0.1, cy - s * 0.1, mix(cube, WHITE, 0.5))
        cv.blob(cx - s - 1.5, cy + 1.0, 2.8, 2.2, body, light=False)
        cv.blob(cx + s + 1.5, cy + 1.0, 2.8, 2.2, body, light=False)
    else:
        draw_arms(cv, body, cx, body_y - 6.0, pose["arms"], stage, reach=body_rx + 2.0, size=3.2)


# -- SynapseSloth -----------------------------------------------------------

def draw_synapsesloth(cv, stage, pose, variant, colors):
    body, accent, belly, eye = colors
    cx = 32.0
    mask_dark = shade(body, 0.55)
    if pose["sleep"]:
        cv.blob(cx, 49.5, 14.5, 7.5, body)
        cv.blob(cx - 8.0, 43.5, 10.0, 8.0, body)
        cv.patch(cx - 8.0, 44.5, 7.0, 5.0, belly)
        cv.blob(cx - 12.0, 43.0, 2.6, 1.8, mask_dark, outline=False, light=False)
        cv.blob(cx - 4.0, 43.0, 2.6, 1.8, mask_dark, outline=False, light=False)
        cv.eye(cx - 12.0, 43.0, 1.4, "closed", eye)
        cv.eye(cx - 4.0, 43.0, 1.4, "closed", eye)
        cv.blob(cx + 9.0, 45.0, 3.0, 5.0, body, light=False)  # arm resting
        cv.line(cx + 9.0, 49.0, cx + 10.5, 52.5, 1.4, accent)
        return
    if stage == "hatchling":
        cv.blob(cx, 41.5, 12.5, 14.5, body)
        cv.patch(cx, 37.5, 9.0, 6.5, belly)
        cv.blob(cx - 4.8, 37.5, 3.0, 2.3, mask_dark, outline=False, light=False)
        cv.blob(cx + 4.8, 37.5, 3.0, 2.3, mask_dark, outline=False, light=False)
        cv.ellipse(cx, 48.0, 2.2, 2.2, BLACK)
        cv.ellipse(cx, 48.0, 1.7, 1.7, CYAN)
        face(cv, eye, cx, 37.5, 4.8, 2.1, pose["eyes"], mouth=False)
        cv.line(cx - 1.4, 42.0, cx + 1.4, 42.0, 0.9, mask_dark)
        return
    head_y, head_rx, head_ry = (23.5, 12.0, 10.5) if stage == "adult" else (26.5, 11.0, 10.2)
    body_y, body_rx, body_ry = (42.0, 10.5, 11.5) if stage == "adult" else (43.0, 9.6, 10.5)
    draw_feet(cv, body, cx, 54.0, 5.0, stage)
    cv.blob(cx, body_y, body_rx, body_ry, body)
    cv.patch(cx, body_y + 2.5, body_rx * 0.55, body_ry * 0.6, belly)
    # long arms with claws (hanging, or raised)
    arm_len = 9.0 if stage == "adult" else 7.0
    if variant == "mutated":
        arm_len *= 1.25
    for side in (-1, 1):
        if pose["arms"] == "up":
            ax, ay = cx + side * (body_rx + 4.0), body_y - 12.0
            cv.blob(ax, ay, 3.2, arm_len * 0.5, body, light=False)
            for k in (-1, 0, 1):
                cv.line(ax + k * 1.6, ay - arm_len * 0.5, ax + k * 2.0, ay - arm_len * 0.5 - 3.0, 1.2, accent)
        elif pose["arms"] == "laptop":
            cv.blob(cx + side * 6.0, body_y + 2.5, 3.2, 2.6, body, light=False)
        else:
            ax, ay = cx + side * (body_rx + 3.5), body_y + 1.0
            cv.blob(ax, ay, 3.2, arm_len * 0.5, body, light=False)
            for k in (-1, 0, 1):
                cv.line(ax + k * 1.6, ay + arm_len * 0.5, ax + k * 2.0, ay + arm_len * 0.5 + 3.0, 1.2, accent)
    cv.blob(cx, head_y, head_rx, head_ry, body)
    cv.patch(cx, head_y + 1.0, head_rx * 0.7, head_ry * 0.6, belly)
    cv.blob(cx - 4.8, head_y + 0.5, 3.0, 2.2, mask_dark, outline=False, light=False)
    cv.blob(cx + 4.8, head_y + 0.5, 3.0, 2.2, mask_dark, outline=False, light=False)
    if variant == "mutated":
        # synapse traces growing out of the mask
        for side in (-1, 1):
            cv.line(cx + side * 6.5, head_y - 1.5, cx + side * (head_rx + 1.5), head_y - 5.5, 1.1, CYAN)
            cv.line(cx + side * (head_rx + 1.5), head_y - 5.5, cx + side * (head_rx + 3.0), head_y - 3.5, 1.1, CYAN)
            cv.ellipse(cx + side * (head_rx + 3.2), head_y - 3.4, 1.1, 1.1, CYAN)
    cv.ellipse(cx, body_y - 3.5, 2.6, 2.6, BLACK)
    cv.ellipse(cx, body_y - 3.5, 2.0, 2.0, CYAN)
    face(cv, eye, cx, head_y + 0.5, 4.8, 2.1, pose["eyes"], mouth=False)
    cv.line(cx - 1.5, head_y + 5.0, cx + 1.5, head_y + 5.0, 0.9, mask_dark)


# -- GitGecko ---------------------------------------------------------------

def draw_gitgecko(cv, stage, pose, variant, colors):
    body, accent, belly, eye = colors
    cx = 32.0
    pad = CYAN if variant == "mutated" else accent
    sclera = belly
    if pose["sleep"]:
        cv.blob(cx + 12.0, 51.5, 9.0, 2.8, body, light=False)
        cv.ellipse(cx + 20.0, 51.5, 1.4, 1.4, CYAN)
        cv.blob(cx, 49.5, 14.0, 6.5, body)
        cv.blob(cx - 9.0, 44.0, 9.5, 7.0, body)
        cv.patch(cx - 9.0, 46.5, 5.5, 2.6, belly)
        for side in (-1, 1):
            cv.blob(cx - 9.0 + side * 7.5, 41.5, 3.0, 3.0, sclera, light=False)
            cv.eye(cx - 9.0 + side * 7.5, 41.5, 1.3, "closed", eye)
        return
    if stage == "hatchling":
        cv.blob(cx + 10.5 * pose["tail_dir"], 52.5, 6.0, 2.2, body, light=False)
        cv.ellipse(cx + 16.0 * pose["tail_dir"], 52.5, 1.3, 1.3, CYAN)
        cv.blob(cx, 42.0, 12.5, 13.5, body)
        cv.patch(cx, 49.5, 7.0, 3.8, belly)
        for side in (-1, 1):
            cv.blob(cx + side * 8.5, 37.0, 4.2, 4.2, sclera, light=False)
            cv.eye(cx + side * 8.5, 37.2, 2.0, pose["eyes"] if pose["eyes"] != "down" else "open", eye)
        cv.ellipse(cx, 46.5, 2.2, 2.2, BLACK)
        cv.ellipse(cx, 46.5, 1.7, 1.7, CYAN)
        cv.line(cx - 1.6, 42.0, cx + 1.6, 42.0, 0.9, shade(body, 0.5))
        return
    head_y, head_rx, head_ry = (24.0, 12.5, 9.5) if stage == "adult" else (27.0, 11.5, 9.2)
    body_y, body_rx, body_ry = (42.0, 9.0, 11.5) if stage == "adult" else (43.0, 8.5, 10.5)
    # tail: single commit line, or a three-way branch when mutated
    tdir = pose["tail_dir"]
    tail_len = 12.0 if stage == "adult" else 9.0
    branches = ((0.0,),) if variant != "mutated" else ((-3.5,), (0.0,), (3.5,))
    for (off,) in branches:
        tx = cx + tdir * (body_rx + tail_len * 0.5)
        ty = body_y + 8.5 + off * 0.9
        cv.blob(tx, ty, tail_len * 0.55, 2.4, body, light=False)
        cv.ellipse(tx + tdir * tail_len * 0.5, ty, 1.6, 1.6, BLACK)
        cv.ellipse(tx + tdir * tail_len * 0.5, ty, 1.1, 1.1, CYAN)
    # four legs with toe pads
    leg_y = 53.5
    for side in (-1, 1):
        cv.blob(cx + side * (body_rx + 1.0), leg_y, 3.6, 2.4, body, light=False)
        cv.ellipse(cx + side * (body_rx + 3.0), leg_y + 0.8, 1.2, 1.0, pad)
    cv.blob(cx, body_y, body_rx, body_ry, body)
    cv.patch(cx, body_y + 2.5, body_rx * 0.6, body_ry * 0.62, belly)
    if pose["arms"] == "up":
        for side in (-1, 1):
            cv.blob(cx + side * (body_rx + 2.5), body_y - 12.0, 3.0, 4.6, body, light=False)
            cv.ellipse(cx + side * (body_rx + 3.5), body_y - 16.0, 1.3, 1.1, pad)
    elif pose["arms"] == "laptop":
        draw_arms(cv, body, cx, body_y - 6.0, "laptop", stage, size=3.0)
    else:
        for side in (-1, 1):
            cv.blob(cx + side * (body_rx + 2.0), body_y + 1.0, 3.0, 4.8, body, light=False)
            cv.ellipse(cx + side * (body_rx + 3.0), body_y + 5.5, 1.3, 1.1, pad)
    cv.blob(cx, head_y, head_rx, head_ry, body)
    cv.patch(cx, head_y + 4.5, head_rx * 0.5, head_ry * 0.36, belly)
    # big side-set eyes
    for side in (-1, 1):
        ex = cx + side * head_rx * 0.68
        cv.blob(ex, head_y - 0.5, 4.1, 4.1, sclera, light=False)
        cv.eye(ex, head_y - 0.3, 2.0, "open" if pose["eyes"] == "down" else pose["eyes"], eye)
    cv.line(cx - 1.8, head_y + 4.6, cx + 1.8, head_y + 4.6, 0.9, shade(body, 0.5))
    cv.ellipse(cx, body_y - 3.5, 2.6, 2.6, BLACK)
    cv.ellipse(cx, body_y - 3.5, 2.0, 2.0, CYAN)


RENDERERS = {
    "agentolotl": draw_agentolotl,
    "vectordragon": draw_vectordragon,
    "tensorchilla": draw_tensorchilla,
    "synapsesloth": draw_synapsesloth,
    "gitgecko": draw_gitgecko,
}


# ---------------------------------------------------------------------------
# Frame / sheet assembly
# ---------------------------------------------------------------------------

def render_frame(species_id, stage, row, col, variant):
    spec = GEN3_SPECIES[species_id]
    pose = pose_for(row, col)
    colors = variant_colors(spec, variant)
    cv = Canvas()
    cv.scale = STAGE_SCALE[stage]
    cv.dx = pose["dx"]
    cv.dy = pose["dy"]

    RENDERERS[species_id](cv, stage, pose, variant, colors)

    s = cv.scale
    if pose["laptop"]:
        w = 22.0
        cv.laptop(32.0, 46.0, w, pose["screen_on"])
    if pose["exclaim"]:
        cv.exclaim(32.0 + 15.0 * s, 8.0 + (GROUND_Y - 8.0) * (1 - s) * 0.6 + pose.get("exclaim_dy", 0.0))
    if pose["sparkle"]:
        ph = pose["phase"]
        top = GROUND_Y - (GROUND_Y - 10.0) * s
        pts = ((-17.0, top + 2.0), (17.0, top + 5.0), (-13.0, top + 14.0), (14.0, top + 16.0))
        for i, (px, py) in enumerate(pts):
            if (i + ph) % 2 == 0:
                cv.sparkle(32.0 + px * s + cv.dx, py + cv.dy, 2.2 if i < 2 else 1.5,
                           SPARK_YELLOW if i % 2 == 0 else SPARK_PINK)
    if pose["zees"]:
        base_x = 32.0 + 13.0 * s
        base_y = GROUND_Y - 22.0 * s + pose["zee_dy"]
        for k in range(pose["zees"]):
            cv.zee(base_x + k * 3.5, base_y - k * 5.0, 1.6 + k * 0.4, SLEEP_PINK)
    return cv.downsample()


def build_sheet(species_id, stage, variant):
    sheet = bytearray(SHEET_W * SHEET_H * 4)
    rows = {}
    for anim in ANIMATION_DEF.values():
        rows[anim["row"]] = max(rows.get(anim["row"], 0), anim["frameCount"])
    for row, frame_count in rows.items():
        for col in range(frame_count):
            frame = render_frame(species_id, stage, row, col, variant)
            for y in range(CELL):
                src = y * CELL * 4
                dst = ((row * CELL + y) * SHEET_W + col * CELL) * 4
                sheet[dst:dst + CELL * 4] = frame[src:src + CELL * 4]
    return sheet


def write_png(raw, path, width=SHEET_W, height=SHEET_H):
    stride = width * 4
    scanlines = b"".join(b"\x00" + bytes(raw[y * stride:(y + 1) * stride]) for y in range(height))

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(scanlines, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as handle:
        handle.write(png)


def write_manifest(species_id, spec, dir_path):
    palette_json = json.dumps(spec["palette"])
    with open(os.path.join(ROOT, "Scripts", "companion-manifest.template.json"), "r") as handle:
        template = handle.read()
    manifest = (template.replace("__ID__", species_id)
                .replace("__DISPLAY_NAME__", spec["displayName"])
                .replace("__PALETTE__", palette_json[1:-1]))
    with open(os.path.join(dir_path, "manifest.json"), "w") as handle:
        handle.write(manifest)


def main():
    for species_id, spec in GEN3_SPECIES.items():
        species_dir = os.path.join(ASSET_ROOT, species_id)
        os.makedirs(species_dir, exist_ok=True)
        for stage in STAGES:
            for variant in ("normal", "legendary", "mutated"):
                filename = f"{stage}-{variant}.png"
                write_png(build_sheet(species_id, stage, variant), os.path.join(species_dir, filename))
                print(f"Generated {species_id}/{filename}")
        write_manifest(species_id, spec, species_dir)
        print(f"Generated {species_id}/manifest.json")


if __name__ == "__main__":
    main()
