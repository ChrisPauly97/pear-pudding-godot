# TID-300: 8-directional A* with Octile heuristic

**Goal:** GID-082
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The current Pathfinder uses 4-directional A* (N/S/E/W only) with a Manhattan heuristic. Adding diagonal movement is the first step toward direct-path movement: it lets the search find shorter routes that hug wall corners diagonally rather than taking L-shaped detours, and produces path geometry that string-pulling (TID-297) can further compress into straight lines.

## Research Notes

**File:** `game_logic/Pathfinder.gd`

Current `_DIRS`:
```
const _DIRS: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
```

Changes needed:

1. Add 4 diagonal directions to `_DIRS`:
   `Vector2i(1,1)`, `Vector2i(1,-1)`, `Vector2i(-1,1)`, `Vector2i(-1,-1)`

2. Change edge cost: cardinal = 1.0, diagonal = √2 (≈ 1.4142136).
   Detect diagonal by `d.x != 0 and d.y != 0`.

3. Change heuristic from Manhattan to Octile (admissible for 8-dir):
   `max(|dx|, |dz|) + (√2 − 1) × min(|dx|, |dz|)`

4. Add corner-cutting guard: for a diagonal step `(dx, dz)`, reject it if either
   `(current.x + dx, current.y)` or `(current.x, current.y + dz)` is a wall.
   This prevents the player from slipping through the gap between two diagonally adjacent walls.

5. Max-radius bound stays as Manhattan (conservative but valid).

**File:** `tests/unit/test_pathfinder.gd`

Tests that need updating for 8-dir:

- `test_diagonal_path_optimal_length`: currently asserts 9 nodes for (0,0)→(4,4).
  With 8-dir, optimal is 5 diagonal steps = 5 nodes. Update assertion to 5.

- `test_open_path_steps_are_adjacent` and `test_detour_path_steps_are_adjacent`: currently
  check Manhattan distance == 1. Must change to Chebyshev distance == 1
  (`max(abs(curr.x - prev.x), abs(curr.y - prev.y)) == 1`) to allow diagonal steps.

- `test_unreachable_surrounded_by_walls`: the `_walled_box` lookup only walls off the 4
  cardinal neighbours of (5,5). With 8-dir, confirm diagonal approach is blocked by the
  corner-cutting guard: step from (4,4)→(5,5) requires both (5,4) [WALL] and (4,5) [WALL]
  to be walkable — they are walls, so the guard blocks it. Test should still pass unchanged.

## Plan

1. `game_logic/Pathfinder.gd`:
   - Add `const _SQRT2: float = 1.4142136`.
   - Expand `_DIRS` to include 4 diagonal directions.
   - In the neighbour loop, add corner-cutting guard: if the step is diagonal, reject it when either cardinal neighbour tile (in x or z direction) is not walkable.
   - Change edge cost to `_SQRT2` for diagonal steps, `1.0` for cardinal.
   - Replace `_heuristic` with Octile formula: `max(dx, dz) + (√2 − 1) × min(dx, dz)`.
2. `tests/unit/test_pathfinder.gd`:
   - `test_diagonal_path_optimal_length`: change expected size from 9 to 5 (4 diagonal steps).
   - `test_open_path_steps_are_adjacent`: change Manhattan dist == 1 to Chebyshev dist == 1.
   - `test_detour_path_steps_are_adjacent`: same Chebyshev change.
   - No other tests need changes (straight path, wall avoidance, unreachable, max-radius all remain valid).

## Changes Made

- `game_logic/Pathfinder.gd`: added `const _SQRT2: float = 1.4142136`; expanded `_DIRS` with 4 diagonal directions; added corner-cutting guard for diagonal steps; diagonal edge cost = `_SQRT2`, cardinal = `1.0`; replaced Manhattan heuristic with Octile (`max(dx,dz) + (√2-1)×min(dx,dz)`).
- `tests/unit/test_pathfinder.gd`: updated `test_diagonal_path_optimal_length` assertion from 9 to 5; updated `test_open_path_steps_are_adjacent` and `test_detour_path_steps_are_adjacent` from Manhattan dist == 1 to Chebyshev dist == 1 via `maxi()`.

## Documentation Updates

_None for this task — docs update is in TID-301._
