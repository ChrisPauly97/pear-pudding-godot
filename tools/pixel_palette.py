"""Master pixel-art palette for Pear Pudding.

The character sprites (0x72 dungeon pack) use exactly these 49 colours; they
are the game's palette. Every sprite we generate draws from it, and other
licensed art is snapped onto it (tools/snap_to_palette.py), so art from mixed
sources reads as one game. A few foliage/earth tones the pack lacks are added
at the end (EXTRA) -- keep additions rare and document why.
"""

PACK = [
    (17, 17, 17), (34, 34, 34), (72, 59, 58), (118, 59, 54), (143, 64, 41), (138, 80, 62),
    (178, 58, 58), (119, 92, 85), (218, 78, 56), (214, 72, 72), (197, 96, 37), (189, 108, 74),
    (228, 110, 51), (181, 128, 87), (238, 142, 46), (170, 141, 122), (195, 141, 112),
    (216, 165, 125), (226, 182, 148), (211, 191, 169), (252, 203, 163), (253, 247, 237),
    (250, 203, 62), (151, 218, 63), (75, 167, 71), (61, 115, 79), (73, 167, 144),
    (114, 214, 206), (20, 27, 42), (49, 65, 82), (82, 96, 124), (65, 112, 137),
    (123, 137, 148), (86, 152, 204), (139, 155, 180), (126, 152, 211), (151, 197, 255),
    (192, 203, 220), (42, 42, 58), (89, 86, 189), (96, 52, 135), (146, 86, 190),
    (95, 45, 86), (63, 38, 49), (159, 41, 78), (220, 74, 123), (98, 35, 47), (115, 40, 52),
    (247, 134, 151),
]

# The pack has one dark green and no dark earth between (72,59,58) and the
# oranges; foliage and soil need a shadow step there.
EXTRA = [
    (38, 72, 56),    # foliage shadow
    (104, 70, 48),   # earth mid
    (84, 54, 38),    # earth shadow
]

PALETTE = PACK + EXTRA

OUTLINE = (34, 34, 34)

# Ramps (shadow -> highlight) used by the generators.
GREEN = [(38, 72, 56), (61, 115, 79), (75, 167, 71), (151, 218, 63)]
TEAL = [(38, 72, 56), (61, 115, 79), (73, 167, 144), (114, 214, 206)]
STONE = [(42, 42, 58), (82, 96, 124), (123, 137, 148), (192, 203, 220)]
STONE_WARM = [(72, 59, 58), (119, 92, 85), (170, 141, 122), (211, 191, 169)]
WOOD = [(84, 54, 38), (104, 70, 48), (143, 64, 41), (189, 108, 74)]
EARTH = [(72, 59, 58), (84, 54, 38), (104, 70, 48), (138, 80, 62)]
RED = [(98, 35, 47), (178, 58, 58), (218, 78, 56), (247, 134, 151)]
PINK = [(115, 40, 52), (159, 41, 78), (220, 74, 123), (247, 134, 151)]
GOLD = [(143, 64, 41), (238, 142, 46), (250, 203, 62), (253, 247, 237)]
FIRE = [(178, 58, 58), (228, 110, 51), (250, 203, 62), (253, 247, 237)]
BLUE = [(49, 65, 82), (65, 112, 137), (86, 152, 204), (151, 197, 255)]
WATER = [(49, 65, 82), (86, 152, 204), (114, 214, 206), (253, 247, 237)]
PURPLE = [(63, 38, 49), (96, 52, 135), (146, 86, 190), (247, 134, 151)]
SKIN = [(181, 128, 87), (216, 165, 125), (252, 203, 163), (253, 247, 237)]
WHITE = (253, 247, 237)


def nearest(c):
    """Nearest palette colour (weighted RGB distance, close to perceptual)."""
    r, g, b = c[:3]
    best = None
    bd = 1e18
    for p in PALETTE:
        rm = (r + p[0]) / 2
        d = (2 + rm / 256) * (r - p[0]) ** 2 + 4 * (g - p[1]) ** 2 + (2 + (255 - rm) / 256) * (b - p[2]) ** 2
        if d < bd:
            bd, best = d, p
    return best

