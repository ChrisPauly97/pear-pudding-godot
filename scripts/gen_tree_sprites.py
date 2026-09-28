#!/usr/bin/env python3
"""Generates the world tree prop sprites (assets/textures/props/prop_tree_*.png).

Deterministic pixel art matching the ground props: a dark 1-texel outline,
light from the upper left, three-tone canopy ramp with a dithered edge.
Re-run after tweaking; needs Pillow (`pip install pillow`).
"""
import math
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "props")
OUTLINE = (18, 13, 23, 255)
# Geometry scale: trees stand ~2.5x the hero at the shared 0.05 texel size.
S = 1.8


def k(v):
    return int(round(v * S))


def blank(w, h):
    return [[None] * w for _ in range(h)]


def outline(px):
    h, w = len(px), len(px[0])
    out = [row[:] for row in px]
    for y in range(h):
        for x in range(w):
            if px[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[ny][nx] is not None and px[ny][nx] != OUTLINE:
                    out[y][x] = OUTLINE
                    break
    return out


def save(px, name):
    h, w = len(px), len(px[0])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            if px[y][x] is not None:
                img.putpixel((x, y), px[y][x])
    img.save(os.path.join(OUT, name))


def trunk(px, cx, top, bottom, width, dark, light, rng):
    for y in range(top, bottom):
        for x in range(cx - width // 2, cx - width // 2 + width):
            px[y][x] = light if x == cx - width // 2 else dark
    # Root flare on the bottom row.
    for x in (cx - width // 2 - 1, cx - width // 2 + width):
        px[bottom - 1][x] = dark


def shade(ramp, nx, ny, rng):
    # Light from the upper left; dither the band edges.
    l = -(nx + ny) * 0.7 + rng.uniform(-0.25, 0.25)
    if l > 0.45:
        return ramp[3]
    if l > -0.05:
        return ramp[2]
    if l > -0.6:
        return ramp[1]
    return ramp[0]


def oak(seed, ramp):
    rng = random.Random(seed)
    w, h = k(30), k(40)
    px = blank(w, h)
    cx = w // 2
    trunk(px, cx, k(22), h - 1, k(4), (74, 50, 36, 255), (110, 78, 52, 255), rng)
    blobs = [(cx, k(13), k(10))]
    for _ in range(8):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(3, 7) * S
        blobs.append((cx + math.cos(a) * r * 1.2, k(14) + math.sin(a) * r * 0.8, rng.uniform(4.5, 7) * S))
    for y in range(1, k(30)):
        for x in range(1, w - 1):
            if any((x - bx) ** 2 + (y - by) ** 2 <= br * br for bx, by, br in blobs):
                px[y][x] = shade(ramp, (x - cx) / k(11), (y - k(13)) / k(11), rng)
    # A few leaf-cluster highlights.
    for _ in range(k(10)):
        x, y = rng.randint(5, w - 6), rng.randint(3, k(20))
        if px[y][x] is not None and px[y][x] != ramp[0]:
            px[y][x] = ramp[3]
    return outline(px)


def pine(seed, ramp, snow=False):
    rng = random.Random(seed)
    w, h = k(24), k(46)
    px = blank(w, h)
    cx = w // 2
    trunk(px, cx, k(36), h - 1, k(3), (70, 46, 34, 255), (100, 70, 48, 255), rng)
    tiers = rng.choice([4, 5])
    top = 2
    for t in range(tiers):
        ty = top + t * k(7)
        half_max = k(3 + t * 2) + rng.randint(0, 1)
        for y in range(ty, ty + k(11)):
            if y >= k(38):
                break
            half = int((y - ty) / float(k(10)) * half_max) + 1
            for x in range(cx - half, cx + half + 1):
                if 0 < x < w - 1:
                    c = shade(ramp, (x - cx) / k(8), (y - ty - k(5)) / k(8), rng)
                    on_slope = abs(x - cx) >= half - 1 and x - cx <= 0
                    if snow and (y - ty <= 2 or on_slope) and rng.random() < 0.75:
                        c = (226, 234, 242, 255)
                    px[y][x] = c
    return outline(px)


def dead(seed):
    rng = random.Random(seed)
    w, h = k(24), k(36)
    px = blank(w, h)
    cx = w // 2
    dark, light = (72, 58, 52, 255), (112, 96, 84, 255)
    trunk(px, cx, k(10), h - 1, k(3), dark, light, rng)

    def branch(x, y, ang, length, depth):
        for i in range(length):
            x += math.cos(ang)
            y -= math.sin(ang)
            ix, iy = int(round(x)), int(round(y))
            for t in range(max(1, depth)):
                if 1 <= ix + t < w - 1 and 1 <= iy < h:
                    px[iy][ix + t] = light if math.cos(ang) < 0 else dark
        if depth > 0:
            branch(x, y, ang + rng.uniform(0.4, 0.8), length - 1, depth - 1)
            branch(x, y, ang - rng.uniform(0.4, 0.8), length - 1, depth - 1)

    branch(cx, k(11), math.pi / 2 + rng.uniform(-0.2, 0.2), k(6), 2)
    branch(cx, k(19), math.pi * 0.85 + rng.uniform(-0.1, 0.1), k(8), 1)
    branch(cx, k(15), math.pi * 0.15 + rng.uniform(-0.1, 0.1), k(8), 1)
    return outline(px)


GREEN = [(28, 58, 30, 255), (44, 88, 40, 255), (70, 122, 52, 255), (122, 168, 74, 255)]
AUTUMN = [(70, 40, 22, 255), (128, 72, 30, 255), (178, 112, 40, 255), (220, 170, 70, 255)]
PINE = [(16, 44, 34, 255), (26, 66, 46, 255), (40, 92, 58, 255), (78, 130, 80, 255)]

if __name__ == "__main__":
    save(oak(1, GREEN), "prop_tree_oak_0.png")
    save(oak(7, GREEN), "prop_tree_oak_1.png")
    save(oak(13, AUTUMN), "prop_tree_oak_2.png")
    save(pine(3, PINE), "prop_tree_pine_0.png")
    save(pine(9, PINE), "prop_tree_pine_1.png")
    save(pine(21, PINE), "prop_tree_pine_2.png")
    save(pine(5, PINE, snow=True), "prop_tree_snowpine_0.png")
    save(pine(17, PINE, snow=True), "prop_tree_snowpine_1.png")
    save(dead(2), "prop_tree_dead_0.png")
    save(dead(11), "prop_tree_dead_1.png")
