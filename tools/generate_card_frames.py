#!/usr/bin/env python3
"""
Generates the card chrome (GID-151 / TID-631): one 9-slice frame per magic
type, a neutral frame, the shared card back + crest, and the cost gem, attack /
health badges and text plate. Colours come only from tools/pixel_palette.py.

Frames are small (FRAME_W x FRAME_H) with a MARGIN-pixel border; the game
upscales them by a whole number (scenes/ui/CardFace.gd) and 9-slices them, so
the border stays crisp at any card size. Edges are uniform so they stretch.

Usage:
  python3 tools/generate_card_frames.py                  # writes assets/textures/cards/
  python3 tools/generate_card_frames.py --preview out.png
"""

import argparse
from pathlib import Path

from PIL import Image

import pixel_palette as P

OUT = Path(__file__).parent.parent / "assets" / "textures" / "cards"
FRAME_W, FRAME_H = 32, 48
MARGIN = 6  # must match CardFace.FRAME_MARGIN

# magic type -> (metal ramp, interior fill). Keys must match MagicTypes.TYPES.
FRAMES = {
    "light": (P.GOLD, (72, 59, 58)),
    "dark": (P.PURPLE, (63, 38, 49)),
    "verdant": (P.GREEN, (38, 72, 56)),
    "rift": (P.TEAL, (20, 27, 42)),
    "neutral": (P.STONE, (42, 42, 58)),
}


