# TID-589: Real Biome Ambience Beds + Weather/Time Loops

**Goal:** GID-141
**Type:** agent
**Status:** done
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

Convert the CC0 loops to mono Vorbis, derive the five biome beds from the wind loop with ffmpeg filters, and flag every import `loop=true`.

## Changes Made

- `assets/audio/ambience/`: 12 files (1.1 MB). rain `Rain OGG/2`, heavy_rain
  `3`+`4` mixed, wind the wind loop, sandstorm wind ×1.3 high-passed, crackle
  `fire-1`, birds isaiah658, crickets Wolfgang_'s loop. Biome beds from the wind
  loop: grasslands low-pass 900 Hz, forest ×0.85 low-pass 600 Hz, desert ×1.1
  band 300–3500 Hz, scorched ×0.7 low-pass 260 Hz, mountains high-pass 120 Hz.
  Each bed was rendered from three back-to-back copies with only the middle one
  kept, so the filter state is continuous across the loop point.
- Every `.ogg.import` sets `loop=true`; the per-frame restart in
  `AudioManager._process` stays as a safety net.
- Owls: no clean CC0 loop found, so the synth stays (BID-064).
- `test_sfx_assets.test_ambience_files_exist_and_loop`.

## Documentation Updates

`assets/audio/ambience/README.md` (shipped-files section); `CREDITS.md`.
