# TID-162: Visual Effects: GPUParticles3D Precipitation, Screen Tint, Grass Wind Hookup

**Goal:** GID-042  
**Type:** agent  
**Status:** done  
**Depends On:** TID-161

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

Makes weather systems visible and immersive. Precipitation particles follow the camera/player; screen tint layers with day/night; grass `wind_direction` uniform reacts to wind intensity. All effects only run in infinite world (check `SaveManager.current_map == "main"`).

## Research Notes

- **Particle infrastructure:** One `GPUParticles3D` rig per weather type, preloaded in memory and parented to the camera/player. Particle parameters: lifetime ~2–4s, emission rate ~100–300 particles/sec (higher for heavy rain/blizzard, lower for dust), falling/drifting trajectory with slight wind sway. **No geometry shaders** (Godot 4 limitation per **CLAUDE.md**); instead use a simple billboard quad per particle (standard `StandardMaterial3D` or custom `mesh.gdshader`). Particles are re-parented to the player node in **WorldScene.gd** during `_ready()` or on weather change.
- **Particle scene structure** (one per weather type, stored in `assets/particles/`):
  - `assets/particles/rain.tscn` — GPUParticles3D with `material = RainMaterial` (preload); particle mesh = unit billboard quad; velocity: downward Z with X sway (wind sway); lifetime 3s; emission 200/sec.
  - `assets/particles/rain_heavy.tscn` — like rain but emission 350/sec, shorter lifetime 2s, heavier Z velocity.
  - `assets/particles/sandstorm.tscn` — horizontal particles drifting in +X direction (simulated wind); lifetime 4s; emission 150/sec; color tint sandy yellow.
  - `assets/particles/ash_fall.tscn` — slow-falling grey/black particles; lifetime 5s; emission 80/sec.
  - `assets/particles/snow.tscn` — slow-falling white particles with wider lateral drift; lifetime 4s; emission 120/sec.
  - `assets/particles/blizzard.tscn` — fast horizontal wind + falling snow; emission 250/sec; lifetime 3s.
- **Dust devil, volcanic (if needed):** Less critical for v1; skip if time constrained.
- **Shader: `.uid` files required.** Every `.gdshader` and `.tres` created in TID-162 needs a companion `.uid` file per **CLAUDE.md Godot Resource .uid Files** section. Generate random 12-char strings for each; commit `.uid` sidecars to git.
- **Screen tint integration:** WorldScene already manages day/night tint via `_world_env` (WorldEnvironment node) and shader uniforms (see **scenes/world/WorldScene.gd** lines 77–88 and the day/night tint caching logic). Weather tint is a **second layer**: multiply the day/night ambient color by a weather-specific color overlay. Approach:
  - Store `_weather_tint: Color` in WorldScene (updated on `weather_changed` signal).
  - Modify the day/night update logic to apply: `final_ambient = base_ambient * day_night_factor * weather_tint`.
  - Per-weather tint colors: rain = `Color(0.85, 0.85, 0.95)` (cool blue-grey); heavy_rain = `Color(0.70, 0.70, 0.85)` (darker); sandstorm = `Color(0.95, 0.85, 0.70)` (warm sandy); ash_fall = `Color(0.70, 0.65, 0.65)` (muted grey); snow = `Color(0.95, 0.95, 1.0)` (icy white); blizzard = `Color(0.80, 0.80, 0.95)` (grey-blue); clear = `Color(1.0, 1.0, 1.0)` (no tint).
  - Transition tints smoothly with a 0.5s tween when weather changes (lerp ambient color toward new target).
- **Grass wind integration:** **GrassBlades.gd** (lines 64–69 and 82–88) already uses `RenderingServer.global_shader_parameter_set()` for global parameters. Add `wind_direction: Vector2` as a global shader parameter (similar to existing `player_pos`, `player_move_dir`). Called from WorldScene on `weather_changed`:
  - Rain: `wind_direction = Vector2(0.2, 0.5).normalized()` (gentle horizontal drift + downwind bias).
  - Heavy rain: `wind_direction = Vector2(0.4, 0.7).normalized()` (stronger).
  - Sandstorm: `wind_direction = Vector2(1.0, 0.2).normalized()` (very strong lateral; sand drifts far).
  - Ash/snow: mild winds `Vector2(0.1, 0.3).normalized()`.
  - Clear: `Vector2.ZERO`.
  - **Transition:** Tween `wind_direction` over 0.5s to avoid jarring snaps (or lerp in `_process`).
