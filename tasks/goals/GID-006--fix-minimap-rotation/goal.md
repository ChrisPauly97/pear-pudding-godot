# GID-006: Fix Minimap Orientation for Isometric Camera Alignment

## Objective

Rotate the minimap 45° so that movement directions visible on screen match what the player sees on the minimap.

## Context

The minimap camera looks straight down with no yaw (`rotation_degrees = Vector3(-90, 0, 0)`), so world −Z (north) renders at the top and world +X (east) at the right. However, the isometric camera has a −45° azimuth: the player's "screen up" corresponds to world NW `(−1, 0, −1)` and "screen right" to world NE `(+1, 0, −1)`. This means moving right in-game moves the minimap dot diagonally up-right, not straight right — the minimap is 45° out of phase with the player's perceived movement.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-014 | Rotate minimap camera and dot overlay to match isometric azimuth | agent | done | — |

## Acceptance Criteria

- [ ] Moving right in the isometric view moves the player dot straight right on the minimap
- [ ] Moving up in the isometric view moves the player dot straight up on the minimap
- [ ] Entity dots remain correctly positioned relative to the player dot
- [ ] The "N" compass label is removed or repositioned to avoid misleading the player
