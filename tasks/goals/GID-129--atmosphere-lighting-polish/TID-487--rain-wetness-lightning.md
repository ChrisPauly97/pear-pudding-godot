# TID-487: Rain Wetness & Lightning

**Goal:** GID-129
**Type:** agent
**Status:** done
**Depends On:** TID-486

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rain should visibly darken and shine the ground, and heavy rain and volcanic weather should flash. Part of GID-129 (polish existing systems, no new features).

## Research Notes

- `assets/shaders/terrain.gdshader` (lit): add `wetness` uniform (or global param): darken albedo, lower roughness, increase specular. Lerp in and out with weather (dries slowly after rain stops).
- Lightning: in heavy_rain (and volcanic, red-tinted), random 8–25 s interval, briefly spike ambient energy/sun and play a delayed thunder SFX (add `thunder` key to `AudioManager.SFX_PATHS` + `SfxGen` fallback generator).
- Accessibility: respect a reduced-flash option; reuse `screen_shake`-style setting or add `reduce_flashing` toggle in SettingsScene.

Shared facts (GID-129 research, 2026-09-24):
- `project.godot` sets no `rendering/renderer/rendering_method`, so desktop runs **Forward+** and Android (only export preset) runs **Mobile**. Mobile lacks volumetric fog, SSAO, SSIL, SSR, SDFGI. Detect at runtime with `RenderingServer.get_current_rendering_method()` (`"forward_plus"` / `"mobile"` / `"gl_compatibility"`).
- Environment is built in code: `WorldScene._setup_environment()` (~line 354): ProceduralSky, depth fog (`fog_density 0.004`), FILMIC tonemap, glow (threshold 1.2, `glow_bloom` must stay 0 — see comment), `_world_env` field. Fill light added right after.
- Sun/moon: `WorldScene.tscn` `DirectionalLight3D` (shadows on, `directional_shadow_mode = 0` orthogonal, max distance 60) + `MoonLight` (no shadows). `scenes/world/DayNightCycle.gd` `_apply_lighting()` sets sun rotation (single X axis), energy (cap 1.1), colour, sky, fog colour, ambient; values are cached and only written on change.
- **Grass shaders (`grass_blade`/`grass_cluster.gdshader`) and ChunkRenderer props/landmarks, WorldItem are `unshaded`** — they ignore lights and shadows. DayNightCycle writes an approximate brightness global for grass instead (see BID-060).
- Weather: `autoloads/WeatherManager.gd` (per-biome tables, ids: rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard), emits `GameBus.weather_changed(id, duration)`; `WorldScene._on_weather_changed` (~2052) swaps `WeatherParticles.make(id)` and lerps `_weather_tint` into `_dnc.tick(delta, _weather_tint)`. `WeatherParticles.get_wind_direction()/get_screen_tint()` hold per-weather tables.
- Settings: `SceneManager.save_manager.get_setting(key, default)` / `set_setting`; UI in `scenes/ui/SettingsScene.gd` with `_add_slider_row/_add_toggle_row/_add_option_row`.
- Rules: preload never class_name; explicit types for Variant; `.uid` sidecar for any new `.gdshader`/`.tres`; run headless import + `scripts/unsafe-hits.sh` + gdlint + tests after edits. Every new visual must degrade gracefully on Mobile.

## Plan

1. `WeatherLook`: three new keys with CLEAR defaults — `wetness` (0..1 ground wetness target:
   rain 0.6, heavy_rain 1.0), `lightning` (0..1 storm strength: heavy_rain 1.0, volcanic 0.7) and
   `lightning_color` (cool blue-white; volcanic red-orange). Co-op needs nothing new: clients already
   route the host weather id through `_on_weather_changed` → `DayNightCycle.set_weather`.
