# GID-047: Tap-to-Move Pathfinding

## Objective

Tap (mobile) or click (desktop) a destination tile and the player pathfinds and walks there automatically, with a visible destination marker.

## Context

The single biggest mobile navigation win. Movement today is joystick/WASD only. A* runs over the same Callable-based tile lookups TerrainMath established; manual input always wins — any joystick/WASD input cancels the active path.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-176 | A* pathfinding over walkable tiles (Callable tile lookup, named maps + loaded chunks) | agent | done | — |
| TID-177 | Tap/click destination input: screen→tile raycast, destination marker, cancel rules | agent | done | TID-176 |
| TID-178 | Path-following in Player + edge cases (unreachable, interrupts, chunk bounds) | agent | done | TID-176 |

## Acceptance Criteria

- A pure-GDScript A* (**game_logic/Pathfinder.gd**) finds tile paths via a Callable tile lookup, works on named maps and the infinite world (bounded to loaded chunks / a max search radius), and is covered by headless tests
- Tapping/clicking a walkable tile sets a destination with a visible marker; tapping a wall or unreachable tile gives subtle feedback and no path
- Tap-to-move never fires from touches that start on the virtual joystick or UI controls
- The player follows the path smoothly with the normal walk animation; any WASD/joystick input, battle start, or map transition cancels the path
- Works identically on desktop (mouse click) and Android (tap) — feature parity per CLAUDE.md
- All tests pass headless
