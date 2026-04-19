# TID-088: Pause During Battle

**Goal:** GID-026
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
