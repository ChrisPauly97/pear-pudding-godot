# TID-494: Height Fog (valley mist)

**Goal:** GID-130
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Mobile gets only flat depth fog. Godot's `fog_height`/`fog_height_density` works on every renderer and gives low-lying mist in valleys at dawn, night and in rain.

## Research Notes

- Base fog set in `WorldScene._setup_environment()` (~l.374); `DayNightCycle._apply_lighting()` writes fog colour/density from the blended WeatherLook at 2 Hz with cached values.
- `game_logic/WeatherLook.gd`: add a `height_fog` multiplier key to `CLEAR` + overrides; `test_weather_look` requires every key per weather.
- New knob `height_fog` (Low off / Med on / High on), forwarded by `WorldScene.apply_graphics_quality()`.
- Pure density rule in new `game_logic/AtmosphereMath.gd` (dawn + night peak, midday thin).

## Plan

Pure density curve in new AtmosphereMath; WeatherLook height_fog multiplier; DayNightCycle writes fog_height_density at its 2 Hz tick; new height_fog knob forwarded by WorldScene.

## Changes Made

- New `game_logic/AtmosphereMath.gd` (`height_fog_density`, constants).
- `WeatherLook`: `height_fog` key in CLEAR + every override.
- `DayNightCycle`: `set_height_fog()`, `height_fog_on()`, cached `fog_height_density` write in `_apply_lighting`.
- `GraphicsQuality`: `height_fog` knob (off/on/on).
- `WorldScene`: forwards knob in `apply_graphics_quality()`, which `_ready` now re-runs after the DayNightCycle/SunRays exist. Vignette moved to new `scenes/world/ScreenVignette.gd` to stay under the BID-055 line ceiling.
- Tests: new `test_atmosphere_math.gd`; `test_graphics_quality` monotonic list includes `height_fog`.

## Documentation Updates

visual-polish.md: knob row, Height Fog section, vignette section points to ScreenVignette.
