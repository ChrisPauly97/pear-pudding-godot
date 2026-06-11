# TID-258: Gamepad / Controller Support

**Goal:** GID-070
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The input map in `project.godot` contains only keyboard bindings (WASD movement, E interact, I inventory, M map, etc.). Desktop is a shipping target and many Android devices/handhelds use controllers; zero gamepad support is a hard platform gap.

## Research Notes

- Add joypad events to existing actions in `project.godot` `[input]`: left stick / D-pad → the four move actions, bottom face button (JoyButton A) → interact, top/left face buttons → inventory / map view, Start → pause (TID-256's action). Use `InputEventJoypadButton` and `InputEventJoypadMotion` entries alongside the existing key events so keyboard keeps working unchanged.
- Movement: `scenes/world/entities/Player.gd` reads the move actions — verify it uses `Input.get_vector()` (analog-friendly, gives deadzone handling) or upgrade it to; isometric remap of input directions is described in docs/agent/camera-and-player.md.
- UI focus navigation: Godot's Control focus system (`focus_neighbor_*`, `ui_up/down/left/right/accept/cancel` built-in actions) already supports joypads by default — the work is ensuring every UI scene (menus, inventory/deck builder, settings, battle overlays) has sensible initial focus (`grab_focus()` on first button) and visible focus styling. Battle's drag-to-play card UI is the hard case: BID-010 notes it is hand-rolled drag-and-drop — a full controller battle scheme may need a select-card → select-target flow; scope a minimal viable version (cursor/focus-based card selection) and note limits in the Plan.
- Detect controller hot-plug via `Input.joy_connection_changed` if showing input-specific prompts; a simple first version can skip per-device button glyphs.
- Virtual joystick (`VirtualJoystick.gd`) exists for touch — unrelated, do not regress it.
- Test on desktop headless is impossible for input; rely on input-map correctness plus manual checklist in the task's Changes Made.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
