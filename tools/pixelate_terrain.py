#!/usr/bin/env python3
"""
Converts terrain textures to pixel art style.

Produces both a small sprite (for Godot import) and an 8x upscaled preview.

Usage:
  python3 tools/pixelate_terrain.py
  python3 tools/pixelate_terrain.py --size 32 --colors 12
"""

import argparse
from pathlib import Path
from PIL import Image

ASSET_DIR = Path(__file__).parent.parent / "assets" / "textures"
OUTPUT_DIR = ASSET_DIR / "pixel_art"

TEXTURES = {
    "grass":     ASSET_DIR / "grass.png",
    "hill_side": ASSET_DIR / "hill_side.png",
    "hill_top":  ASSET_DIR / "hill_top.png",
    "wall_top":  ASSET_DIR / "wall_top.png",
}


def pixelate(img: Image.Image, size: int, num_colors: int) -> Image.Image:
    """Downscale to size×size → quantize palette → return result."""
    img = img.convert("RGB")
    small = img.resize((size, size), Image.NEAREST)
    quantized = small.quantize(colors=num_colors, method=Image.Quantize.MEDIANCUT)
    return quantized.convert("RGB")


def main():
    parser = argparse.ArgumentParser(description="Pixelate terrain textures")
    parser.add_argument("--size", type=int, default=32,
                        help="Target texture size in pixels (default: 32)")
    parser.add_argument("--colors", type=int, default=12,
                        help="Max palette colors per texture (default: 12)")
    parser.add_argument("--preview-scale", type=int, default=16,
                        help="Upscale factor for previews (default: 16)")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    preview_dir = OUTPUT_DIR / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)

    print(f"Settings: {args.size}×{args.size}px, {args.colors} colors, {args.preview_scale}x preview\n")

    for name, src_path in TEXTURES.items():
        if not src_path.exists():
            print(f"  SKIP (not found): {src_path.name}")
            continue

        img = Image.open(src_path)
        pixel_img = pixelate(img, args.size, args.colors)

        out_name = f"{name}_pixel.png"
        pixel_img.save(OUTPUT_DIR / out_name, "PNG")

        # 8× upscale for preview
        preview = pixel_img.resize(
            (pixel_img.width * args.preview_scale, pixel_img.height * args.preview_scale),
            Image.NEAREST
        )
        preview.save(preview_dir / out_name, "PNG")

        print(f"  {src_path.name}  →  {pixel_img.size[0]}×{pixel_img.size[1]}px  →  {out_name}")

    print("\nDone.")


if __name__ == "__main__":
    main()