class Grid:
    """Untrimmed pixel grid (generate_sprites.Canvas trims, frames must not)."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.px[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def ring(self, i, c_top_left, c_bottom_right=None):
        """The i-th ring in from the edge; top/left and bottom/right shaded apart (bevel)."""
        br = c_bottom_right if c_bottom_right is not None else c_top_left
        x1, y1 = self.w - 1 - i, self.h - 1 - i
        for x in range(i, x1 + 1):
            self.set(x, i, c_top_left)
            self.set(x, y1, br)
        for y in range(i, y1 + 1):
            self.set(i, y, c_top_left)
            self.set(x1, y, br)

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is not None:
                    img.putpixel((x, y), (c[0], c[1], c[2], 255))
        return img


def _stud(g, cx, cy, ramp):
    """A small faceted diamond stud centred on (cx, cy), lit from the top-left."""
    for dy in range(-2, 3):
        w = 2 - abs(dy)
        for dx in range(-w, w + 1):
            col = ramp[3] if (dx + dy) < 0 else ramp[2] if (dx + dy) == 0 else ramp[1]
            g.set(cx + dx, cy + dy, col)


_CORNERS = ((3, 3), (FRAME_W - 4, 3), (3, FRAME_H - 4), (FRAME_W - 4, FRAME_H - 4))


def _bevel_frame(g, ramp, fill):
    g.rect(0, 0, g.w - 1, g.h - 1, fill)
    g.ring(0, P.OUTLINE)
    g.ring(1, ramp[3], ramp[1])
    g.ring(2, ramp[2], ramp[1])
    g.ring(3, ramp[1], ramp[0])
    g.ring(4, P.OUTLINE)
    g.ring(5, ramp[0])


def frame(kind):
    ramp, fill = FRAMES[kind]
    g = Grid(FRAME_W, FRAME_H)
    _bevel_frame(g, ramp, fill)
    for cx, cy in _CORNERS:
        _stud(g, cx, cy, P.GOLD if kind != "light" else P.WATER)
    return g.image()


def card_back():
    """Gold-trimmed back over a tileable purple diamond lattice (period 6)."""
    g = Grid(FRAME_W, FRAME_H)
    _bevel_frame(g, P.GOLD, (63, 38, 49))
    for y in range(MARGIN, FRAME_H - MARGIN):
        for x in range(MARGIN, FRAME_W - MARGIN):
            u, v = (x - MARGIN) % 6, (y - MARGIN) % 6
            if u == v or u == 5 - v:
                g.set(x, y, P.PURPLE[1])
            elif (u, v) in ((2, 0), (3, 0)):
                g.set(x, y, P.PURPLE[2])
    for cx, cy in _CORNERS:
        _stud(g, cx, cy, P.WATER)
    return g.image()


def crest():
    """The Pear Pudding crest: a gold pear with a leaf inside a round medallion."""
    s = 24
    g = Grid(s, s)
    c = (s - 1) / 2.0
    for y in range(s):
        for x in range(s):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= 11.5:
                g.set(x, y, P.OUTLINE if d > 10.5 else P.GOLD[1] if d > 9.5 else (63, 38, 49))
    # pear body: two stacked circles
    for (px_, py_, r) in ((11.5, 14.5, 5.2), (11.5, 9.0, 3.2)):
        for y in range(s):
            for x in range(s):
                dx, dy = x - px_, y - py_
                if dx * dx + dy * dy <= r * r:
                    lit = -(dx * -0.6 + dy * -0.8) / r
                    g.set(x, y, P.GOLD[3] if lit > 0.5 else P.GOLD[2] if lit > -0.3 else P.GOLD[1])
    g.set(11, 5, P.WOOD[1])
    g.set(12, 4, P.WOOD[1])
    for x, y in ((13, 4), (14, 4), (14, 3), (15, 3), (13, 5)):
        g.set(x, y, P.GREEN[2])
    return g.image()


def gem_cost():
    """Blue faceted mana gem (12x12) the cost number sits on."""
    g = Grid(12, 12)
    for y in range(12):
        w = 5 - abs(y - 5.5) + 0.5
        for x in range(12):
            dx = x - 5.5
            if abs(dx) <= w:
                col = P.BLUE[3] if dx < -1 and y < 6 else P.BLUE[2] if dx < 1 else P.BLUE[1]
                if abs(dx) > w - 1:
                    col = P.OUTLINE
                g.set(x, y, col)
    return g.image()


def _badge(ramp):
    """Round 12x12 stat badge."""
    g = Grid(12, 12)
    for y in range(12):
        for x in range(12):
            dx, dy = x - 5.5, y - 5.5
            d = (dx * dx + dy * dy) ** 0.5
            if d <= 5.8:
                if d > 4.9:
                    g.set(x, y, P.OUTLINE)
                else:
                    lit = -(dx * -0.6 + dy * -0.8) / 5.0
                    g.set(x, y, ramp[3] if lit > 0.55 else ramp[2] if lit > -0.2 else ramp[1])
    return g.image()


def plate_text():
    """Parchment-dark text plate, 9-sliced with a 3 px margin (must match CardFace.PLATE_MARGIN)."""
    g = Grid(12, 12)
    g.rect(0, 0, 11, 11, (42, 42, 58))
    g.ring(0, P.OUTLINE)
    g.ring(1, P.STONE_WARM[2], P.STONE_WARM[0])
    g.ring(2, (34, 34, 34))
    return g.image()


def all_images():
    imgs = {f"frame_{k}": (lambda k=k: frame(k)) for k in FRAMES}
    imgs.update({
        "card_back": card_back,
        "card_crest": crest,
        "gem_cost": gem_cost,
        "badge_atk": lambda: _badge(P.GOLD),
        "badge_hp": lambda: _badge(P.RED),
        "plate_text": plate_text,
    })
    return {name: fn() for name, fn in imgs.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="write a contact sheet instead of the files")
    args = ap.parse_args()
    imgs = all_images()
    if args.preview:
        z = 4
        sheet = Image.new("RGBA", (FRAME_W * z * len(imgs), FRAME_H * z), (90, 90, 100, 255))
        for i, im in enumerate(imgs.values()):
            sheet.alpha_composite(im.resize((im.width * z, im.height * z), Image.NEAREST), (i * FRAME_W * z, 0))
        sheet.save(args.preview)
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for name, im in imgs.items():
        im.save(OUT / f"{name}.png")
        print("wrote", name)


if __name__ == "__main__":
    main()
