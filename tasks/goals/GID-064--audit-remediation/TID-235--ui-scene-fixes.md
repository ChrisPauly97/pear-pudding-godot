# TID-235: UI scene fixes

**Goal:** GID-064
**Type:** agent
**Status:** pending
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
1. **ShopScene root has no anchors (high).** `scenes/ui/ShopScene.tscn:5-6`: root
   Control lacks `anchors_preset = 15` (every other UI .tscn sets it) → root rect is
   0×0, the full-rect `bg` ColorRect (ShopScene.gd:29-32) and root `mouse_filter = STOP`
   (ShopScene.gd:21) anchor to nothing: no dim backdrop, and taps outside the panel pass
   through to the world. Fix: add full-rect anchors like InventoryScene.tscn.
2. **Mid-signal free() (high).** `scenes/ui/SkillTreeScene.gd:126-127`: `child.free()`
   inside `_on_magic_chosen`, invoked from a `pressed` signal of a Button being freed —
   "object freed during signal emission", crash-prone. Fix: `queue_free()` + deferred
   `_build_ui()`.
3. **Stale Cards tab (medium).** `scenes/ui/InventoryScene.gd:631-633`: `_on_tab_cards`
   only toggles visibility; after crafting (`_do_craft` :585 refreshes only the craft
   list), the Cards tab shows stale collection/coins/essence. Fix: call
   `_refresh_cards()` in `_on_tab_cards`.
4. **Map editor dialog leaks (medium).** `scenes/ui/MapEditorScene.gd:467-486, 488-503`:
   `_new_map_dialog`/`_show_map_list` AcceptDialogs are only freed on confirm/selection —
   cancelling leaks one per open; the LineEdit is a raw child overlapping the dialog's
   built-in layout. Fix: connect `canceled`/`close_requested` → `queue_free`; place the
   LineEdit properly (or `register_text_enter`).
5. **Map view dots never update (medium).** `scenes/ui/MapViewOverlay.gd:44-46, 145-154`:
   the dot layer draws once, never `queue_redraw()`n, while the world keeps processing —
   player/enemy dots go stale immediately. Fix: `_process` on `_DotLayer` calling
   `queue_redraw()` (cheap) while visible.
6. **GameOver off-center (medium).** `scenes/ui/GameOverScene.tscn` VBox (~lines 18-25):
   anchored to center but lacks `grow_horizontal/vertical = 2` (MenuScene.tscn has
   them) → content expands down-right from the center point. Fix: add grow flags.
7. **SkillTree close button vw-vs-vh (low).** `scenes/ui/SkillTreeScene.gd:228-230`:
   sized `_vw * 0.13` square (≈250 px at design width), crushing the title stack —
   almost certainly meant vh. Fix: `_vh * 0.065` like other close buttons.
8. **Achievements Esc handling (low).** `scenes/ui/AchievementsScene.gd:142-144`: checks
   `keycode == KEY_ESCAPE` without `event.pressed`, never `set_input_as_handled()`,
   bypasses `ui_cancel` → Android back button won't close it. Fix:
   `event.is_action_pressed("ui_cancel")` + handled.
9. **AchievementToast stale viewport cache (low).** `scenes/ui/AchievementToast.gd:17-18,
   92-98`: `_vw`/`_vh` cached once at autoload `_ready`; after resize/orientation change
   the toast animates to the wrong position. Fix: read viewport size in `_show_next`.
10. **Dead disabled-button connect (low).** `scenes/ui/InventoryScene.gd:495-497`:
    connects `pressed` on a button just set `disabled = true`. Drop the connect.

Performance:
11. **Inventory O(n²) full rebuild per tap (high).** `scenes/ui/InventoryScene.gd:251-294`:
    every add/remove/sell/scrap/combine (:449, :625, :629, :687, :693) frees all
    collection+deck rows and rebuilds; each non-unique row calls `_count_available`
    (:440 → :615-621) re-scanning the whole owned-cards array → O(n²) per tap, frame
    hitch, and ScrollContainer resets to top. Fix: precompute per-(template,rarity)
    counts once per refresh, update rows incrementally (move one row between lists,
    update affected labels), and/or preserve `scroll_vertical` across refresh.
12. **Shop full rebuild per purchase (medium).** `scenes/ui/ShopScene.gd:88-142`:
    `_refresh()` after every purchase rebuilds the whole list (cards + 4 equipment
    sections + detectors), scroll jumps to top. Fix: update only the bought row, coin
    label, and Buy-button disabled states.
13. **LongPressDetector (medium).** `scenes/ui/LongPressDetector.gd:13-18, 20`: one per
    list row with `_process` always on and `_input` receiving every event (N rows = N
    per-frame calls + N callbacks per touch); also fires `long_pressed` AND the inner
    button's `pressed` (double action) when holding a child button. Fix:
    `set_process(false)` until a press starts; gate on the parent's `_gui_input` / check
    the press didn't land on a child button. TID-234 adopts the fixed detector for
    battle cards.
14. **Map editor paint stroke (medium).** `scenes/ui/MapEditorScene.gd:125-157, 409-426`:
    every painted tile during a drag loops all 10,000 tiles and rewrites an entire
    MultiMesh half (instance_count reset + per-instance transforms) per
    InputEventScreenDrag. Fix: persistent instance arrays, update only the changed
    tile's instance (or batch once per frame via a dirty flag).

Deliberately deferred to backlog (do not do here): shared Theme resource + overlay
boilerplate dedup (BID-009), `_weapon_effect_summary` dedup (part of BID-009).

Verification: manual flow checklist (shop backdrop dims and blocks taps; craft → Cards
tab fresh; cancel map dialogs repeatedly → node count stable; inventory tap keeps scroll
position). Run full suite.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
