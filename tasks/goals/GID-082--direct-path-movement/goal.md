# GID-082: Direct-Path Tap-to-Move Movement

## Objective

Replace tile-centre-hopping pathfinding with direct movement that walks in a straight line to the destination and only deviates around actual wall obstacles.

## Context

The existing tap-to-move system (GID-047) uses 4-directional A* returning every tile centre along the route. The player steers to each centre in sequence, producing a visible zigzag even across open grass. Two improvements fix this: (1) upgrading A* to 8-directional movement so detour paths hug corners diagonally rather than taking L-shaped detours, and (2) adding string-pull smoothing that collapses the returned path to only the minimum turn-point waypoints, giving a perfectly direct line in open space.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-300 | 8-directional A* with Octile heuristic | agent | done | — |
| TID-301 | String-pull path smoothing + docs | agent | pending | TID-300 |

## Acceptance Criteria

- [ ] Tapping across open terrain moves the player in a straight line (single segment, no zigzag).
- [ ] Tapping around a wall obstacle produces a minimal-waypoint path that hugs the corner.
- [ ] Corner-cutting through diagonal wall gaps is prevented.
- [ ] All existing tests pass (updated for 8-dir adjacency); new smoothing tests added.
- [ ] `docs/agent/tap-to-move.md` updated to describe new algorithm.
