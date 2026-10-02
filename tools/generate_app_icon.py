"""Generate the Pear Pudding TCG app icons (Android launcher + project icon).

Design: a gilded TCG card bearing a pear-shaped potion flask over a sword,
on a night-blue background ringed with faint gold runes.

Writes into assets/icons/app/:
  icon_background_432.png  adaptive background (night gradient + rune ring)
  icon_foreground_432.png  adaptive foreground (cards + flask + sword), inside the 66% safe zone
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

BG_IN = (34, 52, 92)
BG_OUT = (8, 10, 24)
RUNE = (214, 172, 84)
GOLD = (232, 186, 86)
GOLD_DARK = (150, 104, 40)
FACE_TOP = (54, 34, 74)
FACE_BOT = (22, 14, 36)
STEEL = (206, 214, 226)
STEEL_DARK = (128, 138, 156)
LEATHER = (110, 64, 36)
GLASS = (220, 236, 240)
BREW = (170, 222, 72)
BREW_DARK = (92, 156, 40)
CORK = (176, 122, 70)
WHITE = (255, 255, 255, 255)


def _radial(size, inner, outer, reach=0.72):
    img = Image.new("RGB", (size, size))
    px = img.load()
    c = size / 2
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x - c, y - c) / (size * reach))
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return img


def background(size):
    img = _radial(size, BG_IN, BG_OUT).convert("RGBA")
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    c = size / 2
    col = RUNE + (70,)
    for r, w in ((0.40, 0.006), (0.355, 0.004)):
        d.ellipse([c - r * size, c - r * size, c + r * size, c + r * size], outline=col, width=max(1, int(w * size)))
    # Rune ticks between the two rings: alternating bars and diamonds.
    for i in range(24):
        a = i / 24 * math.tau
        rm = 0.3775 * size
        x, y = c + math.cos(a) * rm, c + math.sin(a) * rm
        s = 0.012 * size
        if i % 2:
            d.polygon([(x, y - s), (x + s, y), (x, y + s), (x - s, y)], fill=col)
        else:
            dx, dy = math.cos(a) * s, math.sin(a) * s
            d.line([(x - dx, y - dy), (x + dx, y + dy)], fill=col, width=max(1, int(0.006 * size)))
    img.alpha_composite(ring)
    return img.convert("RGB")


def _sword(d, cx, cy, s, mono=False):
    """Vertical sword centred at (cx, cy); caller rotates the canvas."""
    steel, edge = (WHITE, WHITE) if mono else (STEEL, STEEL_DARK)
    gold, grip = (WHITE, WHITE) if mono else (GOLD, LEATHER)
    bw = 0.075 * s
    tip, guard = cy - 0.50 * s, cy + 0.22 * s
    d.polygon([(cx, tip), (cx + bw, tip + 0.1 * s), (cx + bw, guard), (cx - bw, guard),
               (cx - bw, tip + 0.1 * s)], fill=steel)
    if not mono:
        d.polygon([(cx, tip), (cx + bw, tip + 0.1 * s), (cx + bw, guard), (cx, guard)], fill=edge)
    d.rounded_rectangle([cx - 0.24 * s, guard, cx + 0.24 * s, guard + 0.055 * s], int(0.02 * s), fill=gold)
    d.rectangle([cx - 0.04 * s, guard + 0.055 * s, cx + 0.04 * s, guard + 0.22 * s], fill=grip)
    d.ellipse([cx - 0.065 * s, guard + 0.2 * s, cx + 0.065 * s, guard + 0.33 * s], fill=gold)


def _flask(d, cx, cy, s, mono=False):
    """Pear-shaped potion flask: a round belly, a narrower shoulder, a neck and a cork."""
    r_big, r_small = 0.30 * s, 0.18 * s
    by, ty = cy + 0.14 * s, cy - 0.12 * s
    glass_w = int(0.035 * s)

    def body(dr, fill):
        d.ellipse([cx - r_big - dr, by - r_big - dr, cx + r_big + dr, by + r_big + dr], fill=fill)
        d.ellipse([cx - r_small - dr, ty - r_small - dr, cx + r_small + dr, ty + r_small + dr], fill=fill)
        d.rectangle([cx - 0.08 * s - dr, ty - 0.34 * s, cx + 0.08 * s + dr, ty], fill=fill)

    cork = [cx - 0.11 * s, ty - 0.44 * s, cx + 0.11 * s, ty - 0.32 * s]
    if mono:
        body(0, WHITE)
        d.rounded_rectangle(cork, int(0.03 * s), fill=WHITE)
        return
    body(glass_w, GLASS)
    body(0, (40, 56, 70))
    # Brew fills the belly and shoulder (the pear), with a shaded right side and a bright surface.
    d.ellipse([cx - r_small, ty - r_small, cx + r_small, ty + r_small], fill=BREW)
    d.ellipse([cx - r_big, by - r_big, cx + r_big, by + r_big], fill=BREW_DARK)
    d.ellipse([cx - r_big, by - r_big * 0.9, cx + r_big * 0.7, by + r_big * 0.86], fill=BREW)
    d.ellipse([cx - r_big * 0.82, by - r_big * 0.62, cx + r_big * 0.82, by - r_big * 0.34], fill=(214, 246, 130))
    # Glass glint and bubbles.
    d.ellipse([cx - r_big * 0.66, by - r_big * 0.12, cx - r_big * 0.42, by + r_big * 0.42], fill=(236, 252, 210))
    for bx, byy, br in ((0.1, 0.05, 0.035), (0.18, 0.18, 0.025), (0.02, 0.24, 0.02)):
        d.ellipse([cx + bx * s - br * s, by + byy * s - br * s, cx + bx * s + br * s, by + byy * s + br * s],
                  fill=(226, 250, 170))
    d.rounded_rectangle(cork, int(0.03 * s), fill=CORK)
    # A leaf tied at the neck keeps the pear reading.
    lx, ly = cx + 0.08 * s, ty - 0.27 * s
    d.polygon([(lx, ly), (lx + 0.14 * s, ly - 0.12 * s), (lx + 0.27 * s, ly - 0.05 * s),
               (lx + 0.12 * s, ly + 0.05 * s)], fill=(78, 168, 78))


def _card(size, mono=False, art=True):
    w, h = int(size * 0.36), int(size * 0.50)
    pad = int(size * 0.05)
    card = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    x0, y0, x1, y1 = pad, pad, pad + w, pad + h
    rad = int(w * 0.09)
    if mono:
        d.rounded_rectangle([x0, y0, x1, y1], rad, fill=WHITE)
        i = int(w * 0.07)
        d.rounded_rectangle([x0 + i, y0 + i, x1 - i, y1 - i], int(rad * 0.6), fill=(0, 0, 0, 0))
    else:
        d.rounded_rectangle([x0, y0, x1, y1], rad, fill=GOLD_DARK)
        i = int(w * 0.035)
        d.rounded_rectangle([x0 + i, y0 + i, x1 - i, y1 - i], rad, fill=GOLD)
        i = int(w * 0.085)
        face = _radial(64, FACE_TOP, FACE_BOT, 0.9).resize((x1 - x0 - 2 * i, y1 - y0 - 2 * i))
        mask = Image.new("L", face.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, face.width - 1, face.height - 1], int(rad * 0.6), fill=255)
        card.paste(face, (x0 + i, y0 + i), mask)
        # Corner gems.
        g = w * 0.05
        for gx, gy in ((x0 + i, y0 + i), (x1 - i, y0 + i), (x0 + i, y1 - i), (x1 - i, y1 - i)):
            d.polygon([(gx, gy - g), (gx + g, gy), (gx, gy + g), (gx - g, gy)], fill=(120, 210, 230))
    if art:
        acx, acy = (x0 + x1) / 2, (y0 + y1) / 2
        if not mono:
            glow = Image.new("RGBA", card.size, (0, 0, 0, 0))
            ImageDraw.Draw(glow).ellipse([acx - w * 0.36, acy - w * 0.36, acx + w * 0.36, acy + w * 0.36],
                                         fill=(170, 230, 110, 90))
            card.alpha_composite(glow.filter(ImageFilter.GaussianBlur(w * 0.08)))
        sword = Image.new("RGBA", card.size, (0, 0, 0, 0))
        _sword(ImageDraw.Draw(sword), acx, acy, h * 0.9, mono)
        card.alpha_composite(sword.rotate(40, resample=Image.BICUBIC, center=(acx, acy)))
        _flask(ImageDraw.Draw(card), acx, acy + h * 0.04, w * 0.78, mono)
    return card


def foreground(size, mono=False):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    front = _card(size, mono).rotate(-8, resample=Image.BICUBIC, expand=True)
    if mono:
        layer.alpha_composite(front, ((size - front.width) // 2, (size - front.height) // 2))
        return layer
    back = _dim(_card(size, art=False)).rotate(14, resample=Image.BICUBIC, expand=True)
    layer.alpha_composite(back, ((size - back.width) // 2 - int(size * 0.07), (size - back.height) // 2))
    shadow = Image.new("RGBA", front.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 140), mask=front.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.015))
    fx, fy = (size - front.width) // 2 + int(size * 0.04), (size - front.height) // 2
    layer.alpha_composite(shadow, (fx + int(size * 0.012), fy + int(size * 0.02)))
    layer.alpha_composite(front, (fx, fy))
    _sparkles(layer, size)
    return layer


def _sparkles(layer, size):
    d = ImageDraw.Draw(layer)
    for fx, fy, fs in ((0.70, 0.30, 0.030), (0.31, 0.71, 0.022), (0.66, 0.68, 0.016)):
        x, y, s = fx * size, fy * size, fs * size
        d.polygon([(x, y - s), (x + s * 0.25, y - s * 0.25), (x + s, y), (x + s * 0.25, y + s * 0.25),
                   (x, y + s), (x - s * 0.25, y + s * 0.25), (x - s, y), (x - s * 0.25, y - s * 0.25)],
                  fill=(255, 236, 170, 255))


def _dim(img):
    r, g, b, a = img.split()
    rgb = Image.merge("RGB", (r, g, b)).point(lambda v: int(v * 0.55))
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
    _down(background(BASE * 2), BASE).save(os.path.join(OUT, "icon_background_432.png"))
    _down(foreground(big), BASE).save(os.path.join(OUT, "icon_foreground_432.png"))
    _down(foreground(big, mono=True), BASE).save(os.path.join(OUT, "icon_monochrome_432.png"))
    _flatten(192, 0.22).save(os.path.join(OUT, "icon_main_192.png"))
    _flatten(512, 0.22).save(os.path.join(OUT, "icon_512.png"))
    print("wrote icons to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
