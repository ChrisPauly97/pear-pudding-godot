"""Pixel-art square set pieces for the stitched story towns (TownDecor).

Writes assets/textures/props/:
  well_0..3.png     Larik's village well (the bucket rope sways, water glints)
  brazier_0..3.png  Marsax Hold's courtyard war brazier (the fire flickers)
  statue_0..3.png   Blancogov's gilded statue of the first king (a glint runs over it)
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


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("well", well), ("brazier", brazier), ("statue", statue)):
        for i in range(FRAMES):
            fn(i).save(os.path.join(OUT, "%s_%d.png" % (name, i)))
    print("wrote well / brazier / statue frames to %s" % os.path.normpath(OUT))


if __name__ == "__main__":
    main()
