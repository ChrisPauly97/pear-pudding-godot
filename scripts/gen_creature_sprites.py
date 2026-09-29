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

CRITTERS = {
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
}

if __name__ == "__main__":
    for key, frames in CRITTERS.items():
        pal = {"mouse": MOUSE, "rat": RAT, "butterfly": FLY, "bee": BEE, "scorched_larva": LARVA,
               "fawn": FAWN, "snow_rabbit": RABBIT, "blackened_adder": ADDER}[key]
        for i, rows in enumerate(frames):
            build(rows, pal, shade=key not in ("butterfly", "bee")).save(
                os.path.join(ROOT, "critters", "%s_%d.png" % (key, i)))
    for key, (rows, pal) in ENEMIES.items():
        build(rows, pal).save(os.path.join(ROOT, "characters", "enemy_%s.png" % key))
