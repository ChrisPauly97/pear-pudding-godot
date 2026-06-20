# TID-301: String-pull path smoothing + docs

**Goal:** GID-082
**Type:** agent
**Status:** pending
**Depends On:** TID-300

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

After 8-dir A* (TID-296) returns a fine-grained path through tile centres, this task adds a post-processing pass that collapses it to only the minimum "turn point" waypoints needed to navigate around obstacles. In open terrain the result is just [start, destination]; a wall detour produces a small number of waypoints at wall corners. The player steers between these points in straight world-space segments, delivering the direct-movement feel requested.

## Research Notes

**File:** `game_logic/Pathfinder.gd`

### New method: `_has_line_of_sight(tile_lookup, from, to) -> bool`

Bresenham line walk from `from` to `to` (inclusive on `from`, exclusive on `to` — destination
already validated walkable). Returns false if any traversed tile is not walkable.

```gdscript
static func _has_line_of_sight(tile_lookup: Callable, from: Vector2i, to: Vector2i) -> bool:
    var x: int = from.x
    var z: int = from.y
    var dx: int = abs(to.x - from.x)
    var dz: int = abs(to.y - from.y)
    var sx: int = 1 if to.x > from.x else -1
    var sz: int = 1 if to.y > from.y else -1
    var err: int = dx - dz
    while x != to.x or z != to.y:
        if not _is_walkable(tile_lookup.call(x, z)):
            return false
        var e2: int = 2 * err
        if e2 > -dz:
            err -= dz
            x += sx
        if e2 < dx:
            err += dx
            z += sz
    return true
```

### New method: `_smooth_path(tile_lookup, path) -> Array[Vector2i]`

Greedy forward raycast. From the current anchor, extend the probe as far as LOS holds. When
LOS fails to tile `i`, tile `i-1` is a turn point and becomes the new anchor.

```gdscript
static func _smooth_path(tile_lookup: Callable, path: Array[Vector2i]) -> Array[Vector2i]:
    if path.size() <= 2:
        return path
    var result: Array[Vector2i] = [path[0]]
    var anchor_idx: int = 0
    var i: int = 2
    while i < path.size():
        if not _has_line_of_sight(tile_lookup, path[anchor_idx], path[i]):
            result.append(path[i - 1])
            anchor_idx = i - 1
        i += 1
    result.append(path[path.size() - 1])
    return result
```

### Call site in `find_path()`

Replace the `return _reconstruct(came_from, current)` line inside the `current == to` branch:

```gdscript
if current == to:
    var raw: Array[Vector2i] = _reconstruct(came_from, current)
    return _smooth_path(tile_lookup, raw)
```

**File:** `tests/unit/test_pathfinder.gd`

Tests to update/add:

- `test_straight_path_optimal_length`: after smoothing, open (0,0)→(4,0) → 2 nodes
  (start + dest). Update assertion from 5 to 2.

- Add `test_open_diagonal_path_is_direct`: (0,0)→(4,4) open space → 2 nodes after smoothing.

- Add `test_smoothed_path_around_wall_reaches_dest`: detour via `_wall_partial` still reaches
  destination; verify endpoints match.

- `test_open_path_steps_are_adjacent` and `test_detour_path_steps_are_adjacent`:
  Smoothed paths skip intermediate tiles so adjacency-per-step no longer holds.
  Replace the body: verify endpoints are correct and no waypoint is a wall tile.

**File:** `docs/agent/tap-to-move.md`

Rewrite the Pathfinder section to describe:
- 8-directional movement, Octile heuristic, corner-cutting guard.
- String-pulling post-process: `_has_line_of_sight()` + `_smooth_path()`.
- Result: open paths compressed to 2 waypoints; minimal turn points for obstacle detours.
Update test table rows for changed/added tests.

**WorldScene / Player:** No changes needed. `find_path()` API is unchanged.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

`docs/agent/tap-to-move.md` — algorithm section rewrite.
