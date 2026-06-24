# TID-340: Tap-to-move drag steering (update target while dragging)

**Goal:** GID-093
**Type:** agent
**Status:** done
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

## Lock

- **Session:** claude/work-task-gid-093-o3wpfd
- **Acquired:** 2026-06-24T12:00:00Z
- **Expires:** 2026-06-24T12:30:00Z

## Plan

1. Add `var _drag_last_tile: Vector2i = Vector2i(-9999, -9999)` to WorldScene.
2. Modify `InputEventScreenDrag` handler: instead of abandoning the tap on threshold-exceed, check joystick guard first; if the drag is outside joystick area and threshold is exceeded, call `_handle_tap_to_move()` (throttled by tile change).
3. Add `InputEventMouseMotion` handler: while left button held, call `_handle_tap_to_move()` on tile change.
4. Reset `_drag_last_tile` on new touch press and mouse button press.

## Changes Made

- `scenes/world/WorldScene.gd`: added `var _drag_last_tile: Vector2i`; replaced the "abandon tap on threshold" drag handler with a steering handler that calls `_handle_tap_to_move()` on tile change; added `InputEventMouseMotion` handler for mouse drag-steering; reset `_drag_last_tile` on new touch press and mouse button press.

## Documentation Updates

Updated `docs/agent/tap-to-move.md`: documented drag steering (touch + mouse) and joystick-area guard.

## Lock

- **Session:** none
- **Acquired:** —
- **Expires:** —
