# TID-489: Night Point Lights with Flicker

**Goal:** GID-129
**Type:** agent
**Status:** done
**Depends On:** TID-484

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Towns and camps go dark at night; warm light pools should switch on at dusk. Part of GID-129 (polish existing systems, no new features).

## Research Notes

- Candidates: WildernessCamp, named-map buildings/doors, waystones, PlayerHome, PuzzleShrine already uses OmniLight3D (reference pattern).
- Lights only affect lit materials: the terrain shader is lit; grass, props, WorldItem and many sprites are **unshaded** (BID-060). Either make the affected billboards lit (`shading_mode` per-pixel with no shadows) or add a fake 'light pool' decal/additive quad on the ground. Decide during Plan; prefer the cheaper option on Mobile.
- Toggle on from DayNightCycle night factor; flicker via cheap noise in `_process` (a shared manager, not per-light scripts). Cap count by tier (Mobile per-mesh limit is 8 omni/spot lights).
- No shadows on these lights on Low/Medium.

Shared facts (GID-129 research, 2026-09-24):
- `project.godot` sets no `rendering/renderer/rendering_method`, so desktop runs **Forward+** and Android (only export preset) runs **Mobile**. Mobile lacks volumetric fog, SSAO, SSIL, SSR, SDFGI. Detect at runtime with `RenderingServer.get_current_rendering_method()` (`"forward_plus"` / `"mobile"` / `"gl_compatibility"`).
- Environment is built in code: `WorldScene._setup_environment()` (~line 354): ProceduralSky, depth fog (`fog_density 0.004`), FILMIC tonemap, glow (threshold 1.2, `glow_bloom` must stay 0 — see comment), `_world_env` field. Fill light added right after.
- Sun/moon: `WorldScene.tscn` `DirectionalLight3D` (shadows on, `directional_shadow_mode = 0` orthogonal, max distance 60) + `MoonLight` (no shadows). `scenes/world/DayNightCycle.gd` `_apply_lighting()` sets sun rotation (single X axis), energy (cap 1.1), colour, sky, fog colour, ambient; values are cached and only written on change.
- **Grass shaders (`grass_blade`/`grass_cluster.gdshader`) and ChunkRenderer props/landmarks, WorldItem are `unshaded`** — they ignore lights and shadows. DayNightCycle writes an approximate brightness global for grass instead (see BID-060).
- Weather: `autoloads/WeatherManager.gd` (per-biome tables, ids: rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard), emits `GameBus.weather_changed(id, duration)`; `WorldScene._on_weather_changed` (~2052) swaps `WeatherParticles.make(id)` and lerps `_weather_tint` into `_dnc.tick(delta, _weather_tint)`. `WeatherParticles.get_wind_direction()/get_screen_tint()` hold per-weather tables.
- Settings: `SceneManager.save_manager.get_setting(key, default)` / `set_setting`; UI in `scenes/ui/SettingsScene.gd` with `_add_slider_row/_add_toggle_row/_add_option_row`.
- Rules: preload never class_name; explicit types for Variant; `.uid` sidecar for any new `.gdshader`/`.tres`; run headless import + `scripts/unsafe-hits.sh` + gdlint + tests after edits. Every new visual must degrade gracefully on Mobile.

## Plan

Decision: **fake light volumes, not lit billboards and not flat quads.** Making grass, props and sprites lit
(BID-060) costs every fragment of the world on Mobile and still needs real OmniLight3Ds, which Mobile caps at 8
per mesh. A flat ground quad clips on hills and never touches the sprites standing in it. Instead each light is
a small ellipsoid mesh drawn after the opaque pass (unshaded, `blend_add`, `cull_front`, no depth test) whose
fragment shader reads the depth texture, rebuilds the world position of whatever opaque surface is behind the
pixel and adds warm light by its distance to the light centre. So one additive pass lights terrain, unshaded
grass, props and billboards alike, on every renderer, with no per-mesh light limit. Cost: one depth copy plus
the volume's small screen footprint, and only at night.

