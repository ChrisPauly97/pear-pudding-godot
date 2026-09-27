#!/usr/bin/env python3
"""
Generates the HD pixel-art terrain tiles used by assets/shaders/terrain.gdshader
and the battle backdrop.

Each tile is 128x128, seamlessly tileable, and is sampled at 20 texels per world
unit (terrain.gdshader uv_scale = 20/128) -- the same pixel density as the
character sprites (PIXEL_SIZE 0.05), so ground, walls and sprites read as one
style. Tiles use small hand-picked palettes with ordered dithering. The
ALPHA channel carries a height map (0 = recessed mortar/soil, 1 = raised brick,
pebble or blade tip); the terrain shader derives per-texel bump lighting from it.

Every tile is rescaled so its mean RGB matches the tile it replaces, keeping the
per-biome tints in ChunkRenderer / BattleBackdrop calibrated.

It also writes grass_tufts.png, the billboard grass-tuft atlas drawn by
grass_cluster.gdshaderinc (R = tone 0..1 on the shader's grass ramp, A = coverage).

Usage:
  python3 tools/generate_hd_terrain.py            # writes assets/textures/pixel_art/*_pixel.png
  python3 tools/generate_hd_terrain.py --preview out.png
"""

import argparse
import random
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).parent.parent / "assets" / "textures" / "pixel_art"
N = 128

# Mean RGB of the 16x16 tiles these replace (biome tints are tuned against them).
TARGET_MEAN = {
    "grass": (130.5, 197.1, 105.1),
    "hill_side": (233.7, 164.9, 108.5),
    "hill_top": (69.4, 90.0, 33.2),
    "wall_side": (67.0, 56.2, 54.3),
    "wall_top": (73.1, 59.9, 58.4),
    "path": (234.0, 165.0, 108.0),
}

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1.0 / 32.0


