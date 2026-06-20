# TID-275: SceneManager overlay plumbing dedup

**Goal:** GID-074
**Type:** agent
**Status:** done
**Depends On:** —

## Context

SceneManager.gd (autoloads/SceneManager.gd, 492 lines) repeats identical overlay open/close handler pairs 5× plus a 6-overlay cleanup block.

## Research Notes

- **Open handlers** (state check + instantiate + add_child + connect closed + set state): _on_inventory_requested 386–392, shop 402–408, journal 418–424, character 434–440, skill_tree 450–456. Close handlers (state check + queue_free + reset state): 394–400, 410–416, 426–432, 442–448, 459–465. ~100 lines → generic _open_overlay(packed_scene, state) / _close_overlay() helpers + a small overlay table (~30 lines)
- **_exit_world_cleanup** (201–225): repeated `if _X_overlay != null: queue_free; null` for 6 overlays + saved_world_scene → track open overlays in an Array/Dictionary and loop
- **Keep the State enum gating semantics exactly:** overlays only open from State.WORLD, closing returns to WORLD
- **Coordination:** GID-073 (UI Overlay Framework) standardizes the scene-side closed-signal convention — this task only touches SceneManager's side; the contract (instantiate, add to current_scene, listen for `closed`) must stay compatible. GID-064 TID-229 (lambda signal-connection leaks & overlay ownership) also touches overlay lifecycle — re-verify if it landed

## Plan

Add `_overlays: Dictionary` (State → Node) to track the 7 WORLD-state overlays. Add `_open_overlay()` and `_close_overlay()` generic helpers. Replace 7 open/close handler pairs and the 5-field null-check block in `_exit_world_cleanup` with the new pattern. Keep `_achievements_overlay` (MENU state), `_battle_overlay`, `_pack_open_overlay`, `_spire_draft_overlay`, and `_defeat_overlay` as named vars (each has non-standard lifecycle).

## Changes Made

- **Removed** 7 named overlay vars (`_inventory_overlay`, `_shop_overlay`, `_journal_overlay`, `_character_overlay`, `_skill_tree_overlay`, `_bounty_board_overlay`, `_blacksmith_overlay`).
- **Added** `var _overlays: Dictionary = {}` tracking all WORLD-state overlays by State key.
- **Added** `_open_overlay(packed_scene, overlay_state, setup: Callable = Callable()) -> void`: guards WORLD state, instantiates, runs optional setup Callable, adds to current_scene, connects `closed` → `_close_overlay`, stores in `_overlays`, sets state.
- **Added** `_close_overlay(overlay_state: State) -> void`: guards state match, queue_frees, erases from `_overlays`, returns to WORLD.
- **Replaced** 7 open/close function pairs (~75 lines) with 7 one-or-two-line callers of `_open_overlay`.
- **Simplified** `_exit_world_cleanup`: 5-field null-check block replaced with `for overlay in _overlays.values(): overlay.queue_free(); _overlays.clear()`. `_spire_draft_overlay` and `_pack_open_overlay` cleanup blocks retained.
- **Updated** `_on_pack_purchased` to use `_overlays.get(State.SHOP)` instead of `_shop_overlay`.

## Documentation Updates

`docs/agent/ui-and-scene-management.md` may need a note about the `_overlays` dict pattern if updated in a follow-up; not critical for a refactor.
