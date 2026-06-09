# TID-183: Custom Waypoint Pin (Long-Press/Right-Click on MapViewOverlay)

**Goal:** GID-049
**Type:** agent
**Status:** pending
**Depends On:** TID-182

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A single player-placed pin that the player can set/clear by long-pressing (mobile) or right-clicking (desktop) on the map view. The pin shows on the compass, minimap, and map overlay; persists in SaveManager; and can be cleared.

## Research Notes

- **MapViewOverlay.gd interaction:** Currently handles M / Escape keypresses to close (lines 192–196 of **scenes/ui/MapViewOverlay.gd**). Add right-click / long-press detection via `_unhandled_input()` for desktop and mobile. Check if `LongPressDetector` exists: search for **scenes/ui/LongPressDetector.gd** — if it exists, reuse its API; otherwise, implement a simple long-press detection in MapViewOverlay directly (detect touch/mouse down, start a timer, fire on timeout).
- **Panel ↔ world transform:** MapViewOverlay has a helper `_world_to_panel(wx, wz)` (lines 184–189) that converts world tile coords to screen pixels: `tx = wx / TILE_SIZE`, `tz = wz / TILE_SIZE`, `px = panel_x + (tx / 100.0) * panel_size`, `pz = panel_y + (tz / 100.0) * panel_size`. Implement the inverse: `_panel_to_world(px, pz) -> Vector3`:
  ```
  tx = (px - panel_x) / panel_size * 100.0
  tz = (pz - panel_y) / panel_size * 100.0
  wx = tx * TILE_SIZE
  wz = tz * TILE_SIZE
  return Vector3(wx, 0.0, wz)
  ```
  Headless test: round-trip a known tile (e.g., (50, 50)) through both transforms and verify it returns to the original.
- **SaveManager waypoint field:** Add `waypoint: Dictionary = {}` (empty by default) storing `{map: String, tx: int, tz: int}` or empty when cleared. Add to migration in `_migrate()` function (line ~108 of **autoloads/SaveManager.gd**). On load, restore the waypoint state so it persists across sessions.
- **Setting the waypoint:** When the player long-presses / right-clicks on the map panel, compute the tile coords using `_panel_to_world()`, then set `SaveManager.waypoint = {map: current_map, tx: tx, tz: tz}` and `SaveManager.mark_dirty()`. Emit `GameBus.waypoint_changed(waypoint)` (add this signal to **autoloads/GameBus.gd**).
- **Clearing the waypoint:** Long-press / right-click on the existing pin (if drawn) or add a small "Clear Waypoint" button in MapViewOverlay. Button sizing: `vh * 0.05` height, `vh * 0.12` width, positioned below the close hint. On press, set `SaveManager.waypoint = {}` and emit `waypoint_changed({})`.
- **Drawing on MapViewOverlay:** In `_on_draw()` (lines 145–154), after drawing other entities, check if `SaveManager.waypoint` is non-empty and matches the current map. If so, convert waypoint tile coords to panel space and draw a marker (e.g., a coloured circle with a pin icon, or a star shape). Use the same color as TID-166 if the treasure marker exists — coordinate with the dig-site marker color to avoid conflicts. Suggested colors: custom waypoint = white/cyan (distinct from treasure amber), or use `const _MARKER_WAYPOINT := Color(0.2, 0.8, 1.0)` (cyan).
- **Drawing on Minimap:** In `scenes/world/Minimap.gd` `_on_draw()` (lines 158–169), after drawing other entity dots, if `SaveManager.waypoint` is non-empty and matches the current map, compute the dot position using the same bearing math as TID-182 (rotate by ROT45, scale by _scale, clamp to ring) and draw a distinct marker dot. Use the same cyan color as MapViewOverlay for consistency.
- **Rendering on Compass:** The compass ribbon (TID-182) already has the marker API. Register the waypoint as a marker via `compass.add_marker("waypoint", color, get_waypoint_pos)` where `get_waypoint_pos` is a Callable that returns the waypoint world position or `null` if waypoint is empty / off-map. Call this from the ribbon's `_ready()` or from WorldScene after the compass is created.
- **Mobile parity:** Long-press is the primary input on mobile (tap and hold for ~0.5 seconds). On desktop, support right-click as well. Both trigger the same waypoint set/clear logic.
- **Coordinate transform headless tests:** In `tests/unit/test_waypoint_transforms.gd`:
  - Round-trip: panel (50, 50) pix → tile → world → tile → panel, verify start == end.
  - Edge cases: panel edges (0, 0) and (panel_size, panel_size) map to world tile boundaries.
  - Out-of-bounds: panel pixel (−10, −10) (off-panel) maps sensibly (may clamp or return out-of-map, documented).
- **Conflict resolution:** If both treasure dig-site (GID-043 TID-166) and waypoint exist on the same map, they render at different positions and don't conflict. If they happen to be at the same tile, render both (or overlay them). Recommendation: waypoint always renders on top (drawn last) so the player's intention is visible.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
