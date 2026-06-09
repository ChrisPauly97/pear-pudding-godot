# TID-166: Map View Overlay Dig-Site Marker + Fragment Display in Journal

**Goal:** GID-043
**Type:** agent
**Status:** pending
**Depends On:** TID-165

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Surface the treasure hunt in the UI so players know where to dig. Display dig-site location on the map, and show fragment progress + active map status in the journal.

## Research Notes

- **MapViewOverlay.gd treasure marker:** Check existing marker drawing in `scenes/ui/MapViewOverlay.gd` (lines 16–23 show dot colours for entities; line 44–46 is the `_on_draw()` call where dots are rendered). Follow the same pattern:
  - Add a new color constant: `const _DOT_DIGSITE := Color(1.0, 0.65, 0.15)` (amber/gold, distinct from chest yellow)
  - In the `_on_draw()` method (or wherever markers are drawn), check if `SaveManager.active_treasure` is non-empty and `not completed`. If so, convert the dig site tile coords to map panel space (likely a transform from world coords to the map texture panel; cite the exact formula from existing code, e.g., `world_x / TILE_SIZE → tex_x`, scaled to panel dimensions)
  - Draw a marker (circular outline or X shape, 8–12 pixels radius) at that position using `draw_circle()` or `draw_arc()` with the dig-site color
  - Optional: Add a label "Dig Site" or just the marker
- **Minimap.gd optional direction hint:** Check how minimap dots are drawn in `scenes/ui/Minimap.gd` (if it exists; search `Minimap.gd` in the codebase). The minimap is usually a radial ring with entity dots. If the dig site is off-screen (beyond the ring radius), optionally draw a direction arrow on the ring edge pointing toward it. **Only implement if the code is simple** (< 10 lines added); otherwise skip for v1.
- **JournalScene.gd treasure panel:** In `scenes/ui/JournalScene.gd`, add a new section (tab or label row) showing:
  - Fragment progress: "Map Fragments: [count]/3" or similar
  - Active map status: If `SaveManager.active_treasure` is non-empty and not completed, show "Active: Dig site at ([x], [z])" (world tile coords for reference)
  - If completed, show "Treasure Excavated!"
  - If no active map and fragments < 3, show "Collect 3 fragments to form a map."
  - Viewport-relative sizing per CLAUDE.md: Use `vh * 0.025` for font size, `vh * 0.04` for spacing
- **Exact journal placement:** Journal already has tabs/sections (scroll list + detail view per lines 75–95 of `JournalScene.gd`). Add the treasure info as a new row above or below the scroll list in the header area, or as a dedicated "Treasures" tab. Cite the exact position and container.
- **Mobile parity:** The dig-site marker is display-only (no new input); interaction happens via the existing `interact` action (E key or touch prompt on the DigSpot entity itself, already handled in TID-165). No additional mobile work needed here.
- **Coordinate transform for map drawing:** In `scenes/ui/MapViewOverlay.gd`, the helper function `_world_to_panel(wx, wz) -> Vector2` at lines 184–189 converts world coordinates to panel pixels. The formula is: `tx = wx / IsoConst.TILE_SIZE`, `tz = wz / IsoConst.TILE_SIZE`, then `px = _panel_pos.x + (tx / 100.0) * _panel_size` (100 is the map grid size). Use the same function to position the dig-site marker in `_on_draw()`.
- **Headless tests:** Write tests for:
  - Marker visibility: Create an active treasure record, verify marker is drawn (mock the _draw call or check the draw command buffer if Godot exposes it; otherwise test the transform logic separately)
  - Coordinate transform: World tile (150, 200) in a 100×100 map → correct panel pixel position (test the conversion formula in isolation)
  - Journal fragment display: Create SaveManager with 1–3 fragments, instantiate journal (or mock the fragment display logic), verify the correct text is shown

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
