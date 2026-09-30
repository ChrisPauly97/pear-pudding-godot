# TID-644: Stream water ambience loop

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No water sound near streams; only rain and footstep splashes. Part of GID-152 (art motion pass).

## Research Notes

- `game_logic/AmbienceLayers.gd` maps layer keys → `assets/audio/ambience/*.ogg`; `game_logic/AmbienceGen.gd` synthesises loops (see BID-073 for owl precedent). Add a `stream` layer: generate a babbling-water loop (filtered noise + bubble blips) or synthesise at runtime.
- Gain by distance to nearest wet tile: sample `ChunkRenderer.water_at_world(csm, wx, wz, seed)` in a small ring around the player a few times per second (not every frame); fade in/out.
- Hook where ambience layers are driven (`AudioManager.gd`); add unit test for gain curve in a pure helper.

## Plan

Synth `stream` layer in AmbienceGen, `stream_gain(distance)` rule, a fourth AudioManager layer, and a
twice-a-second ring probe in AmbientTouches.

## Changes Made

- `game_logic/AmbienceGen.gd`: `_gen_stream()`. `game_logic/AmbienceLayers.gd`: `stream` path, radii, `stream_gain()`.
- `autoloads/AudioManager.gd`: `_water_layer`, `set_water_proximity()`.
- `scenes/world/modules/AmbientTouches.gd`: `_nearest_water()` probe, fade-out on exit.
- `tests/unit/test_ambience_layers.gd`: `test_stream_gain_by_distance` (synth loop covered by the existing loop test);
  `test_sfx_assets` exempts `stream` like `owls`. Logged BID-083 (no CC0 recording yet).
- `assets/audio/ambience/README.md`: stream row.

## Documentation Updates

- `docs/agent/terrain-rendering.md`: "Stream sound".
