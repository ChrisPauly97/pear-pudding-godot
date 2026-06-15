# GID-049: Compass, Waypoints & Objective Wayfinding

## Objective

A compass ribbon in the HUD showing cardinal directions, a player-placed waypoint pin, and the current Chapter 1 story objective, all as bearing markers.

## Context

"Where do I go next?" has no in-game answer — story progress lives only in dialogue. The compass ribbon gives bearings in a world where the camera is locked isometric; it surfaces a custom pin (set from the map view), the active story objective, and active dig sites from GID-043 once those exist.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-182 | Compass ribbon HUD with marker infrastructure (iso-camera-relative bearings) | agent | done | — |
| TID-183 | Custom waypoint: long-press/click on MapViewOverlay sets a pin shown on compass + minimap, persisted | agent | pending | TID-182 |
| TID-184 | Story objective markers derived from Chapter 1 story flags | agent | pending | TID-182 |

## Acceptance Criteria

- A compass ribbon at the top of the HUD shows N/E/S/W ticks consistent with the isometric camera (same convention the GID-006 minimap fix established) and scrolls as the implied facing is fixed — markers slide along it by bearing from the player
- A generic marker API lets any system register/unregister a compass marker (id, world pos or map+pos, icon/color); markers off the current map show at the ribbon edge
- Long-press (mobile) or right-click (desktop) on the MapViewOverlay sets/moves a single custom waypoint pin; it shows on the compass, minimap, and map overlay, persists in SaveManager with migration, and can be cleared
- The current story objective (derived from existing Chapter 1 story flags, no new flags) registers a distinct objective marker pointing at the relevant map/NPC; it updates as flags advance and disappears when Chapter 1 is complete
- Compass and waypoint interactions are fully touch-operable (mobile parity per CLAUDE.md)
- All tests pass headless
