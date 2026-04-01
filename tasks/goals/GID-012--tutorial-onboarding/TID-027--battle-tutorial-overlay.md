# TID-027: First-battle tutorial overlay in BattleScene

**Goal:** GID-012
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players have no explanation of the TCG battle mechanics on their first fight. This task adds a brief, dismissible tutorial overlay shown only on the player's first battle. It explains drag-to-play and tap-to-attack, then auto-dismisses after 8 seconds or immediately when the player plays their first card. The flag `tutorial_battle_tip` stored in `SaveManager.story_flags` ensures it appears exactly once.

## Research Notes

**Key files:**
- `scenes/battle/BattleScene.gd` — target file
- `autoloads/SaveManager.gd` — `set_story_flag` / `get_story_flag` (same API used by TID-024)

**BattleScene structure (from `scenes/battle/BattleScene.gd`):**
- Extends `Control` (it's a 2D UI scene)
- `_vh: float` set in `_ready()` from `get_viewport().get_visible_rect().size.y`
- `@onready var _turn_label: Label = $SidePanel/TurnLabel` — existing label for reference sizing
- Card play happens in `_finish_hand_drag()` (~line 103): calls `_state.players[0].play_card(_hand_drag_card)` then `_refresh_all()`
- Drag flow: `_start_hand_drag()` → mouse motion moves ghost → `_finish_hand_drag()` or `_cancel_hand_drag()`

**Overlay design:**
- A `PanelContainer` or `ColorRect` added to the scene root in `_ready()`, centered on screen
- Inside: a `Label` with two-line text:
  - Desktop: `"Drag a card from your hand to the board to play it.\nTap an enemy minion to attack with your minion."`
  - Android: `"Drag a card from your hand to the board to play it.\nTap an enemy minion to attack with your minion."` (same — drag works the same on touch)
- A small `"Got it"` Button below the label to dismiss immediately
- Auto-dismiss timer: 8 seconds (`create_tween()` or a `float` countdown in `_process()`)
- On dismiss: `SaveManager.set_story_flag("tutorial_battle_tip")` + hide/free the overlay node

**Show condition in `_ready()`:**
```gdscript
if not SaveManager.get_story_flag("tutorial_battle_tip"):
    _show_battle_tutorial()
```

**Dismiss on first card play:** In `_finish_hand_drag()`, after a successful `play_card()`, call `_dismiss_battle_tutorial()` if the overlay is still visible.

**Sizing:** Use `_vh` (already computed in `_ready()`) for all dimensions — overlay panel `vh * 0.4` wide, `vh * 0.25` tall, centred via `anchors_preset = PRESET_CENTER` or manual position calculation. Font size `int(_vh * 0.022)`.

**Flag key:** `tutorial_battle_tip` in `SaveManager.story_flags`

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
