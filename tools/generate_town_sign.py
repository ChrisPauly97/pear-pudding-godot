"""Pixel-art shop signpost for the stitched towns (GID-168 / TID-689).

Writes assets/textures/props/town_sign.png: a wooden post with an arm and a
hanging painted board. Same style as the legend / camp props.
Usage: python3 tools/generate_town_sign.py   (needs Pillow)
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from generate_camp_props import WOOD, WOOD_D, WOOD_L  # noqa: E402
from generate_legend_props import GOLD, GOLD_D, _outline  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "props")
PAINT = (128, 52, 44, 255)
PAINT_D = (96, 38, 34, 255)
IRON = (70, 70, 84, 255)


def sign():
    img = Image.new("RGBA", (24, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([3, 2, 5, 35], fill=WOOD_D)  # post
    d.rectangle([2, 33, 7, 35], fill=WOOD_D)
    d.rectangle([3, 3, 22, 5], fill=WOOD)  # arm
    d.line([(4, 9), (10, 5)], fill=WOOD_D, width=1)  # brace
    for x in (10, 19):  # chains
        d.line([(x, 6), (x, 9)], fill=IRON)
    d.rectangle([8, 10, 22, 21], fill=PAINT)
    d.rectangle([8, 18, 22, 21], fill=PAINT_D)
    d.rectangle([8, 10, 22, 10], fill=WOOD_L)
    d.rectangle([10, 12, 20, 13], fill=GOLD)  # lettering hint
    d.rectangle([11, 15, 18, 16], fill=GOLD_D)
    return _outline(img)


def main():
    os.makedirs(OUT, exist_ok=True)
    sign().save(os.path.join(OUT, "town_sign.png"))
    print("wrote town_sign.png to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
