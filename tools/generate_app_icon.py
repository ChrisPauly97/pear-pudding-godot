"""Generate the Pear Pudding TCG app icons (Android launcher + project icon).

Writes into assets/icons/app/:
  icon_background_432.png  adaptive background (plum radial gradient)
  icon_foreground_432.png  adaptive foreground (tilted card + pear), inside the 66% safe zone
  icon_monochrome_432.png  adaptive monochrome (themed icons, Android 13+)
  icon_main_192.png        legacy launcher icon (layers flattened, rounded square)
  icon_512.png             project / desktop icon

Usage: python3 tools/generate_app_icon.py   (needs Pillow)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons", "app")
SS = 4  # supersample factor
BASE = 432

PLUM_IN = (122, 52, 120)
PLUM_OUT = (38, 14, 48)
CARD_FACE = (250, 238, 210)
CARD_EDGE = (214, 168, 74)
CARD_INNER = (176, 128, 52)
PEAR_LIGHT = (196, 222, 96)
PEAR_DARK = (120, 160, 50)
STEM = (96, 62, 34)
LEAF = (70, 150, 70)


def _radial(size, inner, outer):
    img = Image.new("RGB", (size, size))
    px = img.load()
    c = size / 2
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x - c, y - c) / (size * 0.72))
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return img


def background(size):
    return _radial(size, PLUM_IN, PLUM_OUT)


def _pear(draw, cx, cy, s, body, dark, stem, leaf, mono=False):
    # Body: a small top circle blended into a large bottom circle.
    r_big, r_small = 0.42 * s, 0.26 * s
    by, ty = cy + 0.18 * s, cy - 0.28 * s
    base = body if mono else dark
    draw.ellipse([cx - r_big, by - r_big, cx + r_big, by + r_big], fill=base)
    draw.ellipse([cx - r_small, ty - r_small, cx + r_small, ty + r_small], fill=body)
    draw.polygon([(cx - r_small, ty), (cx + r_small, ty),
                  (cx + r_big * 0.92, by - r_big * 0.35), (cx - r_big * 0.92, by - r_big * 0.35)], fill=body)
    if not mono:
        # Repaint the lit side shifted left, leaving a shaded crescent on the right.
        o = 0.07 * s
        draw.ellipse([cx - r_big - o, by - r_big * 0.96, cx + r_big * 0.78 - o, by + r_big * 0.9], fill=body)
        draw.ellipse([cx - r_big * 0.62, by - r_big * 0.55, cx - r_big * 0.22, by - r_big * 0.05],
                     fill=(232, 244, 170))
    # Stem and leaf.
    sw = 0.06 * s
    draw.line([(cx, ty - r_small * 0.8), (cx + 0.06 * s, ty - r_small - 0.22 * s)], fill=stem, width=int(sw))
    lx, ly = cx + 0.08 * s, ty - r_small - 0.12 * s
    draw.polygon([(lx, ly), (lx + 0.16 * s, ly - 0.14 * s), (lx + 0.30 * s, ly - 0.06 * s),
                  (lx + 0.14 * s, ly + 0.06 * s)], fill=leaf)


def _card_layer(size, mono=False):
    """Tilted card with a pear, drawn upright on its own canvas then rotated."""
    w, h = int(size * 0.33), int(size * 0.46)
    pad = int(size * 0.04)
    card = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    rad = int(w * 0.10)
    white = (255, 255, 255, 255)
    if mono:
        d.rounded_rectangle([pad, pad, pad + w, pad + h], rad, fill=white)
        inset = int(w * 0.07)
        d.rounded_rectangle([pad + inset, pad + inset, pad + w - inset, pad + h - inset],
                            int(rad * 0.6), fill=(0, 0, 0, 0))
        _pear(d, pad + w / 2, pad + h * 0.52, w * 0.78, white, white, white, white, mono=True)
    else:
        d.rounded_rectangle([pad, pad, pad + w, pad + h], rad, fill=CARD_EDGE)
        inset = int(w * 0.06)
        d.rounded_rectangle([pad + inset, pad + inset, pad + w - inset, pad + h - inset],
                            int(rad * 0.7), fill=CARD_INNER)
        inset2 = int(w * 0.10)
        d.rounded_rectangle([pad + inset2, pad + inset2, pad + w - inset2, pad + h - inset2],
                            int(rad * 0.5), fill=CARD_FACE)
        _pear(d, pad + w / 2, pad + h * 0.52, w * 0.74, PEAR_LIGHT, PEAR_DARK, STEM, LEAF)
    return card.rotate(-12, resample=Image.BICUBIC, expand=True)


def foreground(size, mono=False):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    back = _card_layer(size, mono).rotate(22, resample=Image.BICUBIC, expand=True)
    front = _card_layer(size, mono)
    if not mono:
        # Soft drop shadow under the front card.
        shadow = Image.new("RGBA", front.size, (0, 0, 0, 0))
        shadow.paste((0, 0, 0, 110), mask=front.split()[3])
        shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.015))
        bx, by = (size - back.width) // 2 - int(size * 0.07), (size - back.height) // 2 - int(size * 0.02)
        layer.alpha_composite(_dim(back), (bx, by))
        fx, fy = (size - front.width) // 2 + int(size * 0.05), (size - front.height) // 2 + int(size * 0.02)
        layer.alpha_composite(shadow, (fx + int(size * 0.012), fy + int(size * 0.02)))
        layer.alpha_composite(front, (fx, fy))
    else:
        fx, fy = (size - front.width) // 2, (size - front.height) // 2
        layer.alpha_composite(front, (fx, fy))
    return layer


def _dim(img):
    r, g, b, a = img.split()
    rgb = Image.merge("RGB", (r, g, b)).point(lambda v: int(v * 0.62))
    return Image.merge("RGBA", (*rgb.split(), a))


def _down(img, size):
    return img.resize((size, size), Image.LANCZOS)


def _flatten(size, corner_frac):
    big = size * SS
    bg = background(big // 2).resize((big, big), Image.BICUBIC).convert("RGBA")
    bg.alpha_composite(foreground(big))
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], int(big * corner_frac), fill=255)
    bg.putalpha(mask)
    return _down(bg, size)


def main():
    os.makedirs(OUT, exist_ok=True)
    big = BASE * SS
    _down(background(BASE).convert("RGB"), BASE).save(os.path.join(OUT, "icon_background_432.png"))
    _down(foreground(big), BASE).save(os.path.join(OUT, "icon_foreground_432.png"))
    _down(foreground(big, mono=True), BASE).save(os.path.join(OUT, "icon_monochrome_432.png"))
    _flatten(192, 0.22).save(os.path.join(OUT, "icon_main_192.png"))
    _flatten(512, 0.22).save(os.path.join(OUT, "icon_512.png"))
    print("wrote icons to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
