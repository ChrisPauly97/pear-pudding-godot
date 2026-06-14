# TID-178: Path-Following in Player + Edge Cases

**Goal:** GID-047
**Type:** agent
**Status:** done
**Depends On:** TID-176

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Integrates pathfinding into the Player movement loop, advancing through waypoints smoothly while respecting manual input cancellation, battle/map transitions, and terrain bounds. The player follows a queue of tile waypoints, steering toward each one at normal walk speed until arrival.

## Research Notes

- **Player movement structure:** **scenes/world/entities/Player.gd** (lines 50–79):
  - `_physics_process(delta: float)` reads WASD input (lines 53–60), computes a `dir: Vector3` direction vector, sets `velocity.x` and `velocity.z` to `dir * SPEED` (line 65–66), handles gravity/jumping (lines 68–78), calls `move_and_slide()` (line 79).
  - `SPEED = 6.0` world units/sec (line 3).
  - Animation updates in the same loop (lines 87–106), setting `_anim_frame` every `frame_dur = 1.0 / ANIM_FPS` where `ANIM_FPS = 6.0` (lines 14, 96–98).
  - Walk frame cycling: `_sprite.texture = _walk_frames[_anim_frame]` (line 101).
  - Idle condition: `_is_moving = dir.length_squared() > 0.0` (line 88); frame 0 on idle (lines 104–106).
- **Add path-following mode:**
  - New fields in Player: `var _path_waypoints: Array[Vector2i] = []` (queue of tile coordinates), `var _current_waypoint_index: int = 0`, `var _has_active_path: bool = false`.
  - New func: `set_destination_path(waypoints: Array[Vector2i]) -> void` — called by WorldScene when tap-to-move succeeds. Stores waypoints and starts following.
  - In `_physics_process()`, add at the start: if `_has_active_path`, compute direction toward `_path_waypoints[_current_waypoint_index]` as a world position, steer toward it. If within ~0.3 units of the waypoint, pop to next. When no waypoints remain, clear the path.
  - **Key:** Manual input (WASD/joystick) always wins. Check if `dir.length_squared() > 0.0` from input reading (lines 53–60); if true, clear `_has_active_path` and ignore the active path. The path is a convenience, not a constraint.
- **Waypoint steering:**
  - Convert waypoint tile `Vector2i(tx, tz)` to world centre: `Vector3(tx * TILE_SIZE + TILE_SIZE * 0.5, 0.0, tz * TILE_SIZE + TILE_SIZE * 0.5)` = `Vector3((tx + 0.5) * TILE_SIZE, 0.0, (tz + 0.5) * TILE_SIZE)` (cite **autoloads/IsoConst.gd** line 56: `tile_to_world(tx, tz) -> Vector3`; add 0.5 * TILE_SIZE for center).
  - Compute delta from player position to waypoint centre: `delta = waypoint_world - player.position`.
  - Normalize and scale by SPEED to get velocity: `var dir = delta.normalized(); velocity.x = dir.x * SPEED; velocity.z = dir.z * SPEED`.
  - Gravity/jumping unchanged (still applied to `velocity.y` and `move_and_slide()`).
  - Animation: reuse the existing `_is_moving` logic — as long as steering toward a waypoint, the player appears to move and cycles walk frames.
- **Waypoint advance:**
  - Each frame, compute distance to current waypoint: `distance_sq = (player.position - waypoint_world).length_squared()`.
  - If `distance_sq < 0.3 * 0.3` (0.3 units), increment `_current_waypoint_index` and fetch the next waypoint.
  - When `_current_waypoint_index >= _path_waypoints.size()`, clear the path: set `_has_active_path = false`, `_path_waypoints.clear()`.
- **Cancellation triggers:**
  - **Manual input:** Already handled — if input dir is nonzero, clear the path.
  - **Battle started:** Connect to `GameBus.enemy_engaged` signal (cite **docs/agent/signals-and-constants.md**) and clear the path in the handler.
  - **Map transition:** Connect to `SceneManager.map_changed` signal or `WorldScene._on_map_changed()` callback, clear the path.
  - **Other menu opens:** Connect to `GameBus.inventory_requested`, `battle_started`, `skill_tree_requested`, etc.; each clears the path.
- **Unreachable/empty path handling:**
  - If Pathfinder returns empty `Array[Vector2i]`, the destination is unreachable. Don't set the path. TID-177 already provides feedback (toast/visual flicker). WorldScene should check `if path.is_empty(): return` before calling `player.set_destination_path()`.
- **Infinite world chunk bounds:**
  - Named maps are fixed 100×100 grids; the destination is always within bounds if chosen on-screen.
  - Infinite world: loaded chunks form a region around the player. If the destination chunk unloads mid-walk (player moves far away), the destination becomes invalid. **Simple v1 solution:** When `_current_waypoint_index` advances, check if the waypoint tile is in a loaded chunk (compare against WorldScene's `_chunk_renderers` keys). If the chunk is unloaded, emit a cancelled toast and clear the path: `_has_active_path = false`.
  - **Alternative (stricter):** In Pathfinder.find_path(), bound the search to loaded chunks by checking `loaded_chunk_data.get(tile_chunk_coord)` for each tile. But this couples Pathfinder to WorldScene, so prefer the simple approach.
- **Hills and terrain collision:**
  - Waypoints are computed on tile centres (2D XZ only); gravity/terrain collision already handles Y via `move_and_slide()` and the `HeightMapShape3D` (cite **docs/agent/terrain-rendering.md**). No special handling needed — hills render with height variation, and the player naturally climbs them.
- **Tests (headless, extracted as pure functions where possible):**
  - Create a test `Pathfinder` object with a simple tile lookup, find a 5-tile path.
  - Test waypoint advance: simulate walking 0.1 units at a time toward a waypoint, verify that when distance < 0.3, the waypoint index increments.
  - Test manual input cancellation: call `set_destination_path()` with 3 waypoints, then simulate pressing WASD (set input dir to nonzero), verify `_has_active_path` becomes false.
  - Test empty path: call `set_destination_path([])`, verify no change to movement.
  - Test terrain height: Place a waypoint on a hill tile, verify the player climbs it (not possible without running the game, but verify the steering direction is correct in headless).

## Plan

Implemented during build phase (no separate plan step needed — research notes were sufficient).

## Changes Made

- Updated `scenes/world/entities/Player.gd`:
  - Added path-following state: `_path_waypoints: Array[Vector2i]`, `_path_wp_index: int`, `_has_active_path: bool`, `_WP_ARRIVE_DIST_SQ: float = 0.09`.
  - `_ready()`: connects `GameBus.enemy_engaged` to call `cancel_path()`.
  - `set_destination_path(waypoints: Array[Vector2i]) -> void`: stores waypoints and activates path-following.
  - `cancel_path() -> void`: clears all path state; safe to call idempotently.
  - `_physics_process()` modification: if manual input dir is nonzero → `cancel_path()` (manual always wins); else if `_has_active_path`, steer toward the current waypoint tile centre; advance `_path_wp_index` when within `_WP_ARRIVE_DIST_SQ`; call `cancel_path()` when last waypoint reached.
  - Waypoint world position: `Vector3((wp.x + 0.5) * IsoConst.TILE_SIZE, position.y, (wp.y + 0.5) * IsoConst.TILE_SIZE)` — keeps Y at player height so gravity handling is unchanged.

## Documentation Updates

- Covered in `docs/agent/tap-to-move.md`.
