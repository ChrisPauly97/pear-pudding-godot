# Tap-to-Move Pathfinding

## Key Features

- Tap (Android) or left-click (desktop) any walkable tile to path-find there automatically.
- Visible pulsing torus destination marker placed at the target tile.
- Manual joystick/WASD input always cancels the active path immediately.
- Path cancelled automatically on battle start (`enemy_engaged`), map transition, or new tap.
- No-op for wall tiles or unreachable targets (silent rejection — no marker placed).

## How It Works

### Pathfinder (`game_logic/Pathfinder.gd`)

Pure static class. All public API is static; no state between calls.

```
Pathfinder.find_path(
    tile_lookup: Callable,   # func(tx: int, tz: int) -> int, same as TerrainMath
    from: Vector2i,          # start tile
    to: Vector2i,            # destination tile
    max_radius: int          # max Manhattan radius from start before giving up
) -> Array[Vector2i]         # ordered path start..dest, or [] if unreachable
```

Algorithm: hand-rolled A* with typed dictionaries (`Dictionary[Vector2i, float]`).
- 4-directional movement only (N/S/E/W). No diagonal — prevents corner-cutting through walls.
- Heuristic: Manhattan distance (admissible for 4-dir).
- Tie-breaking: lowest h-cost wins when f-costs equal (steers toward goal faster).
- Max-radius bound: skips any neighbour where `|nb.x - from.x| + |nb.y - from.y| > max_radius`. Prevents runaway searches on isolated wall clusters. Recommended: 64 tiles.
- `_is_walkable()` is a static method (not a const) to allow runtime reference to `IsoConst` autoload values without triggering the GDScript const-initializer parse error.

Walkable tiles: `TILE_GRASS`, `TILE_HILL`, `TILE_PATH`. `TILE_WALL` blocks movement.

### Input Detection (`scenes/world/WorldScene.gd`)

Tap-to-move uses `_unhandled_input()` so HUD buttons (which call `accept_event()`) suppress the event before it reaches the handler.

Touch guard:
1. On `InputEventScreenTouch` press — record `_tap_start_screen` and `_tap_touch_index`.
2. On `InputEventScreenTouch` release — if release position is within `_TAP_DRAG_THRESHOLD` (30 px) of press, treat as a tap and call `_handle_tap_to_move()`.
3. Call `VirtualJoystick.is_touch_in_control_area(pos)` — returns `true` if the tap landed on the joystick base, jump button, or interact button (radius × 1.5 for slop). Abort if true.
4. Mouse: `InputEventMouseButton` left-click `is_pressed()` triggers `_handle_tap_to_move()` directly.

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

`tests/unit/test_pathfinder.gd` — 12 headless tests registered in `tests/runner.gd`:

| Test | Checks |
|---|---|
| test_identity | `from == to` → `[from]` |
| test_straight_path_endpoints | First/last element match from/to |
| test_straight_path_length | 9-tile straight path returns length 9 |
| test_diagonal_path_length | Diagonal requires more steps than straight |
| test_around_wall_reaches_dest | Wall column with gap: detour finds dest |
| test_around_wall_avoids_blocked | Path does not pass through wall column |
| test_unreachable_wall_dest | Wall destination → empty result |
| test_unreachable_surrounded | Tile surrounded by walls → empty result |
| test_max_radius_blocks | Radius smaller than distance → empty |
| test_max_radius_allows | Radius ≥ distance → finds path |
| test_adjacent_tiles | Adjacent walkable tiles → 2-element path |
| test_adjacent_tiles_from_equals_to | Same tile both ends → single element |
