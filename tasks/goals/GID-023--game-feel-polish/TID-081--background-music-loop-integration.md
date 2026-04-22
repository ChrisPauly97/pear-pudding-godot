# TID-081: Background Music Loop Integration

**Goal:** GID-023
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

AudioManager (GID-004) plays SFX but has no music support. Battles and biome exploration should have background music that loops seamlessly. All audio is graceful no-op if files are absent.

## Research Notes

- `autoloads/AudioManager.gd` — Has SFX pool (8 players) and narration player; no `play_music()` method exists yet
- `scenes/world/WorldScene.gd` — Tracks `_last_player_chunk: Vector2i`; `_update_chunks()` fires on chunk change (and direction change); `WORLD_SEED` available; `InfiniteWorldGen.biome_for_chunk(pcx, pcz, WORLD_SEED)` gives biome 0–4
- `game_logic/world/BiomeDef.gd` — GRASSLANDS=0, FOREST=1, DESERT=2, SCORCHED=3, MOUNTAINS=4
- `game_logic/world/InfiniteWorldGen.gd` — `static func biome_for_chunk(p_cx, p_cz, world_seed) -> int`
- `scenes/battle/BattleScene.gd` — `_ready()` is the entry point; battle music should start there
- `autoloads/GameBus.gd` — `battle_won(result: Dictionary)` signal used to resume world music after battle
- `autoloads/SceneManager.gd` — `_on_battle_won` restores WorldScene; `_on_battle_lost` frees WorldScene → no resume needed

## Plan

1. `AudioManager.gd`: add `_music_player` (dedicated looping AudioStreamPlayer, volume −6 dB), `_current_music_path`, `play_music(path)` with same-track guard and graceful no-op, loop via `finished` signal.
2. `WorldScene.gd`: add `_BIOME_MUSIC` const array, `_current_biome: int = -1`; detect biome change inside `_update_chunks()` and call `AudioManager.play_music()`; play dungeon music on `_ready()` for named maps; connect `GameBus.battle_won` to resume world music on battle end.
3. `BattleScene.gd`: call `AudioManager.play_music("res://assets/audio/music/battle.ogg")` at end of `_ready()`.

## Changes Made

- `autoloads/AudioManager.gd`:
  - Added `_music_player: AudioStreamPlayer` (volume_db ≈ −6 dB, loops via `finished` signal).
  - Added `_current_music_path: String = ""`.
  - Added `play_music(path: String)` — same-track guard, graceful no-op if file absent.
  - Added `stop_music()`.
- `scenes/world/WorldScene.gd`:
  - Added `_BIOME_MUSIC` const for biome index → ogg path.
  - Added `_current_biome: int = -1`.
  - In `_update_chunks()`: `InfiniteWorldGen.biome_for_chunk()` on new player chunk; calls `AudioManager.play_music()` when biome changes.
  - In `_ready()`: plays `dungeon.ogg` for named maps; connects `GameBus.battle_won` to resume biome/dungeon music.
- `scenes/battle/BattleScene.gd`:
  - Calls `AudioManager.play_music("res://assets/audio/music/battle.ogg")` at end of `_ready()`.

## Documentation Updates

- Updated `docs/agent/battle-system.md` acceptance criterion for AudioManager.play_music().
