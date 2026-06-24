# TID-340: Tap-to-move drag steering (update target while dragging)

**Goal:** GID-093
**Type:** agent
**Status:** pending
**Depends On:** —

## Context

Tap-to-move only commits a target on touch-release, and a drag cancels the tap entirely.
The request: add a drag handler so the move target adjusts continuously as the finger
drags, with the player following in real time.

## Research Notes

- Input handling in `WorldScene._unhandled_input` (scenes/world/WorldScene.gd ~1858):
  - `InputEventScreenTouch` → `_on_screen_touch` (1871). On press it records
    `_tap_start_screen` / `_tap_touch_index`; on release, if drag distance
    `< _TAP_DRAG_THRESHOLD` it calls `_handle_tap_to_move(touch.position)` — otherwise it's
    discarded.
  - `InputEventScreenDrag` (1860): if the drag exceeds `_TAP_DRAG_THRESHOLD` it sets
    `_tap_touch_index = -2` to **abandon** the tap (treats it as a joystick drag).
  - `InputEventMouseButton` LEFT pressed → `_handle_tap_to_move(mb.position)` immediately
    (desktop, 1867).
- `_handle_tap_to_move(screen_pos)` (WorldScene.gd:2854) raycasts screen→tile and sets the
  move destination + spawns the destination marker (see docs/agent/tap-to-move.md: A*
  `Pathfinder`, screen-to-tile raycast, destination marker, path following).
- Joystick guard: `_on_screen_touch` rejects touches inside the virtual joystick area via
  `_joystick_ref.is_touch_in_control_area(touch.position)` (1876). Drag steering must keep
  this guard so steering doesn't fight the joystick.
- Direct-path movement context: GID-082 made tap-to-move use a direct path; re-targeting
  mid-drag should just re-issue `_handle_tap_to_move` with the new position each drag event
  (throttle if needed to avoid recomputing the path every event).
- Desktop parity (CLAUDE.md): support mouse drag too — while the left button is held and the
  mouse moves, update the target the same way (mirror the touch behaviour with
  `InputEventMouseMotion` + `Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)`).
- Design decision for Plan: when a drag starts outside the joystick, treat it as *steering*
  (continuously call `_handle_tap_to_move`) rather than abandoning the tap — but preserve a
  way for genuine joystick/camera gestures to win. Confirm there's no camera-pan gesture
  that this would break.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._ Update `docs/agent/tap-to-move.md` to document drag
steering (touch + mouse) and the joystick-area guard interaction.
