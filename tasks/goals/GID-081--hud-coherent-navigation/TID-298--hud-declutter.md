# TID-298: HUD declutter and button reorganization

**Goal:** GID-081
**Type:** agent
**Status:** done
**Depends On:** TID-296

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The overworld HUD has buttons in every corner. Now that the Menu Hub (TID-296) provides one entry point for the four player screens, the HUD can collapse the five-button right-side stack into a single Menu/Bag button, merge the top-left `Menu` + `II` pause controls, and regroup the loose contextual action buttons (cantrips, Mount) into a coherent cluster. This is the visual/layout cleanup the user asked for ("top left corner is overloaded… make things more natural").

## Research Notes

**All HUD construction is in `WorldScene.gd`** (3554 lines), built into the `_hud: CanvasLayer` ($HUD) inside `_build_hud()`-style code starting ~line 330. Current elements and positions:

| Element | Code | Current position |
|---|---|---|
| `Menu` button → `SceneManager.go_to_menu()` | `WorldScene.gd:342` | top-left `(vh*0.01, vh*0.01)`, size `vh*0.14 × vh*0.07` |
| `II` pause button → `_open_pause()` | `:350` | right of Menu |
| `Inventory` → `GameBus.inventory_requested` | `:362` | right column under minimap |
| `Journal` → `GameBus.journal_requested` | `:370` | right column |
| `Character` → `GameBus.character_requested` | `:378` | right column |
| `Skills` → `GameBus.skill_tree_requested` | `:386` | right column |
| `Mount` → `_toggle_mount()` (`_mount_btn`, starts hidden) | `:394` | right column |
| `[G] Phase` cantrip → `_activate_ghost_phase()` | `:411` | left, `(vh*0.01, vh*0.17)` |
| `[D] Dig` cantrip → `_activate_skeleton_dig()` | `:419` | below Phase |
| `USE` interact btn (android only) | `:427` | center-bottom |
| coord label | `:473` | `(vh*0.01, vh*0.11)` |
| minimap (`Minimap.new()`) | `:482` | top-right, diameter vh*0.20 |
| compass ribbon | `:487` | top-center |
| XP row (level + bar + frac) | `_update_hud()` ~`:576` | bottom-left `(vh*0.01, vh*0.88)` |

`_open_pause()` opens `OverworldPauseOverlay` which already contains Resume / Settings / Save & Quit. So the standalone `Menu` button (which calls `go_to_menu()` = quit to menu directly) is redundant with the pause overlay's Save & Quit — fold it in.

**Reorg plan:**
1. **Top-left → one system control.** Replace the `Menu` + `II` pair with a single ☰/pause button that calls `_open_pause()`. Drop the direct `go_to_menu()` button (Save & Quit in the pause overlay covers it). Keep it small and viewport-relative.
2. **Right stack → one Menu/Bag entry.** Replace the Inventory/Journal/Character/Skills column with a single button (e.g. "Menu" or a bag icon) that calls `SceneManager.open_menu_hub("deck")` (or emits `GameBus.inventory_requested`, which TID-296 routes to the hub). The hub's tab bar provides access to the other three — no need for four buttons.
3. **Action cluster.** Group the contextual *action* buttons — cantrips (`[G] Phase`, `[D] Dig`) and `Mount` — into one consistent cluster (e.g. a vertical or horizontal group in a free corner, visually distinct from the menu entry). These are gameplay actions, not navigation.
4. **Visibility gating (see BID-020).** Cantrip buttons are always built even when the player hasn't unlocked those cantrips; `Mount` is hidden until owned (already correct). Show cantrip buttons only when the corresponding cantrip is available — check `CantripManager` / unlock state (see `docs/agent/card-cantrips.md`). If the gating signal isn't readily available, at minimum hide buttons for cantrips the player can't use.
5. Keep coord label, coin counter, minimap, compass, XP row, and the android `USE` button where they are (they aren't part of the clutter complaint), but verify nothing overlaps after the right column is removed.

**Parity & sizing:** every button must be tap-operable on Android and viewport-relative (CLAUDE.md UI Sizing + Mobile/Desktop Parity sections). Re-apply sizes in `_notification(NOTIFICATION_RESIZED)` where the existing code does.

**Do not** change the hub internals here — this task only changes `WorldScene.gd` HUD construction and what each button triggers. Key bindings are TID-299.

## Plan

Implemented per research notes.

## Changes Made

**Modified:**
- `scenes/world/WorldHUD.gd`:
  - Added `const CantripManager = preload("res://game_logic/world/CantripManager.gd")`.
  - Added `var _ghost_btn: Button`, `var _dig_btn: Button` instance vars.
  - `_create_nav_buttons()`: replaced Menu + II pair with single II/pause button top-left; replaced four-button right column (Inventory/Journal/Character/Skills) with single "Menu" button → `SceneManager.open_menu_hub("deck")`; kept Mount button below Menu.
  - `_create_cantrip_buttons()`: buttons now created as `_ghost_btn`/`_dig_btn` with initial visibility gated on `CantripManager.is_available()`.
  - Added `refresh_action_cluster()`: re-checks cantrip availability and updates visibility; connected to `GameBus.inventory_changed` in `setup()`.

Resolves BID-020 (cantrip buttons always visible regardless of unlock).

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md`: rewrote HUD section to describe new layout (single system/pause button, single Menu/Bag entry, action cluster with gated cantrip buttons).
