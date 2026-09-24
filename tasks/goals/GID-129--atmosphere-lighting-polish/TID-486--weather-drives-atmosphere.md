# TID-486: Weather Drives Fog, Sun & Grass Wind

**Goal:** GID-129
**Type:** agent
**Status:** done
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

1. New pure module `game_logic/WeatherLook.gd` (static, no class_name) — the per-weather look table:
   - `CLEAR` holds every key with its neutral value; `OVERRIDES[weather_id]` lists only what a weather
     changes. `look_for(id)` = CLEAR merged with the override, so TID-487 extends it by adding one CLEAR
     default (e.g. `wetness`, `lightning`) plus per-weather overrides — no call site changes.
   - Keys: `tint` (ambient multiplier, was `WeatherParticles.get_screen_tint`), `fog_density_mult`,
     `fog_color` + `fog_color_weight`, `sky_overcast` (sky greys toward the fog colour),
     `sun_energy_mult` (sun and moon), `shadow_opacity_mult`, `wind_direction` (was
     `get_wind_direction`), `wind_scale`, `wind_lean`.
   - `blend(a, b, t)` lerps float/Color/Vector2 values generically (anything else snaps at t = 0.5).
   - Fog multiplier capped (`MAX_FOG_DENSITY_MULT` 3.0) so storms never hide the player.
   - Clear weather gets the shader's default breeze direction instead of `Vector2.ZERO`
     (normalize(0) in the grass shaders made the blades NaN after rain ended).
2. `DayNightCycle`: owns the weather blend (it already owns env/sun/moon writes and their caches).
   `set_weather(id, instant := false)` starts a `BLEND_SECONDS` (4 s) smoothstep blend from the current
   look; `tick(delta)` (weather_tint arg dropped) advances it per frame from `_process` and re-applies
   lighting immediately while blending (write-on-change caches still skip unchanged values).
   `_apply_lighting` multiplies sun/moon energy, tints ambient, greys the sky, scales fog density
   from the setup-time base (0.004), blends the fog colour, scales the sun's base shadow opacity, and
   writes the grass wind globals. `weather_look()` getter for later tasks.
3. Grass: new global shader params `grass_wind_scale` (multiplies `wind_strength`) and
   `grass_wind_lean` (steady downwind bend) in `grass_blade`/`grass_cluster.gdshader`, registered in
   `GrassBlades._init_material` and `DayNightCycle.setup`; written by DNC (from `_process`) on change.
4. `WorldScene`: drop `_weather_tint*` state and the tint lerp; `_on_weather_changed` calls
   `_dnc.set_weather(id)` and takes the grass direction from `WeatherLook`. Net line change must stay
   under the 2180-line guardrail. `WeatherParticles.get_screen_tint/get_wind_direction` become thin
   delegates to `WeatherLook`. Co-op: clients already route the host weather id through
   `_on_weather_changed`, so no RPC changes.
5. Works on every tier/renderer (plain Environment/light params only).
6. Tests: `tests/unit/test_weather_look.gd` (table shape, key sets, neutral clear, storms darker/foggier/
   windier than their light variant, fog cap, blend endpoints/midpoint, unknown id = clear) and a DNC
   integration test (instant heavy_rain lowers sun energy, raises fog density, lowers shadow opacity;
   clear restores). Update `test_weather_visuals` clear-wind expectation.
7. Docs: visual-polish.md section "Weather Look"; task/goal/index status.

## Changes Made

- `game_logic/WeatherLook.gd` (new): `CLEAR` neutral look + `OVERRIDES` per weather id (tint, fog density mult + colour/weight, sky overcast, sun/moon energy mult, shadow opacity mult, wind direction/scale/lean), `look_for()`, generic `blend()`, `MAX_FOG_DENSITY_MULT` 3.0, `screen_tint()`/`wind_direction()`.
- `scenes/world/DayNightCycle.gd`: `set_weather(id, instant)` + 4 s smoothstep blend advanced per frame in `tick(delta)` (weather_tint arg removed), `weather_look()`; `_apply_lighting()` applies the look with write-on-change caches (fog density from the setup-time base, fog colour, sky overcast, sun/moon energy, shadow opacity from the base 0.2, grass wind globals). Removed the now-unused `invalidate_ambient_cache()`.
- `assets/shaders/grass_blade.gdshader`, `grass_cluster.gdshader`: global `grass_wind_scale` / `grass_wind_lean`; registered in `GrassBlades._init_material()` and `DayNightCycle.setup()`.
- `scenes/world/WorldScene.gd`: dropped `_weather_tint*` state, the tint lerp and `_WEATHER_TINT_SPEED`; `_on_weather_changed` calls `_dnc.set_weather(id)` (−10 lines, under the guardrail).
- `scenes/world/WeatherParticles.gd`: `get_screen_tint`/`get_wind_direction` delegate to `WeatherLook`. Bug fixed: clear weather returned `Vector2.ZERO` wind, which `normalize()`d to NaN in the grass shaders after rain ended; clear now keeps the shader's default breeze.
- Tests: new `tests/unit/test_weather_look.gd` (table shape/keys, co-op ids covered, neutral clear, copy semantics, ranges + fog cap, heavy harsher than light, blend, DayNightCycle integration: instant apply + mid-blend); `test_weather_visuals` clear-wind expectation updated.
- Validation: headless import clean, `unsafe-hits.sh` clean, gdlint clean, suite 2439 passed / 0 failed with 0 `SCRIPT ERROR` (exit-time leak warnings identical to baseline), `world_scene_smoke` 18/18, 0 `SCRIPT ERROR`.

## Documentation Updates

- `docs/agent/visual-polish.md`: Key Features bullet; new "Weather Look" How-It-Works section (key table, blend, wiring, extension recipe for TID-487); Integrations bullet updated.
