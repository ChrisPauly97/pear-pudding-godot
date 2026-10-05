#!/usr/bin/env python3
"""
Generates the pixel-art roof and gable textures for town buildings (GID-154).

128x128 tiles at the brick wall's density (~20 px per world unit), seamless in
both directions. Rows run along the ridge; +v points down the slope.

Usage:
  python3 tools/generate_roof_textures.py
"""

import random
from pathlib import Path
from PIL import Image

OUTPUT_DIR = Path(__file__).parent.parent / "assets" / "textures" / "pixel_art"
SIZE = 128


def clamp(c):
    return tuple(max(0, min(255, int(v))) for v in c)


def shade(c, f):
    return clamp((c[0] * f, c[1] * f, c[2] * f))


def jitter(rng, c, amt):
    d = rng.uniform(-amt, amt)
    return clamp((c[0] + d, c[1] + d * 0.9, c[2] + d * 0.8))


def make_clay(seed=1):
    """Terracotta barrel tiles: staggered rows, lit crown, shadowed overlap."""
    base = (176, 86, 58)
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    row_h, tile_w = 16, 16
    for row in range(SIZE // row_h):
        off = (tile_w // 2) * (row % 2)
        for col in range(SIZE // tile_w):
            col_c = jitter(rng, base, 14)
            for y in range(row_h):
                for x in range(tile_w):
                    gx = (col * tile_w + x + off) % SIZE
                    gy = row * row_h + y
                    # Barrel profile: bright crown in the middle, dark troughs at the edges.
                    t = abs(x - (tile_w - 1) / 2) / ((tile_w - 1) / 2)
                    f = 1.12 - 0.42 * t * t
                    if y >= row_h - 3:
                        f *= 0.55 if y == row_h - 1 else 0.75  # overlap shadow
                    elif y <= 1:
                        f *= 1.08
                    if x == 0:
                        f *= 0.5
                    c = shade(col_c, f)
                    if rng.random() < 0.06:
                        c = shade(c, rng.choice([0.88, 1.1]))
                    px[gx, gy] = c
    return img


def make_slate(seed=2):
    """Blue-grey slates: rectangular, staggered, hairline gaps and chips."""
    base = (92, 102, 122)
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    row_h, tile_w = 12, 16
    rows = SIZE // row_h + 1
    for gy in range(SIZE):
        row = gy // row_h
        y = gy % row_h
        off = (tile_w // 2) * (row % 2)
        for gx in range(SIZE):
            x = (gx + off) % tile_w
            col = ((gx + off) // tile_w) % (SIZE // tile_w)
            r2 = random.Random(seed * 1000 + (row % rows) * 37 + col)
            c = jitter(r2, base, 16)
            f = 1.0
            if y == row_h - 1:
                f = 0.45
            elif y == row_h - 2:
                f = 0.78
            elif y == 0:
                f = 1.15
            if x == 0:
                f *= 0.55
            c = shade(c, f)
            if rng.random() < 0.05:
                c = shade(c, rng.choice([0.85, 1.12]))
            px[gx, gy] = c
    return img


def make_thatch(seed=3):
    """Straw thatch: vertical strands in banded courses with a dark lip."""
    base = (196, 164, 92)
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    strand = [jitter(rng, base, 26) for _ in range(SIZE)]
    course_h = 16
    shifts = [rng.randrange(SIZE) for _ in range(SIZE // course_h)]
    tips = [rng.randrange(0, 4) for _ in range(SIZE)]  # ragged straw ends
    for gy in range(SIZE):
        y = gy % course_h
        course = gy // course_h
        for gx in range(SIZE):
            c = strand[(gx + shifts[course]) % SIZE]
            if y >= course_h - 2 - tips[(gx + course * 17) % SIZE]:
                c = shade(c, 0.85)
            f = 0.92 + 0.16 * (1 - y / course_h)
            if y >= course_h - 2:
                f *= 0.6
            if (gx * 7 + gy * 3) % 11 == 0:
                f *= 0.82
            c = shade(c, f)
            if rng.random() < 0.08:
                c = shade(c, rng.choice([0.75, 1.15]))
            px[gx, gy] = c
    return img


def make_shingle(seed=4):
    """Split-wood shingles: narrow staggered boards with grain lines."""
    base = (128, 88, 58)
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    row_h, tile_w = 16, 8
    for row in range(SIZE // row_h):
        off = (tile_w // 2) * (row % 2) + rng.randrange(0, 3)
        for col in range(SIZE // tile_w):
            col_c = jitter(rng, base, 18)
            grain = rng.randrange(1, tile_w - 1)
            for y in range(row_h):
                for x in range(tile_w):
                    gx = (col * tile_w + x + off) % SIZE
                    gy = row * row_h + y
                    f = 1.0
                    if x == 0:
                        f = 0.5
                    elif x == grain and y % 5 != 0:
                        f = 0.85
                    if y >= row_h - 2:
                        f *= 0.6
                    elif y == 0:
                        f *= 1.12
                    px[gx, gy] = shade(col_c, f)
    return img


def make_moss_clay(seed=5):
    """Old clay tiles with moss creeping along the overlaps."""
    img = make_clay(seed)
    px = img.load()
    rng = random.Random(seed)
    moss = [(86, 112, 52), (64, 92, 40), (108, 132, 60)]
    for _ in range(90):
        cx = rng.randrange(SIZE)
        cy = rng.randrange(SIZE // 16) * 16 + 13
        for _ in range(rng.randrange(6, 16)):
            x = (cx + rng.randrange(-4, 5)) % SIZE
            y = (cy + rng.randrange(-3, 3)) % SIZE
            px[x, y] = rng.choice(moss)
    return img


def make_gable(seed=6):
    """Lime plaster with dark timber framing: posts, a rail and a brace."""
    plaster = (190, 174, 144)
    timber = (78, 54, 36)
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            c = jitter(rng, plaster, 8)
            if rng.random() < 0.03:
                c = shade(c, 0.9)
            px[x, y] = c

    def beam(x0, y0, x1, y1, w=5):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(steps + 1):
            cx = x0 + (x1 - x0) * i / steps
            cy = y0 + (y1 - y0) * i / steps
            for d in range(w):
                for e in range(w):
                    gx = int(cx + d - w // 2) % SIZE
                    gy = int(cy + e - w // 2) % SIZE
                    f = 0.8 if d == 0 or e == 0 else 1.0
                    px[gx, gy] = shade(jitter(rng, timber, 6), f)

    beam(0, 0, 0, SIZE - 1, 6)          # post (wraps to both tile edges)
    beam(SIZE // 2, 0, SIZE // 2, SIZE - 1)
    beam(0, SIZE // 2, SIZE - 1, SIZE // 2)
    beam(4, SIZE // 2 - 4, SIZE // 2 - 4, 4)
    beam(SIZE // 2 + 4, 4, SIZE - 4, SIZE // 2 - 4)
    return img


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out = {
        "roof_clay_pixel.png": make_clay(),
        "roof_slate_pixel.png": make_slate(),
        "roof_thatch_pixel.png": make_thatch(),
        "roof_shingle_pixel.png": make_shingle(),
        "roof_moss_pixel.png": make_moss_clay(),
        "gable_pixel.png": make_gable(),
    }
    for name, img in out.items():
        img.save(OUTPUT_DIR / name)
        print("wrote", OUTPUT_DIR / name)


if __name__ == "__main__":
    main()
