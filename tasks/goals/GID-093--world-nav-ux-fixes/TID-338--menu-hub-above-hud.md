# TID-338: Menu hub overlay above HUD; close button clear of minimap

**Goal:** GID-093
**Type:** agent
**Status:** done
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

## Lock

- **Session:** claude/work-task-gid-093-o3wpfd
- **Acquired:** 2026-06-24T12:00:00Z
- **Expires:** 2026-06-24T12:30:00Z

## Plan

1. In `autoloads/SceneManager.gd`: add `var _menu_hub_layer: CanvasLayer = null`; in `open_menu_hub()` create a CanvasLayer at layer 10 and add the hub as its child; in `_on_menu_hub_closed()` free the layer; in `_exit_world_cleanup()` free the layer.
2. In `scenes/ui/MenuHubScene.gd`: move the Close button to the **left** side of the tab row (add it first, before the tab buttons) so it never lands in the top-right corner where the minimap lives.

## Changes Made

- `autoloads/SceneManager.gd`: added `var _menu_hub_layer: CanvasLayer = null`; in `open_menu_hub()` create a `CanvasLayer` (layer 10) as the hub's parent before adding to the scene; in `_on_menu_hub_closed()` and `_exit_world_cleanup()` free that layer.
- `scenes/ui/MenuHubScene.gd`: moved Close button to the left end of the tab row so it is clear of the top-right minimap corner.

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md`: added note under Menu Hub section about wrapping the hub in a CanvasLayer at layer 10, and moved Close button position to left.

## Lock

- **Session:** none
- **Acquired:** —
- **Expires:** —
