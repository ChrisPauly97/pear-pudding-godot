# TID-176: A* Pathfinding Over Walkable Tiles

**Goal:** GID-047
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The core search algorithm that finds tile-by-tile paths from player to destination. Uses the same Callable-based tile lookup pattern established in **docs/agent/terrain-rendering.md** (TerrainMath.gd), allowing seamless reuse for both named maps and infinite chunks.

## Research Notes

- **New file:** **game_logic/Pathfinder.gd** — pure static class (no rendering, no state across calls).
- **Core API:**
  - `static func find_path(tile_lookup: Callable, from: Vector2i, to: Vector2i, max_radius: int) -> Array[Vector2i]` — returns ordered tile coordinates from source to destination, or empty Array[Vector2i] if unreachable.
  - `tile_lookup: Callable(ttx: int, ttz: int) -> int` signature matches TerrainMath pattern: takes tile coordinates, returns `int` tile type (`IsoConst.TILE_GRASS`, `TILE_HILL`, `TILE_WALL`, etc.).
- **Walkability rules:** Only `TILE_GRASS`, `TILE_HILL`, and `TILE_PATH` are walkable (cite **autoloads/IsoConst.gd** constants: `TILE_GRASS = 0`, `TILE_WALL = 1`, `TILE_HILL = 2`, `TILE_PATH = 3`). Hills are walkable but impassable terrain (walls) block movement. From player collision rules in **scenes/world/entities/Player.gd** (`move_and_slide()` + `HeightMapShape3D` from terrain mesh), hills do not collide — they are purely visual height. Walls are impassable in both tile grid and collision.
- **Algorithm choice:** Hand-rolled A* with dictionary-based frontier (open set) and closed set. **Rationale:** Godot's built-in `AStarGrid2D` requires a bounded region pre-filled with point costs before search; with a Callable lookup, a dynamic frontier lets us search lazily without pre-allocating a full 100×100 grid (or infinite-world bounded region) up front. The codebase already uses Callable patterns (TerrainMath, InfiniteWorldGen tile access), so consistency favours hand-rolled.
  - **Alternative considered:** `AStarGrid2D` — fast but requires `fill_rect()` preprocessing to build a navigation grid. For infinite worlds, we'd need to dynamically fill a large region (e.g., 128×128 centered on destination); for named maps (100×100), it could work but introduces a setup cost. Hand-rolled avoids this and fits the codebase idiom.
- **Movement:** 4-directional (North, South, East, West) only. **Rationale:** Isometric tiles align to cardinal axes; 8-directional diagonal movement introduces corner-cutting hazards where a diagonal step bypasses a wall. Simpler and safer: stick to 4-dir, which matches wall geometry.
- **Max search radius:** ~64 tiles. **Rationale:** Prevents runaway searches on unreachable tiles (e.g., player clicks a wall surrounded by walls, triggering a full-map scan). A 64-tile radius from start covers most practical scenarios; beyond that, feedback is "too far away" or "unreachable".
- **Data structures (CLAUDE.md Variant inference rules):**
  - Open set: `var open: Dictionary[Vector2i, float] = {}` (tile → heuristic cost). Dictionary lookup is O(1); no Variant inference.
  - Closed set: `var closed: Array[Vector2i] = []` or `HashSet[Vector2i]` for membership check. Use typed array.
  - Came-from map: `var came_from: Dictionary[Vector2i, Vector2i] = {}` (tile → parent tile). Reconstruct path by backtracking.
- **Heuristic:** Manhattan distance scaled to tile units — `(abs(tx - goal_tx) + abs(tz - goal_tz)) * 1.0`. For 4-directional movement, Manhattan is admissible (never overestimates).
- **Tie-breaking:** When multiple tiles have the same f-cost, prioritize the one closest to the goal (lowest h-value) to guide the search toward the destination quickly.
- **Tests (headless, run via `godot --headless -s tests/runner.gd`):**
  - Straight-line path (5×5 grass grid, start at (0,0), goal at (4,4)) → returns 5-tile path (0,0)→(1,1)→(2,2)→(3,3)→(4,4).
  - Path around obstacle (grass with a wall in the middle) → finds detour.
  - Unreachable destination (surrounded by walls, or outside max_radius) → returns empty Array[Vector2i].
  - Max-radius bound (goal 100 tiles away, max_radius=64) → returns empty (goal unreachable within bounds).
  - Identity case (from == to) → returns single-element array `[from]` or empty? **Design decision:** Return `[from]` (start is always reachable).

## Plan

1. Create `game_logic/Pathfinder.gd` — pure static class (no state), exports `find_path(tile_lookup, from, to, max_radius)`.
2. Algorithm: hand-rolled A* with `Dictionary[Vector2i, float]` open-set keyed by tile, `Dictionary[Vector2i, Vector2i]` came_from, `Dictionary[Vector2i, bool]` closed set. Pop minimum f-cost tile each iteration. 4-directional neighbours. Manhattan heuristic.
3. Walkability: `TILE_GRASS`, `TILE_HILL`, `TILE_PATH` are walkable; `TILE_WALL` is not.
4. Max-radius bound: if `(abs(nx - from.x) + abs(nz - from.y)) > max_radius`, skip tile.
5. Identity: `from == to` returns `[from]` immediately.
6. Returns empty `Array[Vector2i]` if unreachable.
7. Create `tests/unit/test_pathfinder.gd` covering: straight path, path around wall, unreachable, max-radius, identity.
8. Register test suite in `tests/runner.gd`.

## Changes Made

- Created `game_logic/Pathfinder.gd` — pure static A* over a `Callable(tx, tz) -> int` tile lookup.
  - `find_path(tile_lookup, from, to, max_radius) -> Array[Vector2i]`: returns ordered tile path or empty if unreachable.
  - 4-directional movement (N/S/E/W), Manhattan heuristic with h-cost tie-breaking.
  - `_is_walkable()` static method (not a const) to reference IsoConst at runtime — avoids GDScript const-initializer autoload parse error.
  - Identity case (`from == to`) returns `[from]` immediately; wall destination rejected before search.
- Created `tests/unit/test_pathfinder.gd` — 12 headless tests: identity, straight path endpoints/length, around-wall detour, unreachable wall dest, unreachable surrounded, max_radius blocking/allowing, adjacency.
- Updated `tests/runner.gd`: added `test_pathfinder` to the `SUITES` array.

## Documentation Updates

- Created `docs/agent/tap-to-move.md` covering key features, algorithm design, integration, and asset requirements for the full tap-to-move system.
