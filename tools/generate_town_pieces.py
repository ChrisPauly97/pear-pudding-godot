"""Pixel-art square set pieces for the stitched story towns (TownDecor).

Writes assets/textures/props/:
  well_0..3.png     Larik's village well (the bucket rope sways, water glints)
  brazier_0..3.png  Marsax Hold's courtyard war brazier (the fire flickers)
  statue_0..3.png   Blancogov's gilded statue of the first king (a glint runs over it)
  grand_fountain_0..3.png  Maykalene's white-marble three-tier fountain (water falls and sprays)
Same style as the fountain / legend props: flat shapes, two-tone shading, 1px outline.
Usage: python3 tools/generate_town_pieces.py   (needs Pillow)
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from generate_legend_props import (  # noqa: E402
    BARK, BARK_D, GOLD, GOLD_D, GOLD_L, MOSS, STONE_D, STONE_HI, STONE_L, _outline)

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "props")
FRAMES = 4
WATER = (46, 98, 168, 255)
WATER_L = (150, 206, 240, 255)
IRON = (58, 58, 66, 255)
IRON_L = (96, 96, 108, 255)
FIRE = (236, 112, 36, 255)
FIRE_L = (255, 196, 72, 255)
FIRE_HI = (255, 244, 180, 255)
ROPE = (196, 164, 108, 255)


def well(i):
    w, h = 48, 56
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Posts and roof.
    d.rectangle([8, 14, 11, 40], fill=BARK)
    d.rectangle([36, 14, 39, 40], fill=BARK_D)
    d.polygon([(2, 16), (24, 3), (45, 16)], fill=BARK_D)
    d.polygon([(6, 15), (24, 6), (24, 15)], fill=BARK)
    d.rectangle([10, 17, 37, 18], fill=BARK_D)  # winch beam
    # Stone ring.
    d.ellipse([4, 32, 43, 44], fill=STONE_L)
    d.ellipse([9, 34, 38, 41], fill=WATER)
    d.rectangle([4, 38, 43, 50], fill=STONE_L)
    d.ellipse([4, 44, 43, 54], fill=STONE_L)
    d.rectangle([28, 38, 43, 50], fill=STONE_D)
    d.ellipse([28, 44, 43, 54], fill=STONE_D)
    d.line([(6, 39), (41, 39)], fill=STONE_HI)
    for x in (12, 20, 28, 36):
        d.line([(x, 40), (x, 51)], fill=STONE_D)
    d.point([(9, 48), (10, 48), (31, 50)], fill=MOSS)
    img = _outline(img)
    d = ImageDraw.Draw(img)
    # Rope and bucket sway; glint on the water.
    sway = (0, 1, 0, -1)[i]
    d.line([(24, 19), (24 + sway, 28)], fill=ROPE)
    d.rectangle([21 + sway, 28, 27 + sway, 32], fill=BARK)
    d.point([(14 + i * 4, 37), (15 + i * 4, 37)], fill=WATER_L)
    return img


def brazier(i):
    w, h = 40, 60
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Tripod legs and bowl.
    d.line([(20, 34), (8, 58)], fill=IRON, width=3)
    d.line([(20, 34), (32, 58)], fill=IRON, width=3)
    d.line([(20, 34), (20, 58)], fill=IRON_L, width=2)
    d.polygon([(4, 28), (36, 28), (30, 38), (10, 38)], fill=IRON)
    d.polygon([(4, 28), (20, 28), (20, 38), (10, 38)], fill=IRON_L)
    d.rectangle([3, 26, 37, 29], fill=IRON_L)
    img = _outline(img)
    d = ImageDraw.Draw(img)
    # Flames after the outline so they stay bright.
    tips = ((10, 8), (16, 2), (22, 5), (28, 10))
    for k, (x, top) in enumerate(tips):
        top += (i + k) % 3 * 2
        d.polygon([(x - 5, 26), (x + 5, 26), (x + (1 if (i + k) % 2 else -1), top)], fill=FIRE)
        d.polygon([(x - 3, 26), (x + 3, 26), (x, top + 7)], fill=FIRE_L)
    d.ellipse([14, 18, 26, 26], fill=FIRE_HI)
    for k in range(3):
        y = 2 + ((i * 5 + k * 7) % 14)
        d.point([(8 + k * 11 + i % 2, y)], fill=FIRE_L)
    return img


def statue(i):
    w, h = 40, 72
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Plinth.
    d.rectangle([4, 54, 35, 70], fill=STONE_L)
    d.rectangle([22, 54, 35, 70], fill=STONE_D)
    d.rectangle([2, 52, 37, 55], fill=STONE_HI)
    d.rectangle([2, 66, 37, 70], fill=STONE_L)
    # Gilded king: robe, arms, head, crown, raised sword.
    d.polygon([(12, 52), (28, 52), (25, 24), (15, 24)], fill=GOLD)
    d.polygon([(20, 52), (28, 52), (25, 24), (20, 24)], fill=GOLD_D)
    d.rectangle([14, 24, 26, 30], fill=GOLD)
    d.ellipse([15, 13, 25, 24], fill=GOLD)
    d.ellipse([20, 13, 25, 24], fill=GOLD_D)
    d.polygon([(15, 14), (17, 9), (19, 13), (20, 8), (21, 13), (23, 9), (25, 14)], fill=GOLD_L)
    d.line([(27, 28), (31, 22)], fill=GOLD, width=3)
    d.rectangle([30, 2, 32, 24], fill=STONE_HI)
    d.rectangle([27, 22, 35, 23], fill=GOLD_D)
    d.line([(13, 28), (10, 40)], fill=GOLD, width=3)
    img = _outline(img)
    d = ImageDraw.Draw(img)
    # A glint sliding down the statue.
    y = 12 + i * 10
    d.point([(17, y), (18, y + 1), (16, y + 1)], fill=GOLD_L)
    d.point([(31, 4 + i * 5)], fill=(255, 255, 255, 255))
    return img


MARBLE_HI = (250, 248, 240, 255)
MARBLE = (226, 222, 210, 255)
MARBLE_D = (170, 166, 160, 255)
MARBLE_DD = (128, 126, 128, 255)
WATER_M = (72, 140, 206, 255)
FOAM = (226, 244, 252, 255)


def _bowl(d, cx, top, rx, ry, depth):
    """A scalloped marble bowl seen from the front: water surface, gold band, carved lip."""
    d.ellipse([cx - rx, top, cx + rx, top + ry * 2], fill=MARBLE)
    d.ellipse([cx - rx + 3, top + 2, cx + rx - 3, top + ry * 2 - 2], fill=WATER_M)
    d.ellipse([cx - rx + 6, top + 4, cx + rx - 6, top + ry * 2 - 3], fill=WATER)
    mid = top + ry
    d.polygon([(cx - rx, mid), (cx + rx, mid), (cx + rx // 3, mid + depth), (cx - rx // 3, mid + depth)],
              fill=MARBLE)
    d.polygon([(cx + rx // 4, mid), (cx + rx, mid), (cx + rx // 3, mid + depth), (cx + rx // 6, mid + depth)],
              fill=MARBLE_D)
    d.line([(cx - rx + 1, mid + 1), (cx + rx - 1, mid + 1)], fill=GOLD)
    for k in range(-rx + 4, rx - 2, 6):  # scallops under the lip
        d.arc([cx + k - 3, mid + 1, cx + k + 3, mid + 6], 0, 180, fill=MARBLE_DD)


def _column(d, cx, top, bottom, half):
    d.rectangle([cx - half, top, cx + half, bottom], fill=MARBLE)
    d.rectangle([cx + 1, top, cx + half, bottom], fill=MARBLE_D)
    for x in range(cx - half + 2, cx + half, 3):  # fluting
        d.line([(x, top + 2), (x, bottom - 2)], fill=MARBLE_DD if x > cx else MARBLE_D)
    d.rectangle([cx - half - 2, top - 2, cx + half + 2, top], fill=GOLD)
    d.rectangle([cx - half - 2, bottom, cx + half + 2, bottom + 2], fill=GOLD_D)


def grand_fountain(i):
    w, h = 96, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = 48
    # Ground basin: octagonal marble wall with gold band and carved panels.
    d.ellipse([2, 58, 93, 82], fill=MARBLE)
    d.ellipse([7, 61, 88, 79], fill=WATER_M)
    d.ellipse([12, 64, 83, 77], fill=WATER)
    d.rectangle([2, 70, 93, 86], fill=MARBLE)
    d.ellipse([2, 78, 93, 94], fill=MARBLE)
    d.rectangle([62, 70, 93, 87], fill=MARBLE_D)
    d.ellipse([62, 79, 93, 94], fill=MARBLE_D)
    d.rectangle([62, 70, 93, 75], fill=MARBLE)
    d.line([(4, 71), (91, 71)], fill=MARBLE_HI)
    d.line([(3, 75), (92, 75)], fill=GOLD)
    for x in (10, 24, 38, 52, 66, 80):  # carved panels with gold rosettes
        d.rectangle([x, 78, x + 9, 85], outline=MARBLE_DD)
        d.point([(x + 4, 81), (x + 5, 81), (x + 4, 82), (x + 5, 82)], fill=GOLD_L)
    # Lower column, middle bowl, upper column, top bowl, gilded finial.
    _column(d, cx, 46, 70, 5)
    _bowl(d, cx, 38, 30, 6, 10)
    _column(d, cx, 22, 44, 3)
    _bowl(d, cx, 17, 17, 4, 7)
    d.rectangle([cx - 2, 8, cx + 2, 20], fill=MARBLE)
    d.ellipse([cx - 4, 2, cx + 4, 11], fill=GOLD)
    d.ellipse([cx, 2, cx + 4, 11], fill=GOLD_D)
    d.point([(cx - 2, 4)], fill=GOLD_L)
    # Two gilded fish spouts at the foot of the column.
    for side in (-1, 1):
        fx = cx + side * 9
        d.ellipse([fx - 4, 62, fx + 4, 68], fill=GOLD)
        d.polygon([(fx - side * 4, 65), (fx - side * 8, 61), (fx - side * 8, 69)], fill=GOLD_D)
    img = _outline(img)
    d = ImageDraw.Draw(img)
    # Water after the outline so it stays bright: top spray, curtains off both bowls, fish arcs, ripples.
    for side in (-1, 1):
        for t in range(8):
            x = cx + side * (1 + t * 2)
            y = 1 + (t * t) // 3 + (t // 2)
            if y < 19:
                d.point([(x, y), (x, y + 1)], fill=FOAM if (t + i) % 3 == 0 else WATER_L)
    for side in (-1, 1):
        for rx, y0, y1 in ((17, 26, 41), (30, 48, 68)):
            for y in range(y0, y1):
                if (y + i * 2) % 4 != 0:
                    d.point([(cx + side * (rx - 1) + side * ((y - y0) // 6), y)], fill=WATER_L)
        fx = cx + side * 13
        for t in range(6):
            d.point([(fx + side * t * 2, 65 + (t * t) // 3 - 2 + (i % 2))], fill=WATER_L)
    for k in range(3):
        r = 8 + ((i * 4 + k * 10) % 30)
        d.arc([cx - r, 70 - r // 4, cx + r, 70 + r // 4], 15, 165, fill=WATER_L)
    for x in (30, 48, 66):
        d.point([(x + (i % 2), 66 + (i % 3)), (x - 1, 67)], fill=FOAM)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("well", well), ("brazier", brazier), ("statue", statue),
                     ("grand_fountain", grand_fountain)):
        for i in range(FRAMES):
            fn(i).save(os.path.join(OUT, "%s_%d.png" % (name, i)))
    print("wrote well / brazier / statue frames to %s" % os.path.normpath(OUT))


if __name__ == "__main__":
    main()
