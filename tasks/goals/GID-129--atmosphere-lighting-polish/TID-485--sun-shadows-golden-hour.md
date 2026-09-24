# TID-485: Sun Shadows & Golden-Hour Sun

**Goal:** GID-129
**Type:** agent
**Status:** done
**Depends On:** TID-484

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Shadows are orthogonal (cheapest, blocky) and the sun moves on one axis, so dawn/dusk looks flat. Part of GID-129 (polish existing systems, no new features).

## Research Notes

- `WorldScene.tscn` DirectionalLight3D: switch mode per tier (Low orthogonal, Medium/High PSSM 2-split), tune `directional_shadow_max_distance` to the iso view (~40–60), bias/normal_bias to avoid acne on terrain.
- `DayNightCycle._apply_lighting()`: add a Y-axis yaw offset so the sun comes in at an angle (longer diagonal shadows at dawn/dusk); warmer, lower-energy horizon colour; keep the cache pattern and the 1.1 energy cap (glow threshold note).
- Moon: optional low-res shadows on High only.
- Check sprites: billboards use ALPHA_CUT_OPAQUE_PREPASS (see CLAUDE.md "Rider invisible") — check whether they cast shadows; `cast_shadow` on billboards can look wrong from an iso camera, so verify visually via the run skill/screenshot.

Shared facts (GID-129 research, 2026-09-24):
- `project.godot` sets no `rendering/renderer/rendering_method`, so desktop runs **Forward+** and Android (only export preset) runs **Mobile**. Mobile lacks volumetric fog, SSAO, SSIL, SSR, SDFGI. Detect at runtime with `RenderingServer.get_current_rendering_method()` (`"forward_plus"` / `"mobile"` / `"gl_compatibility"`).
- Environment is built in code: `WorldScene._setup_environment()` (~line 354): ProceduralSky, depth fog (`fog_density 0.004`), FILMIC tonemap, glow (threshold 1.2, `glow_bloom` must stay 0 — see comment), `_world_env` field. Fill light added right after.
- Sun/moon: `WorldScene.tscn` `DirectionalLight3D` (shadows on, `directional_shadow_mode = 0` orthogonal, max distance 60) + `MoonLight` (no shadows). `scenes/world/DayNightCycle.gd` `_apply_lighting()` sets sun rotation (single X axis), energy (cap 1.1), colour, sky, fog colour, ambient; values are cached and only written on change.
- **Grass shaders (`grass_blade`/`grass_cluster.gdshader`) and ChunkRenderer props/landmarks, WorldItem are `unshaded`** — they ignore lights and shadows. DayNightCycle writes an approximate brightness global for grass instead (see BID-060).
- Weather: `autoloads/WeatherManager.gd` (per-biome tables, ids: rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard), emits `GameBus.weather_changed(id, duration)`; `WorldScene._on_weather_changed` (~2052) swaps `WeatherParticles.make(id)` and lerps `_weather_tint` into `_dnc.tick(delta, _weather_tint)`. `WeatherParticles.get_wind_direction()/get_screen_tint()` hold per-weather tables.
- Settings: `SceneManager.save_manager.get_setting(key, default)` / `set_setting`; UI in `scenes/ui/SettingsScene.gd` with `_add_slider_row/_add_toggle_row/_add_option_row`.
- Rules: preload never class_name; explicit types for Variant; `.uid` sidecar for any new `.gdshader`/`.tres`; run headless import + `scripts/unsafe-hits.sh` + gdlint + tests after edits. Every new visual must degrade gracefully on Mobile.

## Plan

1. `GraphicsQuality.TIERS` — retune shadow knobs and add new ones (all three tiers):
   - `shadow_mode`: Low ORTHOGONAL, Medium/High PSSM_2_SPLITS (Medium keeps `sun_shadows` off, as TID-484 decided).
   - `shadow_max_distance` tuned to the iso view (ortho size 15, camera 34.6 units from the player, so
     on-screen ground sits ~24–45 units deep): Low 45 / Medium 50 / High 55.
   - New: `shadow_split_1` (0.7 — near cascade ends just past the player's depth, far cascade covers the
     top half of the screen), `shadow_blend_splits` (High only), `shadow_bias` / `shadow_normal_bias`
     (larger on coarser atlases to stop terrain acne), `moon_shadows` (High only, orthogonal, low-res).
   - `apply()` writes them; gains an optional trailing `moon` argument.
2. `DayNightCycle`: replace the single-X-axis sun rotation with a tilted arc — static
   `sun_direction(time_of_day)` rises in the NE (dawn shadows fall screen-left/right across the iso
   view), leans 30° away from the camera at noon (shadows fall toward the camera, never straight
   down), sets in the SW. Sun and moon bases from `Basis.looking_at`, cached like the other writes.
   Static `sun_color_for(sun_h)`: three-stop day → golden → deep-orange horizon ramp over a wider
   band (sun_h < 0.45) instead of the old `sun_h < 0.2` snap. Energy curve and 1.1 cap unchanged.
3. WorldScene passes `_moon` to `GraphicsQuality.apply`.
4. Billboards: Player/Avatar sprites already opt out of shadows; leave entity sprites as-is and check
   visually if a rendering screenshot is feasible.
5. Tests: extend `test_graphics_quality` (new keys, moon apply, bias/split writes) and add
   `tests/unit/test_day_night_sun.gd` (sun direction unit length, above horizon by day, never straight
   overhead, dawn/dusk opposite, golden ramp warmth monotonic).
6. Docs: visual-polish.md knob table + new "Sun arc & golden hour" section; task/goal/index status.

## Changes Made

- `game_logic/GraphicsQuality.gd`: shadow knobs retuned — `shadow_mode` Medium/High PSSM_2_SPLITS (Low orthogonal), `shadow_max_distance` 45/50/55 to fit the iso view; new knobs `shadow_split_1` (0.7), `shadow_blend_splits` (High), `shadow_bias`/`shadow_normal_bias` (0.15/1.6, 0.1/1.3, 0.08/1.0), `moon_shadows` (High). `apply()` writes them and takes an optional `moon` (orthogonal, bias ×1.5, opacity 0.5).
- `scenes/world/DayNightCycle.gd`: static `sun_direction()` tilted arc (NE rise, noon 30° toward NW/camera-forward, SW set), `light_basis()`, `sun_color_for()` three-stop golden ramp over sun_h < 0.45; sun/moon bases cached. Energy curve and 1.1 cap unchanged.
- `scenes/world/WorldScene.gd`: passes `_moon` to `GraphicsQuality.apply`.
- Tests: new `tests/unit/test_day_night_sun.gd`; `test_graphics_quality` gains `test_shadow_tuning_applied_to_sun_and_moon` and monotonic checks for `moon_shadows`/`shadow_blend_splits`.
- Billboards: left as-is (Player/Avatar/mount sprites already opt out of shadows).
- Validation: headless import clean, `unsafe-hits.sh` clean, gdlint clean, suite PASS with 0 `SCRIPT ERROR`, `world_scene_smoke` exit 0. A Compatibility/llvmpipe xvfb capture ran but isn't representative (over-saturated vs Forward+, no casters in the spawn meadow), so shadows weren't judged from it.

## Documentation Updates

- `docs/agent/visual-polish.md`: Key Features bullet; knob table updated with the new shadow knobs and values; `apply()` signature; new "Sun Arc & Golden Hour" How-It-Works section.