2. New pure module `game_logic/Lightning.gd` (static, no autoloads): strike interval (8–25 s, longer
   for weaker storms), double-flicker `flash_envelope(t)` over ~0.5 s, thunder delay (0.5–3.5 s, the
   strike's "distance") → thunder pitch, and `step_wetness(current, target, delta)` — wets in ~20 s,
   dries slowly (~90 s from soaked).
3. `DayNightCycle`:
   - `_wetness` follows `_look_to["wetness"]` via `step_wetness` each frame (snapped on the first
     weather id after setup, so re-entering the world mid-rain starts wet); written to the global
     shader param `terrain_wetness` on (quantised) change; `wetness()` getter.
   - Lightning scheduler: while the target look has `lightning > 0`, count down a local-random
     interval; a strike starts the flash envelope (skipped when the `flashing_allowed` Callable returns
     false) and schedules thunder; `thunder_rumbled(pitch)` signal fires after the delay. A storm that
     ends cancels pending strikes but lets queued thunder finish.
   - `_apply_lighting` adds the flash: ambient energy boost + ambient colour and sky pulled toward
     `lightning_color` (sun untouched, so it works at night too). Re-applied per frame only while a
     flash is live.
4. Terrain: `terrain_wetness` registered in `project.godot` `[shader_globals]` (exists before any
   shader compiles). `terrain.gdshader`: when wet, darken albedo, drop roughness, raise specular on
   upward-facing ground (walls' vertical faces barely), with noise-patch puddles that go glossier.
   Uniform branch skipped at 0 → no dry-weather cost; plain PBR params work on Forward+, Mobile and
   Compatibility.
5. Audio: `thunder` key in `AudioManager.SFX_PATHS` (`res://assets/audio/sfx/thunder.wav`, optional)
   + `SfxGen._gen_thunder()` synth fallback (crack + low rolling rumble); WorldScene plays it with
   `play_sfx_varied("thunder", pitch, …)`.
6. Accessibility: `reduce_flashing` toggle in SettingsScene (Accessibility & Comfort); WorldScene sets
   `_dnc.flashing_allowed` to read it live, so the strike keeps its thunder but never flashes.
7. Tests: `tests/unit/test_rain_lightning.gd` (look keys/ranges, wetness rises fast/dries slow,
   interval bounds, envelope shape, DNC wetness + flash integration incl. reduce-flashing and thunder
   signal); SfxGen key list covered by the existing test.
8. Docs: visual-polish.md (Weather Look keys, wetness, lightning), audio-manager.md (thunder key),
   sfx README; task/goal/index status.

## Changes Made

- `game_logic/WeatherLook.gd`: new keys `wetness` (rain 0.6, heavy_rain 1.0), `lightning` (heavy_rain 1.0, volcanic 0.7) and `lightning_color` (blue-white; volcanic red-orange).
- `game_logic/Lightning.gd` (new, pure/static): strike interval (8 s … 8 + 17/strength s), double-flicker `flash_envelope`, thunder delay 0.5–3.5 s → `thunder_pitch` (1.05 close … 0.75 distant), `step_wetness` (soak 20 s, dry 90 s).
- `scenes/world/DayNightCycle.gd`: per-frame wetness easing toward the target look (snapped on the first id after setup and on instant changes; reset to 0 in `setup()` since the global outlives scenes), written to global `terrain_wetness` quantised to 1/128; lightning scheduler + `strike_lightning()`, `thunder_rumbled(pitch)` signal, `flashing_allowed` Callable hook; `_apply_lighting` adds the flash (ambient energy +1.6×flash, ambient colour and sky pulled toward `lightning_color`). Getters `wetness()`, `flash_level()`.
- `project.godot`: `[shader_globals] terrain_wetness` (float, 0.0), so it exists before the terrain shader compiles.
- `assets/shaders/terrain.gdshader`: `global uniform float terrain_wetness`; when > 0 (uniform branch): upward-facing ground darkens up to 35 %, roughness 0.9 → 0.35, specular 0.1 → 0.45; fbm-noise puddle patches go glossier (roughness 0.08). Verified it compiles on the GL Compatibility renderer (xvfb/llvmpipe).
- `game_logic/SfxGen.gd`: `thunder` key + `_gen_thunder()` (high-passed noise crack + normalised double-low-passed rolling rumble, 2.8 s). `autoloads/AudioManager.gd`: `SFX_PATHS["thunder"] = res://assets/audio/sfx/thunder.wav` (optional real file).
- `scenes/world/WorldScene.gd` (+4 lines, 2163): `_dnc.thunder_rumbled` → `AudioManager.play_sfx_varied("thunder", pitch, 0.05)`; `_dnc.flashing_allowed` reads `reduce_flashing` live.
- `scenes/ui/SettingsScene.gd`: "Reduce Flashing" toggle (Accessibility & Comfort) → setting `reduce_flashing` (thunder kept, flash skipped).
- `tests/unit/test_rain_lightning.gd` (new): look keys, soak/dry rates, interval/delay bounds + envelope, DNC wetness follow/dry, flash brightens and fully fades, reduce-flashing suppresses flash but not thunder, heavy rain self-schedules strikes, rain never strikes, thunder synth fallback.
- Validation: headless import clean, `unsafe-hits.sh` clean, gdlint clean, suite 2460 passed / 0 failed with 0 `SCRIPT ERROR`, `world_scene_smoke` 18/18 with 0 `SCRIPT ERROR`.

## Documentation Updates

- `docs/agent/visual-polish.md`: Key Features bullet; Weather Look key table gains `wetness`/`lightning`/`lightning_color`; new "Rain Wetness" and "Storm Lightning" How-It-Works sections.
- `docs/agent/audio-manager.md`: `thunder` row in the SFX map.
- `assets/audio/sfx/README.md`: `thunder` row (optional real file to source in TID-492).