def bayer(n=N):
    return np.tile(BAYER4, (n // 4, n // 4))


# ── Periodic noise ───────────────────────────────────────────────────────────

def value_noise(cells, seed, n=N):
    """Tileable smooth value noise with `cells` lattice cells across the tile."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells, cells))
    t = np.arange(n) * cells / n
    i0 = np.floor(t).astype(int)
    f = t - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fy = f[:, None]
    fx = f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(seed, octaves=((4, 0.5), (8, 0.3), (16, 0.2))):
    v = sum(w * value_noise(c, seed + k * 17) for k, (c, w) in enumerate(octaves))
    return (v - v.min()) / max(1e-6, v.max() - v.min())


def ramp(v, palette):
    """Quantise v in [0,1] onto a palette with Bayer dithering between tones."""
    k = len(palette)
    x = np.clip(v, 0, 1) * (k - 1)
    lo = np.floor(x).astype(int)
    frac = x - lo
    idx = np.clip(lo + (frac > bayer()).astype(int), 0, k - 1)
    pal = np.array(palette, dtype=float)
    return pal[idx]


def shade(col, amount):
    return np.clip(np.array(col, dtype=float) * amount, 0, 255)


def match_mean(rgb, target):
    m = rgb.reshape(-1, 3).mean(0)
    return np.clip(rgb * (np.array(target) / m), 0, 255)


def to_image(rgb, height):
    a = np.clip(height, 0, 1) * 255
    arr = np.dstack([rgb, a]).round().astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


# ── Grass ────────────────────────────────────────────────────────────────────
# The ground tile is deliberately calm: soft clumps of tone and small leaf
# marks, no long strokes. Anything distinctive becomes a visible repeat once
# tiled; the billboard tufts (grass_tufts.png) carry the grass silhouette.

def leaf_mark(rgb, height, x, y, light, dark):
    """A 3px 'v' of leaves with a dark pixel under it (pixel-art grass tick)."""
    for dx, dy, c, h in ((-1, 0, light, 0.7), (1, 0, light, 0.7), (0, 1, dark, 0.15), (-1, -1, light, 0.8)):
        xx, yy = (x + dx) % N, (y + dy) % N
        rgb[yy, xx] = c
        height[yy, xx] = h


def grass_tile(seed, palette, marks, dirt=None, dirt_amount=0.0):
    rng = random.Random(seed)
    v = fbm(seed, ((4, 0.4), (8, 0.3), (16, 0.2), (32, 0.1)))
    rgb = ramp(v * 0.7 + 0.15, palette[:-1])
    height = 0.25 + v * 0.35
    if dirt is not None:
        d = fbm(seed + 99, ((8, 0.3), (16, 0.4), (32, 0.3)))
        bare = d < dirt_amount
        drgb = ramp(fbm(seed + 7) * 0.8 + 0.1, dirt)
        rgb[bare] = drgb[bare]
        height[bare] *= 0.4
    for _ in range(marks):
        x, y = rng.randrange(N), rng.randrange(N)
        k = rng.randrange(1, len(palette) - 1)
        leaf_mark(rgb, height, x, y, palette[k + 1], palette[max(0, k - 2)])
    return rgb, height


def make_grass():
    pal = [(62, 112, 52), (92, 152, 74), (116, 182, 92), (136, 202, 104), (154, 216, 114), (184, 234, 136)]
    rgb, h = grass_tile(11, pal, 260)
    return match_mean(rgb, TARGET_MEAN["grass"]), h


def make_hill_top():
    pal = [(40, 58, 18), (56, 78, 26), (70, 94, 32), (86, 110, 40), (104, 128, 50)]
    dirt = [(58, 44, 24), (74, 56, 30), (90, 70, 40)]
    rgb, h = grass_tile(23, pal, 200, dirt, 0.16)
    return match_mean(rgb, TARGET_MEAN["hill_top"]), h


# ── Earth: hill sides and paths ──────────────────────────────────────────────

def pebble(rgb, height, cx, cy, rx, ry, col, hl, sh):
    for dy in range(-ry - 1, ry + 2):
        for dx in range(-rx - 1, rx + 2):
            q = (dx / (rx + 0.5)) ** 2 + (dy / (ry + 0.5)) ** 2
            x = (cx + dx) % N
            y = (cy + dy) % N
            if q <= 1.0:
                # Light from the top-left: rim highlight up-left, shade down-right.
                edge = q > 0.45
                if edge and dx + dy < 0:
                    c = hl
                elif edge and dx + dy > 0:
                    c = sh
                else:
                    c = col
                rgb[y, x] = c
                height[y, x] = 0.55 + 0.45 * (1 - q)
            elif q <= 1.6 and dx + dy > 0:
                # Contact shadow on the soil below/right of the stone.
                rgb[y, x] = rgb[y, x] * 0.8
                height[y, x] = min(height[y, x], 0.12)


def earth_tile(seed, palette, stones, stone_pal, roots=0):
    rng = random.Random(seed)
    v = fbm(seed, ((4, 0.4), (8, 0.3), (16, 0.15), (32, 0.15)))
    rgb = ramp(v, palette)
    height = v * 0.4
    # Grit: scattered single light/dark pixels.
    for _ in range(420):
        x, y = rng.randrange(N), rng.randrange(N)
        light = rng.random() < 0.5
        rgb[y, x] = palette[-1] if light else palette[0]
        height[y, x] = 0.5 if light else 0.05
    for _ in range(roots):
        x, y = rng.randrange(N), rng.randrange(N)
        for _s in range(rng.randrange(5, 11)):
            rgb[y % N, x % N] = shade(palette[0], 0.8)
            height[y % N, x % N] = 0.3
            x += rng.choice((1, 1, 0))
            y += rng.choice((-1, 0, 1))
    # Jittered grid so stones spread evenly instead of clumping (clumps read as
    # an obvious repeat once the tile tiles).
    g = int(np.ceil(np.sqrt(stones)))
    cell = N // g
    slots = rng.sample([(i, j) for i in range(g) for j in range(g)], stones)
    for i, j in slots:
        c = rng.choice(stone_pal[1:-1])
        rx = rng.choice((1, 1, 1, 2, 2, 3))
        ry = max(1, rx - rng.choice((0, 1)))
        cx = i * cell + rng.randrange(cell)
        cy = j * cell + rng.randrange(cell)
        pebble(rgb, height, cx, cy, rx, ry, c, stone_pal[-1], stone_pal[0])
    return rgb, height


def make_hill_side():
    pal = [(150, 96, 58), (178, 118, 72), (204, 140, 88), (226, 160, 104), (244, 180, 122)]
    stones = [(120, 104, 96), (168, 150, 136), (196, 178, 160), (220, 204, 186), (246, 234, 214)]
    rgb, h = earth_tile(31, pal, 40, stones, roots=14)
    return match_mean(rgb, TARGET_MEAN["hill_side"]), h


def make_path():
    pal = [(200, 136, 86), (216, 150, 96), (230, 162, 106), (242, 176, 118), (252, 190, 132)]
    stones = [(150, 118, 94), (200, 170, 140), (222, 196, 166), (238, 216, 188), (252, 238, 214)]
    rgb, h = earth_tile(47, pal, 30, stones)
    return match_mean(rgb, TARGET_MEAN["path"]), h


# ── Masonry ──────────────────────────────────────────────────────────────────

def paint_block(rgb, height, rng, x0, y0, w, hgt, tones, mortar, speck):
    """One brick / slab: rounded corners, bevel lighting, speckle, maybe a crack."""
    base = np.array(rng.choice(tones), dtype=float) * rng.uniform(0.92, 1.08)
    hl = np.clip(base * 1.28, 0, 255)
    sh = base * 0.68
    for dy in range(hgt):
        for dx in range(w):
            x, y = (x0 + dx) % N, (y0 + dy) % N
            corner = (dx in (0, w - 1)) and (dy in (0, hgt - 1))
            if corner:
                rgb[y, x] = mortar
                height[y, x] = 0.15
                continue
            c = base
            h = 0.85
            if dy == 0 or dx == 0:
                c, h = hl, 0.75
            elif dy == hgt - 1 or dx == w - 1:
                c, h = sh, 0.6
            elif speck[y, x] > 0.86:
                c, h = base * 0.84, 0.72
            elif speck[y, x] < 0.1:
                c = np.clip(base * 1.1, 0, 255)
            rgb[y, x] = c
            height[y, x] = h
    # Hairline crack on a few blocks.
    if rng.random() < 0.12 and w > 5 and hgt > 4:
        x, y = x0 + rng.randrange(2, w - 2), y0 + 1
        for _ in range(hgt - 2):
            rgb[y % N, x % N] = sh * 0.7
            height[y % N, x % N] = 0.3
            y += 1
            x += rng.choice((-1, 0, 1))
            x = min(max(x, x0 + 1), x0 + w - 2)


def make_wall_side():
    rng = random.Random(53)
    mortar = (30, 24, 26)
    tones = [(72, 60, 58), (84, 70, 66), (96, 80, 74), (78, 68, 70), (104, 88, 80)]
    rgb = np.empty((N, N, 3))
    rgb[:] = mortar
    height = np.full((N, N), 0.1)
    speck = np.random.default_rng(5).random((N, N))
    course = 8  # 0.4 world units per course at 20 texels/unit
    for row in range(N // course):
        x = rng.randrange(0, 24)
        start = x
        while x < start + N:
            w = rng.choice((14, 16, 18, 20, 22, 24))
            if x + w > start + N:
                w = start + N - x
            # Brick fills w-1 x course-1; the remaining row/column is mortar.
            if w > 3:
                paint_block(rgb, height, rng, x, row * course, w - 1, course - 1, tones, mortar, speck)
            x += w
    return match_mean(rgb, TARGET_MEAN["wall_side"]), height


def make_wall_top():
    rng = random.Random(71)
    mortar = (34, 28, 30)
    tones = [(76, 62, 60), (88, 72, 68), (98, 82, 76), (70, 62, 64), (106, 90, 82)]
    rgb = np.empty((N, N, 3))
    rgb[:] = mortar
    height = np.full((N, N), 0.1)
    speck = np.random.default_rng(9).random((N, N))
    # Flagstones on an 8x8 lattice of 16px cells; some merge into 2-cell slabs.
    k = N // 16
    used = np.zeros((k, k), dtype=bool)
    for cy in range(k):
        for cx in range(k):
            if used[cy, cx]:
                continue
            w = h = 1
            r = rng.random()
            if r < 0.3 and not used[cy, (cx + 1) % k]:
                w = 2
            elif r < 0.55 and not used[(cy + 1) % k, cx]:
                h = 2
            for yy in range(h):
                for xx in range(w):
                    used[(cy + yy) % k, (cx + xx) % k] = True
            jx, jy = rng.randrange(0, 2), rng.randrange(0, 2)
            paint_block(rgb, height, rng, cx * 16 + jx, cy * 16 + jy, w * 16 - 2 - jx, h * 16 - 2 - jy,
                        tones, mortar, speck)
    return match_mean(rgb, TARGET_MEAN["wall_top"]), height


# ── Grass tuft atlas ─────────────────────────────────────────────────────────
# Row 0: 8 short tufts, 16x12. Row 1: 8 tall tufts, 16x24. Same pixel size as
# the character sprites. R = tone (0 dark outline .. 1 sunlit tip), A = coverage.

TUFT_W = 16
SHORT_H = 12
TALL_H = 24
TONES = (0.0, 0.3, 0.5, 0.7, 0.85, 1.0)


def tuft(seed, h, blades, min_len, max_len):
    rng = random.Random(seed)
    tone = np.zeros((h, TUFT_W))
    cov = np.zeros((h, TUFT_W), dtype=bool)
    spread = 3.0 if h == SHORT_H else 3.5
    for bi in range(blades):
        # Roots near the bottom centre; outer blades lean out and curl over.
        # Back blades first (darker), front blades last (lighter, on top).
        front = bi >= blades * 0.55
        x = TUFT_W / 2 - 0.5 + rng.uniform(-spread, spread)
        lean = (x - TUFT_W / 2 + 0.5) * rng.uniform(0.08, 0.16) + rng.uniform(-0.2, 0.2)
        curl = lean * rng.uniform(0.02, 0.06)
        length = rng.randint(min_len, max_len)
        for s in range(length):
            t = s / max(1, length - 1)
            y = h - 1 - s
            if y < 0:
                break
            xi = int(round(x))
            if 0 <= xi < TUFT_W:
                # Mostly mid greens; only the last few pixels of a front
                # blade reach the sunlit tones.
                lvl = (2 if front else 1) + int(t ** 1.6 * 2.6 + (0.5 if front else 0.0))
                lvl = min(lvl, 4 if front else 3)
                cov[y, xi] = True
                tone[y, xi] = TONES[lvl]
                # Blades are 2px wide near the root; the right pixel is in shade.
                if s < length * 0.4 and xi + 1 < TUFT_W and not (front is False and cov[y, xi + 1]):
                    cov[y, xi + 1] = True
                    tone[y, xi + 1] = TONES[max(1, lvl - 1)]
            x = min(max(x + lean, 0.0), TUFT_W - 1.0)
            lean += curl
    # Short gaps between blades near the root fill with shade, so the clump
    # has a footing instead of reading as separate sticks.
    for y in range(h - max(2, h // 5), h):
        xs = np.nonzero(cov[y])[0]
        for a, b in zip(xs[:-1], xs[1:]):
            if 1 < b - a <= 3:
                cov[y, a + 1:b] = True
                tone[y, a + 1:b] = TONES[1]
    # Dark outline on the silhouette's lower sides (like the sprites' outlines,
    # without boxing in the airy tips).
    out = cov.copy()
    for y in range(int(h * 0.6), h):
        xs = np.nonzero(cov[y])[0]
        if xs.size:
            for x in (xs.min() - 1, xs.max() + 1):
                if 0 <= x < TUFT_W:
                    out[y, x] = True
                    tone[y, x] = TONES[0]
    return tone, out


def make_tufts():
    atlas = np.zeros((SHORT_H + TALL_H, TUFT_W * 8, 4))
    for i in range(8):
        t, c = tuft(100 + i, SHORT_H, 10, 4, 11)
        atlas[:SHORT_H, i * TUFT_W:(i + 1) * TUFT_W, 0] = t
        atlas[:SHORT_H, i * TUFT_W:(i + 1) * TUFT_W, 3] = c
        t, c = tuft(200 + i, TALL_H, 12, 9, 23)
        atlas[SHORT_H:, i * TUFT_W:(i + 1) * TUFT_W, 0] = t
        atlas[SHORT_H:, i * TUFT_W:(i + 1) * TUFT_W, 3] = c
    atlas[..., 1] = atlas[..., 0]
    atlas[..., 2] = atlas[..., 0]
    return Image.fromarray((atlas * 255).round().astype(np.uint8), "RGBA")


TILES = {
    "grass": make_grass,
    "hill_top": make_hill_top,
    "hill_side": make_hill_side,
    "path": make_path,
    "wall_side": make_wall_side,
    "wall_top": make_wall_top,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="also write a 2x2-tiled contact sheet here")
    args = ap.parse_args()
    imgs = {}
    for name, fn in TILES.items():
        rgb, h = fn()
        img = to_image(rgb, h)
        img.save(OUT / f"{name}_pixel.png")
        imgs[name] = img
        print(f"  {name}_pixel.png  mean={np.asarray(img)[..., :3].reshape(-1, 3).mean(0).round(1)}")
    make_tufts().save(OUT / "grass_tufts.png")
    print("  grass_tufts.png")
    if args.preview:
        s = 4
        sheet = Image.new("RGB", (len(imgs) * N * 2 * s // 2, N * 2 * s // 2))
        for i, img in enumerate(imgs.values()):
            t = Image.new("RGB", (N * 2, N * 2))
            for oy in (0, N):
                for ox in (0, N):
                    t.paste(img.convert("RGB"), (ox, oy))
            sheet.paste(t.resize((N * s, N * s), Image.NEAREST), (i * N * s, 0))
        sheet.save(args.preview)


if __name__ == "__main__":
    main()
