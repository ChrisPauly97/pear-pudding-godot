# TID-338: Menu hub overlay above HUD; close button clear of minimap

**Goal:** GID-093
**Type:** agent
**Status:** pending
**Depends On:** —

## Context

The combined menu (menu hub, GID-081) isn't easily closeable: its Close button overlaps the
minimap and the whole overlay renders behind the HUD. Players can't reliably tap Close.

## Research Notes

- `MenuHubScene` (scenes/ui/MenuHubScene.gd) `extends "res://scenes/ui/BaseOverlay.gd"`,
  which `extends Control` (scenes/ui/BaseOverlay.gd:1) — a layer-0 node.
- `SceneManager.open_menu_hub` (autoloads/SceneManager.gd:927) adds the hub via
  `get_tree().current_scene.add_child(hub)` — i.e. a plain Control child of the WorldScene
  (a Node3D scene at canvas layer 0).
- The HUD and minimap live on a `CanvasLayer`: `WorldHUD` holds `var _hud: CanvasLayer`
  (scenes/world/WorldHUD.gd:12); `Minimap.setup(world, hud: CanvasLayer, ...)`
  (scenes/world/Minimap.gd:66) parents its dot/ring layers onto that CanvasLayer. A
  CanvasLayer (default layer 1) renders **above** layer-0 Controls — so the minimap draws on
  top of the hub overlay. Result: the hub is visually "at the back."
- The hub's Close button is built in `tab_row` at the top, pushed right by a spacer
  (MenuHubScene.gd:56-66) — i.e. top-right, exactly where the minimap sits
  (`minimap_bottom` math in WorldHUD.gd:93 places the minimap top-right). So even if it
  rendered on top, the button location collides with the minimap.
- Two fixes are needed together: (a) raise the overlay above the HUD CanvasLayer, and
  (b) move the Close control out of the minimap's corner.
- Approach for (a): wrap/host the hub on its own `CanvasLayer` with a layer value higher
  than the HUD's, or have `open_menu_hub` add it to a high-layer CanvasLayer instead of the
  raw scene. Check how other overlays (e.g. `MapViewOverlay`, SettingsScene via
  `_open_overlay`) are layered and follow the established pattern — several BaseOverlay
  overlays already display correctly over the HUD, so mirror whichever mechanism they use.
- Approach for (b): relocate Close (e.g. left side of the tab row, or a bottom bar), or size
  the backdrop/panel so the button never lands under the minimap. Keep it viewport-relative
  (CLAUDE.md UI sizing rule) and re-applied on resize (`_notification(NOTIFICATION_RESIZED)`).
- Cross-check the other BaseOverlay-based screens opened over the world (Shop, MapView,
  Settings) for the same z-order/corner issue while here; fix consistently if shared.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._ Update `docs/agent/ui-and-scene-management.md` (overlay
layering vs. HUD) and/or `docs/agent/signals-and-constants.md` if the layering convention
changes.
