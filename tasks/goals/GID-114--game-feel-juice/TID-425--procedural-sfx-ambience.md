# TID-425: Procedural SFX Synthesis & Biome Ambience (Un-mute the Game)

**Goal:** GID-114
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The game is completely silent. `autoloads/AudioManager.gd` has full plumbing — an
8-player `AudioStreamPlayer` SFX pool, `SFX_PATHS` (12 registered keys), a music
loop player, and a 2-player ambience crossfade pair (`set_ambience(biome_id)`,
added by GID-070/TID-261) — and there are ~40 `play_sfx()` call sites across
battle and world code. But `assets/audio/sfx/` contains only a README, there is
no `assets/audio/ambience/` directory, and **zero** `.wav`/`.ogg`/`.mp3` files
exist anywhere in the repo. Every hook is a silent no-op via the
`ResourceLoader.exists()` guards.

This is the single highest-impact feel gap: sound is the cheapest, broadest
feedback channel and it is entirely absent. Music remains out of scope per
`docs/human/specification.md` ("Voice acting or music" out of scope; see
BID-002 for the narration-audio tension) — this task covers SFX and ambience
only, which GID-070 established as in-scope.

## Research Notes

**Approach: synthesize sounds at runtime, no external assets.** The project
already does exactly this for art: `game_logic/TextureGen.gd` procedurally
generates all pixel-art textures on the CPU. Mirror that with a
`game_logic/SfxGen.gd` that synthesizes short chiptune-style sounds into
`AudioStreamWAV` objects (16-bit PCM, 22050 Hz mono is plenty) at startup.
This sidesteps the Android `.uid`/import-sidecar problem entirely (no
resource files to package — see CLAUDE.md "Android: Always preload()"),
and keeps the repo binary-free.

**Synthesis recipes (each is a few lines of sample math):**
- `card_draw` — short upward pitch-swept sine "swish" (~0.12s)
- `card_play` — square-wave thunk + tiny noise transient (~0.15s)
- `spell_resolve` — shimmering dual-sine chord with vibrato (~0.35s)
- `attack` — noise burst with fast decay (impact) + low sine punch (~0.18s)
- `battle_win` — 3-note ascending arpeggio (~0.6s)
- `battle_lose` — 2-note descending minor fall (~0.6s)
- `enemy_engage` / `enemy_alert` — sharp two-tone alarm sting (~0.3s)
- `chest_open` — creak (pitch-swept saw) + coin sparkle (high sine pings) (~0.4s)
- `scroll_pickup` — soft harp-like pluck (~0.25s)
- `door_enter` — low whoosh (filtered noise swell) (~0.3s)
- `footstep` — very short low-passed noise tap (~0.06s), randomize pitch ±10% per play to avoid machine-gun effect
- `nightfall_ambient` — low pad swell (~1.5s)
- `ui_click` — **new key** — tiny high tick (~0.03s) (consumed by TID-429)
- `land` — **new key** — soft thud (consumed by TID-428)
- `dig_success`, `waystone_travel` — **new keys** (consumed by TID-427)

**AudioManager integration:**
- In `_ready()` (autoloads/AudioManager.gd:45), after the existing file-based
  cache loop, fill any `_sfx_cache` miss from `SfxGen` — file assets, if ever
  added, still win. Keep `SFX_PATHS` as the override mechanism.
- Register the missing `enemy_alert` key (currently played at
  WorldScene.gd:5035 but absent from `SFX_PATHS` — BID-045) plus the new keys
  above.
- Pitch variation: `AudioStreamPlayer.pitch_scale` randomization for footstep
  (set before `play()`, reset after pick from pool) — cheapest way to avoid
  repetition fatigue.

**Ambience:** generate per-biome looping beds as `AudioStreamWAV` with
`loop_mode = LOOP_FORWARD` (a few seconds of shaped noise each):
- Grasslands: gentle filtered pink-noise breeze + occasional high chirp
- Forest: darker noise + slow amplitude LFO (rustle)
- Desert: thin high-passed wind whistle
- Scorched: low rumble + crackle transients
- Mountains: hollow wind with slow beat-frequency drone
`set_ambience()` (AudioManager.gd:160) currently loads from `AMBIENCE_PATHS`;
add the same synth fallback. Loudness: keep the existing `sfx_vol * 0.4` bed
level.

**Constraints / gotchas:**
- GDScript is not Python (CLAUDE.md): `/` on ints is int division; annotate
  `max/min/clamp/lerp` results.
- `AudioStreamWAV.data` wants a `PackedByteArray` of little-endian 16-bit
  samples; build via `PackedByteArray.resize()` + `encode_s16()` or
  `PackedFloat32Array` → manual conversion. Keep generation under ~100ms total
  on Android: precompute in `_ready()` once, cache forever.
- SfxGen must be pure logic (no scene deps) → lives in `game_logic/`, unit
  testable headless (assert non-empty data, correct length, amplitude bounds).
- Existing volume settings flow through `set_sfx_volume()` on the pool —
  synthesized streams need no special handling.
- Run the headless editor import after edits (CLAUDE.md rule).

**Tests:** new `tests/unit/test_sfx_gen.gd` — every registered key returns a
non-null `AudioStreamWAV` with data length > 0 and correct format; ambience
streams have `loop_mode = LOOP_FORWARD`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
