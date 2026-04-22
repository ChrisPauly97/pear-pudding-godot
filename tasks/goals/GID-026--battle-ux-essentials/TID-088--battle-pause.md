# TID-088: Pause During Battle

**Goal:** GID-026
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

There is no way to pause during a battle. On mobile this is critical — phone calls, notifications, and context switches happen constantly. Without pause, any interruption forces the player to lose their turn or the entire battle.

## Research Notes

- `scenes/battle/BattleScene.gd` — add a pause button (top-right corner, small) and a `_pause_battle()` method
- Godot `get_tree().paused = true` pauses all nodes with `process_mode != PROCESS_MODE_ALWAYS` — use this to pause the battle loop
- Pause overlay: a CanvasLayer with `process_mode = PROCESS_MODE_ALWAYS` containing:
  - "Paused" title
  - "Resume" button → `get_tree().paused = false`, hide overlay
  - "Settings" button → open SettingsScene (or inline volume sliders)
  - "Return to Menu" button → confirm dialog ("Your battle progress will be lost") → unpause → `SceneManager.go_to_menu()`
- Pause button: visible during player turn and enemy turn (always accessible); sized per CLAUDE.md (icon button ~5% vh square)
- Keyboard shortcut: Escape key toggles pause on desktop
- Mobile: the pause button is the only entry point (Escape key not available on Android)
- BattleScene should also auto-pause when the app loses focus (`NOTIFICATION_APPLICATION_FOCUS_OUT`)

## Plan

- Add `_paused: bool` and `_pause_overlay: CanvasLayer` to BattleScene
- `_add_pause_button()` — inserts "II" button at top of SidePanel, `process_mode = ALWAYS`
- `_show_pause_overlay()` — sets `get_tree().paused = true`, creates CanvasLayer layer 200 with full-screen backdrop, panel containing Resume/Settings/Return to Menu buttons; all buttons `PROCESS_MODE_ALWAYS`
- `_hide_pause_overlay()` — sets `get_tree().paused = false`, frees CanvasLayer
- `_toggle_pause()` — toggle between show/hide
- `_confirm_return_to_menu()` — inline confirm dialog inside the pause overlay
- `_open_settings_from_pause()` — instantiates SettingsScene into pause overlay's CanvasLayer
- `_notification()` — auto-pause on `NOTIFICATION_APPLICATION_FOCUS_OUT`
- `_input()` — Escape key calls `_toggle_pause()` (skip if inspect overlay open)

## Changes Made

- `BattleScene.gd`: added `_paused`, `_pause_overlay`, `_add_pause_button()`, `_toggle_pause()`, `_show_pause_overlay()`, `_hide_pause_overlay()`, `_open_settings_from_pause()`, `_confirm_return_to_menu()`, `_notification()` handling focus-out auto-pause; Escape key handling in `_input()`
- Pause button added to top of SidePanel (process_mode ALWAYS so it works during AI turn)
- SettingsScene opened inline from pause overlay

## Documentation Updates

Updated `docs/agent/battle-system.md` with pause system details.
