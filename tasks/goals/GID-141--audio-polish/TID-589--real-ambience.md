# TID-589: Real Biome Ambience Beds + Weather/Time Loops

**Goal:** GID-141
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Biome beds and weather/time layers are synthesized noise loops
(`AmbienceGen`). Real recorded loops make the world feel alive.

## Research Notes

- Slots, documented in `assets/audio/ambience/README.md`:
  - `AudioManager.AMBIENCE_PATHS`: `grasslands/forest/desert/scorched/mountains.ogg`
  - `game_logic/AmbienceLayers.gd` `LAYER_PATHS`: `rain, heavy_rain, wind,
    sandstorm, crackle, birds, crickets, owls`
- Candidates (all CC0 on opengameart.org, `/content/<slug>`):
  - rain / heavy_rain: `rain-loopable` (zip "Rain OGG") and `30-cc0-sfx-loops` (`rain.ogg`)
  - wind / sandstorm: `wind-whoosh-loop`. For sandstorm, use the same loop pitched and gained differently, or a noise loop from `30-cc0-sfx-loops`
  - crackle: `fire-crackling` / `fireplace-sound-loop`
  - birds: `ambient-bird-sounds` (`birds-isaiah658_0.ogg`)
  - crickets: `crickets-ambient-noise-loopable` (mp3, which Godot 4 imports directly)
  - owls: search OGA for "owl" CC0. If there's nothing clean, keep the synth fallback and log it
  - biome beds: soft wind for mountains/desert, a birds+breeze mix for grasslands/forest,
    and a low rumble + crackle for scorched (`30-cc0-sfx-loops` `ambient_0*`, `noise_0*`)
- **Looping**: imported ogg/mp3 don't loop by default. Set `loop=true` in each
  file's `.import` (`[params] loop=true`), or set `stream.loop = true` after load in
  `AudioManager` / `AmbienceLayers._layer_stream`. Check the note near
  `AudioManager.gd:280` about "not be flagged to loop" first.
- Trim or crossfade seams by ear. No ffmpeg, so pick loops already marked seamless.
- Budget: ≤ ~4 MB total. Prefer short loops (10–30 s). Keep credits in `CREDITS.md`.
- Existing gains: `BIOME_LAYER_GAIN 0.4`, `WEATHER_LAYER_GAIN 0.5`,
  `TIME_LAYER_GAIN 0.3`. Rebalance these if the real files are louder than the synth.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
