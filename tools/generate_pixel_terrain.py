#!/usr/bin/env python3
"""
Generates clean hand-crafted pixel art terrain tiles from scratch.
No downsampling noise — uses deliberate color patterns.

Usage:
  python3 tools/generate_pixel_terrain.py
  python3 tools/generate_pixel_terrain.py --size 16 --preview-scale 32
"""

import argparse
import random
from pathlib import Path
from PIL import Image

OUTPUT_DIR = Path(__file__).parent.parent / "assets" / "textures" / "pixel_art"


def make_grass(size: int, seed: int = 1) -> Image.Image:
    """Flat grass with sparse darker/lighter accent pixels."""
    BASE   = (58,  90,  30)   # main green
    DARK   = (38,  60,  18)   # shadow accent
    LIGHT  = (82, 118,  44)   # highlight accent

    rng = random.Random(seed)
    img = Image.new("RGB", (size, size), BASE)
    px = img.load()

    for y in range(size):
        for x in range(size):
            r = rng.random()
            if r < 0.10:
                px[x, y] = DARK
            elif r < 0.18:
                px[x, y] = LIGHT
            # else stays BASE

    return img


def make_dirt(size: int, seed: int = 2) -> Image.Image:
    """Dirt/soil with a couple of brown shades."""
    BASE  = (82,  54,  30)
    DARK  = (58,  36,  18)
    LIGHT = (108, 74,  46)

    rng = random.Random(seed)
    img = Image.new("RGB", (size, size), BASE)
    px = img.load()

    for y in range(size):
        for x in range(size):
            r = rng.random()
            if r < 0.12:
                px[x, y] = DARK
            elif r < 0.22:
                px[x, y] = LIGHT

    return img


def make_hill_top(size: int, seed: int = 3) -> Image.Image:
    """Patchy grassy hilltop — alternating grass and dirt clusters."""
    GRASS = (66, 102,  34)
    DIRT  = (90,  62,  36)
    DARK  = (44,  68,  20)

    rng = random.Random(seed)
    img = Image.new("RGB", (size, size), GRASS)
    px = img.load()

    for y in range(size):
        for x in range(size):
            r = rng.random()
            if r < 0.25:
                px[x, y] = DIRT
            elif r < 0.32:
                px[x, y] = DARK

    return img


def make_stone(size: int, seed: int = 4) -> Image.Image:
    """Stone wall top — brick-like grid with mortar lines."""
    STONE  = (74,  78,  74)
    MORTAR = (34,  36,  34)
    LIGHT  = (96, 100,  96)

    img = Image.new("RGB", (size, size), STONE)
    px = img.load()

    # Mortar lines at fixed rows/cols to create brick grid
    brick_h = max(3, size // 4)
    brick_w = max(4, size // 3)

    for y in range(size):
        for x in range(size):
            row = y // brick_h
            # Offset alternate rows for brick stagger
            col_offset = (brick_w // 2) if (row % 2 == 1) else 0
            col_x = (x + col_offset) % size

            is_mortar_row = (y % brick_h == 0)
            is_mortar_col = (col_x % brick_w == 0)

            if is_mortar_row or is_mortar_col:
                px[x, y] = MORTAR
            elif (x + y) % 7 == 0:
                px[x, y] = LIGHT  # subtle highlight fleck

    return img


def save(img: Image.Image, name: str, out_dir: Path, preview_scale: int) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    preview_dir = out_dir / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)

    img.save(out_dir / name, "PNG")

    preview = img.resize(
        (img.width * preview_scale, img.height * preview_scale),
        Image.NEAREST
    )
    preview.save(preview_dir / name, "PNG")
    print(f"  {name}  ({img.width}×{img.height}px)")


def make_wall_side(size: int, seed: int = 5) -> Image.Image:
    """Dark stone for wall vertical faces — same palette as wall_top but no brick grid."""
    BASE   = (54,  58,  54)
    DARK   = (34,  36,  34)
    LIGHT  = (74,  78,  74)

    rng = random.Random(seed)
    img = Image.new("RGB", (size, size), BASE)
    px = img.load()

    for y in range(size):
        for x in range(size):
            r = rng.random()
            if r < 0.10:
                px[x, y] = DARK
            elif r < 0.18:
                px[x, y] = LIGHT

    return img


def main():
    parser = argparse.ArgumentParser(description="Generate pixel art terrain tiles")
    parser.add_argument("--size", type=int, default=16,
                        help="Tile size in pixels (default: 16)")
    parser.add_argument("--preview-scale", type=int, default=32,
                        help="Upscale for preview images (default: 32)")
    args = parser.parse_args()

    print(f"Generating {args.size}×{args.size}px tiles:\n")

    save(make_grass(args.size),     "grass_pixel.png",      OUTPUT_DIR, args.preview_scale)
    save(make_dirt(args.size),      "hill_side_pixel.png",  OUTPUT_DIR, args.preview_scale)
    save(make_hill_top(args.size),  "hill_top_pixel.png",   OUTPUT_DIR, args.preview_scale)
    save(make_stone(args.size),     "wall_top_pixel.png",   OUTPUT_DIR, args.preview_scale)
    save(make_wall_side(args.size), "wall_side_pixel.png",  OUTPUT_DIR, args.preview_scale)

    print("\nDone.")


if __name__ == "__main__":
    main()
