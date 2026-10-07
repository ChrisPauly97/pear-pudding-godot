"""Pixel-art set dressing for Madrian's starter camps (GID-166 / TID-687).

Each quest camp (game_logic/world/StarterZone.gd CAMPS) is dressed to match its
name: the Old Orchard gets apple trees, the Grain-Store Field a granary and hay,
the North Barrow its mound and stones, the South Road Wreck a broken cart...

Writes camp_<key>.png into assets/textures/props/. Same style as the legend
props: flat shapes, two-tone shading, 1px dark outline.
Usage: python3 tools/generate_camp_props.py   (needs Pillow)
"""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from generate_legend_props import (  # noqa: E402
    BARK, BARK_D, LEAF, LEAF_D, LEAF_L, MOSS, MOSS_L, OUTLINE, STONE_D, STONE_HI, STONE_L, _blob, _outline,
    _stone,
)

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "props")
APPLE = (196, 52, 48, 255)
APPLE_L = (236, 104, 84, 255)
WOOD = (150, 104, 62, 255)
WOOD_L = (186, 138, 86, 255)
WOOD_D = (104, 70, 44, 255)
HAY = (222, 186, 88, 255)
HAY_L = (246, 220, 134, 255)
HAY_D = (176, 138, 58, 255)
SACK = (196, 172, 128, 255)
SACK_D = (150, 126, 90, 255)
THATCH = (190, 150, 74, 255)
THATCH_D = (140, 104, 50, 255)
GRASS = (78, 140, 70, 255)
GRASS_D = (54, 104, 56, 255)
GRASS_L = (110, 172, 86, 255)
DARK = (42, 34, 40, 255)
IRON = (90, 92, 104, 255)
CLOTH = (120, 60, 52, 255)
HEDGE = (52, 104, 52, 255)
HEDGE_L = (78, 140, 66, 255)
HEDGE_D = (36, 76, 42, 255)


