# Tap-to-Move Pathfinding

## Key Features

- Tap (Android) or left-click (desktop) any walkable tile to path-find there automatically.
- Visible pulsing torus destination marker placed at the target tile.
- Manual joystick/WASD input always cancels the active path immediately.
- Path cancelled automatically on battle start (`enemy_engaged`), map transition, or new tap.
- Rejected taps (wall tile / unreachable) show a text tip **and** a brief red
  marker at the tapped tile (TID-462).
- Tapping directly on a chest/door/NPC/waystone/etc. auto-fires the normal
  interaction once the player arrives, without a second tap on USE (TID-461).

## How It Works

### Pathfinder (`game_logic/Pathfinder.gd`)

Pure static class. All public API is static; no state between calls.

```
Pathfinder.find_path(
    tile_lookup: Callable,   # func(tx: int, tz: int) -> int, same as TerrainMath
    from: Vector2i,          # start tile
    to: Vector2i,            # destination tile
    max_radius: int          # max Manhattan radius from start before giving up
) -> Array[Vector2i]         # smoothed path start..dest, or [] if unreachable
```

Algorithm: hand-rolled A* with typed dictionaries (`Dictionary[Vector2i, float]`), followed by string-pull smoothing.

**8-directional A* with Octile heuristic:**
- 8-directional movement: N/S/E/W plus NE/NW/SE/SW diagonals.
- Corner-cutting guard: a diagonal step is rejected if either of the two adjacent cardinal tiles is a wall, preventing passage through the gap between two diagonally-touching walls.
- Edge cost: `1.0` for cardinal steps, `√2 ≈ 1.4142` for diagonal steps.
- Heuristic: Octile distance — `max(|dx|,|dz|) + (√2−1)×min(|dx|,|dz|)` — admissible for 8-dir.
- Tie-breaking: lowest h-cost wins when f-costs equal (steers toward goal faster).
- Max-radius bound: skips any neighbour where `|nb.x−from.x| + |nb.y−from.y| > max_radius`. Prevents runaway searches on isolated wall clusters. Recommended: 64 tiles.
- `_is_walkable()` is a static method (not a const) to allow runtime reference to `IsoConst` autoload values without triggering the GDScript const-initializer parse error.

**String-pull smoothing (`_smooth_path`):**
After A* returns the fine-grained per-tile path, a greedy forward raycast collapses it to only the minimum turn-point waypoints:
1. Start with `anchor = path[0]`.
2. Advance probe index `i` forward; call `_has_line_of_sight(anchor, path[i])`.
3. When LOS fails at `path[i]`, record `path[i-1]` as a turn waypoint and set it as the new anchor.
4. Always append `path[last]` as the final waypoint.

`_has_line_of_sight` uses a Bresenham line walk; it returns false if any traversed tile is non-walkable.

Result: open terrain produces a 2-waypoint path `[start, dest]`, giving pixel-perfect straight-line movement. A wall detour produces the minimum corner waypoints needed to navigate around the obstacle.

Walkable tiles: `TILE_GRASS`, `TILE_HILL`, `TILE_PATH`. `TILE_WALL` blocks movement.

### Input Detection (`scenes/world/WorldScene.gd`)

Tap-to-move uses `_unhandled_input()` so HUD buttons (which call `accept_event()`) suppress the event before it reaches the handler.

Touch guard:
1. On `InputEventScreenTouch` press — record `_tap_start_screen`, `_tap_touch_index`, and reset `_drag_last_tile`.
2. On `InputEventScreenTouch` release — if release position is within `_TAP_DRAG_THRESHOLD` (30 px) of press, treat as a tap and call `_handle_tap_to_move()`.
3. Call `VirtualJoystick.is_touch_in_control_area(pos)` — returns `true` if the tap landed on the joystick base, jump button, or interact button (radius × 1.5 for slop). Abort if true.
4. Mouse: `InputEventMouseButton` left-click `is_pressed()` triggers `_handle_tap_to_move()` directly and resets `_drag_last_tile`.

**Drag steering (TID-340):** Once the drag threshold is crossed, the move target updates continuously:

