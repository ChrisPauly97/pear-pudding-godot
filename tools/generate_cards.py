#!/usr/bin/env python3
"""
Generates the card illustrations (GID-144 / TID-611): minion portraits cropped
from the generated world characters (tools/generate_characters.py) and the
spell-branch runes drawn as glyphs (all eight branches, GID-151) — replacing the 0x72 / Kenney portraits and
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


def _flame(c, cx, base, height, radius, ramp_idx, sway=1.5):
    """Teardrop flame: sharp wavering tip, round belly sitting on `base`."""
    tip = base - height
    for y in range(int(tip), int(base) + 1):
        t = (y - tip) / float(height)                         # 0 at the tip, 1 at the bottom
        if t < 0.7:
            w = radius * (t / 0.7) ** 0.9
        else:
            w = radius * math.sqrt(max(0.0, 1 - ((t - 0.7) / 0.3) ** 2))
        lean = sway * math.sin(t * math.pi * 1.6) * (1 - t)
        c.line(cx + lean - w, y, cx + lean + w, y, ramp_idx)


def rune_ember():
    """Ember: a layered flame (red rim, orange body, white-hot core) over glowing coals."""
    c = Canvas(S, S)
    for x, r in ((9, 3.2), (16, 4.0), (23, 3.2)):             # coal bed
        c.blob(x, 26, r, 2.4, [(62, 20, 30), P.RED[0], P.RED[1], P.FIRE[1]])
    _flame(c, 10, 24, 11, 4.0, P.RED[1], -1.0)                # side tongues
    _flame(c, 22, 24, 10, 3.6, P.RED[1], 1.0)
    _flame(c, 16, 25, 21, 7.0, P.RED[1])                      # main flame, outer to core
    _flame(c, 16, 25, 16, 5.2, P.FIRE[1])
    _flame(c, 10, 24, 7, 2.4, P.FIRE[1], -1.0)
    _flame(c, 22, 24, 6, 2.2, P.FIRE[1], 1.0)
    _flame(c, 16, 25, 11, 3.4, P.FIRE[2])
    _flame(c, 16, 25, 7, 2.4, P.FIRE[3], 0.0)
    for x, y, col in ((7, 7, P.FIRE[2]), (25, 5, P.FIRE[1]), (21, 2, P.FIRE[2]), (11, 3, P.FIRE[1])):
        c.set(x, y, col)                                      # rising sparks
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


def rune_bloom():
    """Bloom: a five-petal flower opening over two leaves."""
    c = Canvas(S, S)
    c.line(16, 18, 16, 28, P.GREEN[1])
    c.blob(10, 24, 4.5, 2.2, P.GREEN)
    c.blob(22, 22, 4.5, 2.2, P.GREEN)
    for i in range(5):
        a = -math.pi / 2 + i * 2 * math.pi / 5
        c.blob(16 + math.cos(a) * 6, 12 + math.sin(a) * 6, 4.0, 4.0, P.PINK)
    c.blob(16, 12, 3.0, 3.0, P.GOLD)
    c.outline()
    return _fit(c.image())


def rune_thorn():
    """Thorn: a twisting bramble stem studded with hooked spikes."""
    c = Canvas(S, S)
    pts = [(16 + math.sin(t / 4.0) * 5, t) for t in range(3, 30)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        c.line(x0, y0, x1, y1, P.EARTH[3])
        c.line(x0 + 1, y0, x1 + 1, y1, P.EARTH[2])
    for i, (x, y) in enumerate(pts[2::4]):
        d = 1 if i % 2 == 0 else -1
        c.line(x + d, y, x + d * 5, y - 3, P.STONE_WARM[3])
        c.set(x + d * 5, y - 4, P.STONE_WARM[2])
    c.blob(12, 20, 3.0, 1.6, P.GREEN)
    c.outline()
    return _fit(c.image())


def rune_flux():
    """Flux: a teal vortex spiralling into a bright core."""
    c = Canvas(S, S)
    for i in range(160):
        t = i / 160.0
        a = t * math.pi * 5.0
        r = 13.0 * (1.0 - t) + 1.0
        ramp = P.TEAL[1] if t < 0.4 else P.TEAL[2] if t < 0.8 else P.TEAL[3]
        c.set(16 + math.cos(a) * r, 16 + math.sin(a) * r, ramp)
        c.set(16 + math.cos(a) * r + 1, 16 + math.sin(a) * r, ramp)
    c.blob(16, 16, 2.2, 2.2, P.WATER)
    c.outline()
    return _fit(c.image())


def rune_fracture():
    """Fracture: a cracked crystal shard splitting apart."""
    c = Canvas(S, S)
    for dx, ramp in ((-3, P.BLUE), (3, P.PURPLE)):
        for y in range(4, 29):
            w = 5 - abs(y - 16) * 5 / 12.0
            for x in range(int(16 + dx - w), int(16 + dx + w) + 1):
                side = x < 16 + dx
                c.set(x, y, ramp[3] if side and y < 14 else ramp[2] if side else ramp[1])
    for y in range(4, 29):
        c.set(16 + ((y // 3) % 2) * 1 - 0, y, None)
    c.line(16, 4, 14, 10, P.WHITE)
    c.line(14, 10, 17, 17, P.WHITE)
    c.line(17, 17, 15, 28, P.WHITE)
    c.outline()
    return _fit(c.image())


# ---------------------------------------------------------------------------
# Creature families (GID-151 / TID-640): one portrait per family, cropped from
# the generated world sprites in assets/textures/. SpriteRegistry maps every
# minion / legendary card id onto a family (or a rune, for spell-like ones).
# ---------------------------------------------------------------------------

TEX = Path(__file__).parent.parent / "assets" / "textures"

FAMILIES = {
    "wolf": "characters/enemy_wolf.png",
    "wolf_pack": "characters/enemy_wolf_pack.png",
    "scarab": "characters/enemy_scarab.png",
    "scarab_swarm": "characters/enemy_scarab_swarm.png",
    "barrow_king": "characters/enemy_barrow_king.png",
    "bog_hag": "characters/enemy_bog_hag.png",
    "ember_cultist": "characters/enemy_ember_cultist.png",
    "rift_echo": "characters/enemy_rift_echo.png",
    "scout": "characters/enemy_martarquas_scout.png",
    "raider": "characters/enemy_raider.png",
    "wendigo": "characters/enemy_frost_wendigo.png",
    "warleader": "characters/enemy_warleader.png",
    "terror": "characters/enemy_terror.png",
    "undead_elite": "characters/enemy_undead_elite.png",
    "worm": "characters/enemy_cactus_worm.png",
    "stag": "characters/enemy_imbued_stag.png",
    "duelist": "characters/enemy_duelist.png",
    "rival": "characters/enemy_rival.png",
    "monk": "characters/npc_brother_aldo.png",
    "herbalist": "characters/npc_wenna_herbalist.png",
    "trainer": "characters/npc_combat_trainer.png",
    "warden": "characters/npc_rift_warden.png",
    "treant": "props/prop_tree_oak_0.png",
}

BUST_MIN_H = 24   # sprites at least this tall get a head-and-shoulders crop
BUST_ROWS = 18


def family_portrait(rel):
    """Whole sprite for beasts and short figures; a bust for tall humanoids."""
    img = Image.open(TEX / rel).convert("RGBA")
    img = img.crop(img.getbbox())
    if img.height >= BUST_MIN_H and not rel.startswith("props/"):
        cx = img.width // 2
        img = img.crop((max(0, cx - 10), 0, min(img.width, cx + 10), BUST_ROWS))
        img = img.crop(img.getbbox())
    scale = max(1, min(S // img.width, S // img.height))
    img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    if img.width > S or img.height > S:
        img.thumbnail((S, S), Image.NEAREST)
    return _fit(img)


CARDS = {
    "card_ghost": lambda: portrait(GC.spectre),
    "card_skeleton": lambda: portrait(GC.skeleton),
    "card_zombie": lambda: portrait(GC.zombie),
    "card_ghoul": lambda: portrait(GC.ghoul),
    "rune_dawn": rune_dawn,
    "rune_dusk": rune_dusk,
    "rune_ember": rune_ember,
    "rune_ash": rune_ash,
    "rune_bloom": rune_bloom,
    "rune_thorn": rune_thorn,
    "rune_flux": rune_flux,
    "rune_fracture": rune_fracture,
}
CARDS.update({f"card_{k}": (lambda rel=rel: family_portrait(rel)) for k, rel in FAMILIES.items()})


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
