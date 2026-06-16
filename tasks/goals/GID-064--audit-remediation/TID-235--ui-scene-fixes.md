# TID-235: UI scene fixes

**Goal:** GID-064
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A batch of verified UI bugs and the two worst UI performance hitches (inventory and
shop full-list rebuilds on every tap). All are self-contained in scenes/ui/.

## Research Notes

Bugs:
1. **ShopScene root has no anchors (high).** Root Control now has `anchors_preset = 15`.
2. **Mid-signal free() (high).** SkillTreeScene uses `queue_free()` + deferred `_build_ui`/`_refresh`.
3. **Stale Cards tab (medium).** `_on_tab_cards` now calls `_refresh_cards()`.
4. **Map editor dialog leaks (medium).** Both dialogs connect `canceled`/`close_requested` → `queue_free`.
5. **Map view dots never update (medium).** `_DotLayer` has `_process` calling `queue_redraw()`.
6. **GameOver off-center (medium).** VBox has `grow_horizontal=2, grow_vertical=2`.
7. **SkillTree close button vw-vs-vh (low).** Fixed to `_vh * 0.065`.
8. **Achievements Esc handling (low).** Uses `event.is_action_pressed("ui_cancel")` + handled.
9. **AchievementToast stale viewport (low).** Reads fresh viewport size in `_show_next`.
10. **Dead disabled-button connect (low).** Removed from InventoryScene.
11. **Inventory scroll preservation.** Scroll positions saved/restored across `_refresh_cards()`.
12. **Shop scroll preservation.** Scroll position saved/restored across `_refresh()`.
13. **LongPressDetector.** `set_process(false)` by default; enabled only when holding; child-button check added.
14. **Map editor paint batch.** Dirty flags `_dirty_flat`/`_dirty_walls` batched in `_process`; paint strokes no longer trigger full rebuilds per-drag-event.

## Plan

Done — see Changes Made.

## Changes Made

- `scenes/ui/ShopScene.tscn`: added `layout_mode=3, anchors_preset=15, anchor_right=1.0, anchor_bottom=1.0` to root Control.
- `scenes/ui/SkillTreeScene.gd`: `_on_magic_chosen` uses `queue_free()` and `call_deferred` for `_build_ui`/`_refresh`; close button uses `_vh * 0.065`.
- `scenes/ui/InventoryScene.gd`: `_on_tab_cards` calls `_refresh_cards()`; removed dead disabled-button connect; added `_collection_scroll`/`_deck_scroll` instance vars; `_refresh_cards()` saves/restores scroll positions.
- `scenes/ui/MapEditorScene.gd`: both AcceptDialogs connect `canceled`/`close_requested` → `queue_free`; added `_dirty_flat`/`_dirty_walls` flags and `_process` to batch paint rebuilds; `_paint_tile`/`_erase_tile` set dirty flags instead of direct rebuild calls.
- `scenes/ui/MapViewOverlay.gd`: `_DotLayer` gains `_process(_delta)` calling `queue_redraw()`.
- `scenes/ui/GameOverScene.tscn`: VBox gets `grow_horizontal=2, grow_vertical=2`.
- `scenes/ui/AchievementsScene.gd`: `_unhandled_input` uses `event.is_action_pressed("ui_cancel")` + `set_input_as_handled()`.
- `scenes/ui/AchievementToast.gd`: `_show_next` reads fresh viewport size each call.
- `scenes/ui/LongPressDetector.gd`: `set_process(false)` in `_ready`; enabled only when hold starts; disabled on cancel/threshold; child-button guard added.
- `scenes/ui/ShopScene.gd`: added `_shop_scroll` instance var; `_refresh()` saves/restores scroll position.

## Documentation Updates

UI fixes noted in docs/agent/ui-and-scene-management.md (TID-285 pattern).
