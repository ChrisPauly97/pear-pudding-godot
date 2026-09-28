# TID-588: Sound Variation — Random Takes for Repeated SFX

**Goal:** GID-141
**Type:** agent
**Status:** done
**Depends On:** TID-587

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Footsteps, card draws and hits fire constantly. A single sample repeated every
step sounds robotic. The Kenney packs ship 4–5 takes per sound.

## Research Notes

- Use Godot's built-in `AudioStreamRandomizer` (`add_stream(idx, stream)`,
  `random_pitch`, `random_volume_offset_db`, `playback_mode = PLAYBACK_RANDOM_NO_REPEATS`).
  Build it in `AudioManager._ready()` from a list of paths per key, and cache it in
  `_sfx_cache[key]` like any other stream. `play_sfx`/`play_sfx_varied` need no change.
- Suggested shape: let a `SFX_PATHS` value be either a `String` or an
  `Array[String]`, or add a separate `SFX_VARIANTS` dict so the existing table
  stays simple. Check `tests/` for anything that asserts `SFX_PATHS` values are
  Strings (grep `SFX_PATHS`).
- `play_sfx_varied` already applies pitch jitter (`_jitter_rng`). Keep the
  randomizer's `random_pitch` at 1.0 so the jitter isn't applied twice.
- Candidate keys: all `footstep_*`, `card_draw`, `card_play`, `attack`,
  `ui_click`, `land`.
- Paths are static `const` strings, so Android packaging is unaffected (see
  CLAUDE.md Android preload rule. `.ogg` imports are exported like the music).

## Plan

Ship extra takes as `<key>_N.ogg`, declare counts in `SFX_TAKES`, and wrap them in an `AudioStreamRandomizer` at load time.

## Changes Made

- `AudioManager.SFX_TAKES` (15 keys) and `_load_sfx_takes(path, count)`:
  randomizer with `PLAYBACK_RANDOM_NO_REPEATS`, `random_pitch` 1.0 (the caller's
  jitter stays the only pitch variation). Falls back to the single stream if only
  the base file exists, and to null (synth) if even that is missing.
- 35 extra take files alongside the base files.
- `test_sfx_assets.test_sfx_takes_exist_and_load_as_randomizer`.

## Documentation Updates

`docs/agent/audio-manager.md` (Real files, takes and mix).
