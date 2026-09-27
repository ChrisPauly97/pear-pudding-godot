#!/usr/bin/env python3
"""Snap sprite PNGs onto the master palette (tools/pixel_palette.py).

Opaque pixels move to their nearest palette colour; alpha is kept. Use it on
any licensed or hand-made sprite before it goes into assets/textures so all art
shares one palette. Prints how many colours changed per file.

Usage: python3 tools/snap_to_palette.py assets/textures/cards/card_zombie.png [...]
"""
import sys

from PIL import Image

import pixel_palette as P


def snap(path):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    changed = set()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            n = P.nearest((r, g, b))
            if n != (r, g, b):
                changed.add((r, g, b))
                px[x, y] = (n[0], n[1], n[2], a)
    im.save(path)
    return len(changed)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(f"  {p}: {snap(p)} colour(s) snapped")
