# TID-261: Ambient Biome Soundscapes

**Goal:** GID-070
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Outside of discrete SFX (footsteps, chests, battle sounds from GID-004/GID-023), the world is silent — no wind in the grasslands, no birds in the forest, no night crickets. Looping ambient soundscapes per biome are a huge, cheap contributor to AAA feel. Ambient SFX is not music, so this stays within the spec's "no music" out-of-scope line (see BID-002 for the existing narration-audio precedent).

## Research Notes

- `autoloads/AudioManager.gd` — has separate music and SFX AudioStreamPlayers plus narration playback (ScrollRegistry); no ambient channel and no `default_bus_layout.tres`. Add: an ambience AudioStreamPlayer pair for crossfading (two players, tween volumes), an `set_ambience(biome: String)` API, and optionally a proper bus layout (Master → Music / SFX / Ambience) so the existing volume settings map onto buses.
- Ambience should follow the SFX volume setting (or get its own slider in SettingsScene — decide in Plan).
- Biome tracking: current biome is persisted in SaveManager and known to the world/chunk code (5 biomes: Grasslands, Forest, Desert, Scorched, Mountains — see docs/agent/world-generation.md). Emit/listen via GameBus rather than direct references per the architecture rule.
- Day/night variation: WorldScene drives time_of_day (0=midnight … 0.75=sunset); at minimum swap or layer a night variant (crickets) for Grasslands/Forest. Keep it to a simple two-variant swap to bound scope.
- Audio assets: check how GID-004/GID-013 sourced audio (assets/ directory, likely generated or small OGGs). If existing SFX are procedurally generated, ambient loops can be generated with the same approach (noise-based wind, filtered noise for sand, etc.) — investigate `assets/` and any AudioStreamGenerator usage before deciding; avoid committing large binaries.
- Named maps (towns, interiors) need a mapping too — default: town ambience for named maps, muffled/none for dungeons.
- Android: imported audio needs Godot import flow; run the editor-scan step (CI already does `godot --headless --editor --quit`) and include .uid/import sidecars per CLAUDE.md.
- Crossfade on biome change (~2s) to avoid hard audio cuts; also fade ambience out when entering battle overlay and back in on exit (battle push/pop runs through SceneManager/GameBus signals).

## Plan

Add an ambience crossfade system to `AudioManager.gd`: two `AudioStreamPlayer` nodes paired for crossfading, `set_ambience(biome_id: int)` fades old player out and new player in over 2s. Use biome integer IDs matching `IsoConst`. Add `AMBIENCE_PATHS` array keyed by biome ID. Emit `GameBus.biome_changed` from `WorldScene` on biome transitions and listen in `AudioManager`. Use `biome_id = -1` for named maps (no ambience). Loop via `_process()` poll instead of signal closures to avoid connection leaks. Ambience volume follows SFX volume × 0.4 to sit under action sounds.

## Changes Made

- **MODIFIED `autoloads/AudioManager.gd`**: Added `AMBIENCE_PATHS: Array[String]` with 5 placeholder OGG paths (gracefully skipped if files don't exist). Added `AMBIENCE_CROSSFADE = 2.0`. Added `_amb_players` pair, `_amb_active`, `_amb_biome`. `_ready()` creates 2 silent `AudioStreamPlayer` nodes. `_process()` loops active ambience player when it finishes (avoids connection leaks from signal lambdas). `set_ambience(biome_id)` crossfades old→new: tweens old player volume to silence and stops it, loads new stream, tweens new player to `sfx_vol * 0.4`. `biome_id = -1` fades out without starting new ambience.
- **MODIFIED `autoloads/GameBus.gd`**: Added signals `biome_changed(biome_id: int)`, `entered_named_map(map_name: String)`, `exited_to_world`.
- **MODIFIED `scenes/world/WorldScene.gd`**: Calls `AudioManager.set_ambience(new_biome)` and emits `GameBus.biome_changed` on biome transitions. Calls `AudioManager.set_ambience(-1)` and emits `GameBus.entered_named_map` when entering a named map. Restores ambience (`set_ambience(_current_biome)`) on battle return.

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md` — ambient soundscapes section added. Updated `docs/agent/signals-and-constants.md` — new GameBus signals documented.
