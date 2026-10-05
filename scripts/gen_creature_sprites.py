#!/usr/bin/env python3
"""Generates critter and creature-enemy sprites from ASCII templates.

Critters -> assets/textures/critters/<key>_<frame>.png
Enemies  -> assets/textures/characters/enemy_<key>.png

Each template is fill only: '.' is transparent, every other char is a palette
key. A 1-texel dark outline is added around the silhouette, and each fill
texel is lightened under open sky / darkened over open ground for volume.
Needs Pillow (`pip install pillow`).
"""
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
OUTLINE = (18, 13, 23, 255)


def build(rows, pal, shade=True):
    w = max(len(r) for r in rows) + 2
    h = len(rows) + 2
    grid = [[None] * w for _ in range(h)]
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".":
                grid[y + 1][x + 1] = pal[c]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            c = grid[y][x]
            if c is None:
                if any(0 <= x + dx < w and 0 <= y + dy < h and grid[y + dy][x + dx] is not None
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    img.putpixel((x, y), OUTLINE)
                continue
            r, g, b = c[:3]
            if shade and c[3] == 255:
                if grid[y - 1][x] is None:
                    r, g, b = (min(255, int(v * 1.18 + 12)) for v in (r, g, b))
                elif grid[y + 1][x] is None:
                    r, g, b = (int(v * 0.78) for v in (r, g, b))
            img.putpixel((x, y), (r, g, b, 255))
    return img


def rgb(r, g, b, a=255):
    return (r, g, b, a)


# Critters ------------------------------------------------------------------
MOUSE = {"a": rgb(138, 122, 110), "b": rgb(214, 150, 150), "e": rgb(20, 16, 20), "l": rgb(200, 140, 140),
         "t": rgb(190, 140, 140)}
RAT = {"a": rgb(92, 80, 76), "b": rgb(180, 120, 118), "e": rgb(170, 30, 30), "l": rgb(170, 118, 112),
       "t": rgb(168, 120, 116)}
FLY = {"w": rgb(245, 245, 240), "b": rgb(40, 32, 36)}
BEE = {"y": rgb(240, 196, 48), "k": rgb(36, 28, 24), "w": rgb(220, 236, 250)}
LARVA = {"a": rgb(64, 46, 42), "o": rgb(255, 136, 40), "e": rgb(255, 210, 90)}
FAWN = {"a": rgb(176, 118, 70), "w": rgb(244, 232, 210), "b": rgb(140, 92, 56), "e": rgb(20, 16, 20),
        "l": rgb(140, 94, 58), "t": rgb(236, 226, 210)}
RABBIT = {"a": rgb(236, 240, 246), "b": rgb(226, 170, 176), "e": rgb(40, 30, 40), "l": rgb(210, 216, 226)}
ADDER = {"a": rgb(44, 40, 46), "h": rgb(96, 84, 92), "e": rgb(230, 40, 30)}
# GID-156 town critters
PIGEON = {"a": rgb(150, 156, 172), "d": rgb(104, 108, 126), "n": rgb(92, 140, 124), "e": rgb(232, 128, 44),
          "k": rgb(70, 60, 60), "l": rgb(220, 112, 112), "t": rgb(90, 94, 110)}
CHICKEN = {"w": rgb(244, 238, 226), "r": rgb(214, 40, 36), "e": rgb(20, 16, 20), "y": rgb(240, 180, 40),
           "o": rgb(232, 150, 40), "t": rgb(220, 212, 200)}
CAT = {"a": rgb(206, 134, 62), "s": rgb(150, 88, 40), "e": rgb(120, 200, 90), "l": rgb(180, 112, 52),
       "t": rgb(196, 126, 58)}

CRITTERS = {
    "pigeon": [
        ["........nn..",
         ".......nnek.",
         "..ddaaaann..",
         "tdddaaaaa...",
         "..aaaaaa....",
         "....l.l....."],
        ["............",
         "............",
         "..ddaaaa....",
         "tdddaaaaann.",
         "..aaaaaa.nek",
         "....l.l....."],
    ],
    "chicken": [
        ["......rr..",
         ".....wwwe.",
         ".....wwwwy",
         "tt..wwww..",
         "twwwwwww..",
         ".wwwwwww..",
         "..wwwww...",
         "...o.o...."],
        ["..........",
         "..........",
         "tt........",
         "twwwwww.rr",
         ".wwwwwwwwe",
         ".wwwwwwwwy",
         "..wwwww...",
         "...o.o...."],
    ],
    "cat": [
        ["t..........a.a",
         "t.........aaaa",
         "t.........aeae",
         ".t.......aaaaa",
         "..aasaasaaaa..",
         "..aaaaaaaaaa..",
         "..l.l....l.l..",
         "..l.l....l.l.."],
        ["...........a.a",
         "..........aaaa",
         "..........aeae",
         ".........aaaaa",
         "..aasaasaaaa..",
         "taaaaaaaaaaa..",
         "t.l.l....l.l..",
         "..l.l....l.l.."],
    ],
    "mouse": [
        [".......bb..",
         "..aaaaaabb.",
         "taaaaaaaaae",
         "t.aaaaaaaa.",
         "...l...l..."],
        [".......bb..",
         "..aaaaaabb.",
         "taaaaaaaaae",
         "t.aaaaaaaa.",
         "..l.....l.."],
    ],
    "rat": [
        ["..........bb..",
         "...aaaaaaaab..",
         "..aaaaaaaaaaae",
         "ttaaaaaaaaaaa.",
         "t...l....l...."],
        ["..........bb..",
         "...aaaaaaaab..",
         "..aaaaaaaaaaae",
         "ttaaaaaaaaaaa.",
         "...l......l..."],
    ],
    "butterfly": [
        ["ww...ww",
         "wwwbwww",
         ".ww.ww.",
         ".w...w."],
        ["..wbw..",
         "..wbw..",
         "...b...",
         "......."],
    ],
    "bee": [
        [".w.w.",
         "ykyky",
         ".yky."],
        [".....",
         "ykyky",
         "wyky w".replace(" ", "")],
    ],
    "scorched_larva": [
        ["..aaaaaa..",
         ".aoaaoaaoe",
         "aaaaaaaaaa"],
        ["...aaaaa..",
         ".aoaaoaaoe",
         ".aaaaaaaa."],
    ],
    "fawn": [
        ["..........bb..",
         ".........bbb..",
         ".........aaae.",
         ".........aaaa.",
         "t.aaaaaaaaa...",
         ".aawaawaaaa...",
         ".aaaaaaaaa....",
         ".aaaaaaaaa....",
         "..l.l...l.l...",
         "..l.l...l.l...",
         "..l.l...l.l..."],
        ["..........bb..",
         ".........bbb..",
         ".........aaae.",
         ".........aaaa.",
         "t.aaaaaaaaa...",
         ".aawaawaaaa...",
         ".aaaaaaaaa....",
         ".aaaaaaaaa....",
         "..l..l..l..l..",
         ".l...l.l...l..",
         ".l....l.....l."],
    ],
    "snow_rabbit": [
        [".....ab..",
         ".....ab..",
         "....aaaa.",
         "....aaea.",
         ".aaaaaaa.",
         "aaaaaaaa.",
         ".aaaaaa..",
         "..l...l.."],
        [".....ab..",
         ".....ab..",
         "....aaaa.",
         "....aaea.",
         ".aaaaaaa.",
         "aaaaaaaa.",
         ".aaaaaaa.",
         "l......l."],
    ],
    "blackened_adder": [
        ["...aa.......aaa.",
         "..ahha.....ahhae",
         ".aa..aa...aa....",
         "aa....aaaaa....."],
        ["aa.....aa....aa.",
         ".aa...ahha..ahae",
         "..ahhaa..aaaa...",
         "................"],
    ],
}

# Creature enemies ----------------------------------------------------------
CACTUS_WORM = {"g": rgb(84, 150, 70), "d": rgb(52, 104, 50), "s": rgb(236, 226, 150), "e": rgb(220, 40, 40),
               "m": rgb(40, 20, 24)}
STAG = {"b": rgb(120, 82, 54), "d": rgb(92, 62, 42), "c": rgb(140, 244, 232), "v": rgb(96, 214, 210),
        "w": rgb(236, 226, 210), "e": rgb(150, 250, 240), "n": rgb(30, 22, 24), "h": rgb(44, 34, 30),
        "l": rgb(100, 68, 46)}

WOLF = {"a": rgb(128, 128, 136), "d": rgb(84, 84, 94), "w": rgb(206, 204, 200), "e": rgb(250, 210, 70),
        "n": rgb(24, 20, 24), "l": rgb(96, 96, 104), "t": rgb(110, 110, 120), "m": rgb(60, 58, 68),
        "s": rgb(170, 60, 60)}
HAG = {"h": rgb(62, 76, 48), "f": rgb(150, 176, 118), "e": rgb(250, 230, 90), "n": rgb(96, 120, 70),
       "c": rgb(78, 70, 54), "m": rgb(92, 128, 60), "k": rgb(140, 164, 110), "r": rgb(56, 50, 40),
       "l": rgb(44, 38, 32), "s": rgb(104, 76, 48), "g": rgb(150, 255, 120)}
SCOUT = {"h": rgb(86, 40, 36), "s": rgb(196, 150, 116), "e": rgb(24, 18, 20), "r": rgb(140, 50, 42),
         "l": rgb(220, 190, 120), "k": rgb(186, 140, 106), "w": rgb(120, 84, 50), "q": rgb(92, 64, 40),
         "b": rgb(60, 40, 30), "p": rgb(88, 70, 56), "d": rgb(42, 32, 28)}
SCARAB = {"s": rgb(40, 96, 110), "j": rgb(80, 180, 170), "g": rgb(210, 180, 80), "e": rgb(250, 90, 60),
          "l": rgb(30, 40, 44), "y": rgb(230, 196, 70), "o": rgb(160, 120, 40)}
CULTIST = {"h": rgb(120, 30, 26), "k": rgb(30, 16, 18), "e": rgb(255, 170, 40), "r": rgb(170, 48, 32),
           "o": rgb(230, 170, 60), "f": rgb(255, 120, 30), "y": rgb(255, 236, 140), "d": rgb(90, 24, 20)}
WENDIGO = {"a": rgb(214, 236, 246), "s": rgb(232, 226, 210), "e": rgb(110, 220, 255), "j": rgb(40, 30, 34),
           "f": rgb(150, 164, 176), "b": rgb(90, 100, 116), "c": rgb(40, 44, 60)}
BARROW = {"y": rgb(236, 196, 70), "s": rgb(226, 218, 196), "e": rgb(120, 255, 150), "j": rgb(60, 50, 50),
          "m": rgb(72, 78, 92), "p": rgb(96, 44, 120), "w": rgb(200, 210, 224), "k": rgb(140, 110, 60),
          "b": rgb(120, 90, 50), "h": rgb(236, 196, 70)}
ECHO = {"v": rgb(150, 96, 220), "w": rgb(255, 255, 255), "u": rgb(104, 60, 176), "c": rgb(140, 250, 255),
        "l": rgb(80, 44, 140)}

ENEMIES = {
    "cactus_worm": (
        ["......s..s.....",
         ".....sgggggs...",
         "....sgggeggs...",
         "....ggggmmgs...",
         ".....gdgggs....",
         "......gggg.....",
         ".....sgdgg.....",
         ".....gggggs....",
         "....sgggdgs....",
         "..s.gggggg.....",
         ".sgggdgggg.s...",
         "sggggggggdggs..",
         ".ggdggggggggggs"], CACTUS_WORM),
    "imbued_stag": (
        ["..............c.c.c.....",
         "...............ccc..c...",
         "..............c.ccc.c...",
         "................cccc....",
         ".................bb.....",
         "................bbbb....",
         "................bbbe....",
         "................bbbbbn..",
         "...............bbbbbbb..",
         "..............bbbb......",
         ".bbbbbbbbbbbbbbbbb......",
         "wbbvbbbbbbvbbbbbb.......",
         ".bbbvvbbbbbvvbbbb.......",
         "..dbbbvbbbbbbvbd........",
         "..ddbbbbbbbbbbdd........",
         "..l.l........l.l........",
         "..l.l........l.l........",
         "..l.l........l.l........",
         "..h.h........h.h........"], STAG),
    "wolf": (
        ["...............a.a..",
         "..............aaaa..",
         "..............aaeaa.",
         "t.............aaaaan",
         "tt.dddddddddddaaaw..",
         ".taaaaaaaaaaaaaaww..",
         "..aaaaaaaaaaaaaw....",
         "..awwwwwwwwwwaa.....",
         "..l.l.......l.l.....",
         "..l.l.......l.l.....",
         "..l..l.....l..l....."], WOLF),
    "wolf_pack": (
        ["....................m.m...",
         "...................mmmm...",
         "..................maaaaa..",
         "..................aaaeas..",
         "t.................aaaaaaan",
         "tt...............maaaaaw..",
         ".tt.mmmmmmmmmmmmmmmaaaw...",
         "..ttaaaaaaaaaaaaaaaaaww...",
         "...aaaaaaaaaaaaaaaaaaw....",
         "...aaaaaaaaaaaaaaaaaa.....",
         "...awwwwwwwwwwwwwwaa......",
         "...l.l..........l.l.......",
         "...l.l..........l.l.......",
         "...l.l..........l.l.......",
         "...l..l........l..l......."], WOLF),
    "bog_hag": (
        [".....hhhh.....g.",
         "....hhhhhh...ggg",
         "...hhffffh....s.",
         "...hfefeffh...s.",
         "...hffnffh....s.",
         "....fffff.....s.",
         "...ccffcccc..ks.",
         "..cccccccccckks.",
         "..ccmcccccc...s.",
         ".cccmccccccc..s.",
         ".ccccmcccccc..s.",
         ".cccccmccccc..s.",
         "cccccccmcccc..s.",
         "ccccccccccccc.s.",
         "cccccccccccccc..",
         ".rrrrrrrrrrrr...",
         "...ll....ll....."], HAG),
    "martarquas_scout": (
        ["....hhhh....w.",
         "...hhhhhh...lw",
         "...hsesesh..l.w",
         "...hsssssh..l.w",
         "....ssss....l.w",
         "..qrrrrrrr..l.w",
         "..qrrlrrrrrkl.w",
         ".kqrrlrrrr..l.w",
         ".k.rrlrrr...lw.",
         "...rrlrrr...w..",
         "...bbbbbb......",
         "...rrrrrr......",
         "...pp..pp......",
         "...pp..pp......",
         "...pp..pp......",
         "...dd..dd......"], SCOUT),
    "scarab": (
        ["..g...g..",
         "...sss...",
         ".ssjsjsse",
         "sssjjjsss",
         ".l.l.l.l."], SCARAB),
    "scarab_swarm": (
        [".................g..",
         "................gg..",
         "......yyyyyyy..g....",
         "....yyoyyyyoyyyg....",
         "...yyyoyyyyyoyyyse..",
         "..yyyyyoyyyyoyyysss.",
         "..yyyyyoyyyyoyyyss..",
         "..yyyyyyoyyoyyyys...",
         "...ssssssssssssss...",
         "..l.l..l..l..l..l...",
         ".l..l..l..l..l...l.."], SCARAB),
    "ember_cultist": (
        [".....hhh.......",
         "....hhhhh...ff.",
         "...hhkkkhh.fyf.",
         "...hkekekh..f..",
         "...hhkkkhh..k..",
         "....rrrrr..kk..",
         "...rrorrrrrk...",
         "..rrrorrrrr....",
         "..rrrorrrrr....",
         ".rrrrorrrrrr...",
         ".rrrrorrrrrr...",
         "rrrrrorrrrrrr..",
         "rrrrrorrrrrrr..",
         "ddddddddddddd.."], CULTIST),
    "frost_wendigo": (
        ["a..a........a..a",
         ".aa.a......a.aa.",
         "..a..a....a..a..",
         "...aaa....aaa...",
         ".....assssa.....",
         "......sees......",
         "......ssss......",
         "......sjjs......",
         "....ffffffff....",
         "...ffbfffffbff..",
         "..ff.ffffff.ff..",
         "..f..ffbbff..f..",
         ".cf..ffffff..fc.",
         ".c...ffffff...c.",
         ".....fff.fff....",
         ".....ff...ff....",
         ".....ff...ff....",
         ".....ff...ff....",
         "....cc.....cc..."], WENDIGO),
    "barrow_king": (
        ["....y.y.y.......",
         "....yyyyy.......",
         "....sssss.......",
         "....seses.......",
         "....sssss.......",
         ".....sjs........",
         "..pppmmmppp.....",
         ".ppmmmmmmmpp..w.",
         ".pmmmyymmmmp..w.",
         "pp.mmmmmmm.pp.w.",
         "p..mmmmmmm..pkw.",
         "p..mmmmmmm..pkk.",
         "p...bbbbb...p.h.",
         "p...mmmmm...p...",
         "pp..mm.mm..pp...",
         ".p..mm.mm..p....",
         ".pp.mm.mm.pp....",
         "..pmmm.mmmp....."], BARROW),
    "rift_echo": (
        [".....vvvv.....",
         "....vvvvvv....",
         "....vwvvwv....",
         "....vvcvvv....",
         ".....vvcv.....",
         "...uuuuucuu...",
         "..uuuuuuucuu..",
         "..vuuuuuuuuv..",
         "..v.uucuuu.v..",
         "..c.uuucuu.c..",
         "....uuuucu....",
         "....uu..uu....",
         "....uu..cu....",
         "....ll..ll...."], ECHO),
}

# GID-152 / TID-645: walk frames derived from the idle sprite. The bottom rows
# (legs, tail tip, worm body) split at the centre and stride in opposite
# directions; the frames between strides bob the body down a pixel. Floaters
# (no legs to stride) only bob. Frames are padded one pixel each side so a
# stride never clips; the sprite is centred, so idle and walk still line up.
FLOATERS = {"rift_echo"}
STRIDE = [(1, -1, 0), (0, 0, 1), (-1, 1, 0), (0, 0, 1)]  # (left dx, right dx, bob)


def walk_frames(idle, legs_frac=0.3, floater=False):
    w, h = idle.size
    leg_top = h - max(2, int(round(h * legs_frac)))
    mid = w // 2
    out = []
    for lx, rx, bob in STRIDE:
        if floater:
            lx = rx = 0
        f = Image.new("RGBA", (w + 2, h), (0, 0, 0, 0))
        body = idle.crop((0, 0, w, leg_top))
        f.alpha_composite(body, (1, bob))
        left = idle.crop((0, leg_top, mid, h))
        right = idle.crop((mid, leg_top, w, h))
        # Legs first so the body's lower edge (bobbed down) overlaps the hip.
        legs = Image.new("RGBA", (w + 2, h), (0, 0, 0, 0))
        legs.alpha_composite(left, (1 + lx, leg_top))
        legs.alpha_composite(right, (1 + mid + rx, leg_top))
        legs.alpha_composite(f)
        out.append(legs)
    return out


if __name__ == "__main__":
    for key, frames in CRITTERS.items():
        pal = {"mouse": MOUSE, "rat": RAT, "butterfly": FLY, "bee": BEE, "scorched_larva": LARVA,
               "fawn": FAWN, "snow_rabbit": RABBIT, "blackened_adder": ADDER,
               "pigeon": PIGEON, "chicken": CHICKEN, "cat": CAT}[key]
        for i, rows in enumerate(frames):
            build(rows, pal, shade=key not in ("butterfly", "bee")).save(
                os.path.join(ROOT, "critters", "%s_%d.png" % (key, i)))
    for key, (rows, pal) in ENEMIES.items():
        idle = build(rows, pal)
        idle.save(os.path.join(ROOT, "characters", "enemy_%s.png" % key))
        for i, fr in enumerate(walk_frames(idle, floater=key in FLOATERS)):
            fr.save(os.path.join(ROOT, "characters", "enemy_%s_walk_%d.png" % (key, i + 1)))
