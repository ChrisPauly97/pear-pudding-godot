# TID-484: Graphics Quality Tiers

**Goal:** GID-129
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Foundation for GID-129: one setting that decides which atmosphere effects run. Low/Medium default on mobile, High default on desktop; High enables Forward+-only effects when that renderer is actually active. Part of GID-129 (polish existing systems, no new features).

## Research Notes

- Add `graphics_quality` setting (0 Low / 1 Medium / 2 High) via `get_setting`; default from `OS.has_feature("mobile")` (Medium) else High. Option row in `SettingsScene` (`_add_option_row`).
- Put the tier table in a pure module (e.g. `game_logic/GraphicsQuality.gd`): per tier → shadow atlas size, shadow mode, soft-shadow filter (`RenderingServer.directional_soft_shadow_filter_set_quality`), SSAO, volumetric fog, glow, MSAA, particle amount scale, max night lights. Clamp Forward+-only flags off unless rendering method is `forward_plus`.
- Apply function takes the Environment + sun light; call from `_setup_environment()` and on setting change (signal via GameBus or direct call if world is live). Add a GameBus signal only if needed, with a real emit.
- Unit test: tier table sane, Forward+-only flags off for `"mobile"`.
- Later tasks (485, 488, 489, 493) read their knobs from this table — don't hard-code per-effect checks elsewhere.

Shared facts (GID-129 research, 2026-09-24):
- `project.godot` sets no `rendering/renderer/rendering_method`, so desktop runs **Forward+** and Android (only export preset) runs **Mobile**. Mobile lacks volumetric fog, SSAO, SSIL, SSR, SDFGI. Detect at runtime with `RenderingServer.get_current_rendering_method()` (`"forward_plus"` / `"mobile"` / `"gl_compatibility"`).
- Environment is built in code: `WorldScene._setup_environment()` (~line 354): ProceduralSky, depth fog (`fog_density 0.004`), FILMIC tonemap, glow (threshold 1.2, `glow_bloom` must stay 0 — see comment), `_world_env` field. Fill light added right after.
- Sun/moon: `WorldScene.tscn` `DirectionalLight3D` (shadows on, `directional_shadow_mode = 0` orthogonal, max distance 60) + `MoonLight` (no shadows). `scenes/world/DayNightCycle.gd` `_apply_lighting()` sets sun rotation (single X axis), energy (cap 1.1), colour, sky, fog colour, ambient; values are cached and only written on change.
- **Grass shaders (`grass_blade`/`grass_cluster.gdshader`) and ChunkRenderer props/landmarks, WorldItem are `unshaded`** — they ignore lights and shadows. DayNightCycle writes an approximate brightness global for grass instead (see BID-060).
- Weather: `autoloads/WeatherManager.gd` (per-biome tables, ids: rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard), emits `GameBus.weather_changed(id, duration)`; `WorldScene._on_weather_changed` (~2052) swaps `WeatherParticles.make(id)` and lerps `_weather_tint` into `_dnc.tick(delta, _weather_tint)`. `WeatherParticles.get_wind_direction()/get_screen_tint()` hold per-weather tables.
- Settings: `SceneManager.save_manager.get_setting(key, default)` / `set_setting`; UI in `scenes/ui/SettingsScene.gd` with `_add_slider_row/_add_toggle_row/_add_option_row`.
- Rules: preload never class_name; explicit types for Variant; `.uid` sidecar for any new `.gdshader`/`.tres`; run headless import + `scripts/unsafe-hits.sh` + gdlint + tests after edits. Every new visual must degrade gracefully on Mobile.

## Plan

