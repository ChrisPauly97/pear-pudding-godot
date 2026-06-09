# TID-182: Compass Ribbon HUD with Marker Infrastructure

**Goal:** GID-049
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The static ribbon that renders bearing markers. A fixed isometric camera means the ribbon itself does not rotate — only the markers slide as the player moves relative to targets. This is the foundational piece all other compass tasks build on.

## Research Notes

- **Camera perspective:** The isometric camera is fixed at azimuth −45° (doc `docs/agent/camera-and-player.md`, line 22) with look direction `(−1, −1, −1)` normalised. Player has no facing — the ribbon stays put, markers move.
- **Bearing math:** For a target at world position (target.x, target.z) and player at (player.x, player.z), the bearing angle is `atan2(target.z - player.z, target.x - player.x)`. This is geographic angle in radians (0 = East world +X, π/2 = North world +Z, π = West, −π/2 = South).
- **Ribbon space mapping:** The compass ribbon is a horizontal bar in 2D screen space. N/E/S/W are displayed at equal intervals (ribbon spans ~360°). Convert bearing angle to ribbon X: the world coordinate system has N at (0, −1) direction, E at (1, 0); the minimap post-GID-006 rotation (lines 180–184 of **scenes/world/Minimap.gd**) applies `ROT45 = 0.7071...` with `rx = (off.x - off.z) * ROT45`, `ry = (off.x + off.z) * ROT45` to rotate +45° and align screen-right with world NE. Use the same rotation formula: screen-right on the ribbon is world NE (−45° bearing), screen-left is world SW (135° bearing). Map bearing angle `θ` to ribbon X as: `ribbon_x = ribbon_center + (θ + 45°) / 360° * ribbon_width`, clamping X to the ribbon bounds.
- **Ribbon as Control node:** Implement in a new **scenes/ui/CompassRibbon.gd** script extending Control. Draw with `_draw()` using `draw_line()` and `draw_string()` for ticks and labels. Render tick marks (short lines) at N/E/S/W positions and a marker at the ribbon center (pointing up). For each registered marker, compute bearing from player to target and draw a coloured dot/icon at the corresponding ribbon X.
- **Marker API (core of the system):**
  - `add_marker(id: String, color: Color, get_pos: Callable) -> void` — register a marker. `get_pos` is a Callable that returns `Vector3(world_x, y, world_z)` or `null` if the marker is off-world / invalid. Called every frame.
  - `remove_marker(id: String) -> void` — unregister by id.
  - `set_current_map(map_name: String) -> void` — called when the player enters a named map; used to determine if targets are off-map.
  - Markers dict: `var _markers: Dictionary = {}` with id → `{color, get_pos}`.
- **Processing:** In `_process(delta)`, iterate `_markers`, call each `get_pos()`, and update `_marker_positions` (dict id → computed ribbon X). In `_draw()`, render the ribbon background, ticks, and each marker dot at its computed X. Store `_player: CharacterBody3D` reference (passed from WorldScene).
- **Off-map edge behavior:** When a target is on a different named map (only relevant in v2+), the marker appears at the ribbon's left or right edge (clamped) pointing toward the map transition. For v1: store `_current_map: String = "main"` and check if target belongs to the same map. Non-matching targets clamp to the ribbon edge. The door/transition is a future detail (see v2 note in TID-183).
- **Viewport-relative sizing:** Ribbon height = `vh * 0.04` (vh from `get_viewport().get_visible_rect().size.y`), width = `vw * 0.40` (vw from viewport width). Position at top-center: X = `(vw - ribbon_width) * 0.5`, Y = `vh * 0.01`. Font size = `vh * 0.018` for tick labels (N/E/S/W).
- **Collision with existing HUD:** Top of HUD currently has Menu button at `(vh * 0.01, vh * 0.01)`. Menu button is small (~vh * 0.14 wide); compass ribbon is centered and ~vh * 0.40 wide, so they do not overlap. No change to existing buttons needed.
- **Headless tests:** Write `tests/unit/test_compass_bearing.gd`:
  - Pure function test: `bearing_to_ribbon_x(bearing_rad, ribbon_width) -> float` returns correct screen position for a 0° / 90° / 180° / 270° bearing.
  - Marker visibility: create a mock marker at a known world position, verify the computed X matches the bearing formula.
  - Off-map clamping: target on "main" map when player is on "maykalene" clamps to ribbon edge.
- **GameBus integration:** When a marker is added/removed, no signal is emitted immediately (the system is internal to the compass). In v2+, if markers come from other systems (e.g., objective markers from SaveManager), those systems emit signals (already in **autoloads/GameBus.gd**, line 24: `story_flag_set`).
- **Update docs/agent/ui-and-scene-management.md:** Add a "Compass Ribbon" subsection under the HUD section (after Minimap, before VirtualJoystick), documenting the marker API, bearing math, and viewport sizing. Include code example of `add_marker()` usage.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
