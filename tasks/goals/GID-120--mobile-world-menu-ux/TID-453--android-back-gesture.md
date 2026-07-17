# TID-453: Android Back Gesture Routing

**Goal:** GID-120
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

`quit_on_go_back` defaults to `true` and no `_notification` handler exists for
`NOTIFICATION_WM_GO_BACK_REQUEST`, so the Android back gesture hard-quits the app
from any screen. Escape is bound to both `pause` and `ui_cancel`, and every layer
already closes on Escape: WorldScene `_unhandled_input` (`pause` action →
`_open_pause`), BattleScene `_input` (KEY_ESCAPE → pause toggle), BaseOverlay
`_input` (`ui_cancel` → `_close`), MenuHub (`ui_cancel`).

## Plan

1. `project.godot`: `application/config/quit_on_go_back=false`.
2. `SceneManager._notification`: on `NOTIFICATION_WM_GO_BACK_REQUEST` →
   `_handle_back_request()`.
3. `_handle_back_request()`: at `State.MENU`, double-press-to-quit (transient
   "Press back again to exit" label, 2 s window, then `get_tree().quit()`);
   everywhere else synthesize an Escape key press+release via
   `Input.parse_input_event` so all existing Escape paths handle it.

## Changes Made

- `project.godot`: `quit_on_go_back=false` under `[application]`.
- `SceneManager`: `_notification()` handler, `_handle_back_request()`,
  `_synthesize_escape()`, double-back-to-quit at the main menu with a transient
  toast layer (`_back_quit_deadline_ms`).

## Documentation Updates

- `docs/agent/ui-and-scene-management.md`: back-gesture section under GID-120.
