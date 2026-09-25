# TID-497: Ground Mist Particles

**Goal:** GID-130
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rolling low mist at night/dawn in grassland, forest and mountains — soft billboard puffs, cheap at particle_scale.

## Research Notes

- `game_logic/AmbientParticles.gd` factories (shared static meshes/materials) + pure `*_level` rules; `scenes/world/modules/AmbientTouches.gd` fades emitters via `amount_ratio` every 0.5 s.
- Biome ids: 0 grasslands, 1 forest, 2 desert, 3 scorched, 4 mountains.
- Knob `ground_mist` (off/on/on).

## Plan

AmbientParticles factory + pure mist_level/mist_color; AmbientTouches spawns and fades a third emitter gated on the new ground_mist knob.

## Changes Made

- `AmbientParticles`: `make_mist`, `apply_mist_wind`, `set_mist_tint`, `mist_color`, `mist_level`, MIST_* tables; shared mist mesh/material/ramp.
- `AmbientTouches`: mist emitter follow/spawn/fade/wind/tint, `mist_level()`.
- `GraphicsQuality`: `ground_mist` (off/on/on).
- Tests: mist rules + factory in `test_ambient_particles`; GQ monotonic list.

## Documentation Updates

visual-polish.md: knob row + Ground mist bullet under Ambient Touches.