1. `game_logic/NightLightMath.gd` (pure, static): `STYLES` (lantern / campfire / waystone / mana_well: colour,
   radius, energy, flicker amount and speed), `night_factor(sun_h)` (ramps in from dusk while the sun is still
   just above the horizon), `flicker(t, phase, amount, speed)` (three incommensurate sines, cheap noise),
   `phase_for(pos)`, `nearest(sources, origin, count, max_dist)`.
2. `assets/shaders/night_light_pool.gdshader` + `.uid`: the depth-reconstructing additive volume
   (`CURRENT_RENDERER` branch for Compatibility NDC).
3. `scenes/world/modules/NightLights.gd` (`night_lights`, created by `_ensure_world_modules`): shared manager.
   Every 0.5 s gathers sources from WorldScene's live dicts (doors = lanterns, waystones, mana wells, the
   wilderness camp fire) via `_valid_node3d`, keeps the nearest 8 within 30 units. Each rig: a billboarded
   additive glow dot at the source (all tiers, so Low still shows glowing lamps) plus the pool volume for the
   first `max_night_lights` (0 Low / 4 Medium / 8 High), plus a shadowed OmniLight3D only when
   `night_light_shadows` is on (off on every tier today). `_process` writes the flicker per rig each frame. Rigs
   are pooled, parented via `_world.add_child`, hidden in daytime (no gather work then). Knobs are re-read from
   `_world.graphics_knobs()` each gather, so `graphics_quality_changed` applies within 0.5 s.
4. WorldScene: preload const, typed field, one `_ensure_world_module` line (+3 lines).
5. `tests/unit/test_night_lights.gd`: night factor (day 0, night 1, dusk ramp), flicker bounds, nearest cap/range/
   order, styles shape, phase stability, tier caps (the module itself is exercised by `world_scene_smoke`).
6. Docs: visual-polish.md section; CLAUDE.md module row; BID-060 partly resolved (lights reach unshaded
   geometry) — note it, keep the shadow half open.

## Changes Made

- `game_logic/NightLightMath.gd` (new, pure/static): `STYLES` (lantern / campfire / waystone / mana_well), `night_factor(sun_h)` (fades in from sun height 0.15 to −0.05), `flicker` (three-sine noise in `[1 − amount, 1]`), `phase_for`, `nearest`.
- `assets/shaders/night_light_pool.gdshader` + `.uid` (new): additive, front-culled, no-depth-test ellipsoid that rebuilds world positions from the depth texture (Compatibility NDC branch) and adds light by distance, so it lights unshaded grass, props and sprites. Verified rendering under xvfb (Compatibility): warm pool at the light, untouched ground outside it.
- `scenes/world/modules/NightLights.gd` (new world module `night_lights`): shared manager. It gathers doors (lanterns), waystones, mana wells and the wilderness camp fire every 0.5 s and keeps the nearest 8 within 30 units in pooled rigs. Each rig has a glow dot (every tier), a light pool (first `max_night_lights`: 0 / 4 / 8) and a shadowed OmniLight3D only when `night_light_shadows` is on (off on every tier). Flicker is written per frame, and everything is hidden and idle in daylight. Knobs are re-read each gather, so a tier change applies live.
- `scenes/world/WorldScene.gd` (+3 lines, 2176 < 2180): preload, typed `night_lights` field, one `_ensure_world_module` line.
- `tests/unit/test_night_lights.gd` (new, 7 tests).
- BID-060 partly resolved: point lights now reach unshaded geometry, but sun shadows remain open (progress noted in the backlog file and the index row).
- Validation: headless import clean, `unsafe-hits.sh` clean, gdlint clean, suite 2474 passed / 0 failed with 0 `SCRIPT ERROR` (exit-time leak warnings same as baseline), `world_scene_smoke` exit 0 with 0 `SCRIPT ERROR`.

## Documentation Updates

- `docs/agent/visual-polish.md`: Key Features bullet, knob table readers for `max_night_lights` / `night_light_shadows`, new "Night Lights" How-It-Works section (why a fake light, shader, rules, manager, cost, tests), Integrations bullet, Asset Requirements note.
- `CLAUDE.md`: `NightLights.gd` row in the WorldScene module table.
- `tasks/backlog/BID-060`: Progress section (lights done, shadows open).
