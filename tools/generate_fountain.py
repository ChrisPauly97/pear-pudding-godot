"""Pixel-art village fountain for Madrian's square (GID-167 / TID-688).

Writes assets/textures/props/fountain_0..3.png: a round stone basin with a
pedestal and upper bowl, water arcing from the top; the frames shift the spray
and the ripples so it loops as an animation. Same style as the legend / camp
props: flat shapes, two-tone shading, 1px dark outline.
Usage: python3 tools/generate_fountain.py   (needs Pillow)
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from generate_legend_props import MOSS, STONE_D, STONE_HI, STONE_L, _outline  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "props")
WATER = (72, 140, 206, 255)
WATER_D = (46, 98, 168, 255)
WATER_L = (150, 206, 240, 255)
FOAM = (226, 244, 252, 255)
FRAMES = 4
W, H = 64, 56


def frame(i):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Basin: back rim, water, front wall.
    d.ellipse([2, 26, 61, 46], fill=STONE_L)
    d.ellipse([6, 28, 57, 42], fill=WATER)
    d.ellipse([10, 31, 53, 41], fill=WATER_D)
    d.rectangle([2, 36, 61, 49], fill=STONE_L)
    d.ellipse([2, 43, 61, 55], fill=STONE_L)
    d.rectangle([40, 37, 61, 50], fill=STONE_D)
    d.ellipse([40, 44, 61, 55], fill=STONE_D)
    d.rectangle([40, 37, 61, 44], fill=STONE_L)  # keep the rim top lit
    d.line([(4, 37), (59, 37)], fill=STONE_HI)
    for x in (12, 22, 32, 42, 52):
        d.line([(x, 39), (x, 52)], fill=STONE_D)
    d.line([(3, 45), (60, 45)], fill=STONE_D)
    for x, y in ((8, 50), (20, 52), (46, 51), (56, 47)):
        d.point([(x, y), (x + 1, y)], fill=MOSS)
    # Pedestal and upper bowl.
    d.rectangle([28, 16, 35, 36], fill=STONE_L)
    d.rectangle([32, 16, 35, 36], fill=STONE_D)
    d.ellipse([18, 12, 45, 20], fill=STONE_L)
    d.ellipse([21, 12, 42, 16], fill=WATER)
    d.polygon([(20, 17), (43, 17), (37, 23), (26, 23)], fill=STONE_L)
    d.polygon([(32, 17), (43, 17), (37, 23), (32, 23)], fill=STONE_D)
    # Top spout.
    d.rectangle([30, 6, 33, 13], fill=STONE_L)
    d.ellipse([28, 3, 35, 8], fill=STONE_L)
    img = _outline(img)
    d = ImageDraw.Draw(img)
    # Moving water goes on after the outline, so droplets stay light.
    for k in range(2):
        r = 6 + ((i * 3 + k * 8) % 16)
        d.arc([32 - r, 34 - r // 3, 32 + r, 34 + r // 3], 200, 340, fill=WATER_L)
    for side in (-1, 1):
        for t in range(10):
            x = 32 + side * (2 + t * 2)
            y = 4 + (t * t) // 4 - 2 + (t // 3)
            if 0 <= y < 30:
                c = FOAM if (t + i) % 3 == 0 else WATER_L
                d.point([(x, y), (x, y + 1)], fill=c)
        # Overflow streams from the bowl to the basin.
        for y in range(19, 33):
            if (y + i * 2) % 4 != 0:
                d.point([(32 + side * 12 + (y - 19) // 5 * side, y)], fill=WATER_L)
    for x in (24, 32, 40):
        d.point([(x + (i % 2), 33 + (i % 3)), (x - 1, 34)], fill=FOAM)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for i in range(FRAMES):
        frame(i).save(os.path.join(OUT, "fountain_%d.png" % i))
    print("wrote %d fountain frames to %s" % (FRAMES, os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
