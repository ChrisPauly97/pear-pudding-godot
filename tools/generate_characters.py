#!/usr/bin/env python3
"""
Generates original character sprites (GID-143) in the same pixel style as the
props (tools/generate_sprites.py): palette from tools/pixel_palette.py, light
from the top-left, 1 px dark outline. Each character gets an idle frame and a
4-frame walk cycle (<name>.png, <name>_walk_1..4.png).

Characters are built from a small humanoid rig (head, torso, arms, legs) with
per-character parts, so new ones are a spec, not a drawing.

Usage:
  python3 tools/generate_characters.py                  # writes assets/textures/characters/
  python3 tools/generate_characters.py --preview out.png
"""

import argparse
import math
from pathlib import Path

from PIL import Image

import pixel_palette as P
from generate_sprites import Canvas

OUT = Path(__file__).parent.parent / "assets" / "textures" / "characters"

W, H = 20, 30
BONE = [(119, 92, 85), (170, 141, 122), (211, 191, 169), (253, 247, 237)]
ROT = [(38, 72, 56), (61, 115, 79), (73, 167, 144), (151, 218, 63)]
RAG = [(63, 38, 49), (72, 59, 58), (119, 92, 85), (170, 141, 122)]
RUST = [(98, 35, 47), (143, 64, 41), (170, 141, 122), (192, 203, 220)]
DARK = (17, 17, 17)


def _walk(frame):
    """Leg/arm swing for walk frame 0..4 (0 = idle): (left leg dx, right leg dx, bob)."""
    if frame == 0:
        return 0, 0, 0
    phase = (frame - 1) / 4.0 * 2 * math.pi
    s = math.sin(phase)
    return round(s * 2), round(-s * 2), (1 if frame in (2, 4) else 0)


def _legs(c, hip_y, lx, rx, ramp, thin=False, foot=None):
    w = 0 if thin else 1
    for x0, dx in ((7, lx), (11, rx)):
        c.line(x0 + dx * 0.5, hip_y, x0 + dx, H - 2, ramp[1])
        if not thin:
            c.line(x0 + 1 + dx * 0.5, hip_y, x0 + 1 + dx, H - 2, ramp[2])
        c.rect(int(x0 + dx) - 1, H - 2, int(x0 + dx) + w + 1, H - 1, foot or ramp[0])


def skeleton(frame):
    """Undead Wanderer: a bare skeleton with a rusty blade and a rag of a cloak."""
    c = Canvas(W, H)
    lx, rx, bob = _walk(frame)
    top = 2 + bob
    # tattered hood-cloak over the shoulders only, so the ribs read
    c.blob(9.5, top + 8, 5.5, 2.5, [RAG[0], RAG[0], RAG[1], RAG[1]])
    c.line(4, top + 9, 3, top + 13, RAG[0])
    c.line(15, top + 9, 16, top + 12, RAG[0])
    _legs(c, top + 17, lx, rx, BONE, thin=True, foot=BONE[1])
    # pelvis + spine + ribs
    c.rect(7, top + 16, 12, top + 17, BONE[1])
    c.line(9.5, top + 8, 9.5, top + 16, BONE[2])
    for i, y in enumerate(range(top + 9, top + 15, 2)):
        half = 4 - (i // 2)
        c.line(9.5 - half, y, 9.5 + half, y, BONE[2 if i % 2 == 0 else 1])
    # arms: left hangs, right holds the sword forward
    c.line(5, top + 9, 4 - rx * 0.5, top + 16, BONE[2])
    c.line(14, top + 9, 15.5, top + 14, BONE[2])
    c.line(15.5, top + 14, 18, top + 6, RUST[3])   # blade
    c.line(16.5, top + 14, 18.5, top + 7, RUST[2])
    c.rect(14, top + 14, 17, top + 14, RUST[1])      # guard
    # skull
    c.blob(9.5, top + 4, 4.2, 4.0, BONE)
    c.rect(8, top + 7, 11, top + 8, BONE[1])          # jaw
    c.set(8, top + 4, DARK)
    c.set(11, top + 4, DARK)
    c.set(8, top + 5, DARK)
    c.set(11, top + 5, DARK)
    c.set(9.5, top + 6, BONE[0])                      # nose hole
    c.set(9, top + 8, DARK)
    c.set(10.5, top + 8, DARK)
    c.outline()
    return c.image()


def zombie(frame):
    """Horde Shambler: hunched, green-grey, arms reaching, torn peasant clothes."""
    c = Canvas(W, H)
    lx, rx, bob = _walk(frame)
    top = 3 + bob
    _legs(c, top + 17, lx, rx, RAG, foot=RAG[0])
    # torn tunic
    c.blob(9.5, top + 13, 5.0, 5.5, RAG)
    c.line(6, top + 18, 13, top + 18, RAG[0])
    c.set(8, top + 17, ROT[2])                        # skin through a tear
    c.set(11, top + 15, ROT[1])
    # reaching arms
    c.line(6, top + 10, 1 + rx * 0.3, top + 12, ROT[2])
    c.line(6, top + 11, 1 + rx * 0.3, top + 13, ROT[1])
    c.line(13, top + 10, 18 + lx * 0.3, top + 12, ROT[2])
    c.line(13, top + 11, 18 + lx * 0.3, top + 13, ROT[1])
    # head, tilted forward
    c.blob(10.5, top + 5, 4.0, 4.2, ROT)
    c.set(9, top + 5, DARK)
    c.set(12, top + 5, P.RED[2])
    c.line(9, top + 8, 12, top + 8, ROT[0])           # slack mouth
    c.set(8, top + 2, RAG[1])                         # hair tufts
    c.set(11, top + 1, RAG[1])
    c.outline()
    return c.image()


CHARACTERS = {
    "enemy_skeleton": skeleton,
    "enemy_zombie": zombie,
}


def frames(fn):
    return [fn(i) for i in range(5)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="write a contact sheet instead of the sprites")
    args = ap.parse_args()
    if args.preview:
        rows = [frames(fn) for fn in CHARACTERS.values()]
        sheet = Image.new("RGBA", (W * 5 * 4, H * len(rows) * 4), (60, 70, 60, 255))
        for r, row in enumerate(rows):
            for i, im in enumerate(row):
                big = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
                sheet.alpha_composite(big, (i * W * 4, r * H * 4 + (H - im.height) * 4))
        sheet.save(args.preview)
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in CHARACTERS.items():
        fs = frames(fn)
        fs[0].save(OUT / f"{name}.png")
        for i in range(1, 5):
            fs[i].save(OUT / f"{name}_walk_{i}.png")
        print("wrote", name)


if __name__ == "__main__":
    main()
