# TID-486: Weather Drives Fog, Sun & Grass Wind

**Goal:** GID-129
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Weather today is particles plus a tint. It should reshape the scene: fog, sun strength, grass wind. Part of GID-129 (polish existing systems, no new features).

## Research Notes

- Add per-weather table (next to `get_screen_tint` in `WeatherParticles.gd`, or a new pure `game_logic/WeatherLook.gd`): fog density multiplier + fog colour, sun energy multiplier, shadow opacity, wind strength.
- Lerp these alongside `_weather_tint` in `WorldScene._process` (~1456) and feed to `DayNightCycle` (extend `tick()` args or add a setter; keep its write-on-change cache and call `invalidate_ambient_cache()`).
- Grass: global shader param `wind_direction` exists (vec2) — add or scale a wind strength so storms bend grass harder. Update from `_process`, not physics (CLAUDE.md grass rule).
- Co-op: weather is host-synced (`CoopSession` synced clock/weather) — derive visuals only from the received weather id, no extra RPC.

Shared facts (GID-129 research, 2026-09-24):
- `project.godot` sets no `rendering/renderer/rendering_method`, so desktop runs **Forward+** and Android (only export preset) runs **Mobile**. Mobile lacks volumetric fog, SSAO, SSIL, SSR, SDFGI. Detect at runtime with `RenderingServer.get_current_rendering_method()` (`"forward_plus"` / `"mobile"` / `"gl_compatibility"`).
- Environment is built in code: `WorldScene._setup_environment()` (~line 354): ProceduralSky, depth fog (`fog_density 0.004`), FILMIC tonemap, glow (threshold 1.2, `glow_bloom` must stay 0 — see comment), `_world_env` field. Fill light added right after.
- Sun/moon: `WorldScene.tscn` `DirectionalLight3D` (shadows on, `directional_shadow_mode = 0` orthogonal, max distance 60) + `MoonLight` (no shadows). `scenes/world/DayNightCycle.gd` `_apply_lighting()` sets sun rotation (single X axis), energy (cap 1.1), colour, sky, fog colour, ambient; values are cached and only written on change.
- **Grass shaders (`grass_blade`/`grass_cluster.gdshader`) and ChunkRenderer props/landmarks, WorldItem are `unshaded`** — they ignore lights and shadows. DayNightCycle writes an approximate brightness global for grass instead (see BID-060).
- Weather: `autoloads/WeatherManager.gd` (per-biome tables, ids: rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard), emits `GameBus.weather_changed(id, duration)`; `WorldScene._on_weather_changed` (~2052) swaps `WeatherParticles.make(id)` and lerps `_weather_tint` into `_dnc.tick(delta, _weather_tint)`. `WeatherParticles.get_wind_direction()/get_screen_tint()` hold per-weather tables.
- Settings: `SceneManager.save_manager.get_setting(key, default)` / `set_setting`; UI in `scenes/ui/SettingsScene.gd` with `_add_slider_row/_add_toggle_row/_add_option_row`.
- Rules: preload never class_name; explicit types for Variant; `.uid` sidecar for any new `.gdshader`/`.tres`; run headless import + `scripts/unsafe-hits.sh` + gdlint + tests after edits. Every new visual must degrade gracefully on Mobile.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