- **Particle scene preloads in WorldScene:** At the top of **scenes/world/WorldScene.gd**, add:
  ```gdscript
  const _RainParticles       = preload("res://assets/particles/rain.tscn")
  const _RainHeavyParticles  = preload("res://assets/particles/rain_heavy.tscn")
  const _SandstormParticles  = preload("res://assets/particles/sandstorm.tscn")
  const _AshFallParticles    = preload("res://assets/particles/ash_fall.tscn")
  const _SnowParticles       = preload("res://assets/particles/snow.tscn")
  const _BlizzardParticles   = preload("res://assets/particles/blizzard.tscn")
  ```
  Store in `_active_weather_particles: Node3D = null`. On `weather_changed`: call `_update_weather_visuals(weather_id)` which queues the old particles for deletion and instantiates the new one, parenting to `_player.position` (offset slightly higher for visibility).
- **Lifecycle:** On map unload (WorldScene exit), free all weather particle instances. On named-map load, ensure particles are freed (already covered by context check in TID-161). On battle start, pause particles (if needed for focus); resume on return to world.
- **Headless tests** (`tests/unit/test_weather_visuals.gd`):
  - Mock WorldScene, verify particle instantiation and parenting on weather change.
  - Verify wind_direction global shader param updates match weather type.
  - Verify screen tint color updates and tweens.
  - Verify particles freed on scene unload.

## Plan

1. Create `scenes/world/WeatherParticles.gd` — static factory that constructs GPUParticles3D nodes programmatically for each weather type (no .tscn files needed)
2. Add `set_wind_direction(dir: Vector2)` to `GrassBlades.gd` — sets `wind_direction` on the shared shader material
3. Update `WorldScene.gd`:
   - Add `_weather_tint: Color`, `_weather_tint_target: Color`, and `_active_weather_particles: Node3D` fields
   - Connect to `GameBus.weather_changed` in `_ready()`
   - Implement `_on_weather_changed(weather_id, duration)` to swap particles and set tint target
   - Multiply weather tint into ambient color in `_update_day_night()`
   - Update GrassBlades wind_direction on weather change
   - Free particles on `_exit_tree()`
   - Call `WeatherManager.on_world_entered()` and `WeatherManager.set_biome()` from infinite world path
4. Create `tests/unit/test_weather_visuals.gd`
5. Add to `tests/runner.gd`

## Changes Made

- `scenes/world/WeatherParticles.gd` (new): Static factory with `make(weather_id)` returning a configured `GPUParticles3D`; `get_wind_direction(weather_id)` returning per-weather `Vector2`; `get_screen_tint(weather_id)` returning per-weather `Color`. Supports rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard.
- `scenes/world/GrassBlades.gd`: Added `set_wind_direction(dir: Vector2)` that sets `wind_direction` shader parameter on both `_mat` and `_cluster_mat`
- `scenes/world/WorldScene.gd`: Added `_active_weather_particles`, `_weather_tint`, `_weather_tint_target`, `_weather_tint_lerp_t` fields; connected `GameBus.weather_changed` in infinite-world `_ready()`; called `WeatherManager.on_world_entered()` and `WeatherManager.set_biome()` on biome change; multiplied weather tint into ambient color in `_update_day_night()`; lerped tint toward target in `_process()`; freed particles on `_exit_tree()`; added `_on_weather_changed()` handler
- `tests/unit/test_weather_visuals.gd` (new): Tests for `WeatherParticles.make()`, `get_wind_direction()`, `get_screen_tint()`
- `tests/runner.gd`: Added `test_weather_visuals.gd` suite

## Documentation Updates

- No new agent docs file required; changes captured in task file and inline code.
