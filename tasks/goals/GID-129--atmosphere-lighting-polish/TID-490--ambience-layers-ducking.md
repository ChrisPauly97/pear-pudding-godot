# TID-490: Weather & Time-of-Day Ambience Layers, Music Ducking

**Goal:** GID-129
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

One looping biome ambience per biome, no weather or night sound; music doesn't make room for battles or dialogue. Part of GID-129 (polish existing systems, no new features).

## Research Notes

- `autoloads/AudioManager.gd`: `set_ambience(biome_id)` crossfades two players (`AMBIENCE_CROSSFADE 2.0`). Add a weather layer (rain, heavy_rain, wind, sandstorm, crackle) and a day/night layer (birds by day, crickets/owls at night), each with its own crossfade and volume following the SFX bus/setting.
- Missing files fall back to `game_logic/SfxGen.gd` (`get_ambience`, `_noise`, `_lowpass`, `_make_seamless`) — add synth fallbacks for the new loops; add paths to a table, like `AMBIENCE_PATHS`.
- Drive the weather layer from `GameBus.weather_changed`; drive the time layer from DayNightCycle's day factor (hysteresis so it doesn't flap).
- Ducking: tween the music bus down during dialogue (`_on_dialogue_state_changed` exists) and narration; no layer change in battle other than music.
- Named maps: `set_ambience(-1)` today; indoors/dungeon should mute the weather layer.
- Test: layer selection is a pure function (weather id → key) and has a unit test.

Shared facts (GID-129 research, 2026-09-24):
- `project.godot` sets no `rendering/renderer/rendering_method`, so desktop runs **Forward+** and Android (only export preset) runs **Mobile**. Mobile lacks volumetric fog, SSAO, SSIL, SSR, SDFGI. Detect at runtime with `RenderingServer.get_current_rendering_method()` (`"forward_plus"` / `"mobile"` / `"gl_compatibility"`).
- Environment is built in code: `WorldScene._setup_environment()` (~line 354): ProceduralSky, depth fog (`fog_density 0.004`), FILMIC tonemap, glow (threshold 1.2, `glow_bloom` must stay 0 — see comment), `_world_env` field. Fill light added right after.
- Sun/moon: `WorldScene.tscn` `DirectionalLight3D` (shadows on, `directional_shadow_mode = 0` orthogonal, max distance 60) + `MoonLight` (no shadows). `scenes/world/DayNightCycle.gd` `_apply_lighting()` sets sun rotation (single X axis), energy (cap 1.1), colour, sky, fog colour, ambient; values are cached and only written on change.
- **Grass shaders (`grass_blade`/`grass_cluster.gdshader`) and ChunkRenderer props/landmarks, WorldItem are `unshaded`** — they ignore lights and shadows. DayNightCycle writes an approximate brightness global for grass instead (see BID-060).
- Weather: `autoloads/WeatherManager.gd` (per-biome tables, ids: rain, heavy_rain, sandstorm, dust_devil, ash_fall, volcanic, snow, blizzard), emits `GameBus.weather_changed(id, duration)`; `WorldScene._on_weather_changed` (~2052) swaps `WeatherParticles.make(id)` and lerps `_weather_tint` into `_dnc.tick(delta, _weather_tint)`. `WeatherParticles.get_wind_direction()/get_screen_tint()` hold per-weather tables.
- Settings: `SceneManager.save_manager.get_setting(key, default)` / `set_setting`; UI in `scenes/ui/SettingsScene.gd` with `_add_slider_row/_add_toggle_row/_add_option_row`.
- Rules: preload never class_name; explicit types for Variant; `.uid` sidecar for any new `.gdshader`/`.tres`; run headless import + `scripts/unsafe-hits.sh` + gdlint + tests after edits. Every new visual must degrade gracefully on Mobile.

## Plan

1. New pure module `game_logic/AmbienceLayers.gd`: `weather_layer(weather_id)` → loop key
   (`rain`, `heavy_rain`, `wind`, `sandstorm`, `crackle`, or `""`), `weather_gain(weather_id)`,
   `time_layer(biome_id, is_day, weather_key)` → `birds` / `crickets` / `owls` / `""` (birds hush
   under active weather), `next_is_day(time_of_day, was_day)` with a sun-height hysteresis band,
   `named_map_is_outdoors(map_name)` (dungeons, spire floors, interiors → false), and
   `LAYER_PATHS` (key → `res://assets/audio/ambience/<key>.ogg`).
2. New synth fallbacks `game_logic/AmbienceGen.gd` (`get_layer(key)`): seamless loops for each
   key, built from SfxGen primitives with an in-place overlay mixer (no per-transient realloc).
3. `AudioManager`: generalise the biome crossfade pair into three layers (biome / weather / time),
   each a crossfading player pair with its own key + gain; all follow the SFX volume and are
   retargeted by `set_sfx_volume`. Weather layer from `GameBus.weather_changed` (restored from
   `WeatherManager.current_weather` when biome ambience resumes); muted on named maps. Time layer
   from `set_time_of_day(t)` (hysteresis); kept in outdoor towns via `GameBus.entered_named_map`,
   muted indoors. Battle changes nothing but music.
4. Music ducking: a duck factor multiplied into the music player volume, tweened down while NPC
   dialogue is open (`dialogue_state_changed`) or narration is playing, back up afterwards.
5. WorldScene: one hook line after `_dnc.tick` → `AudioManager.set_time_of_day(...)`.
6. Tests: `tests/unit/test_ambience_layers.gd` (weather→key table, hysteresis, time layer, indoor
   check, synth loops valid).

## Changes Made

- `game_logic/AmbienceLayers.gd` (new): pure rules — weather id → layer key + gain, day/night
  hysteresis (`next_is_day`, ±0.08 sun height), wildlife per biome with birds hushed under weather,
  `named_map_is_outdoors`, `music_duck`, `LAYER_PATHS`.
- `game_logic/AmbienceGen.gd` (new): synthesized seamless loops for `rain`, `heavy_rain`, `wind`,
  `sandstorm`, `crackle`, `birds`, `crickets`, `owls` (in-place wrap-around overlay mixer).
- `autoloads/AudioManager.gd`: biome crossfade generalised into three `AmbLayer`s (biome, weather,
  time) with per-player volume tweens; layers follow and are retargeted by `set_sfx_volume`;
  weather from `GameBus.weather_changed` (resumed from `WeatherManager.current_weather` on biome
  entry, muted on named maps); time layer from new `set_time_of_day()`; indoor/outdoor from
  `GameBus.entered_named_map`; layer changes deferred while in `BATTLE`. Music ducking under dialogue
  and narration via a tweened duck multiplier; `get_music_volume()` now returns the user setting.
  New `get_ambience_keys()`, `get_music_duck()`.
- `scenes/world/WorldScene.gd`: one hook line after `_dnc.tick` → `AudioManager.set_time_of_day`.
- `tests/unit/test_ambience_layers.gd` (new): mapping, every WeatherManager id mapped, hysteresis,
  wildlife table, indoor maps, synth loops, duck levels.
- `assets/audio/ambience/README.md`: new layer files listed.

## Documentation Updates

- `docs/agent/audio-manager.md`: new "Layered Ambience" and "Music Ducking" sections, integration rows,
  asset rows for the eight new optional loops.
