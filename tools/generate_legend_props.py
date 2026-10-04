"""Pixel-art props for the Pear Pudding legend's riddle spots (GID-153 / TID-655).

Writes into assets/textures/props/:
  legend_stones.png        three leaning standing stones
  legend_pear_tree.png     gnarled lone tree with golden pears
  legend_pear_tree_bare.png  the same tree once the golden pear is taken
  legend_well.png          the ruined queen's well (dry rubble ring)

Matches the house prop style: flat shapes, two-tone shading, 1px dark outline.
Usage: python3 tools/generate_legend_props.py   (needs Pillow)
"""
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "props")
OUTLINE = (34, 34, 34, 255)
STONE_L = (123, 137, 148, 255)
STONE_D = (82, 96, 124, 255)
STONE_HI = (160, 172, 184, 255)
MOSS = (61, 115, 79, 255)
MOSS_L = (75, 167, 71, 255)
BARK = (84, 54, 38, 255)
BARK_D = (58, 38, 28, 255)
LEAF = (58, 112, 54, 255)
LEAF_L = (86, 150, 66, 255)
LEAF_D = (38, 78, 44, 255)
GOLD = (240, 196, 72, 255)
GOLD_L = (255, 232, 140, 255)
GOLD_D = (184, 128, 40, 255)


def _outline(img):
    """Adds a 1px dark outline around every opaque region."""
    src = img.copy()
    px, out = src.load(), img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0 and px[nx, ny] != OUTLINE:
                    out[x, y] = OUTLINE
                    break
    return img


def _stone(d, x0, y0, x1, y1, lean):
    """A slab from (x0,y1) base to height y0, leaning `lean` px at the top."""
    d.polygon([(x0, y1), (x1, y1), (x1 + lean, y0 + 2), (x1 + lean - 2, y0), (x0 + lean + 1, y0),
               (x0 + lean, y0 + 2)], fill=STONE_L)
    mid = (x0 + x1) // 2
    d.polygon([(mid + 1, y1), (x1, y1), (x1 + lean, y0 + 2), (mid + 1 + lean, y0 + 1)], fill=STONE_D)
    d.line([(x0 + lean + 1, y0 + 1), (x0 + 1, y1 - 2)], fill=STONE_HI)
    d.rectangle([x0, y1 - 1, x1, y1], fill=MOSS)


def stones():
    img = Image.new("RGBA", (40, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _stone(d, 3, 8, 10, 28, 3)    # leans right
    _stone(d, 26, 6, 33, 28, -3)  # leans left
    _stone(d, 15, 2, 23, 28, 0)   # tallest, upright, in front
    d.rectangle([2, 27, 36, 28], fill=MOSS)
    for x in (4, 13, 20, 30, 35):
        img.putpixel((x, 26), MOSS_L)
    # Faint rune on the middle stone.
    for p in ((19, 9), (19, 10), (19, 11), (18, 12), (20, 12), (19, 13)):
        img.putpixel(p, STONE_D)
    return _outline(img)


def _blob(d, cx, cy, r, colour):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)


def pear_tree(with_pear=True):
    rng = random.Random(7)
    img = Image.new("RGBA", (46, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Gnarled trunk bending to the left, with a root flare.
    d.polygon([(19, 59), (28, 59), (26, 50), (27, 40), (24, 30), (20, 30), (22, 40), (20, 50)], fill=BARK)
    d.polygon([(24, 59), (28, 59), (26, 50), (27, 40), (24, 30), (23, 40), (24, 50)], fill=BARK_D)
    d.line([(23, 34), (14, 26)], fill=BARK, width=2)
    d.line([(24, 32), (32, 24)], fill=BARK, width=2)
    # Sparse crown: a few leaf clumps.
    for cx, cy, r in ((12, 20, 8), (23, 14, 10), (34, 20, 8), (23, 24, 7)):
        _blob(d, cx, cy, r, LEAF)
    for cx, cy, r in ((10, 17, 4), (21, 9, 5), (32, 16, 4)):
        _blob(d, cx, cy, r, LEAF_L)
    for cx, cy, r in ((16, 26, 4), (30, 26, 4), (25, 20, 3)):
        _blob(d, cx, cy, r, LEAF_D)
    for _ in range(40):
        x, y = rng.randrange(4, 42), rng.randrange(4, 30)
        if img.getpixel((x, y))[3]:
            img.putpixel((x, y), LEAF_D if rng.random() < 0.5 else LEAF_L)
    if with_pear:
        # The one golden pear, hanging below the right bough, plus a glint.
        px, py = 31, 28
        d.line([(px, py - 3), (px, py - 1)], fill=BARK_D)
        _blob(d, px, py + 4, 3, GOLD)
        _blob(d, px, py + 1, 2, GOLD)
        d.point([(px + 2, py + 5), (px + 1, py + 6), (px + 2, py + 4)], fill=GOLD_D)
        d.point([(px - 1, py + 2), (px - 1, py + 3)], fill=GOLD_L)
    return _outline(img)


def well():
    rng = random.Random(3)
    img = Image.new("RGBA", (28, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Broken ring: back wall, dark dry shaft, low front wall with a gap.
    d.ellipse([2, 4, 25, 15], fill=STONE_D)
    d.ellipse([6, 6, 21, 12], fill=(42, 42, 58, 255))
    d.rectangle([2, 10, 25, 17], fill=STONE_L)
    d.ellipse([2, 13, 25, 19], fill=STONE_L)
    d.rectangle([11, 10, 15, 13], fill=(0, 0, 0, 0))  # collapsed gap
    d.ellipse([6, 6, 21, 12], fill=(42, 42, 58, 255))
    # Block seams and moss.
    for x in (6, 10, 17, 21):
        d.line([(x, 11), (x, 16)], fill=STONE_D)
    d.line([(3, 14), (24, 14)], fill=STONE_D)
    for _ in range(9):
        x, y = rng.randrange(3, 25), rng.randrange(10, 18)
        if img.getpixel((x, y))[3]:
            img.putpixel((x, y), MOSS if rng.random() < 0.6 else MOSS_L)
    # Tumbled stones at the base of the gap.
    d.rectangle([12, 17, 14, 18], fill=STONE_L)
    d.point([(16, 18), (10, 18)], fill=STONE_D)
    return _outline(img)


def main():
    os.makedirs(OUT, exist_ok=True)
    stones().save(os.path.join(OUT, "legend_stones.png"))
    pear_tree(True).save(os.path.join(OUT, "legend_pear_tree.png"))
    pear_tree(False).save(os.path.join(OUT, "legend_pear_tree_bare.png"))
    well().save(os.path.join(OUT, "legend_well.png"))
    print("wrote legend props to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