1. New pure-ish module `game_logic/GraphicsQuality.gd` (no class_name, all static):
   - `LOW/MEDIUM/HIGH`, `SETTING_KEY = "graphics_quality"`, `LABELS`.
   - `TIERS` table, one Dictionary per tier with every knob later GID-129 tasks read:
     `sun_shadows`, `shadow_mode`, `shadow_atlas_size`, `soft_shadow_quality`, `shadow_max_distance`,
     `ssao`, `volumetric_fog`, `glow`, `msaa_3d`, `particle_scale`, `ambient_particles`,
     `sun_rays` (off / screen-space / volumetric), `max_night_lights`, `night_light_shadows`.
   - `FORWARD_PLUS_ONLY` flag list; `clamp_to_renderer(knobs, method)` turns them off (and
     downgrades volumetric sun rays to screen-space) unless the method is `forward_plus`.
   - `default_tier(is_mobile)` (Medium on mobile, High elsewhere), `tier_from_setting(v, is_mobile)`
     (clamps junk), `knobs_for(tier, method)`, `current_knobs(save_manager)` convenience.
   - `apply(knobs, env, sun, viewport)` writes the env/sun/viewport/RenderingServer knobs; later
     tasks' knobs (sun rays, night lights, ambient particles) are only read, not applied.
   - `scaled_amount(amount, knobs)` for particle systems.
2. Medium keeps today's mobile look (sun shadows off, MSAA 4x as project.godot), High keeps
   today's desktop look plus SSAO (Forward+ only). Volumetric fog stays off on every tier until
   TID-488 tunes it (the knob and the Forward+ clamp exist now).
3. WorldScene: replace the ad-hoc `OS.has_feature("mobile")` shadow switch in `_ready` with
   `_apply_graphics_quality()` (stores `graphics_knobs` for later tasks); scale weather particle
   `amount` by `particle_scale`; connect new `GameBus.graphics_quality_changed(tier)`.
4. SettingsScene: "Graphics Quality" option row (Low/Medium/High) under a Graphics header; writes
   the setting and emits `GameBus.graphics_quality_changed`.
5. Unit test `tests/unit/test_graphics_quality.gd`: table has 3 tiers with identical key sets,
   monotonic costs, defaults, setting clamp, Forward+-only flags off for mobile/compatibility, apply
   writes env/sun.
6. Docs: visual-polish.md section; task/goal/index status.

## Changes Made

- `game_logic/GraphicsQuality.gd` (new): tier constants, `TIERS` knob table (shadows, SSAO, volumetric fog, glow, MSAA, particle scale, ambient particles, sun-ray mode, night-light cap/shadows), `FORWARD_PLUS_ONLY` + `clamp_to_renderer`, `default_tier`/`tier_from_setting`/`knobs_for`/`current_knobs`, `scaled_amount`, `apply(knobs, env, sun, viewport)`.
- `autoloads/GameBus.gd`: `graphics_quality_changed(tier: int)` signal (emitted by SettingsScene).
- `scenes/world/WorldScene.gd`: `apply_graphics_quality()` replaces the `OS.has_feature("mobile")` sun-shadow switch in `_ready`, reconnected live via GameBus; `graphics_knobs()` accessor for later tasks; weather particle `amount` scaled by `particle_scale`.
- `scenes/ui/SettingsScene.gd`: new "Graphics" section with a Low/Medium/High option row (default from platform).
- `tests/unit/test_graphics_quality.gd` (new): table shape, monotonic costs, defaults, setting clamp, Forward+-only flags off on mobile/compatibility, `knobs_for` copies, `scaled_amount`, `apply`.
- Behaviour: Medium reproduces the old mobile look, High the old desktop look plus SSAO (Forward+ only). Low drops glow, MSAA and halves particles. Volumetric fog stays off on every tier until TID-488 tunes it.
- Validation: headless import clean, `unsafe-hits.sh` clean, gdlint clean, test suite PASS with no `SCRIPT ERROR`, `world_scene_smoke` / `menu_hub_smoke` clean.

## Documentation Updates

- `docs/agent/visual-polish.md`: Key Features bullet, new "Graphics Quality Tiers" How-It-Works section with the full knob table and which task reads each knob, Integrations bullet.
- `docs/agent/signals-and-constants.md`: `graphics_quality_changed` row.
