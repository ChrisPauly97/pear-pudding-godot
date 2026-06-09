# TID-200: Nocturnal Spawn Layer

**Goal:** GID-055
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Spectral enemies spawn only when night falls in the infinite world, fade at dawn, and respect a per-chunk cap to prevent overwhelming the player. The spawn layer is decoupled from the standard chunk entity spawning and uses a transient tracking system (not persisted in `SaveManager.defeated_enemies`).

## Research Notes

- **Night window definition:** Reuse the existing day/night curve from **WorldScene.gd** lines 963–991. The sun angle is `sun_angle = (_time_of_day - 0.25) * TAU`, and `sun_h = sin(sun_angle)`. Night occurs when `sun_h < 0`, which happens when `time_of_day < 0.25` (after midnight) or `time_of_day > 0.75` (after sunset until midnight). A simple predicate: `is_night(time_of_day: float) -> bool: return sin((_time_of_day - 0.25) * TAU) < 0`.

- **Spawn driver location:** Add to **WorldScene.gd** a new `_nocturnal_manager: NocturnalManager` autoload-like object, initialized in `_ready()` and updated in `_process(delta)`. Alternatively, inline the spawning logic in `WorldScene._process()` since nocturnal spawning is tightly coupled to world state. For v1, inline is cleaner; refactor to a manager if GID-039 lands first and needs sharing. Decision: inline for now with clear method boundaries (`_update_nocturnal_spawns(delta: float)`).

- **Infinite-world check:** Only spawn spectres when `_is_infinite == true` (already computed in **WorldScene.gd** line 182). Skip in named maps and dungeons.

- **Spawn positioning:** Use the existing `find_spawn_tile` pattern from GID-039 research: find a walkable grass tile 4–8 world units away from the player (off-screen), not occupied by an existing entity. Implement a static helper `find_nocturnal_spawn_tile(player_pos: Vector3, player_chunk: Vector2i, get_tile: Callable, min_dist: float, max_dist: float, chunk_data_cache: Dictionary) -> Vector3` in **WorldScene.gd**. It checks loaded chunks around the player, samples random grass tiles in the distance band, and returns a valid position or Vector3.ZERO if none found within a small retry budget.

- **Spawn cap:** Track alive spectral enemies per-chunk in a `_nocturnal_entities: Dictionary` (chunk_key -> Array[Node3D]). Cap at 4 alive spectres per 16×16 chunk. When a spectre is defeated or despawns, remove it from the array. Check cap before spawning.

- **Spawning frequency:** Timer-based. Add `_nocturnal_spawn_timer: float = 0.0` and a spawn interval of 30–60 seconds (randomized per spawn event). After each spawn, roll the next interval. Only countdown while night is active and player is in infinite world.

- **Transient tracking:** Spectral enemies are **not** tracked in `SaveManager.defeated_enemies`. Instead, create a local `_nocturnal_enemies: Dictionary` (enemy_id -> {"node": Node3D, "chunk": Vector2i}) to track them for despawn/fade. On chunk eviction (when a chunk is unloaded in `_update_chunks()` line 594), despawn all spectral enemies in that chunk immediately.

- **Fade-out at dawn:** When the night window exits (sun_h >= 0 again, signalled by `time_of_day` crossing 0.25 going forward or 0.75 going backward), tween all alive spectral enemies' modulate alpha from 1.0 to 0.0 over 1 second, then queue_free. Use a helper method `_despawn_nocturnal_enemies()` called from `_update_day_night()` after the time advance.

- **Entity instantiation:** Use the existing `_EnemyScene` preload (**WorldScene.gd** line 26) and the `ChunkRenderer.build_visual()` spawning logic as a template. The spectre node should be identical to a regular EnemyNPC except for modulate alpha (0.7) and a flag `is_nocturnal: bool = true` set on the node. The flag is used by Minimap to color spectres differently (TID-202).

- **Tests:** Extract predicates into testable functions: `is_night(time: float) -> bool`, `find_nocturnal_spawn_tile(...)` pure logic, and spawn cap enforcement. Headless tests verify night-window transitions and cap clamping without needing a full scene.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
