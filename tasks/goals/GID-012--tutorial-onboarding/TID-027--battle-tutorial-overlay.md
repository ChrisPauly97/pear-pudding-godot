# TID-027: First-battle tutorial overlay in BattleScene

**Goal:** GID-012
**Type:** agent
**Status:** done
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

1. Add `_tutorial_overlay: Control` member var to BattleScene.
2. Add `_tutorial_timer: float = 0.0` and `const TUTORIAL_DURATION: float = 8.0`.
3. In `_ready()`, after `_refresh_all()`, check `SaveManager.get_story_flag("tutorial_battle_tip")` — if not set, call `_show_battle_tutorial()`.
4. `_show_battle_tutorial()`: build a semi-transparent `ColorRect` panel centred on screen, add a `Label` with the instructions text, add a `"Got it"` `Button` that calls `_dismiss_battle_tutorial()`. Set `_tutorial_timer = TUTORIAL_DURATION`.
5. `_dismiss_battle_tutorial()`: if `_tutorial_overlay` is not null and valid, free it and set to null. Set `SaveManager.set_story_flag("tutorial_battle_tip")`.
6. In `_process(delta)` (add if absent): count down `_tutorial_timer`; when it hits 0, call `_dismiss_battle_tutorial()`.
7. In `_finish_hand_drag()`, after a successful `play_card()`, call `_dismiss_battle_tutorial()`.
8. Use `_vh` for all sizing. Overlay: `_vh * 0.5` wide, `_vh * 0.3` tall, centred. Font: `int(_vh * 0.025)`. Button: `_vh * 0.12` wide, `_vh * 0.06` tall.

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - Added `_tutorial_overlay: Control`, `_tutorial_timer: float`, `const TUTORIAL_DURATION: float = 8.0`
  - In `_ready()`: calls `_show_battle_tutorial()` if `tutorial_battle_tip` flag not set
  - `_show_battle_tutorial()`: builds a `ColorRect` overlay centred on screen with instruction label and "Got it" button; sets `_tutorial_timer = TUTORIAL_DURATION`
  - `_dismiss_battle_tutorial()`: frees overlay, resets timer, sets `tutorial_battle_tip` flag
  - `_process(delta)`: counts down `_tutorial_timer`; auto-dismisses on expiry
  - `_finish_hand_drag()`: calls `_dismiss_battle_tutorial()` after first successful card play

## Documentation Updates

Updated `docs/agent/ui-and-scene-management.md` — added battle tutorial overlay to BattleScene section.