- **Touch drag (`InputEventScreenDrag`):** if the dragging finger is still tracked and the drag has exceeded `_TAP_DRAG_THRESHOLD`, the joystick area is checked first — if the drag moves into the joystick, steering stops and the tap is abandoned. Otherwise `_handle_tap_to_move()` is called whenever the drag crosses into a new tile (throttled by `_drag_last_tile`).
- **Mouse drag (`InputEventMouseMotion`):** while the left button is held, any tile-change triggers `_handle_tap_to_move()` on the new tile.
- The player follows the finger/cursor in real time; releasing lands at the final position.

### Screen-to-Tile Conversion (`_screen_to_tile`)

Analytic ray-plane intersection against the y = 0 tile plane:

```gdscript
var ray_origin := _camera.project_ray_origin(screen_pos)
var ray_dir    := _camera.project_ray_normal(screen_pos)
var t: float   = -ray_origin.y / ray_dir.y
var world_pos  := ray_origin + t * ray_dir
return IsoConst.world_to_tile(world_pos.x, world_pos.z)
```

Works for both named maps and the infinite world because tiles are always on the y = 0 plane.

### Destination Marker

`_make_dest_marker()` creates an `MeshInstance3D` with:
- `TorusMesh` (inner_radius = 0.50, outer_radius = 0.72, section height = 0.12).
- `StandardMaterial3D`: shading_mode UNSHADED, albedo/emission `Color(0.2, 1.0, 0.4)`.
- Placed at `Vector3((tx + 0.5) * TILE_SIZE, 0.12, (tz + 0.5) * TILE_SIZE)`.

`_place_dest_marker()` attaches a looping `Tween` that pulses scale between 0.85 and 1.2 over 0.45 s.

Marker is freed by `_clear_dest_marker()`, called on: new tap, `cancel_path()` from Player, battle start, or map change. `_process()` polls `player._has_active_path` each frame; when it becomes false, `_clear_dest_marker()` is called automatically.

### Reject Marker (TID-462)

A tap that resolves to a wall tile or an unreachable tile calls
`_show_reject_marker(tile)` in addition to the existing `_show_tip(...)` text
tip. `_make_reject_marker()` builds the same `TorusMesh` shape as the
destination marker but red/orange (`Color(1.0, 0.25, 0.2)`, unshaded,
emissive) and transient: it scales up to 1.4 while fading to alpha 0 over
~0.4s via a one-shot `Tween`, then `queue_free()`s itself. It is independent
of `_dest_marker`/`_dest_tween` — a rejected tap never touches the real
destination-marker lifecycle, so a reject flash can't cancel or interfere
with an in-progress path.

### Tap-to-Interact on Arrival (TID-461)

Tapping a walkable tile that is itself near an interactable (chest, door,
NPC, waystone, mailbox, scroll, shrine, digspot, garden plot, burial mound,
blight heart, mana well, enemy, wilderness camp, scout ambush, Maiteln)
walks the player there and then automatically fires the same interaction
E/USE would — no second tap needed.

**Detection:** `_tile_has_interactable(wx, wz)` mirrors
`_check_interactions()`'s `has_entity` boolean check, but against the
*tapped tile's* world center instead of the live player position, reusing
the same `_find_nearby_*` finder battery (door at `INTERACT_RANGE * 2.0`,
everything else at `INTERACT_RANGE`). `_handle_tap_to_move()` sets
`_pending_tap_interact` from this check once a valid path is found, before
placing the marker.

**Arrival:** `Player.gd` emits a `path_arrived` signal — separate from
`cancel_path()` — only in the natural-arrival branch of
`_physics_process()` (waypoint index overflow). Manual-input override and
the `enemy_engaged`-triggered cancellation both call bare `cancel_path()`
and never emit `path_arrived`, so overriding a walk with WASD or getting
ambushed mid-route never auto-fires a stale queued interaction.
`WorldScene._spawn_player()` connects `path_arrived` dynamically
(`_player.connect("path_arrived", ...)` — `_player` is statically typed
`CharacterBody3D`, so this uses the same dynamic-dispatch pattern as the
rest of the Player-specific API in this file) to
`_on_player_path_arrived()`, which calls the existing `_handle_interact()`
exactly once when `_pending_tap_interact` is set and neither an overlay is
open nor the player is downed (co-op). `_handle_interact()`'s own
priority-ordered dispatch (door → enemy → chest → npc → …) is untouched —
this only automates pressing the button, never re-implements what it does.

