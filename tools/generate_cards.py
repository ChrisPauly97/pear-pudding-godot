#!/usr/bin/env python3
"""
Generates the card illustrations (GID-144 / TID-611): minion portraits cropped
from the generated world characters (tools/generate_characters.py) and the four
spell-branch runes drawn as glyphs — replacing the 0x72 / Kenney portraits and
the game-icons.net (CC BY) runes. 32x32, same palette and outline as the props.

Usage:
  python3 tools/generate_cards.py                  # writes assets/textures/cards/
  python3 tools/generate_cards.py --preview out.png
"""

import argparse
import math
from pathlib import Path

from PIL import Image

import generate_characters as GC
import pixel_palette as P
from generate_sprites import Canvas

OUT = Path(__file__).parent.parent / "assets" / "textures" / "cards"
S = 32


def _fit(img):
    """Centre an image on a transparent SxS card tile."""
    tile = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    tile.alpha_composite(img, ((S - img.width) // 2, (S - img.height) // 2))
    return tile


def portrait(fn, rows=16):
    """Head-and-shoulders bust: the top `rows` of the character's idle frame, doubled."""
    idle = fn(0)
    half = S // 4
    cx = idle.width // 2
    bust = idle.crop((max(0, cx - half), 0, min(idle.width, cx + half), min(rows, idle.height)))
    bust = bust.crop(bust.getbbox())
    scale = max(1, min(S // bust.width, S // bust.height))
    return _fit(bust.resize((bust.width * scale, bust.height * scale), Image.NEAREST))


def _sun(c, cx, cy, r, ramp, rays):
    c.blob(cx, cy, r, r, ramp)
    for i in range(rays):
        a = math.pi + math.pi * (i + 0.5) / rays
        c.line(cx + math.cos(a) * (r + 2), cy + math.sin(a) * (r + 2),
               cx + math.cos(a) * (r + 4), cy + math.sin(a) * (r + 4), ramp[2])


def _clear_below(c, y):
    for yy in range(y, c.h):
        for x in range(c.w):
            c.px[yy][x] = None


def rune_dawn():
    """Dawn: a sun climbing over the horizon, arrow up."""
    c = Canvas(S, S)
    _sun(c, 16, 22, 6, P.GOLD, 5)
    _clear_below(c, 23)
    c.rect(4, 23, 27, 24, P.GOLD[1])
    c.line(16, 5, 16, 11, P.GOLD[3])
    c.line(13, 8, 16, 5, P.GOLD[3])
    c.line(19, 8, 16, 5, P.GOLD[3])
    c.outline()
    return _fit(c.image())


def rune_dusk():
    """Dusk: the sun sinking below the horizon, arrow down."""
    c = Canvas(S, S)
    _sun(c, 16, 13, 6, P.PURPLE, 5)
    _clear_below(c, 14)
    c.rect(4, 14, 27, 15, P.PURPLE[1])
    c.line(16, 19, 16, 26, P.PURPLE[3])
    c.line(13, 23, 16, 26, P.PURPLE[3])
    c.line(19, 23, 16, 26, P.PURPLE[3])
    c.outline()
    return _fit(c.image())


def rune_ember():
    """Ember: a flame on a glowing ring, sparks rising."""
    c = Canvas(S, S)
    for x in range(6, 27):
        t = (x - 16) / 10.0
        c.set(x, 26 + round(t * t * 2), P.FIRE[1])
        c.set(x, 25 + round(t * t * 2), P.FIRE[2] if abs(t) < 0.7 else P.FIRE[1])
    for y in range(4, 25):                                      # teardrop flame
        t = (y - 4) / 20.0
        w = 7.5 * math.sin(math.pi * min(1.0, t * 1.15)) * (0.35 + 0.65 * t)
        lean = (1 - t) * 3.0
        for x in range(round(16 + lean - w), round(16 + lean + w) + 1):
            inner = abs(x - 16 - lean) < w * 0.45 and t > 0.45
            c.set(x, y, P.GOLD[3] if inner and t > 0.7 else (P.FIRE[3] if inner else P.FIRE[2 if t > 0.3 else 1]))
    for x, y in ((8, 9), (24, 7), (22, 13)):
        c.set(x, y, P.FIRE[2])
    c.outline()
    return _fit(c.image())


def rune_ash():
    """Ash: a drifting grey plume with falling cinders."""
    c = Canvas(S, S)
    grey = P.STONE
    for i, (x, y, r) in enumerate(((10, 21, 5.0), (16, 16, 5.5), (22, 10, 5.0), (25, 6, 3.0))):
        c.blob(x, y, r, r * 0.8, grey)
    for x, y in ((6, 27), (11, 29), (18, 26), (24, 28), (9, 12)):
        c.set(x, y, grey[1])
        c.set(x + 1, y, grey[2])
    c.set(15, 16, P.FIRE[1])                                     # a last cinder inside
    c.outline()
    return _fit(c.image())


CARDS = {
    "card_ghost": lambda: portrait(GC.spectre),
    "card_skeleton": lambda: portrait(GC.skeleton),
    "card_zombie": lambda: portrait(GC.zombie),
    "card_ghoul": lambda: portrait(GC.ghoul),
    "rune_dawn": rune_dawn,
    "rune_dusk": rune_dusk,
    "rune_ember": rune_ember,
    "rune_ash": rune_ash,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="write a contact sheet instead of the cards")
    args = ap.parse_args()
    imgs = {name: fn() for name, fn in CARDS.items()}
    if args.preview:
        sheet = Image.new("RGBA", (S * 4 * len(imgs), S * 4), (60, 60, 70, 255))
        for i, im in enumerate(imgs.values()):
            sheet.alpha_composite(im.resize((S * 4, S * 4), Image.NEAREST), (i * S * 4, 0))
        sheet.save(args.preview)
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for name, im in imgs.items():
        im.save(OUT / f"{name}.png")
        print("wrote", name)


if __name__ == "__main__":
    main()
