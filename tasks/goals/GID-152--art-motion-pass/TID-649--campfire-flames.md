# TID-649: Campfire flame frames

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Campfires (WildernessCamp, dungeon campfire chamber) have glow only (`NightLights.gd` L149 'campfire' style, `NightLightMath`). Part of GID-152 (art motion pass).

## Research Notes

- Generate campfire logs + 4-6 flame frames in `generate_sprites.py`; ember spark particles (GPUParticles3D, small, mobile-safe caps like AmbientTouches).
- Attach to `scenes/world/entities/WildernessCamp.gd` and dungeon campfire entity (`game_logic/world/DungeonGen.gd` L119). Cold camp (flag after lesson learned) shows logs only.
- Optionally sync NightLights flicker phase to the frame index.

## Plan

Generated lit (6) and smouldering (4) campfire frames; `CampfireVisual` helper on `SpriteLoop.with_frames`;
use it for dungeon rest sites (were a townsperson sprite) and the wilderness camp (story-cold).

## Changes Made

- `tools/generate_sprites.py`: `_fire_pit`, `campfire()`; 10 new `props/campfire_*.png`.
- `game_logic/LandmarkFrames.gd`: `campfire(lit)`. `scenes/world/entities/SpriteLoop.gd`: `with_frames(sprite,
  frames, fps)`. New `scenes/world/entities/CampfireVisual.gd`.
- `TownspersonNPC.gd`: rest sites draw a campfire. `WildernessCamp.gd`: meshes → smouldering sprite.
- Sparks are pixels in the flame frames instead of a GPUParticles3D emitter (cheaper on mobile, same read).
- Test: `test_sprite_loop::test_campfire_builds_a_looping_billboard`.

## Documentation Updates

- `docs/agent/art-sprites.md`: "Campfires".
