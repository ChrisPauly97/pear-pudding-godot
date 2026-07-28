# GID-126: Battle Board Backdrop

## Objective

Direct user request (2026-07-28, branch `claude/board-background-art-o1r5t1`):

> can we find board background art or maybe make one using the art we have for
> the game so far so its not just a blue background?

Give the card board a real backdrop instead of the flat
`Color(0.1, 0.1, 0.15)` rectangle `BattleScene.tscn` has shipped since the
scene was written.

## Context

The user offered two routes — source third-party art, or build one from what
the game already has. The second was taken, for three reasons:

1. **The battle already knows where it is.** Battlefield Resonance (GID-059)
   stamps `battlefield_biome` and `is_night` into `GameState` on every world
   encounter, and shows them in the side panel. A static image would throw that
   away; a generated one can make the backdrop *be* the ground you were
   standing on when the fight started.
2. **Licensing and size.** Five biomes × day/night plus a neutral variant is
   eleven full-screen images to source, credit and ship. The generated version
   is one 200-line shader with no new files in `assets/textures/`.
3. **The art already tiles.** `assets/textures/pixel_art/*.png` are the
   seamless 16×16 terrain tiles the 3-D world is built from, and
   `assets/textures/props/prop_*.png` are the scatter sprites. Reusing them is
   what keeps the battle and the world looking like one game.

`BattleScene.tscn`'s `Divider` anchor (0.38) is reused rather than drawn
alongside: the line that already separates the enemy half from the player half
is what gets lit.

**On framing (TID-476).** TID-475 shipped this as a landscape seen edge-on —
sky, horizon, ridges, a ground plane receding to a vanishing point. The user
pushed back: a card board is a flat layout, so a vista behind it implies a
camera looking *across* a scene the cards are standing up in. TID-476 re-framed
it overhead, as the patch of ground the cards are laid out on. That is the
shipped version; the vista is one commit back in history.

## Tasks

| Task | Title | Type | Status |
|------|-------|------|--------|
| [TID-475](TID-475--biome-battle-backdrop.md) | Biome-aware battle backdrop | agent | done |
| [TID-476](TID-476--top-down-backdrop.md) | Re-frame the backdrop overhead | agent | done |

## Acceptance Criteria

- [x] The battle background is no longer a flat colour.
- [x] It differs per biome and between day and night, driven by the battlefield
      context the battle already carries — not by a second source of truth.
- [x] Puzzle, scripted, PvP and dungeon battles, which carry no biome, get a
      deliberate neutral look rather than a broken one.
- [x] No new art files; the ground and its scatter are the game's own tiles
      and props.
- [x] Framed overhead, matching the flat card layout rather than fighting it.
- [x] Cards stay legible over it.
- [x] Falls back to the original flat colour if the shader fails to load.
- [x] Headless import clean; suite 2291 passed / 0 failed.
