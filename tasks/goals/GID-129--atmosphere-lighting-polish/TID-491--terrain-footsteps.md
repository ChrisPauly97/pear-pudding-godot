# TID-491: Terrain-Aware Footsteps

**Goal:** GID-129
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

One synthesised footstep for every surface. Part of GID-129 (polish existing systems, no new features).

## Research Notes

- `scenes/world/entities/Player.gd:352` plays `"footstep"`. Pick the surface from the tile under the player (IsoConst tile ids; TerrainMath for lookups — never duplicate terrain logic) plus biome: grass, sand, stone/path, snow, wood (named-map interiors), water.
- Add `footstep_<surface>` keys to `AudioManager.SFX_PATHS` + SfxGen fallbacks; random pitch ±8% and small volume jitter per step so the loop isn't robotic (add `play_sfx` optional pitch param or a new `play_sfx_varied`).
- Mounted: heavier hoof variant or lower pitch.
- Remote players (co-op avatars): optional, only if cheap.

Shared facts (GID-129 research, 2026-09-24):
- `project.godot` sets no `rendering/renderer/rendering_method`, so desktop runs **Forward+** and Android (only export preset) runs **Mobile**. Mobile lacks volumetric fog, SSAO, SSIL, SSR, SDFGI. Detect at runtime with `RenderingServer.get_current_rendering_method()` (`"forward_plus"` / `"mobile"` / `"gl_compatibility"`).
- Environment is built in code: `WorldScene._setup_environment()` (~line 354): ProceduralSky, depth fog (`fog_density 0.004`), FILMIC tonemap, glow (threshold 1.2, `glow_bloom` must stay 0 — see comment), `_world_env` field. Fill light added right after.
- Sun/moon: `WorldScene.tscn` `DirectionalLight3D` (shadows on, `directional_shadow_mode = 0` orthogonal, max distance 60) + `MoonLight` (no shadows). `scenes/world/DayNightCycle.gd` `_apply_lighting()` sets sun rotation (single X axis), energy (cap 1.1), colour, sky, fog colour, ambient; values are cached and only written on change.
- **Grass shaders (`grass_blade`/`grass_cluster.gdshader`) and ChunkRenderer props/landmarks, WorldItem are `unshaded`** — they ignore lights and shadows. DayNightCycle writes an approximate brightness global for grass instead (see BID-060).
- Weather: `autoloads/WeatherManager.gd` (per-biome tables, ids: rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard), emits `GameBus.weather_changed(id, duration)`; `WorldScene._on_weather_changed` (~2052) swaps `WeatherParticles.make(id)` and lerps `_weather_tint` into `_dnc.tick(delta, _weather_tint)`. `WeatherParticles.get_wind_direction()/get_screen_tint()` hold per-weather tables.
- Settings: `SceneManager.save_manager.get_setting(key, default)` / `set_setting`; UI in `scenes/ui/SettingsScene.gd` with `_add_slider_row/_add_toggle_row/_add_option_row`.
- Rules: preload never class_name; explicit types for Variant; `.uid` sidecar for any new `.gdshader`/`.tres`; run headless import + `scripts/unsafe-hits.sh` + gdlint + tests after edits. Every new visual must degrade gracefully on Mobile.

## Plan

IsoConst has no water or sand tile (grass, wall, hill, path, cracked), so the surface is a pure
function of tile + biome + map + weather:

1. New pure module `game_logic/FootstepSurface.gd`:
   - `surface_for(tile, biome_id, map_name, weather_id)` → `grass` / `sand` / `stone` / `snow` /
     `wood` / `water`. Overworld: biome base (grasslands/forest grass, desert sand, scorched stone,
     mountains snow flats + stone hills), path/wall/cracked → stone (desert path stays sand); heavy rain
     puddles every non-sand step, light rain puddles paths. Named maps: home/mansion/guildhall → wood,
     temple/dungeons/spire floors → stone, towns → path stone else grass.
   - `sfx_for(surface, mounted)` → `{key, pitch}`: `footstep_<surface>`; mounted → `footstep_hoof` on
     hard ground, the surface step pitched down (0.75) on soft ground.
   - `get_sfx(key)` synth fallbacks for the seven `footstep_*` keys (SfxGen primitives).
2. `AudioManager`: `footstep_*` in `SFX_PATHS`, fallbacks from FootstepSurface; new
   `play_sfx_varied(name, pitch=1.0, pitch_jitter=0.08, vol_jitter_db=1.5)`; the SFX setting kept in
   `_sfx_db` so per-step jitter never leaks into `get_sfx_volume()`; `play_sfx` resets pitch/volume.
3. `Player.gd`: footstep resolves the tile under the player via `WorldScene.get_tile_global` (typed
   `current_scene` cast; no WorldScene edit) and biome via `InfiniteWorldGen.biome_for_chunk`; mounted
   gets a hoof cadence timer (on floor + moving) since the rider sprite doesn't animate.
4. Remote avatars: skipped (optional; would need per-avatar players for positional audio).
5. Tests: `tests/unit/test_footstep_surface.gd` (surface table, mounted variants, synth keys).

## Changes Made

- `game_logic/FootstepSurface.gd` (new): `surface_for(tile, biome, map, weather)`, `sfx_for(surface, mounted)`,
  `all_keys()`, and synthesized fallbacks for `footstep_{grass,sand,stone,snow,wood,water,hoof}`.
- `autoloads/AudioManager.gd`: seven `footstep_*` entries in `SFX_PATHS` with FootstepSurface fallbacks;
  new `play_sfx_varied(name, pitch, pitch_jitter, vol_jitter_db)`; SFX setting held in `_sfx_db` and every
  pooled play sets its own pitch/volume (`_play_pooled`), so jitter never leaks into `get_sfx_volume()`.
- `scenes/world/entities/Player.gd`: `_play_step()` picks the surface underfoot (tile via
  `WorldScene.get_tile_global` through a typed `current_scene` cast, biome via
  `InfiniteWorldGen.biome_for_chunk`, weather on main) and plays it varied; mounted players get a 0.26 s
  hoofbeat cadence (previously silent). No WorldScene edit.
- `tests/unit/test_footstep_surface.gd` (new): biome ground, paths, rain puddles, named-map floors,
  mounted variants, every key registered + synthesized.
- `assets/audio/sfx/README.md`: new keys listed.
- Remote co-op avatars: not done (optional; would need positional per-avatar players).

## Documentation Updates

- `docs/agent/audio-manager.md`: new "Varied playback and terrain footsteps" section, SFX table rows,
  Player integration row, FootstepSurface asset row.
