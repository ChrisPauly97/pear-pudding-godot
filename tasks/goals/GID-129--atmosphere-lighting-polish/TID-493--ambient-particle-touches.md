# TID-493: Small Ambient Touches (Dust, Fireflies, Leaves)

**Goal:** GID-129
**Type:** agent
**Status:** done
**Depends On:** TID-484

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Tiny motion details that make the world feel alive, scaled by quality tier. Part of GID-129 (polish existing systems, no new features).

## Research Notes

- Dust puff on landing/sprint start and under mount (mount dust exists, see `docs/agent/rideable-mounts.md` — reuse its particle setup).
- Fireflies: night-only, grassland/forest, GPUParticles3D around the player with emissive unshaded quads (bloom threshold 1.2 → emission energy >1.2).
- Blowing leaves in forest, with direction from the weather wind table (TID-486 if landed, else `WeatherParticles.get_wind_direction`).
- Pattern: `WeatherParticles.make()` returns a configured `GPUParticles3D`; follow that shape. Share materials/meshes statically (CLAUDE.md chest hitch note).
- Scale `amount` by the tier's particle multiplier; off on Low.

Shared facts (GID-129 research, 2026-09-24):
- `project.godot` sets no `rendering/renderer/rendering_method`, so desktop runs **Forward+** and Android (only export preset) runs **Mobile**. Mobile lacks volumetric fog, SSAO, SSIL, SSR, SDFGI. Detect at runtime with `RenderingServer.get_current_rendering_method()` (`"forward_plus"` / `"mobile"` / `"gl_compatibility"`).
- Environment is built in code: `WorldScene._setup_environment()` (~line 354): ProceduralSky, depth fog (`fog_density 0.004`), FILMIC tonemap, glow (threshold 1.2, `glow_bloom` must stay 0 — see comment), `_world_env` field. Fill light added right after.
- Sun/moon: `WorldScene.tscn` `DirectionalLight3D` (shadows on, `directional_shadow_mode = 0` orthogonal, max distance 60) + `MoonLight` (no shadows). `scenes/world/DayNightCycle.gd` `_apply_lighting()` sets sun rotation (single X axis), energy (cap 1.1), colour, sky, fog colour, ambient; values are cached and only written on change.
- **Grass shaders (`grass_blade`/`grass_cluster.gdshader`) and ChunkRenderer props/landmarks, WorldItem are `unshaded`** — they ignore lights and shadows. DayNightCycle writes an approximate brightness global for grass instead (see BID-060).
- Weather: `autoloads/WeatherManager.gd` (per-biome tables, ids: rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard), emits `GameBus.weather_changed(id, duration)`; `WorldScene._on_weather_changed` (~2052) swaps `WeatherParticles.make(id)` and lerps `_weather_tint` into `_dnc.tick(delta, _weather_tint)`. `WeatherParticles.get_wind_direction()/get_screen_tint()` hold per-weather tables.
- Settings: `SceneManager.save_manager.get_setting(key, default)` / `set_setting`; UI in `scenes/ui/SettingsScene.gd` with `_add_slider_row/_add_toggle_row/_add_option_row`.
- Rules: preload never class_name; explicit types for Variant; `.uid` sidecar for any new `.gdshader`/`.tres`; run headless import + `scripts/unsafe-hits.sh` + gdlint + tests after edits. Every new visual must degrade gracefully on Mobile.

## Plan

Finding during research: the existing foot/mount/landing dust in `Player.gd` has **no draw pass mesh**, so it has
never rendered; `WeatherParticles.make()` builds a `StandardMaterial3D` but never assigns it, so weather quads draw
with the default material (untinted, not billboarded). Both are fixed here rather than copied.

1. `game_logic/AmbientParticles.gd` (pure/static, `WeatherParticles.make()` shape): shared static draw meshes
   (dust puff, firefly glow, leaf) with their materials; factories `make_fireflies()`, `make_leaves()`,
   `make_dust_puff(amount)`; level math `firefly_level(night, biome, weather)` (grassland/forest, night only,
   none in precipitation), `leaf_level(biome, weather, wind_scale)` (forest only, more in wind),
   `apply_wind(pm, wind_dir, wind_scale)` (leaf drift from the `WeatherLook` wind table). Fireflies are additive
   unshaded billboards with an HDR albedo (>1.2 so glow blooms them) and a blink colour ramp.
2. `scenes/world/modules/AmbientTouches.gd` (`ambient`, created by `_ensure_world_modules`): owns one firefly and
   one leaf emitter parented via `_world._entity_root`. Every 0.5 s re-reads knobs (`ambient_particles`,
   `particle_scale`), biome, night factor (`NightLightMath.night_factor`) and `_dnc.weather_look()` wind; sets
   `amount` (scaled; only when it changes, since that restarts the system) and fades with `amount_ratio`.
   `_process` keeps emitters on the player. Off entirely on Low / named maps without a biome. Also pushes the
   knobs into the player's dust (`Player.apply_particle_knobs`).
3. `Player.gd`: give foot/mount/landing dust the shared draw pass; new one-shot move-start puff when the player
   starts moving on the ground; `apply_particle_knobs(knobs)` scales dust amounts and turns foot trail + start
   puff off when `ambient_particles` is false (landing and mount dust stay, scaled).
4. `WeatherParticles.gd`: assign the built material to the mesh (one line).
5. WorldScene: preload const, typed `ambient` field, one `_ensure_world_module` line (+3 lines; free lines if
   the 2180 ceiling bites).
6. `tests/unit/test_ambient_particles.gd`: level math (biome/night/weather gates), wind mapping, factories have a
   draw pass + material, shared meshes are reused, knob scaling.
7. Docs: visual-polish.md section, rideable-mounts.md dust note, CLAUDE.md module row.

## Changes Made

- `game_logic/AmbientParticles.gd` (new, static): shared dust / firefly / leaf draw meshes + materials and ramp textures; `make_fireflies()`, `make_leaves()`, `make_dust_puff()`, `dust_mesh()`, `style_dust()`, `apply_wind()`, `firefly_level()`, `leaf_level()`.
- `scenes/world/modules/AmbientTouches.gd` (new world module `ambient`): lazily-created firefly and leaf emitters following the player; 0.5 s refresh of knobs, biome, night factor and WeatherLook wind; `amount_ratio` fades, `amount` only rewritten on tier change; pushes knobs to the player.
- `scenes/world/entities/Player.gd`: foot/mount/landing dust gets the shared draw pass (it had none and never rendered), fade/swell styling, bigger scales and a 0.2 lift; new move-start puff; `apply_particle_knobs()` scales amounts and gates the foot trail + start puff on `ambient_particles`.
- `scenes/world/WeatherParticles.gd`: assigns the tinted billboard material it already built but never used (weather quads drew with the default material).
- `scenes/world/WorldScene.gd` (+3 lines, 2179 < 2180): preload, typed `ambient` field, one `_ensure_world_module` line.
- `tests/unit/test_ambient_particles.gd` (new, 7 tests).
- Validation: headless import clean, `unsafe-hits.sh` clean, gdlint clean, suite 2481 passed / 0 failed with 0 `SCRIPT ERROR`, `world_scene_smoke` exit 0 with 0 `SCRIPT ERROR` (exit-time leak warnings same as baseline).

## Documentation Updates

- `docs/agent/visual-polish.md`: Key Features bullet, knob table readers, new "Ambient Touches" How-It-Works section, Integrations bullet, Asset Requirements note.
- `docs/agent/rideable-mounts.md`: dust particles entry (draw pass, scaling, Low gating).
- `CLAUDE.md`: `AmbientTouches.gd` row in the WorldScene module table.
