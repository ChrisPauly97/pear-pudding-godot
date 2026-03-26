#!/usr/bin/env python3
"""
Converts wizard walk frames to pixel art by:
  1. Downscaling to target resolution with nearest-neighbor
  2. Quantizing to a limited palette
  3. Re-upscaling for preview (optional)
  4. Saving both the small sprite and a 4x upscaled preview

Usage:
  python3 tools/pixelate_wizard.py
  python3 tools/pixelate_wizard.py --width 48 --colors 24 --preview-scale 6
"""

import argparse
import os
from pathlib import Path
from PIL import Image

ASSET_DIR = Path(__file__).parent.parent / "assets" / "textures"
OUTPUT_DIR = ASSET_DIR / "pixel_art"

INPUT_FILES = [
    ASSET_DIR / "wizard_walk_1.png",
    ASSET_DIR / "wizard_walk_2.png",
    ASSET_DIR / "wizard_walk_3.png",
    ASSET_DIR / "wizard_walk_4.png",
]


def pixelate(img: Image.Image, target_w: int, num_colors: int) -> Image.Image:
    """Downscale → quantize palette → keep transparency."""
    src_w, src_h = img.size
    aspect = src_h / src_w
    target_h = max(1, round(target_w * aspect))

    # Separate alpha so quantization doesn't touch it
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    rgb = img.convert("RGB")
    alpha = img.getchannel("A")

    # Downscale with nearest-neighbor for crisp pixels
    small_rgb = rgb.resize((target_w, target_h), Image.NEAREST)
    small_alpha = alpha.resize((target_w, target_h), Image.NEAREST)

    # Palette quantize on the RGB portion
    quantized = small_rgb.quantize(colors=num_colors, method=Image.Quantize.MEDIANCUT)
    quantized_rgb = quantized.convert("RGB")

    # Rebuild RGBA
    result = quantized_rgb.convert("RGBA")
    result.putalpha(small_alpha)

    return result


def make_preview(img: Image.Image, scale: int) -> Image.Image:
    """Upscale with nearest-neighbor for a crisp preview."""
    return img.resize(
        (img.width * scale, img.height * scale),
        Image.NEAREST,
    )


def main():
    parser = argparse.ArgumentParser(description="Pixelate wizard walk frames")
    parser.add_argument("--width", type=int, default=32,
                        help="Target sprite width in pixels (default: 32)")
    parser.add_argument("--colors", type=int, default=20,
                        help="Max palette colors (default: 20)")
    parser.add_argument("--preview-scale", type=int, default=8,
                        help="Upscale factor for preview images (default: 8)")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    preview_dir = OUTPUT_DIR / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)

    print(f"Settings: {args.width}px wide, {args.colors} colors, {args.preview_scale}x preview")
    print(f"Output:   {OUTPUT_DIR}\n")

    for src_path in INPUT_FILES:
        if not src_path.exists():
            print(f"  SKIP (not found): {src_path.name}")
            continue

        img = Image.open(src_path)
        pixel_img = pixelate(img, args.width, args.colors)

        out_name = src_path.stem + "_pixel.png"
        out_path = OUTPUT_DIR / out_name
        pixel_img.save(out_path, "PNG")

        preview = make_preview(pixel_img, args.preview_scale)
        preview_path = preview_dir / out_name
        preview.save(preview_path, "PNG")

        print(f"  {src_path.name}  →  {pixel_img.size[0]}×{pixel_img.size[1]}px  →  {out_name}")

    # Also build a horizontal sprite sheet from all frames
    frames = []
    for src_path in INPUT_FILES:
        if not src_path.exists():
            continue
        img = Image.open(src_path)
        frames.append(pixelate(img, args.width, args.colors))

    if frames:
        sheet_w = sum(f.width for f in frames)
        sheet_h = max(f.height for f in frames)
        sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
        x = 0
        for f in frames:
            sheet.paste(f, (x, sheet_h - f.height))  # bottom-align frames
            x += f.width
        sheet.save(OUTPUT_DIR / "wizard_walk_pixel_sheet.png", "PNG")
        make_preview(sheet, args.preview_scale).save(
            preview_dir / "wizard_walk_pixel_sheet.png", "PNG"
        )
        print(f"\n  Sprite sheet → wizard_walk_pixel_sheet.png  ({sheet_w}×{sheet_h}px)")

    print("\nDone.")


if __name__ == "__main__":
    main()
