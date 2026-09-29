#!/usr/bin/env python3
"""
Generates the world prop and landmark sprites in the character sprites' style:
one pixel = 0.05 world units (SpriteRegistry.CHAR_PIXEL_SIZE), colours only
from tools/pixel_palette.py, light from the top-left, 1px dark outline.

Ground props get several variants each (prop_<key>_<n>.png) so a biome is not
one sprite repeated; landmarks are drawn at the pixel height that gives their
intended world height at 0.05.

Usage:
  python3 tools/generate_sprites.py                 # writes assets/textures/props/
  python3 tools/generate_sprites.py --preview out.png
"""

import argparse
import math
import random
from pathlib import Path

from PIL import Image

import pixel_palette as P

OUT = Path(__file__).parent.parent / "assets" / "textures" / "props"
LIGHT = (-0.6, -0.8)  # screen-space light direction (from the top-left)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.px[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def blob(self, cx, cy, rx, ry, ramp, rng=None, rough=0.0, light_bias=0.0):
        """Filled ellipse shaded as a lit dome: highlight up-left, shadow down-right."""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                dx = (x - cx) / max(rx, 0.5)
                dy = (y - cy) / max(ry, 0.5)
                q = dx * dx + dy * dy
                if rough and rng is not None:
                    q += (rng.random() - 0.5) * rough
                if q > 1.0:
                    continue
                lit = -(dx * LIGHT[0] + dy * LIGHT[1]) + light_bias
                rim = q > 0.55
                if lit > 0.55 and not rim:
                    i = 3
                elif lit > -0.05:
                    i = 2
                elif lit > -0.6 or not rim:
                    i = 1
                else:
                    i = 0
                self.set(x, y, ramp[min(i, len(ramp) - 1)])

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n):
            t = i / max(1, n - 1)
            self.set(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def outline(self, color=P.OUTLINE):
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    continue
                if any(self.get(x + dx, y + dy) is not None and self.get(x + dx, y + dy) != color
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    add.append((x, y))
        for x, y in add:
            self.px[y][x] = color

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is not None:
                    img.putpixel((x, y), (c[0], c[1], c[2], 255))
        return trim(img)


def trim(img):
    """Crop to content, keeping the bottom row as the ground line."""
    box = img.getbbox()
    if box is None:
        return img
    return img.crop((box[0], box[1], box[2], img.height))


# ── Ground props ─────────────────────────────────────────────────────────────

def flower(seed):
    """A leafy clump with 2-3 round blooms on stems of different heights."""
    rng = random.Random(seed)
    petals = [P.PINK, P.GOLD, P.BLUE, [P.STONE[1], P.STONE[2], P.STONE[3], P.WHITE], P.PURPLE][seed % 5]
    c = Canvas(17, 16)
    heads = rng.choice((2, 3, 3))
    tops = rng.sample((3, 5, 7), heads)
    for k in range(heads):
        x = 8 + (k - (heads - 1) / 2) * 5 + rng.uniform(-0.4, 0.4)
        top = tops[k]
        c.line(x, 14, x, top + 2, P.GREEN[1])
        c.set(x + (1 if k % 2 else -1), top + 5, P.GREEN[2])  # a leaf on the stem
        c.blob(x, top, 2.2, 2.0, petals)
        c.set(x, top, P.GOLD[2] if petals is not P.GOLD else P.WOOD[2])
    c.blob(8, 14, 5.5, 1.8, P.GREEN, rng, 0.3)          # leaf clump at the base
    c.outline()
    return c.image()


def rock(seed):
    rng = random.Random(seed)
    ramp = P.STONE if seed % 2 == 0 else P.STONE_WARM
    c = Canvas(14, 11)
    c.blob(6.5, 6.5, rng.uniform(4.2, 5.5), rng.uniform(3.2, 4.0), ramp, rng, 0.25)
    if rng.random() < 0.6:
        c.blob(10.5, 8.5, 2.2, 1.8, ramp, rng, 0.2)
    c.set(5 + rng.randint(-1, 1), 5, ramp[0])  # a chip
    c.outline()
    return c.image()


def boulder(seed):
    rng = random.Random(seed)
    c = Canvas(20, 16)
    c.blob(9.5, 9, rng.uniform(7.0, 8.5), rng.uniform(5.8, 6.6), P.STONE, rng, 0.2)
    # Crack and a moss cap.
    x, y = rng.randint(7, 12), 5
    for _ in range(5):
        c.set(x, y, P.STONE[0])
        x += rng.choice((-1, 0, 1))
        y += 1
    for _ in range(rng.randint(8, 16)):
        mx = rng.randint(4, 15)
        my = rng.randint(3, 6)
        if c.get(mx, my) is not None:
            c.set(mx, my, P.GREEN[rng.randint(1, 2)])
    c.outline()
    return c.image()


def mushroom(seed):
    rng = random.Random(seed)
    cap = P.RED if seed % 3 != 2 else [P.EARTH[1], P.WOOD[2], P.WOOD[3], P.SKIN[2]]
    c = Canvas(14, 12)
    n = rng.choice((1, 2, 3))
    for k in range(n):
        x = 4 + k * 4 + rng.uniform(-0.5, 0.5)
        h = rng.randint(4, 7) if k == 0 else rng.randint(3, 5)
        c.rect(int(x), 11 - h + 2, int(x) + 1, 11, P.SKIN[1])
        c.set(int(x), 11 - h + 3, P.SKIN[2])
        r = 2.6 if k == 0 else 2.0
        c.blob(x + 0.5, 11 - h + 1, r, r * 0.7, cap)
        if cap is P.RED:
            c.set(x - 0.5, 11 - h, P.WHITE)
            c.set(x + 1.5, 11 - h + 1, P.WHITE)
    c.outline()
    return c.image()


def fern(seed):
    """Tapered, arching fronds fanned from one root (thick enough to read)."""
    rng = random.Random(seed)
    c = Canvas(21, 17)
    fronds = rng.randint(4, 5)
    order = sorted(range(fronds), key=lambda k: -abs(k - (fronds - 1) / 2))  # outer (back) first
    for k in order:
        a = math.pi * (0.16 + 0.68 * k / (fronds - 1)) + rng.uniform(-0.05, 0.05)
        length = rng.uniform(9.0, 11.5) * (0.75 + 0.25 * math.sin(a))
        back = abs(math.cos(a)) > 0.55
        for i in range(int(length * 2)):
            s = i / 2
            t = s / length
            x = 10 + math.cos(a) * s
            y = 16 - math.sin(a) * s * 1.3 + t * t * 3.0
            w = 1.6 * math.sin(math.pi * min(1.0, t * 1.15))  # fat middle, pointed ends
            for dx in range(-2, 3):
                if abs(dx) <= w:
                    lit = dx < 0
                    c.set(x + dx, y, P.GREEN[(2 if lit else 1) - (1 if back else 0) + (1 if lit and t > 0.3 else 0)])
            c.set(x, y, P.GREEN[1 if back else 2])  # rib
    c.outline()
    return c.image()


def lichen(seed):
    rng = random.Random(seed)
    c = Canvas(14, 8)
    for _ in range(3):
        c.blob(rng.uniform(4, 10), rng.uniform(4, 5.5), rng.uniform(2.5, 4), rng.uniform(1.8, 2.5), P.TEAL, rng, 0.5)
    for _ in range(6):
        x, y = rng.randint(2, 11), rng.randint(2, 6)
        if c.get(x, y) is not None:
            c.set(x, y, P.GOLD[2] if rng.random() < 0.3 else P.TEAL[3])
    c.outline()
    return c.image()


def cactus(seed):
    rng = random.Random(seed)
    c = Canvas(16, 24)
    h = rng.randint(15, 21)
    top = 23 - h
    c.rect(6, top + 2, 9, 23, P.GREEN[1])
    c.rect(7, top + 1, 8, 23, P.GREEN[2])
    c.rect(6, top + 2, 6, 23, P.GREEN[0])
    c.line(8, top + 2, 8, 22, P.GREEN[3])
    for side in (-1, 1):
        if rng.random() < 0.8:
            ay = rng.randint(top + 5, top + h - 7)
            ax = 7.5 + side * 4
            c.rect(int(min(7.5, ax)), ay, int(max(7.5, ax)), ay + 1, P.GREEN[1])
            c.rect(int(ax) - 1 if side > 0 else int(ax), ay - rng.randint(3, 5), int(ax) if side > 0 else int(ax) + 1,
                   ay + 1, P.GREEN[2])
    for y in range(top + 3, 22, 3):
        c.set(6 if y % 2 else 9, y, P.SKIN[3])
    if rng.random() < 0.5:
        c.set(7, top, P.PINK[2])
        c.set(8, top, P.PINK[3])
    c.outline()
    return c.image()


def thorn(seed):
    rng = random.Random(seed)
    c = Canvas(16, 14)
    for k in range(rng.randint(4, 6)):
        x, y = 8 + rng.uniform(-2, 2), 13
        a = math.pi * rng.uniform(0.2, 0.8)
        for s in range(rng.randint(6, 10)):
            col = [P.RED[0], P.WOOD[0], P.RED[1]][min(2, s // 3)]
            c.set(x, y, col)
            if s % 3 == 2:
                c.set(x + rng.choice((-1, 1)), y - 1, P.RED[1])
            x += math.cos(a) * 1.0
            y -= math.sin(a) * 1.0
            a += rng.uniform(-0.35, 0.35)
    c.outline()
    return c.image()


def ash_pile(seed):
    rng = random.Random(seed)
    c = Canvas(15, 8)
    c.blob(7, 6, rng.uniform(5.5, 6.5), rng.uniform(3.0, 3.8), P.STONE_WARM, rng, 0.3)
    for _ in range(rng.randint(1, 3)):
        x, y = rng.randint(4, 10), rng.randint(5, 7)
        if c.get(x, y) is not None:
            c.set(x, y, P.FIRE[1])
    c.outline()
    return c.image()


def ember(seed):
    rng = random.Random(seed)
    c = Canvas(10, 12)
    c.blob(4.5, 10, 3.5, 1.5, [P.OUTLINE, P.EARTH[0], P.EARTH[1], P.FIRE[0]])
    h = rng.randint(5, 8)
    for y in range(h):
        t = y / h
        w = max(0, int((1 - t) * 2.2 + 0.4))
        x0 = 4.5 + math.sin(y * 1.3 + seed) * 0.6
        for x in range(int(x0 - w), int(x0 + w) + 1):
            core = abs(x - x0) < w * 0.5
            c.set(x, 9 - y, P.FIRE[3 if core and t < 0.4 else (2 if core else 1)])
    c.outline()
    return c.image()


PROPS = {
    "flower": (flower, 5),
    "rock": (rock, 4),
    "boulder": (boulder, 3),
    "mushroom": (mushroom, 3),
    "fern": (fern, 3),
    "lichen": (lichen, 3),
    "cactus": (cactus, 3),
    "thorn": (thorn, 3),
    "ash_pile": (ash_pile, 3),
    "ember": (ember, 3),
}


# ── Landmarks ────────────────────────────────────────────────────────────────

def waystone(active):
    # 1.9 world units = 38 px.
    c = Canvas(16, 38)
    c.rect(2, 33, 13, 37, P.STONE[1])            # plinth
    c.rect(2, 33, 13, 33, P.STONE[3])
    c.rect(2, 37, 13, 37, P.STONE[0])
    c.rect(4, 6, 11, 32, P.STONE[2])              # obelisk shaft
    c.rect(4, 6, 4, 32, P.STONE[3])
    c.rect(10, 6, 11, 32, P.STONE[1])
    for y, x in ((3, 7), (4, 6), (4, 7), (4, 8), (5, 5), (5, 6), (5, 7), (5, 8), (5, 9), (5, 10)):
        c.set(x, y, P.STONE[2] if x < 8 else P.STONE[1])
    c.set(7, 2, P.STONE[3])
    runes = P.GOLD if active else [P.STONE[0]] * 4
    for y in (10, 16, 22, 28):
        c.set(7, y, runes[2])
        c.set(8, y, runes[1])
        c.set(7, y + 1, runes[1])
        c.set(8, y + 2, runes[2] if active else runes[0])
    if active:
        c.set(6, 9, P.GOLD[3])
        c.set(9, 21, P.GOLD[3])
    c.outline()
    return c.image()


def mana_well():
    # 1.1 world units = 22 px: a stone ring with glowing water.
    c = Canvas(22, 22)
    c.blob(10.5, 15, 10, 6, P.STONE, None)
    c.blob(10.5, 13.5, 7.5, 3.2, P.WATER)
    c.set(8, 12, P.WHITE)
    c.set(13, 14, P.WATER[3])
    for x in range(3, 19, 4):                     # rim blocks
        c.set(x, 17, P.STONE[0])
        c.set(x, 18, P.STONE[0])
    c.rect(3, 3, 4, 13, P.WOOD[2])                # posts and roof beam
    c.rect(16, 3, 17, 13, P.WOOD[1])
    c.rect(2, 2, 18, 3, P.WOOD[3])
    c.rect(2, 3, 18, 3, P.WOOD[1])
    c.line(10, 3, 10, 11, P.STONE[1])
    c.outline()
    return c.image()


def shrine():
    # 1.3 world units = 26 px: stepped stone altar with a glowing orb.
    c = Canvas(20, 26)
    c.rect(1, 21, 18, 25, P.STONE[1])
    c.rect(1, 21, 18, 21, P.STONE[3])
    c.rect(4, 12, 15, 20, P.STONE[2])
    c.rect(4, 12, 4, 20, P.STONE[3])
    c.rect(14, 12, 15, 20, P.STONE[1])
    c.rect(3, 11, 16, 12, P.STONE[3])
    c.blob(9.5, 7, 3.4, 3.4, P.PURPLE)
    c.set(8, 5, P.WHITE)
    for x, y in ((7, 15), (9, 16), (11, 15), (9, 18)):
        c.set(x, y, P.PURPLE[2])
    c.outline()
    return c.image()


def burial_mound():
    # 0.95 world units = 19 px: earth mound with a leaning grave marker.
    c = Canvas(22, 19)
    c.blob(10.5, 15.5, 10, 4.5, P.EARTH)
    for x, y in ((5, 14), (13, 13), (16, 15), (8, 16)):
        c.set(x, y, P.STONE[2])
    c.rect(9, 3, 12, 12, P.STONE[2])
    c.rect(9, 3, 9, 12, P.STONE[3])
    c.rect(12, 3, 12, 12, P.STONE[1])
    c.rect(10, 2, 11, 2, P.STONE[2])
    c.set(10, 5, P.STONE[0])
    c.set(11, 5, P.STONE[0])
    c.set(10, 7, P.STONE[0])
    c.set(11, 8, P.STONE[0])
    c.set(7, 11, P.GREEN[2])
    c.set(15, 12, P.GREEN[1])
    c.outline()
    return c.image()


def blight_heart():
    # 1.5 world units = 30 px: purple crystal cluster around a skull.
    rng = random.Random(7)
    c = Canvas(22, 30)
    spikes = [(11, 2, 3.0), (6, 9, 2.2), (16, 8, 2.4), (3, 16, 1.8), (19, 15, 1.9)]
    for sx, sy, w in spikes:
        for y in range(sy, 27):
            t = (y - sy) / (27 - sy)
            half = w * min(1.0, t * 2.2)
            for x in range(int(sx - half), int(sx + half) + 1):
                i = 3 if x < sx - half * 0.3 and t < 0.5 else (2 if x <= sx else 1)
                c.set(x, y, P.PURPLE[i if i < 3 else 2] if i != 3 else P.PINK[3])
    c.blob(11, 22, 4.5, 4.0, [P.STONE[1], P.STONE[2], P.STONE[3], P.WHITE])
    c.set(9, 22, P.OUTLINE)
    c.set(13, 22, P.OUTLINE)
    c.set(11, 24, P.OUTLINE)
    for _ in range(4):
        c.set(rng.randint(4, 18), rng.randint(26, 29), P.PURPLE[1])
    c.rect(4, 27, 18, 29, P.PURPLE[0])
    c.outline()
    return c.image()


def headstone(variant):
    # GID-143: graveyard dressing, ~0.9 world units. Three shapes: round-top,
    # cross, slab; mossy at the foot, a crack on one.
    c = Canvas(14, 19)
    ramp = P.STONE if variant != 1 else P.STONE_WARM
    if variant == 1:  # cross
        c.rect(6, 3, 7, 16, ramp[2])
        c.rect(3, 6, 10, 7, ramp[2])
        c.rect(6, 3, 6, 16, ramp[3])
        c.rect(3, 6, 10, 6, ramp[3])
    else:
        top = 3 if variant == 0 else 5
        c.rect(3, top + 2, 10, 16, ramp[2])
        c.rect(3, top + 2, 3, 16, ramp[3])
        c.rect(10, top + 2, 10, 16, ramp[1])
        if variant == 0:
            c.blob(6.5, top + 2, 3.6, 2.4, ramp)
        else:
            c.rect(3, top, 10, top + 1, ramp[2])
        c.line(5, top + 5, 8, top + 5, ramp[0])       # inscription
        c.line(5, top + 7, 8, top + 7, ramp[0])
        if variant == 2:
            c.line(8, top + 1, 7, top + 4, ramp[0])   # a crack
    c.rect(2, 16, 11, 17, P.EARTH[1])
    c.set(3, 15, P.GREEN[1])
    c.set(10, 16, P.GREEN[2])
    c.outline()
    return c.image()


def iron_fence():
    # A low wrought-iron fence segment, 2 tiles wide (~40 px at 0.05), ~0.8 units tall.
    c = Canvas(40, 17)
    dark = [(17, 17, 17), (34, 34, 34), (42, 42, 58), (82, 96, 124)]
    c.rect(0, 5, 39, 5, dark[2])
    c.rect(0, 13, 39, 13, dark[2])
    for x in range(1, 40, 4):
        c.rect(x, 3, x, 16, dark[3] if x % 8 == 1 else dark[2])
        c.set(x, 2, dark[3])                           # spear tip
    c.outline()
    return c.image()


def crypt_door():
    # The sealed crypt's facade: stone lintel, iron-banded door, a skull boss.
    c = Canvas(26, 30)
    c.rect(2, 4, 23, 29, P.STONE[1])
    c.rect(2, 4, 23, 7, P.STONE[2])                   # lintel
    c.rect(2, 4, 23, 4, P.STONE[3])
    c.rect(7, 10, 18, 29, P.WOOD[0])                  # door
    c.rect(7, 10, 18, 10, P.WOOD[1])
    for y in (14, 20, 26):
        c.rect(7, y, 18, y, (42, 42, 58))             # iron bands
    c.blob(12.5, 7.5, 2.2, 2.0, [P.STONE[1], P.STONE[2], P.STONE[3], P.WHITE])
    c.set(11.5, 7, P.OUTLINE)
    c.set(13.5, 7, P.OUTLINE)
    c.set(4, 20, P.GREEN[1])
    c.set(21, 12, P.GREEN[2])
    c.outline()
    return c.image()


def pad(img, w, h):
    """Place a trimmed sprite bottom-centre on a fixed w×h canvas (callers size by pixels)."""
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(img, ((w - img.width) // 2, h - img.height))
    return out


def chest_body(c, lid_open=False, x0=1, y0=3):
    """A 14-px planked chest in iron corner bands with a gold lock; the lid is shut or thrown back.

    Rows y0..y0+4 are the lid, y0+5..y0+12 the box (the mimic reuses this and clears the lid rows).
    """
    wood = P.WOOD
    iron = [(42, 42, 58), (82, 96, 124), (123, 137, 148), (192, 203, 220)]
    base_top = y0 + 5
    bottom = y0 + 12
    # box: two planks with a dark seam, shaded darker to the right
    c.rect(x0, base_top, x0 + 13, bottom, wood[1])
    c.rect(x0 + 1, base_top, x0 + 6, bottom - 1, wood[2])
    c.line(x0, base_top + 3, x0 + 13, base_top + 3, wood[0])
    c.line(x0, bottom, x0 + 13, bottom, wood[0])
    if lid_open:
        # lid thrown back: its dark underside above, loot heaped in the box mouth
        c.rect(x0 + 1, y0 - 1, x0 + 12, y0 + 2, wood[0])
        c.line(x0 + 1, y0 - 1, x0 + 12, y0 - 1, wood[1])
        c.rect(x0 + 1, y0 + 3, x0 + 12, base_top, (42, 30, 26))          # shadowed interior
        c.blob(x0 + 6.5, base_top - 0.5, 5.2, 2.0, P.GOLD)                # coin heap
        for x, y in ((x0 + 3, base_top - 2), (x0 + 8, base_top - 2), (x0 + 5, base_top - 3)):
            c.set(x, y, P.GOLD[3])
        c.set(x0 + 9, base_top - 1, P.BLUE[3])                            # gems
        c.set(x0 + 3, base_top, P.RED[2])
        c.line(x0, base_top + 1, x0 + 13, base_top + 1, wood[3])          # lit box rim
    else:
        # domed lid: highlight on top, a plank line, a dark lip over the box
        c.rect(x0 + 1, y0, x0 + 12, y0, wood[3])
        c.rect(x0, y0 + 1, x0 + 13, y0 + 3, wood[2])
        c.line(x0 + 1, y0 + 1, x0 + 7, y0 + 1, wood[3])
        c.line(x0, y0 + 4, x0 + 13, y0 + 4, wood[0])
    top = y0 - 1 if lid_open else y0
    for bx in (x0 + 2, x0 + 11):                                          # iron straps + rivets
        c.line(bx, top if not lid_open else y0 + 3, bx, bottom, iron[1])
        c.set(bx, base_top + 1, iron[3])
        c.set(bx, bottom - 1, iron[3])
    for bx in (x0, x0 + 13):                                              # corner bands
        c.line(bx, base_top, bx, bottom, iron[0])
    if not lid_open:
        c.rect(x0 + 6, y0 + 4, x0 + 7, base_top + 1, P.GOLD[1])           # hasp + lock plate
        c.set(x0 + 6, y0 + 4, P.GOLD[3])
        c.set(x0 + 7, base_top + 1, P.OUTLINE)                            # keyhole


def chest(lid_open):
    c = Canvas(16, 16)
    chest_body(c, lid_open)
    c.outline()
    return pad(c.image(), 16, 16)


def door():
    """Every map-transition door: an arched plank door in a stone frame, iron hinges and ring."""
    c = Canvas(32, 32)
    cx = 15.5
    for y in range(2, 32):                                # stone arch frame
        half = 12 if y > 9 else math.sqrt(max(0.0, 144 - (9 - y) ** 2 * 1.9))
        c.line(cx - half, y, cx + half, y, P.STONE[1] if (y + int(half)) % 5 else P.STONE[2])
    for y in range(5, 32):                                # planks
        half = 9 if y > 11 else math.sqrt(max(0.0, 81 - (11 - y) ** 2 * 1.3))
        for x in range(int(cx - half), int(cx + half) + 1):
            c.set(x, y, P.WOOD[1] if (x - 7) % 4 else P.WOOD[0])
    c.line(7, 12, 24, 12, P.WOOD[2])
    for y in (13, 24):                                    # hinges
        c.rect(7, y, 12, y + 1, (42, 42, 58))
        c.set(7, y, (123, 137, 148))
    c.blob(20.5, 20, 1.6, 1.6, [(42, 42, 58), (82, 96, 124), (123, 137, 148), (192, 203, 220)])  # ring
    c.set(20.5, 20, P.WOOD[0])
    c.set(5, 17, P.GREEN[1])                              # moss
    c.set(26, 26, P.GREEN[2])
    c.outline()
    return pad(c.image(), 32, 32)


LANDMARKS = {
    "headstone_0": lambda: headstone(0),
    "headstone_1": lambda: headstone(1),
    "headstone_2": lambda: headstone(2),
    "iron_fence": iron_fence,
    "crypt_door": crypt_door,
    "waystone_dormant": lambda: waystone(False),
    "waystone_active": lambda: waystone(True),
    "mana_well": mana_well,
    "puzzle_shrine": shrine,
    "burial_mound": burial_mound,
    "blight_heart": blight_heart,
    # GID-144 / TID-612: replaced the 0x72 chest and door.
    "chest_closed": lambda: chest(False),
    "chest_open": lambda: chest(True),
    "door": door,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="write a contact sheet here")
    args = ap.parse_args()
    out = []
    for key, (fn, n) in PROPS.items():
        for v in range(n):
            img = fn(v * 7 + 3)
            img.save(OUT / f"prop_{key}_{v}.png")
            out.append(img)
    for name, fn in LANDMARKS.items():
        img = fn()
        img.save(OUT / f"{name}.png")
        out.append(img)
        print(f"  {name}.png {img.size}")
    if args.preview:
        s = 5
        w = sum(i.width + 3 for i in out) * s
        h = max(i.height for i in out) * s
        sheet = Image.new("RGBA", (w, h), (92, 138, 80, 255))
        x = 0
        for i in out:
            sheet.alpha_composite(i.resize((i.width * s, i.height * s), Image.NEAREST), (x, h - i.height * s))
            x += (i.width + 3) * s
        sheet.save(args.preview)


if __name__ == "__main__":
    main()
