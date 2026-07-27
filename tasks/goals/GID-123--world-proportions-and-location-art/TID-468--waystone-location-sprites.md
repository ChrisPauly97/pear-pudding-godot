# TID-468: Waystone & Rare-Location Sprites

**Goal:** GID-123
**Type:** agent
**Status:** done
**Depends On:** TID-466

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

Five world entities still drew flat-colored unshaded primitive meshes:
Waystone (gray `BoxMesh` pillar), ManaWell (cylinder + prism crystal),
PuzzleShrine (blue prism), BurialMound (brown cylinder), BlightHeart
(pulsing purple spheres). User request: "the rare locations dont have
textures yet, neither do the fast travel obelisks."

## Plan

Compose licensed pixel-art sprites (0x72 v1.7 + Kenney Tiny Dungeon, both
CC0; recolors/composites permitted) and integrate them with the same
registry-then-mesh-fallback pattern Chest/Door use.

## Changes Made

New sprites in `assets/textures/props/` (+ generated `.import` sidecars):

| File | Source | Entity height |
|---|---|---|
| `waystone_dormant.png` 16×48 | 0x72 `column`, cool-stone recolor | 1.9 |
| `waystone_active.png` 16×48 | same + hand-pixelled gold rune glyphs | 1.9 |
| `mana_well.png` 16×32 | Kenney TD statue 20 + basin 32, teal→cyan, floor pixels stripped | 1.1 |
| `puzzle_shrine.png` 16×32 | Kenney TD statue 19 + 31, blue recolor | 1.3 |
| `burial_mound.png` 16×22 | Kenney TD gravestone 65 + hand-pixelled dirt mound | 0.95 |
| `blight_heart.png` 16×24 | 0x72 `skull` purple recolor on hand-pixelled crystal spikes | 1.5 |

Code (each keeps the old mesh construction as fallback when the registry
texture is null):

- `game_logic/SpriteRegistry.gd`: 6 preloads + `waystone_texture(active)`,
  `mana_well_texture()`, `puzzle_shrine_texture()`, `burial_mound_texture()`,
  `blight_heart_texture()`.
- `scenes/world/entities/Waystone.gd`: billboard sprite; activation swaps
  dormant→active texture; scene `MeshInstance3D` hidden on the sprite path.
- `scenes/world/entities/ManaWell.gd`: sprite; mesh fallback.
- `scenes/world/entities/PuzzleShrine.gd`: sprite + kept `OmniLight3D`;
  solved state dims via sprite `modulate` (mesh fallback keeps material dup).
- `scenes/world/entities/BurialMound.gd`: sprite; mesh fallback.
- `scenes/world/entities/BlightHeart.gd`: sprite + kept aura sphere and
  pulse tween; sprite pulse capped at 1.05 so center-scaling never pushes
  the bottom edge below y=0 (FEET_MARGIN is 0.05).
- `CREDITS.md`: per-slot rows + pack "Used for" updates.

## Documentation Updates

- `docs/agent/art-sprites.md` (GID-123 section with integration notes),
  `docs/agent/waystone-fast-travel.md`, `docs/agent/ley-lines.md`,
  `docs/agent/blight-system.md` asset sections.
