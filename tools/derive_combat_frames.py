#!/usr/bin/env python3
"""
Derives enemy combat frames from each enemy's idle sprite (GID-152 / TID-646):

  enemy_<name>_attack_1..3.png   wind-up (lean back), strike (lunge forward), recover
  enemy_<name>_hit.png           flinch (lean back, a row squashed)
  enemy_<name>_death_1..3.png    buckle, slump, collapse into a heap

The body is sheared row by row (feet fixed, head moves most) and squashed
towards the ground line, so every sprite (rig or ASCII roster) gets the same
motion without per-enemy drawing. "Forward" is +x: the sprites face right or
the viewer, and the battle token mirrors enemies. Frames are 2×PAD px wider
than the idle (room for the largest lean) and keep its height, so a centred
sprite never shifts. Re-run after regenerating any enemy idle.

Usage:
  python3 tools/derive_combat_frames.py
"""

from pathlib import Path

from PIL import Image

CHARS = Path(__file__).parent.parent / "assets" / "textures" / "characters"
PAD = 4  # >= the largest |lean| below
SUFFIXES = ("_walk_", "_idle_", "_attack_", "_hit", "_death_")

# (lean at the head in px, height scale) per frame.
ATTACK = [(-2, 1.0), (3, 0.95), (1, 1.0)]
HIT = (-2, 0.94)
DEATH = [(-2, 0.85), (-3, 0.6), (-4, 0.35)]


def pose(idle, lean, squash):
    w, h = idle.size
    nh = max(2, int(round(h * squash)))
    body = idle.resize((w, nh), Image.NEAREST) if nh != h else idle
    out = Image.new("RGBA", (w + PAD * 2, h), (0, 0, 0, 0))
    for y in range(nh):
        t = 1.0 - y / max(1, nh - 1)          # 1 at the head, 0 at the feet
        out.alpha_composite(body.crop((0, y, w, y + 1)), (PAD + int(round(lean * t)), h - nh + y))
    return out


def main():
    names = sorted(p.stem for p in CHARS.glob("enemy_*.png") if not any(s in p.stem for s in SUFFIXES))
    for name in names:
        idle = Image.open(CHARS / f"{name}.png").convert("RGBA")
        for i, (lean, sq) in enumerate(ATTACK, 1):
            pose(idle, lean, sq).save(CHARS / f"{name}_attack_{i}.png")
        pose(idle, *HIT).save(CHARS / f"{name}_hit.png")
        for i, (lean, sq) in enumerate(DEATH, 1):
            pose(idle, lean, sq).save(CHARS / f"{name}_death_{i}.png")
    print(f"{len(names)} enemies x 7 combat frames")


if __name__ == "__main__":
    main()
