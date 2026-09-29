#!/usr/bin/env python3
"""
Writes the HUD action icons (GID-144 / TID-613): original, hand-authored
geometric SVGs (white, 512 viewBox) replacing the game-icons.net set (CC BY).
Same file names, so `scenes/ui/HudIcons.gd` and the .import settings
(svg/scale=0.25) stay as they are.

Usage: python3 tools/generate_hud_icons.py
"""

from pathlib import Path

OUT = Path(__file__).parent.parent / "assets" / "icons" / "hud"

# Shared stroke style for line icons.
S = 'fill="none" stroke="#ffffff" stroke-width="40" stroke-linecap="round" stroke-linejoin="round"'
F = 'fill="#ffffff"'

ICONS = {
    "pause": f'<rect {F} x="120" y="70" width="96" height="372" rx="24"/>'
             f'<rect {F} x="296" y="70" width="96" height="372" rx="24"/>',
    "interact": (  # an open hand
        f'<rect {F} x="130" y="236" width="252" height="220" rx="80"/>'
        + "".join(f'<rect {F} x="{x}" y="{y}" width="52" height="{h}" rx="26"/>'
                  for x, y, h in ((140, 130, 170), (200, 70, 220), (262, 60, 230), (324, 100, 200)))
        + f'<path {S} d="M160 330 L80 250"/>'),
    "party": "".join(
        f'<circle {F} cx="{cx}" cy="{cy}" r="{r}"/>'
        f'<path {F} d="M{cx - r * 1.9} {cy + r * 3.6} a{r * 1.9} {r * 1.9} 0 0 1 {r * 3.8} 0z"/>'
        for cx, cy, r in ((130, 190, 48), (382, 190, 48), (256, 150, 62))),
    "emote": f'<circle {S} cx="256" cy="256" r="196"/>'
             f'<circle {F} cx="190" cy="206" r="30"/><circle {F} cx="322" cy="206" r="30"/>'
             f'<path {S} d="M160 300 Q256 400 352 300"/>',
    "chat": f'<path {S} d="M110 90 H402 a50 50 0 0 1 50 50 V310 a50 50 0 0 1 -50 50 H230 L130 440 V360 H110 '
            f'a50 50 0 0 1 -50 -50 V140 a50 50 0 0 1 50 -50z"/>'
            f'<circle {F} cx="170" cy="225" r="30"/><circle {F} cx="256" cy="225" r="30"/>'
            f'<circle {F} cx="342" cy="225" r="30"/>',
    "trade": f'<path {S} d="M90 180 H400 M320 100 L400 180 L320 260"/>'
             f'<path {S} d="M422 332 H112 M192 252 L112 332 L192 412"/>',
    "spectate": f'<path {S} d="M40 256 Q256 40 472 256 Q256 472 40 256z"/>'
                f'<circle {F} cx="256" cy="256" r="72"/>',
    "challenge": (  # crossed swords
        f'<path {S} d="M100 100 L380 380 M412 100 L132 380"/>'
        f'<path {S} d="M330 420 L420 330 M92 330 L182 420"/>'
        f'<path {S} d="M400 400 L450 450 M112 400 L62 450"/>'),
    "wager_challenge": (  # a sword planted beside a stack of coins
        f'<path {S} d="M80 60 L260 300 M170 290 L270 210 M260 300 L300 350"/>'
        + "".join(f'<rect {F} x="270" y="{y}" width="200" height="56" rx="28"/>' for y in (420, 350, 280))),
    "draft_duel": (  # a fan of three cards
        f'<rect {S} x="186" y="90" width="140" height="220" rx="20" transform="rotate(-24 256 420)"/>'
        f'<rect {S} x="186" y="90" width="140" height="220" rx="20" transform="rotate(24 256 420)"/>'
        f'<rect {F} x="186" y="80" width="140" height="220" rx="20"/>'),
    "menu_hub": (  # an open book
        f'<path {S} d="M256 130 Q170 80 60 110 V410 Q170 380 256 430 Q342 380 452 410 V110 Q342 80 256 130z"/>'
        f'<path {S} d="M256 130 V430"/>'),
    "mount": (  # a horseshoe
        f'<path fill="none" stroke="#ffffff" stroke-width="72" stroke-linecap="butt" '
        f'd="M130 450 V250 a126 126 0 0 1 252 0 V450"/>'
        + f'<rect {F} x="94" y="436" width="72" height="36" rx="10"/>'
          f'<rect {F} x="346" y="436" width="72" height="36" rx="10"/>'),
    "cantrip_ghost_phase": (  # a sheet ghost
        f'<path {F} fill-rule="evenodd" d="M256 50 C140 50 96 150 96 250 V460 L150 410 L204 460 L256 410 '
        f'L308 460 L362 410 L416 460 V250 C416 150 372 50 256 50z '
        f'M200 190 a28 40 0 1 0 0.1 0z M312 190 a28 40 0 1 0 0.1 0z"/>'),
    "cantrip_skeleton_dig": (  # a spade over a bone
        f'<path {S} d="M380 60 L230 250"/><path {S} d="M340 60 L420 100"/>'
        f'<path {F} d="M230 250 L150 190 L70 300 Q90 380 170 400 L270 300z"/>'
        f'<path {S} d="M300 440 L460 380"/>'
        f'<circle {F} cx="292" cy="420" r="30"/><circle {F} cx="312" cy="466" r="30"/>'
        f'<circle {F} cx="452" cy="354" r="30"/><circle {F} cx="470" cy="402" r="30"/>'),
}


def main():
    for name, body in ICONS.items():
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{body}</svg>\n'
        (OUT / f"{name}.svg").write_text(svg)
        print("wrote", name)


if __name__ == "__main__":
    main()
