"""Pixel-art boats moored off Maykalene's quay (GID-171).

Writes assets/textures/props/boat_rowboat.png and boat_cog.png: a small wooden
rowboat and a single-masted cog with a furled-and-reefed striped sail, drawn side-on
to sit in the water as billboards. Same style as the town pieces: flat shapes,
two-tone shading, 1px dark outline.
Usage: python3 tools/generate_boats.py   (needs Pillow)
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from generate_legend_props import BARK, BARK_D, GOLD, _outline  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "props")
WOOD_L = (150, 104, 62, 255)
SAIL = (236, 228, 204, 255)
SAIL_D = (196, 184, 156, 255)
STRIPE = (168, 52, 44, 255)
ROPE = (196, 164, 108, 255)
WATERLINE = (60, 120, 170, 255)


def rowboat():
    w, h = 44, 18
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(1, 5), (42, 5), (37, 15), (6, 15)], fill=BARK)
    d.polygon([(1, 5), (42, 5), (41, 8), (2, 8)], fill=WOOD_L)
    d.line([(4, 11), (39, 11)], fill=BARK_D)
    d.rectangle([14, 3, 16, 5], fill=BARK_D)  # oarlock posts
    d.rectangle([28, 3, 30, 5], fill=BARK_D)
    img = _outline(img)
    d = ImageDraw.Draw(img)
    d.line([(10, 4), (2, 13)], fill=WOOD_L, width=2)  # shipped oar
    d.line([(6, 16), (37, 16)], fill=WATERLINE)
    return img


def cog():
    w, h = 72, 84
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Hull with raised castles fore and aft.
    d.polygon([(2, 60), (70, 60), (62, 80), (10, 80)], fill=BARK)
    d.polygon([(2, 60), (70, 60), (68, 66), (4, 66)], fill=WOOD_L)
    d.rectangle([2, 52, 18, 61], fill=BARK)
    d.rectangle([56, 54, 70, 61], fill=BARK)
    d.rectangle([2, 52, 18, 54], fill=WOOD_L)
    d.rectangle([56, 54, 70, 56], fill=WOOD_L)
    for x in range(6, 66, 6):
        d.line([(x, 67), (x + 1, 78)], fill=BARK_D)
    d.line([(6, 72), (66, 72)], fill=BARK_D)
    # Mast, yard and a striped square sail.
    d.rectangle([35, 4, 37, 60], fill=BARK_D)
    d.rectangle([14, 10, 58, 12], fill=BARK_D)
    d.polygon([(16, 12), (56, 12), (54, 46), (18, 46)], fill=SAIL)
    d.polygon([(36, 12), (56, 12), (54, 46), (36, 46)], fill=SAIL_D)
    for x in (22, 30, 42, 50):
        d.rectangle([x, 13, x + 3, 45], fill=STRIPE)
    d.ellipse([33, 1, 39, 6], fill=GOLD)  # masthead
    img = _outline(img)
    d = ImageDraw.Draw(img)
    for a, b in (((36, 6), (3, 52)), ((36, 6), (69, 54))):  # stays
        d.line([a, b], fill=ROPE)
    d.line([(10, 81), (62, 81)], fill=WATERLINE)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    rowboat().save(os.path.join(OUT, "boat_rowboat.png"))
    cog().save(os.path.join(OUT, "boat_cog.png"))
    print("wrote boat_rowboat.png / boat_cog.png to %s" % os.path.normpath(OUT))


if __name__ == "__main__":
    main()
