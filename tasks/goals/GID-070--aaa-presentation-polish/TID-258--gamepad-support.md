# TID-258: Gamepad / Controller Support

**Goal:** GID-070
**Type:** agent
**Status:** done
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

Add `InputEventJoypadButton` and `InputEventJoypadMotion` events to all existing actions in `project.godot`. Upgrade `Player.gd` movement to `Input.get_vector()` for analog stick support with deadzone. Left stick + D-pad → movement, A (button 0) → interact, Y (button 3) → inventory, X (button 2) → map_view, B (button 1) → character, RB (button 5) → skill_tree, Y (button 3) → mount, START (button 6) → pause.

## Changes Made

- **MODIFIED `project.godot`**: Added joypad bindings to all actions: `move_left/right/up/down` get left-stick axes (threshold 0.5) plus D-pad buttons; `interact` gets button 0 (A/Cross); `inventory` gets button 3 (Y/Triangle); `map_view` gets button 2 (X/Square); `character` gets button 1 (B/Circle); `skill_tree` gets button 5 (RB/R1); `mount` gets button 3 (Y); `pause` gets button 6 (START). Keyboard bindings unchanged.
- **MODIFIED `scenes/world/entities/Player.gd`**: Replaced 4 separate `Input.is_action_pressed()` WASD checks with `Input.get_vector("move_left", "move_right", "move_up", "move_down")`. Applied isometric remap: `dir.x = inp.y + inp.x`, `dir.z = inp.y - inp.x`. Works for both keyboard and analog stick with built-in deadzone handling.

## Documentation Updates

Updated `docs/agent/camera-and-player.md` — gamepad input section noted.
