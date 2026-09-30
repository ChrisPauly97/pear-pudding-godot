# TID-648: Landmark idle loops

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Waystone, mana well, blight heart and puzzle shrine are static PNGs (only NightLights glow). Part of GID-152 (art motion pass).

## Research Notes

- Draw 4-frame loops in `tools/generate_sprites.py` (rune pulse on active waystone, swirl in mana well, heartbeat for blight heart, glyph shimmer on shrine) → `<name>_anim_1..4.png`.
- Entities set up via `SpriteRegistry.setup_sprite`; switch to AnimatedSprite3D with frames (preload consts) at ~4-6 fps. Dormant waystone stays static.
- Files: find spawners in `scenes/world/modules/NamedMapProps.gd` (waystones, shrines), mana wells (ley lines, `docs/agent/ley-lines.md`), `BlightHeart` entity.

## Plan

Phase argument on the four landmark drawers (phase 0 = unchanged still), `ANIMATED` frame export,
`LandmarkFrames` preload table, `SpriteLoop` node wired into Waystone / ManaWell / PuzzleShrine / BlightHeart.

## Changes Made

- `tools/generate_sprites.py`: phased drawers + `ANIMATED`; 16 new `props/*_anim_{1..4}.png` (stills unchanged).
- New `game_logic/LandmarkFrames.gd`, `scenes/world/entities/SpriteLoop.gd`.
- `Waystone.gd`, `ManaWell.gd`, `PuzzleShrine.gd` (stops when solved), `BlightHeart.gd`: attach the loop.
- Test: `tests/unit/test_sprite_loop.gd`.

## Documentation Updates

- `docs/agent/art-sprites.md`: "Landmark loops".