def _img(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def _speckle(img, rng, box, colours, n):
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        if img.getpixel((x, y))[3] and img.getpixel((x, y)) != OUTLINE:
            img.putpixel((x, y), rng.choice(colours))


def apple_tree(seed):
    """Round, well-kept fruit tree: straight trunk, full crown, red apples."""
    rng = random.Random(seed)
    img, d = _img(44, 54)
    lean = rng.choice((-1, 0, 1))
    d.polygon([(19, 53), (25, 53), (24 + lean, 34), (20 + lean, 34)], fill=BARK)
    d.polygon([(22, 53), (25, 53), (24 + lean, 34), (22 + lean, 34)], fill=BARK_D)
    d.line([(22 + lean, 36), (14, 28)], fill=BARK, width=2)
    d.line([(22 + lean, 35), (30, 27)], fill=BARK, width=2)
    _blob(d, 22, 21, 17, LEAF)
    for cx, cy, r in ((12, 24, 8), (32, 24, 8), (22, 12, 10)):
        _blob(d, cx, cy, r, LEAF)
    for cx, cy, r in ((16, 14, 5), (27, 10, 5), (11, 21, 3)):
        _blob(d, cx, cy, r, LEAF_L)
    for cx, cy, r in ((18, 31, 5), (30, 30, 4), (24, 25, 3)):
        _blob(d, cx, cy, r, LEAF_D)
    _speckle(img, rng, (4, 3, 40, 36), [LEAF_D, LEAF_L], 50)
    for _ in range(9):
        x, y = rng.randrange(8, 37), rng.randrange(8, 33)
        if img.getpixel((x, y))[3]:
            d.rectangle([x, y, x + 1, y + 1], fill=APPLE)
            img.putpixel((x, y), APPLE_L)
    return _outline(img)


def apple_basket():
    img, d = _img(18, 14)
    d.ellipse([2, 1, 15, 7], fill=APPLE)
    for x, y in ((4, 2), (8, 1), (12, 3), (6, 4), (10, 4)):
        img.putpixel((x, y), APPLE_L)
    d.polygon([(1, 5), (16, 5), (14, 13), (3, 13)], fill=WOOD)
    for y in (7, 10):
        d.line([(2, y), (15, y)], fill=WOOD_D)
    d.line([(4, 6), (5, 12)], fill=WOOD_L)
    return _outline(img)


def hay_bale():
    img, d = _img(22, 16)
    d.rectangle([1, 3, 20, 14], fill=HAY)
    d.polygon([(1, 3), (5, 0), (21, 0), (20, 3)], fill=HAY_L)
    d.rectangle([15, 3, 20, 14], fill=HAY_D)
    for x in (7, 12):
        d.line([(x, 1), (x, 14)], fill=WOOD_D)
    rng = random.Random(5)
    _speckle(img, rng, (1, 0, 21, 15), [HAY_D, HAY_L], 30)
    return _outline(img)


def grain_sacks():
    img, d = _img(22, 18)
    for x0, y0 in ((1, 5), (11, 5), (6, 0)):
        d.ellipse([x0, y0 + 2, x0 + 9, y0 + 12], fill=SACK)
        d.rectangle([x0 + 3, y0, x0 + 6, y0 + 3], fill=SACK_D)
        d.line([(x0 + 2, y0 + 3), (x0 + 7, y0 + 3)], fill=WOOD_D)
        d.ellipse([x0 + 5, y0 + 5, x0 + 9, y0 + 12], fill=SACK_D)
    return _outline(img)


def granary():
    """Small raised timber store on stone staddles, thatched roof."""
    img, d = _img(40, 40)
    for x in (5, 17, 30):
        d.rectangle([x, 33, x + 4, 39], fill=STONE_L)
        d.ellipse([x - 1, 31, x + 5, 34], fill=STONE_D)
    d.rectangle([3, 16, 36, 31], fill=WOOD)
    d.rectangle([26, 16, 36, 31], fill=WOOD_D)
    for y in (20, 24, 28):
        d.line([(3, y), (36, y)], fill=WOOD_D)
    d.rectangle([13, 19, 20, 31], fill=DARK)
    d.line([(13, 19), (20, 19)], fill=WOOD_L)
    d.polygon([(0, 17), (20, 1), (39, 17)], fill=THATCH)
    d.polygon([(20, 1), (39, 17), (28, 17)], fill=THATCH_D)
    rng = random.Random(11)
    _speckle(img, rng, (1, 2, 38, 17), [THATCH_D, HAY_L], 40)
    return _outline(img)


def scarecrow():
    img, d = _img(22, 36)
    d.rectangle([10, 10, 11, 35], fill=WOOD_D)
    d.rectangle([2, 13, 19, 14], fill=WOOD_D)
    d.polygon([(6, 13), (15, 13), (16, 26), (5, 26)], fill=CLOTH)
    d.line([(10, 14), (10, 25)], fill=(90, 44, 40, 255))
    for x in (2, 4, 17, 19):
        d.line([(x, 14), (x, 17)], fill=HAY)
    d.ellipse([6, 3, 15, 12], fill=SACK)
    d.point([(9, 7), (12, 7)], fill=DARK)
    d.polygon([(4, 5), (17, 5), (13, 0), (8, 0)], fill=THATCH_D)
    d.line([(3, 5), (18, 5)], fill=THATCH_D)
    return _outline(img)


def wheat_sheaf():
    img, d = _img(14, 20)
    d.polygon([(4, 19), (10, 19), (9, 9), (5, 9)], fill=HAY)
    d.line([(4, 13), (10, 13)], fill=WOOD_D)
    for x in range(2, 13, 2):
        d.line([(7, 9), (x, 2)], fill=HAY_D)
        d.ellipse([x - 1, 0, x + 1, 3], fill=HAY_L)
    return _outline(img)


def barrow_mound():
    """Long grassy barrow with a dark stone-lintelled entrance."""
    img, d = _img(56, 30)
    d.ellipse([0, 6, 55, 34], fill=GRASS)
    d.ellipse([24, 8, 55, 34], fill=GRASS_D)
    rng = random.Random(17)
    _speckle(img, rng, (2, 7, 54, 29), [GRASS_L, GRASS_D], 70)
    d.rectangle([20, 17, 33, 29], fill=STONE_D)
    d.rectangle([23, 20, 30, 29], fill=DARK)
    d.rectangle([18, 15, 35, 17], fill=STONE_L)
    d.line([(18, 15), (35, 15)], fill=STONE_HI)
    return _outline(img)


def standing_stone(seed):
    img, d = _img(14, 28)
    lean = (-1, 0, 2)[seed % 3]
    _stone(d, 3, 2, 9, 27, lean)
    return _outline(img)


def ruin_pillar(seed):
    """A broken column: fluted shaft snapped off at a jagged top."""
    rng = random.Random(seed)
    img, d = _img(16, 36)
    top = (4, 10)[seed % 2]
    d.rectangle([1, 31, 14, 35], fill=STONE_L)
    d.rectangle([3, top, 12, 31], fill=STONE_L)
    d.rectangle([9, top, 12, 31], fill=STONE_D)
    d.line([(6, top + 2), (6, 30)], fill=STONE_D)
    d.line([(4, top + 1), (4, 30)], fill=STONE_HI)
    jag = [(3, top), (5, top - 3), (7, top), (9, top - 2), (12, top + 1)]
    d.polygon(jag + [(12, top + 2), (3, top + 2)], fill=STONE_L)
    for _ in range(8):
        x, y = rng.randrange(3, 13), rng.randrange(top + 4, 32)
        img.putpixel((x, y), MOSS if rng.random() < 0.6 else MOSS_L)
    return _outline(img)


def rubble():
    img, d = _img(26, 12)
    rng = random.Random(23)
    for x, y, w, h in ((1, 5, 7, 6), (7, 2, 8, 9), (15, 4, 9, 7), (11, 8, 6, 3)):
        d.rectangle([x, y, x + w, y + h], fill=STONE_L)
        d.rectangle([x + w - 2, y, x + w, y + h], fill=STONE_D)
        d.line([(x, y), (x + w - 3, y)], fill=STONE_HI)
    _speckle(img, rng, (1, 2, 25, 12), [MOSS, MOSS_L], 10)
    return _outline(img)


def hedge():
    img, d = _img(32, 18)
    for cx, cy, r in ((7, 10, 7), (16, 8, 8), (25, 10, 7)):
        _blob(d, cx, cy, r, HEDGE)
    d.rectangle([1, 10, 31, 17], fill=HEDGE)
    for cx, cy, r in ((6, 6, 3), (15, 4, 3), (24, 6, 3)):
        _blob(d, cx, cy, r, HEDGE_L)
    d.rectangle([1, 14, 31, 17], fill=HEDGE_D)
    rng = random.Random(29)
    _speckle(img, rng, (1, 1, 31, 17), [HEDGE_D, HEDGE_L], 45)
    return _outline(img)


def signpost():
    img, d = _img(26, 34)
    d.rectangle([12, 6, 14, 33], fill=WOOD_D)
    d.polygon([(2, 7), (20, 7), (24, 10), (20, 13), (2, 13)], fill=WOOD_L)
    d.polygon([(24, 16), (6, 16), (2, 19), (6, 22), (24, 22)], fill=WOOD)
    for y in (10, 19):
        d.line([(6, y), (18, y)], fill=WOOD_D)
    d.rectangle([11, 4, 15, 6], fill=WOOD_D)
    return _outline(img)


def fence_post():
    """A short run of split-rail fence (one post and its rails)."""
    img, d = _img(30, 18)
    for x in (2, 26):
        d.rectangle([x, 2, x + 2, 17], fill=WOOD_D)
    d.line([(2, 6), (28, 7)], fill=WOOD_L, width=2)
    d.line([(2, 12), (28, 11)], fill=WOOD, width=2)
    return _outline(img)


def tor_rock():
    """Stacked granite slabs, the summit of the tor."""
    img, d = _img(48, 40)
    for x0, y0, x1, y1 in ((2, 22, 46, 39), (8, 11, 38, 23), (14, 2, 32, 12)):
        d.rectangle([x0, y0, x1, y1], fill=STONE_L)
        d.rectangle([(x0 + x1) // 2 + 4, y0, x1, y1], fill=STONE_D)
        d.line([(x0, y0), (x1, y0)], fill=STONE_HI)
    rng = random.Random(31)
    _speckle(img, rng, (2, 2, 46, 39), [MOSS, MOSS_L, STONE_D], 40)
    return _outline(img)


def broken_cart():
    """Overturned cart: tipped bed, one wheel off, a snapped shaft."""
    img, d = _img(48, 30)
    d.polygon([(4, 12), (34, 6), (38, 20), (8, 26)], fill=WOOD)
    d.polygon([(34, 6), (38, 20), (35, 21), (31, 8)], fill=WOOD_D)
    for t in (0.33, 0.66):
        x0, y0 = 4 + 30 * t, 12 - 6 * t
        d.line([(x0, y0), (x0 + 4, y0 + 14)], fill=WOOD_D)
    d.ellipse([28, 14, 42, 28], fill=WOOD_D)
    d.ellipse([31, 17, 39, 25], fill=WOOD)
    d.line([(35, 15), (35, 27)], fill=WOOD_D)
    d.line([(29, 21), (41, 21)], fill=WOOD_D)
    d.ellipse([40, 20, 47, 29], fill=WOOD_D)  # loose wheel, flat on the ground
    d.ellipse([42, 22, 45, 27], fill=WOOD_L)
    d.line([(2, 20), (14, 27)], fill=WOOD_L, width=2)  # snapped shaft
    d.rectangle([12, 22, 18, 27], fill=SACK)  # spilled sack
    return _outline(img)


def crate():
    img, d = _img(16, 16)
    d.rectangle([1, 4, 14, 15], fill=WOOD)
    d.polygon([(1, 4), (4, 1), (15, 1), (14, 4)], fill=WOOD_L)
    d.rectangle([11, 4, 14, 15], fill=WOOD_D)
    d.line([(1, 4), (11, 15)], fill=WOOD_D)
    d.line([(1, 9), (11, 9)], fill=WOOD_D)
    return _outline(img)


def barrel():
    img, d = _img(14, 18)
    d.ellipse([1, 1, 12, 6], fill=WOOD_L)
    d.rectangle([1, 3, 12, 15], fill=WOOD)
    d.ellipse([1, 12, 12, 17], fill=WOOD)
    d.rectangle([9, 3, 12, 15], fill=WOOD_D)
    for y in (5, 12):
        d.line([(1, y), (12, y)], fill=IRON)
    d.ellipse([3, 2, 10, 5], fill=WOOD_D)
    return _outline(img)


PROPS = {
    "apple_tree_0": lambda: apple_tree(1),
    "apple_tree_1": lambda: apple_tree(2),
    "apple_basket": apple_basket,
    "hay_bale": hay_bale,
    "grain_sacks": grain_sacks,
    "granary": granary,
    "scarecrow": scarecrow,
    "wheat_sheaf": wheat_sheaf,
    "barrow_mound": barrow_mound,
    "standing_stone_0": lambda: standing_stone(0),
    "standing_stone_1": lambda: standing_stone(1),
    "ruin_pillar_0": lambda: ruin_pillar(0),
    "ruin_pillar_1": lambda: ruin_pillar(1),
    "rubble": rubble,
    "hedge": hedge,
    "signpost": signpost,
    "fence_post": fence_post,
    "tor_rock": tor_rock,
    "broken_cart": broken_cart,
    "crate": crate,
    "barrel": barrel,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for key, fn in PROPS.items():
        fn().save(os.path.join(OUT, "camp_%s.png" % key))
    print("wrote %d camp props to %s" % (len(PROPS), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
