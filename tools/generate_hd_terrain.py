#!/usr/bin/env python3
"""
Generates the HD pixel-art terrain tiles used by assets/shaders/terrain.gdshader
and the battle backdrop.

Each tile is 64x64 (4x the old 16x16), seamlessly tileable, built from small
hand-picked palettes with ordered dithering so it still reads as pixel art. The
ALPHA channel carries a height map (0 = recessed mortar/soil, 1 = raised brick,
pebble or blade tip); the terrain shader derives per-texel bump lighting from it.

Every tile is rescaled so its mean RGB matches the tile it replaces, keeping the
per-biome tints in ChunkRenderer / BattleBackdrop calibrated.

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
N = 64

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

def grass_tile(seed, palette, blades, dirt=None, dirt_amount=0.0):
    rng = random.Random(seed)
    base_v = fbm(seed)
    height = base_v * 0.35
    # Low spots can show bare earth (hill tops).
    rgb = ramp(base_v * 0.8 + 0.1, palette)
    if dirt is not None:
        d = fbm(seed + 99, ((4, 0.6), (8, 0.4)))
        bare = d < dirt_amount
        drgb = ramp(fbm(seed + 7) * 0.8 + 0.1, dirt)
        rgb[bare] = drgb[bare]
        height[bare] *= 0.3
    # Blades: 1px strokes, dark root, lighter tip, leaning, with a shadow
    # pixel under the root. Drawn with wraparound so the tile stays seamless.
    for _ in range(blades):
        x = rng.randrange(N)
        y = rng.randrange(N)
        length = rng.choice((2, 3, 3, 4, 4, 5))
        lean = rng.choice((-1, 0, 0, 1))
        tone = rng.random()
        rgb[(y + 1) % N, x] = shade(palette[0], 0.9)
        height[(y + 1) % N, x] = min(height[(y + 1) % N, x], 0.05)
        for s in range(length):
            yy = (y - s) % N
            xx = (x + (lean if s >= length // 2 + 1 else 0)) % N
            t = s / max(1, length - 1)
            pi = int(round(1 + t * (len(palette) - 2) * (0.6 + 0.4 * tone)))
            rgb[yy, xx] = palette[min(pi, len(palette) - 1)]
            height[yy, xx] = 0.45 + 0.55 * t
    return rgb, height


def make_grass():
    pal = [(62, 112, 52), (86, 146, 70), (112, 178, 88), (136, 204, 104), (160, 222, 118), (190, 238, 140)]
    rgb, h = grass_tile(11, pal, 520)
    return match_mean(rgb, TARGET_MEAN["grass"]), h


def make_hill_top():
    pal = [(40, 58, 18), (54, 76, 24), (70, 94, 32), (88, 112, 40), (108, 132, 50)]
    dirt = [(58, 44, 24), (74, 56, 30), (90, 70, 40)]
    rgb, h = grass_tile(23, pal, 420, dirt, 0.22)
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
                rgb[y, x] = rgb[y, x] * 0.78
                height[y, x] = min(height[y, x], 0.12)


def earth_tile(seed, palette, stones, stone_pal, roots=0, ruts=False):
    rng = random.Random(seed)
    v = fbm(seed, ((4, 0.45), (8, 0.3), (32, 0.25)))
    if ruts:
        # Soft wheel-worn bands along one axis (paths are drawn world-aligned).
        y = np.arange(N)[:, None] / N
        v = v * 0.8 + 0.2 * (0.5 + 0.5 * np.cos(y * np.pi * 4.0))
    rgb = ramp(v, palette)
    height = v * 0.4
    # Tiny grit: scattered single light/dark pixels.
    for _ in range(170):
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
    rgb, h = earth_tile(31, pal, 22, stones, roots=6)
    return match_mean(rgb, TARGET_MEAN["hill_side"]), h


def make_path():
    pal = [(196, 132, 84), (214, 148, 94), (230, 162, 106), (242, 176, 118), (252, 192, 134)]
    stones = [(150, 118, 94), (200, 170, 140), (222, 196, 166), (238, 216, 188), (252, 238, 214)]
    rgb, h = earth_tile(47, pal, 14, stones, ruts=True)
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
    # Chipped corner or hairline crack on some blocks.
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
    course = 8  # 8 courses per tile -> a quarter world unit each
    for row in range(N // course):
        x = rng.randrange(0, 16)
        start = x
        while x < start + N:
            w = rng.choice((12, 14, 16, 16, 18, 20))
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
    # Flagstones on a 4x4 lattice of 16px cells; some merge into 2-cell slabs.
    used = np.zeros((4, 4), dtype=bool)
    cells = [(cy, cx) for cy in range(4) for cx in range(4)]
    for cy, cx in cells:
        if used[cy, cx]:
            continue
        w = h = 1
        r = rng.random()
        if r < 0.3 and not used[cy, (cx + 1) % 4]:
            w = 2
        elif r < 0.55 and not used[(cy + 1) % 4, cx]:
            h = 2
        for yy in range(h):
            for xx in range(w):
                used[(cy + yy) % 4, (cx + xx) % 4] = True
        jx, jy = rng.randrange(0, 2), rng.randrange(0, 2)
        paint_block(rgb, height, rng, cx * 16 + jx, cy * 16 + jy, w * 16 - 2 - jx, h * 16 - 2 - jy,
                    tones, mortar, speck)
    return match_mean(rgb, TARGET_MEAN["wall_top"]), height


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
