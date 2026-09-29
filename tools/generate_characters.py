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


HAIR = {
    "brown": [(72, 59, 58), (118, 59, 54), (143, 64, 41), (189, 108, 74)],
    "grey": [(82, 96, 124), (123, 137, 148), (192, 203, 220), (253, 247, 237)],
    "red": [(98, 35, 47), (143, 64, 41), (197, 96, 37), (228, 110, 51)],
    "black": [(17, 17, 17), (34, 34, 34), (42, 42, 58), (72, 59, 58)],
    "blond": [(143, 64, 41), (197, 96, 37), (238, 142, 46), (250, 203, 62)],
}
CLOTH = {
    "red": P.RED, "green": P.GREEN, "brown": P.WOOD, "blue": P.BLUE, "purple": P.PURPLE,
    "grey": P.STONE, "earth": P.EARTH, "teal": P.TEAL, "dark": [(17, 17, 17), (34, 34, 34), (42, 42, 58), (72, 59, 58)],
}


def person(spec):
    """A standing townsperson from a spec: hair, dress/tunic colours, extras."""
    def draw(frame):
        c = Canvas(W, H)
        lx, rx, bob = _walk(frame)
        top = 2 + bob
        body = CLOTH[spec["body"]]
        legs = CLOTH[spec.get("legs", "earth")]
        if spec.get("robe"):
            c.blob(9.5, top + 18, 5.2, 8.0, body)          # long robe/dress to the ground
            c.rect(6, H - 2, 13, H - 1, body[0])
        else:
            _legs(c, top + 18, lx, rx, legs, foot=(34, 34, 34))
            c.blob(9.5, top + 14, 4.8, 5.0, body)
        if spec.get("apron"):
            c.rect(8, top + 12, 11, top + 21, (253, 247, 237))
            c.line(8, top + 12, 11, top + 12, (211, 191, 169))
        if spec.get("belt"):
            c.line(5, top + 16, 14, top + 16, P.WOOD[0])
        # arms
        c.line(5, top + 11, 4, top + 17, body[1])
        c.line(14, top + 11, 15, top + 17, body[1])
        c.set(4, top + 18, P.SKIN[2])
        c.set(15, top + 18, P.SKIN[2])
        # prop in the right hand
        prop = spec.get("prop")
        if prop == "spade":
            c.line(16, top + 4, 16, top + 22, P.WOOD[2])
            c.rect(15, top + 22, 17, top + 25, P.STONE[2])
        elif prop == "pike":
            c.line(16, top - 1, 16, top + 24, P.WOOD[2])
            c.line(16, top - 3, 16, top - 1, P.STONE[3])
        elif prop == "staff":
            c.line(16, top + 2, 16, top + 25, P.WOOD[1])
            c.blob(16, top + 1, 1.6, 1.6, P.PURPLE)
        elif prop == "sword":
            c.line(16, top + 8, 18, top + 2, P.STONE[3])
            c.line(15, top + 10, 17, top + 10, P.GOLD[1])
        elif prop == "loaf":
            c.blob(15.5, top + 17, 2.2, 1.4, P.GOLD[:3] + [P.GOLD[2]])
        elif prop == "candle":
            c.rect(15, top + 14, 16, top + 17, (253, 247, 237))
            c.set(15.5, top + 13, P.FIRE[2])
            c.set(15.5, top + 12, P.FIRE[1])
        elif prop == "satchel":
            c.blob(5, top + 16, 2.0, 2.0, P.WOOD)
            c.set(5, top + 14, P.PINK[2])
        # head
        c.blob(9.5, top + 5, 3.8, 3.9, P.SKIN)
        hair = HAIR[spec.get("hair", "brown")]
        style = spec.get("hair_style", "short")
        if style == "tonsure":
            c.line(6, top + 4, 6, top + 6, hair[1])
            c.line(13, top + 4, 13, top + 6, hair[1])
        elif style == "long":
            c.blob(9.5, top + 3, 4.2, 2.4, hair)
            c.line(5.5, top + 4, 5.5, top + 10, hair[1])
            c.line(13.5, top + 4, 13.5, top + 10, hair[1])
        elif style == "hood":
            c.blob(9.5, top + 4, 4.8, 4.4, CLOTH[spec.get("hood", spec["body"])])
            c.blob(9.5, top + 6, 3.0, 2.6, P.SKIN)
        elif style == "hat":
            c.rect(4, top + 2, 15, top + 2, CLOTH["dark"][1])
            c.rect(6, top - 1, 13, top + 1, CLOTH["dark"][2])
        else:
            c.blob(9.5, top + 2.5, 4.0, 2.0, hair)
        if spec.get("beard"):
            c.blob(9.5, top + 8, 2.6, 1.8, hair)
        c.set(8, top + 5, (34, 34, 34))
        c.set(11, top + 5, (34, 34, 34))
        c.outline()
        return c.image()
    return draw


NPCS = {
    "npc_hilda_baker": {"body": "red", "robe": True, "apron": True, "hair": "red", "hair_style": "long",
                        "prop": "loaf"},
    "npc_wenna_herbalist": {"body": "green", "robe": True, "hair": "blond", "hair_style": "long", "prop": "satchel"},
    "npc_brother_aldo": {"body": "brown", "robe": True, "belt": True, "hair": "brown", "hair_style": "tonsure"},
    "npc_old_tam": {"body": "blue", "hair": "grey", "beard": True, "prop": "pike", "belt": True},
    "npc_ivy_chandler": {"body": "purple", "robe": True, "hair": "black", "hair_style": "long", "prop": "candle"},
    "npc_combat_trainer": {"body": "earth", "legs": "brown", "hair": "black", "belt": True, "prop": "sword"},
    "npc_bounty_master": {"body": "dark", "legs": "dark", "hair": "black", "hair_style": "hat", "beard": True},
    "npc_gravedigger": {"body": "grey", "legs": "earth", "hair": "grey", "hair_style": "hood", "hood": "dark",
                        "prop": "spade"},
    "npc_rift_warden": {"body": "purple", "robe": True, "hair_style": "hood", "hood": "purple", "prop": "staff"},
}

CHARACTERS = {
    "enemy_skeleton": skeleton,
    "enemy_zombie": zombie,
}


for _name, _spec in NPCS.items():
    CHARACTERS[_name] = person(_spec)


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
        if name in NPCS:
            continue  # townsfolk stand at their post: idle only
        for i in range(1, 5):
            fs[i].save(OUT / f"{name}_walk_{i}.png")
        print("wrote", name)


if __name__ == "__main__":
    main()