`_pending_tap_interact` is also cleared by `_clear_dest_marker()`, so
battle-start, map-transition, and new-tap cancellations can't leave a stale
queued interaction around.

### Path Following (`scenes/world/entities/Player.gd`)

New fields:

| Field | Type | Purpose |
|---|---|---|
| `_path_waypoints` | `Array[Vector2i]` | Ordered tile coords to follow |
| `_path_wp_index` | `int` | Current waypoint being steered to |
| `_has_active_path` | `bool` | Whether path-following is active |
| `_WP_ARRIVE_DIST_SQ` | `float` | Arrive threshold squared (0.3² = 0.09) |

`set_destination_path(waypoints)` stores the array and sets `_has_active_path = true`.

In `_physics_process()`:
1. Read manual input dir as before.
2. If `dir.length_squared() > 0` → `cancel_path()` (manual always wins).
3. Else if `_has_active_path`:
   - Compute waypoint world centre: `Vector3((wp.x + 0.5) * TILE_SIZE, position.y, (wp.y + 0.5) * TILE_SIZE)`.
   - Advance `_path_wp_index` when `dist_sq <= _WP_ARRIVE_DIST_SQ`.
   - If index ≥ waypoints.size() → `cancel_path()`.
   - Else set `dir` = normalised delta to waypoint.

Waypoint Y is set to `position.y` so the existing gravity / `move_and_slide()` path is unchanged — hills are climbed naturally by physics.

Cancellation wiring:
- `GameBus.enemy_engaged` → `cancel_path()` (connected in `_ready()`).
- Manual input (WASD / joystick) → `cancel_path()` each frame.
- New tap → `cancel_path()` + `set_destination_path(new_path)`.
- Map transition → `_clear_dest_marker()` in WorldScene removes the visual; player state resolves on next move.

## Integrations with Other Features

| System | Integration |
|---|---|
| TerrainMath | Same `Callable(tx, tz) -> int` tile-lookup pattern; Pathfinder is drop-in compatible |
| VirtualJoystick | `is_touch_in_control_area(pos)` guard prevents tap-to-move on joystick/button area |
| IsoConst | `world_to_tile()` and `TILE_SIZE` used for coordinate conversion; tile type constants used in `_is_walkable()` |
| GameBus | `enemy_engaged` signal cancels active path |
| WorldScene | Owns marker lifecycle; calls `player.set_destination_path()` / `player.cancel_path()` via `has_method()` + `call()` (Player is typed as `CharacterBody3D`) |

## Asset Requirements

No new art assets needed. The destination marker is a procedural `TorusMesh` with a `StandardMaterial3D`. No textures, shaders, or `.tres` files created.

## Tests

`tests/unit/test_pathfinder.gd` — headless tests auto-discovered by `tests/runner.gd`:

| Test | Checks |
|---|---|
| test_identity_returns_single_element | `from == to` → `[from]` |
| test_straight_path_has_correct_endpoints | First/last element match from/to |
| test_straight_path_optimal_length | Open straight path → 2 nodes after smoothing |
| test_diagonal_path_optimal_length | Open diagonal path → 2 nodes after smoothing |
| test_path_around_wall_reaches_destination | Wall column with gap: detour finds dest |
| test_path_around_wall_avoids_blocked_tiles | Path does not pass through wall column |
| test_unreachable_wall_destination | Wall destination → empty result |
| test_unreachable_surrounded_by_walls | Tile surrounded by walls → empty result |
| test_max_radius_blocks_far_goal | Radius smaller than distance → empty |
| test_max_radius_allows_near_goal | Radius ≥ distance → finds path |
| test_open_path_steps_are_adjacent | Endpoints match; no waypoint is a wall tile |
| test_detour_path_steps_are_adjacent | Endpoints match; no waypoint on wall column |
| test_open_diagonal_path_is_direct | Open (0,0)→(4,4) → exactly 2 waypoints |
| test_smoothed_path_around_wall_reaches_dest | Detour endpoints correct; no wall waypoints |
