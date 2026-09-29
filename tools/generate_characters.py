#!/usr/bin/env python3
"""
Generates original character sprites (GID-143) in the same pixel style as the
props (tools/generate_sprites.py): palette from tools/pixel_palette.py, light
from the top-left, 1 px dark outline. Each character gets an idle frame and a
4-frame walk cycle (<name>.png, <name>_walk_1..4.png) where one is used.

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


def _legs(c, hip_y, lx, rx, ramp, thin=False, foot=None, xs=(7, 11)):
    w = 0 if thin else 1
    h = c.h
    for x0, dx in ((xs[0], lx), (xs[1], rx)):
        c.line(x0 + dx * 0.5, hip_y, x0 + dx, h - 2, ramp[1])
        if not thin:
            c.line(x0 + 1 + dx * 0.5, hip_y, x0 + 1 + dx, h - 2, ramp[2])
        c.rect(int(x0 + dx) - 1, h - 2, int(x0 + dx) + w + 1, h - 1, foot or ramp[0])


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
        if spec.get("cloak"):
            cl = CLOTH[spec["cloak"]]
            c.blob(9.5, top + 15, 6.2, 9.0, [cl[0], cl[0], cl[1], cl[1]])
        if spec.get("pack"):
            c.blob(9.5, top + 12, 6.0, 4.5, P.WOOD)
            c.rect(6, top + 7, 13, top + 8, P.EARTH[2] if spec["pack"] == "bedroll" else P.WOOD[3])
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
        if spec.get("pauldrons"):
            pm = CLOTH[spec["pauldrons"]]
            c.blob(5.5, top + 10.5, 1.8, 1.4, pm)
            c.blob(13.5, top + 10.5, 1.8, 1.4, pm)
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
        elif prop == "axe":
            c.line(16, top + 6, 16, top + 22, P.WOOD[1])
            c.blob(17.5, top + 7, 1.8, 2.6, RUST)
        elif prop == "rapier":
            c.line(15, top + 18, 19, top + 3, P.STONE[3])
            c.line(14, top + 17, 16, top + 19, P.GOLD[2])
        elif prop == "lantern":
            c.line(15.5, top + 16, 15.5, top + 18, (34, 34, 34))
            c.rect(15, top + 19, 16, top + 21, P.FIRE[2])
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
        elif style == "helm":
            c.blob(9.5, top + 3, 4.4, 3.0, CLOTH[spec.get("helm", "grey")])
            c.line(9.5, top + 3, 9.5, top + 6, CLOTH[spec.get("helm", "grey")][1])
        elif style == "wizard":
            hat = CLOTH[spec.get("hat", spec["body"])]
            c.rect(4, top + 2, 15, top + 2, hat[1])
            for i in range(6):
                c.line(6.5 + i * 0.5, top + 1 - i, 12.5 - i * 0.7, top + 1 - i, hat[2 if i < 3 else 3])
            c.set(13, top - 5, hat[2])
        elif style == "wide_hat":
            c.rect(3, top + 2, 16, top + 2, P.WOOD[1])
            c.blob(9.5, top + 0.5, 3.6, 1.8, P.WOOD)
        elif style == "hat":
            c.rect(4, top + 2, 15, top + 2, CLOTH["dark"][1])
            c.rect(6, top - 1, 13, top + 1, CLOTH["dark"][2])
        else:
            c.blob(9.5, top + 2.5, 4.0, 2.0, hair)
        if spec.get("beard"):
            if spec["beard"] == "long":
                c.blob(9.5, top + 10, 2.8, 3.6, hair)
            else:
                c.blob(9.5, top + 8, 2.6, 1.8, hair)
        c.set(8, top + 5, (34, 34, 34))
        c.set(11, top + 5, (34, 34, 34))
        c.outline()
        return c.image()
    return draw


def elite(frame):
    """Undead Knight (undead_elite): an armoured, spectral skeleton with shield and blade."""
    c = Canvas(W, H)
    lx, rx, bob = _walk(frame)
    top = 2 + bob
    ghost = [(58, 63, 94), (82, 96, 124), (143, 211, 255), (234, 255, 255)]
    steel = [(42, 42, 58), (82, 96, 124), (123, 137, 148), (192, 203, 220)]
    _legs(c, top + 17, lx, rx, ghost, thin=True, foot=steel[1])
    c.blob(9.5, top + 12, 5.0, 5.2, steel)                    # breastplate
    c.line(9.5, top + 9, 9.5, top + 16, steel[0])
    c.rect(6, top + 16, 13, top + 17, steel[1])               # fauld
    c.line(14, top + 9, 15.5, top + 14, ghost[2])             # sword arm
    c.line(15.5, top + 14, 18, top + 4, steel[3])
    c.line(16.5, top + 14, 18.5, top + 5, steel[2])
    c.rect(14, top + 14, 17, top + 14, P.GOLD[1])
    c.blob(4.0, top + 13, 2.8, 4.0, [P.BLUE[0], P.BLUE[1], P.BLUE[2], P.BLUE[2]])  # kite shield
    c.line(4, top + 10, 4, top + 16, P.GOLD[2])
    c.blob(9.5, top + 4, 4.2, 4.0, ghost)                    # skull
    c.blob(9.5, top + 2.5, 4.6, 2.4, steel)                   # helm
    c.line(5, top + 2, 4, top - 1, P.RED[2])                  # plume
    c.set(8, top + 5, (143, 211, 255))
    c.set(11, top + 5, (143, 211, 255))
    c.rect(8, top + 7, 11, top + 7, ghost[1])
    c.outline()
    return c.image()


def ghoul(frame):
    """Ghoul: crouched and long-armed, pale grey-violet skin, raking claws."""
    c = Canvas(W + 4, H)
    lx, rx, bob = _walk(frame)
    top = 8 + bob
    skin = [(66, 57, 82), (104, 88, 118), (150, 138, 160), (196, 188, 204)]
    _legs(c, top + 13, lx, rx, skin, foot=skin[0], xs=(8, 14))
    c.rect(8, H - 1, 16, H - 1, None)
    c.blob(12, top + 9, 6.2, 5.0, skin)                       # hunched back
    c.line(8, top + 14, 15, top + 14, RAG[0])                 # loincloth
    c.rect(9, top + 15, 14, top + 16, RAG[1])
    for x0, sway in ((6, rx), (18, lx)):                      # knuckle-dragging arms
        d = -1 if x0 < 12 else 1
        c.line(x0, top + 7, x0 + d * 2 + sway * 0.3, top + 16, skin[1])
        c.line(x0 + d, top + 7, x0 + d * 3 + sway * 0.3, top + 16, skin[2])
        for k in range(3):
            c.set(x0 + d * (1 + k) + sway * 0.3, top + 17, BONE[3])
    c.blob(12, top + 3, 3.8, 3.4, skin)                       # low-slung head
    c.set(10, top + 3, P.GOLD[3])
    c.set(13, top + 3, P.GOLD[3])
    c.line(10, top + 5, 14, top + 5, DARK)                    # wide mouth
    c.set(11, top + 6, BONE[3])
    c.set(13, top + 6, BONE[3])
    c.set(9, top, skin[0])                                    # pointed ears
    c.set(15, top, skin[0])
    c.outline()
    return c.image()


def spectre(frame):
    """Night-hunt spectre: a pale sheet-ghost with a ragged, drifting hem (tinted in-engine)."""
    c = Canvas(W, H)
    sway = [0, 1, 0, -1, 0][frame]
    body = [(143, 211, 255), (192, 230, 255), (225, 245, 255), (255, 255, 255)]
    c.blob(9.5, 9, 6.0, 6.0, body)
    c.blob(9.5 + sway * 0.5, 16, 6.5, 6.0, body)
    for i, x in enumerate(range(4, 16, 3)):                   # ragged hem
        c.line(x + sway, 21, x + sway + (1 if i % 2 else -1), 25 + (i % 2) * 2, body[1])
        c.set(x + 1 + sway, 22, body[0])
    c.line(3, 13, 1 + sway, 17, body[1])                      # trailing arms
    c.line(16, 13, 18 + sway, 17, body[1])
    c.blob(7.5, 9, 1.2, 1.8, [DARK] * 4)                      # hollow eyes
    c.blob(11.5, 9, 1.2, 1.8, [DARK] * 4)
    c.blob(9.5, 13, 1.0, 1.4, [(58, 63, 94)] * 4)             # mouth
    c.outline((58, 63, 94))
    return c.image()


BW, BH = 32, 40


def _big_legs(c, hip_y, lx, rx, ramp, foot):
    for x0, dx in ((11, lx), (19, rx)):
        for k in range(3):
            c.line(x0 + k + dx * 0.5, hip_y, x0 + k + dx, BH - 3, ramp[1 + (k == 1)])
        c.rect(int(x0 + dx) - 1, BH - 3, int(x0 + dx) + 4, BH - 1, foot)


def warleader(frame):
    """Martarquas Warleader: huge, fur-mantled, horned helm, a great axe."""
    c = Canvas(BW, BH)
    lx, rx, bob = _walk(frame)
    top = 3 + bob
    red = P.RED
    fur = [(72, 59, 58), (118, 92, 70), (170, 141, 122), (211, 191, 169)]
    _big_legs(c, top + 25, lx, rx, P.EARTH, DARK)
    c.blob(16, top + 18, 9.5, 9.0, red)                       # tabard
    c.rect(8, top + 25, 23, top + 26, P.WOOD[0])              # belt
    c.rect(15, top + 25, 17, top + 26, P.GOLD[2])
    c.blob(16, top + 11, 11.0, 4.0, fur, light_bias=0.2)      # fur mantle
    c.line(5, top + 13, 4, top + 24, fur[1])                  # arms
    c.line(6, top + 13, 5, top + 24, fur[2])
    c.blob(4.5, top + 25, 1.8, 1.5, P.SKIN)
    c.line(27, top + 13, 27, top + 23, fur[1])
    c.blob(27, top + 24, 1.8, 1.5, P.SKIN)
    c.line(28, top - 2, 28, top + 34, P.WOOD[1])              # great axe
    c.blob(30, top + 3, 2.5, 4.5, RUST)
    c.blob(26, top + 3, 1.5, 3.0, RUST)
    c.blob(16, top + 6, 5.0, 4.8, P.SKIN)                     # head
    c.blob(16, top + 3.5, 5.4, 3.0, P.STONE)                  # helm
    for d in (-1, 1):                                         # horns
        c.line(16 + d * 5, top + 3, 16 + d * 8, top - 1, BONE[2])
        c.set(16 + d * 8, top - 2, BONE[3])
    c.rect(13, top + 6, 19, top + 6, P.STONE[1])              # visor slit
    c.set(14, top + 6, P.FIRE[2])
    c.set(18, top + 6, P.FIRE[2])
    c.blob(16, top + 10, 3.8, 2.2, HAIR["red"])               # braided beard
    c.outline()
    return c.image()


def terror(frame):
    """Roaming Terror: a hulking horned demon wreathed in embers."""
    c = Canvas(BW, BH)
    lx, rx, bob = _walk(frame)
    top = 3 + bob
    hide = [(62, 20, 30), (98, 35, 47), (143, 64, 41), (197, 96, 37)]
    _big_legs(c, top + 25, lx, rx, hide, DARK)
    c.blob(16, top + 16, 11.0, 10.0, hide)                    # chest
    c.blob(16, top + 19, 5.0, 4.0, P.FIRE)                    # molten core
    for x0, d in ((5, -1), (27, 1)):                          # clawed arms
        c.blob(x0, top + 16, 3.2, 6.5, hide)
        for k in range(3):
            c.line(x0 + d * (k - 1), top + 22, x0 + d * k, top + 25, BONE[3])
    c.blob(16, top + 6, 6.0, 5.0, hide)                       # head
    for d in (-1, 1):                                         # curled horns
        c.line(16 + d * 5, top + 3, 16 + d * 9, top - 1, BONE[2])
        c.line(16 + d * 9, top - 1, 16 + d * 10, top + 2, BONE[1])
    c.set(13, top + 6, P.GOLD[3])
    c.set(19, top + 6, P.GOLD[3])
    c.line(13, top + 9, 19, top + 9, P.FIRE[2])               # glowing maw
    c.set(14, top + 10, BONE[3])
    c.set(18, top + 10, BONE[3])
    rng_embers = [(4, 5), (28, 8), (2, 30), (30, 27), (9, 1)]
    for i, (x, y) in enumerate(rng_embers):                   # drifting embers
        c.set(x, (y - frame * 2) % BH, P.FIRE[3 if i % 2 else 2])
    c.outline()
    return c.image()


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

# GID-144 / TID-610: the rest of the world cast (replaced the 0x72 / Kenney pack art).
CAST = {
    "enemy_raider": {"body": "earth", "legs": "brown", "hair": "black", "hair_style": "helm", "helm": "grey",
                     "pauldrons": "red", "belt": True, "prop": "axe"},
    "enemy_duelist": {"body": "dark", "robe": True, "belt": True, "hair_style": "hood", "hood": "purple",
                      "prop": "rapier", "cloak": "purple"},
    "enemy_rival": {"body": "teal", "legs": "dark", "hair": "blond", "cloak": "red", "belt": True,
                    "prop": "rapier"},
    "npc_townsperson": {"body": "green", "legs": "brown", "hair": "brown", "belt": True},
    "npc_townsperson_2": {"body": "blue", "robe": True, "apron": True, "hair": "blond", "hair_style": "long"},
    "npc_townsperson_3": {"body": "brown", "legs": "earth", "hair": "grey", "beard": True, "hair_style": "hat"},
    "npc_merchant": {"body": "red", "legs": "brown", "hair": "brown", "beard": True, "belt": True, "pack": "crate",
                     "prop": "satchel"},
    "npc_merchant_traveling": {"body": "teal", "legs": "earth", "hair": "black", "hair_style": "wide_hat",
                               "pack": "bedroll", "prop": "lantern"},
    "npc_maiteln": {"body": "blue", "robe": True, "belt": True, "hair": "grey", "hair_style": "wizard", "hat": "blue",
                    "beard": "long", "prop": "staff", "cloak": "grey"},
}

CHARACTERS = {
    "enemy_skeleton": skeleton,
    "enemy_zombie": zombie,
    "enemy_undead_elite": elite,
    "enemy_ghoul": ghoul,
    "enemy_spectre": spectre,
    "enemy_warleader": warleader,
    "enemy_terror": terror,
}

# Only these get walk frames; the loader animates Maiteln alone (SpriteRegistry.maiteln_walk_frames), so the rest
# are idle-only and their pack walk frames were deleted (TID-610).
WALKERS = {"npc_maiteln"}


for _name, _spec in list(NPCS.items()) + list(CAST.items()):
    CHARACTERS[_name] = person(_spec)


def frames(fn):
    return [fn(i) for i in range(5)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="write a contact sheet instead of the sprites")
    args = ap.parse_args()
    if args.preview:
        rows = [frames(fn) for fn in CHARACTERS.values()]
        sheet = Image.new("RGBA", (BW * 5 * 3, BH * len(rows) * 3), (60, 70, 60, 255))
        for r, row in enumerate(rows):
            for i, im in enumerate(row):
                big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
                sheet.alpha_composite(big, (i * BW * 3, r * BH * 3 + (BH - im.height) * 3))
        sheet.save(args.preview)
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in CHARACTERS.items():
        fs = frames(fn)
        fs[0].save(OUT / f"{name}.png")
        if name not in WALKERS:
            continue  # nothing animates their walk: idle only
        for i in range(1, 5):
            fs[i].save(OUT / f"{name}_walk_{i}.png")
        print("wrote", name)


if __name__ == "__main__":
    main()
