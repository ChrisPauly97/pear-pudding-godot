# TID-455: Display Safe-Area Insets

**Goal:** GID-120
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

No code reads `DisplayServer.get_display_safe_area()`. Landscape phones put camera
cutouts and rounded corners exactly where edge-anchored controls sit: WorldHUD
zones (pause top-left, nav/social right, context bottom), VirtualJoystick,
Minimap (top-right), battle SidePanel (right edge).

## Plan

1. `UiUtil.safe_insets(viewport) -> Dictionary` (`left/top/right/bottom` in canvas
   px): safe area vs screen size, scaled into the viewport's coordinate space;
   zeros on desktop/headless.
2. Apply to `WorldHUD._init_zones` (+ coord label / XP bar), `VirtualJoystick`
   `_edge_margin`, `Minimap` margin, `BattleScene` SidePanel + cancel-button y.

## Changes Made

- `UiUtil.safe_insets()` added.
- WorldHUD zones, coord label, and XP bar offset by the insets; VirtualJoystick
  adds `right/bottom` insets to its edge margin; Minimap margin adds `top/right`;
  BattleScene shifts SidePanel `offset_right` and the targeting cancel button.

## Documentation Updates

- `docs/agent/ui-and-scene-management.md`: safe-area section under GID-120.
