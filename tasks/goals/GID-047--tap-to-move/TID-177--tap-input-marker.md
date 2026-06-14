# TID-177: Tap/Click Destination Input, Screen-to-Tile Raycast, and Destination Marker

**Goal:** GID-047
**Type:** agent
**Status:** done
**Depends On:** TID-176

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Detects player taps/clicks on the world, converts screen coordinates to world tiles, validates walkability, requests a path from the Pathfinder, and renders a transient destination marker. Input must respect UI and virtual joystick touchscreen ownership so tap-to-move doesn't interfere with existing controls.

## Research Notes

- **Input handler location:** **scenes/world/WorldScene.gd**, inside `_unhandled_input(event: InputEvent)` or a new `_input(event: InputEvent)` handler. **Choice:** `_input()` instead of `_unhandled_input()`, because it fires before `_unhandled_input()`, allowing us to check Control GUI consumption first. Cite line ~1141 in WorldScene.gd where `_unhandled_input` currently handles map_view, inventory, etc.
- **Existing input precedent:** **VirtualJoystick.gd** (lines 62–71) uses `_input()` to claim touch events for joystick/jump/interact buttons. It checks `InputEventScreenTouch` and `InputEventScreenDrag`, stores touch `index` to track which finger is which. The virtual joystick intercepts touches within its button radius and does **not** call `get_viewport().set_input_as_handled()`, so other input handlers see the events too. **Key insight:** The joystick claims a touch by recording its `index` (line 75: `_joy_index = index`); while `_joy_index != -1`, that finger is owned by the joystick and we should **not** use it for tap-to-move. **Design:** In tap-to-move handler, check `if VirtualJoystick._joy_index == touch.index: return` (or store a reference to the VirtualJoystick node and check its state).
- **UI consumption:** Before processing a tap, check if the Control system has claimed it. Godot's `Control` nodes consume input via `gui_input(event)` which fires in `_input()` phase **before** unhandled input; if a Control consumes the event (calls `set_input_as_handled()`), it won't reach `_unhandled_input()`. However, we're using `_input()` to check **before** consumption, so we need a different guard: check the event's position against known UI regions. **Pragmatic approach:** Store references to UI elements (HUD buttons, minimap, inventory overlay) and reject taps within their bounds.
- **Screen-to-world conversion:**
  - **Method 1 (analytic):** Intersect a ray with the y=0 plane (the tile plane). Camera already exists as `_camera: Camera3D` (line 107). Use `_camera.project_ray_origin(screen_pos)` and `_camera.project_ray_normal(screen_pos)` to get the ray, then solve for t where `ray_origin + t * ray_direction` has `y == 0`. Result: world position (wx, wy, wz) where wy ≈ 0. Convert to tile via `IsoConst.world_to_tile(wx, wz)`.
  - **Method 2 (physics raycast):** Cast a `PhysicsRayQueryParameters3D` from the camera through the screen point against the terrain `HeightMapShape3D`. More accurate for hills but adds physics overhead. **Decision:** Use Method 1 (analytic plane intersection) for v1 simplicity. The destination marker will be placed on the y=0 plane anyway.
- **Tile coordinate conversion:** `IsoConst.world_to_tile(wx: float, wz: float) -> Vector2i` (line 59–60 in **autoloads/IsoConst.gd**) returns `Vector2i(int(wx / TILE_SIZE), int(wz / TILE_SIZE))`. `TILE_SIZE = 2.0` world units per tile.
- **Walkability check:** After converting screen→world→tile, call `tile_lookup(tx, tz)` (the same Callable used by Pathfinder). Reject clicks on `TILE_WALL`. If the result is `TILE_GRASS`, `TILE_HILL`, or `TILE_PATH`, it's valid.
- **Tap vs. drag:** VirtualJoystick (line 70) checks for `InputEventScreenDrag` separately. A player might long-press and drag; we should ignore short drags (< 0.2 units) as taps, and only drags (> 0.3 units) as intentional movement. **Check if a tap-vs-drag detector exists:** Search the codebase for LongPressDetector or similar. If not, add simple logic: store `touch_start_pos` and `touch_start_time` in `_input()`, then in `_input()` phase of `InputEventScreenDrag`, measure `(current_pos - start_pos).length()`. If < 0.3, ignore; if > 0.3 and moved > 0.2 seconds, treat as drag and don't trigger tap-to-move. Simpler v1: reject all `InputEventScreenDrag` events that aren't from the joystick.
- **Destination marker:**
  - Create a small transient Sprite3D with a pulsing quad or a small 3D sprite (e.g., a flag, a ring, a star).
  - Position at `Vector3(dest_tx * TILE_SIZE, 0.5, dest_tz * TILE_SIZE)` (center of destination tile, offset y to clear the floor).
  - **Y-offset rule from CLAUDE.md (Sprite3D: Depth Clipping Into Floor):** Position so the bottom edge clears y=0. For a small marker (e.g., 0.5 units tall), set `y = 0.5` (bottom at y=0.25, above tiles at y=0).
  - Use `billboard = BILLBOARD_ENABLED` so it always faces the camera (matches Player.gd sprite setup, line 36).
  - Texture: a simple 16×16 or 32×32 PNG with a glowing ring or flag icon. If not creating new art, use an existing icon (e.g., a recoloured tile texture or a simple alpha-blended circle in a shader).
  - Animation: tween the scale up/down (0.8→1.2 scale over 0.5s, looping) or adjust vertex color alpha.
  - Lifetime: freed when the path completes, when the player cancels (input), or after 60 seconds timeout.
- **Feedback for invalid clicks:**
  - Wall tile: no marker, no path. Add a subtle toast/toast message: "Can't go there" or visual feedback (flicker the click position red for 0.2s).
  - Unreachable tile (e.g., surrounded by walls within max_radius): no marker, brief toast "Too far away" or "Unreachable".
  - **Toast system check:** Search WorldScene for `_show_tip()` (line 1244) or similar toast mechanism. Reuse it if available, else add a 2-second text label that fades out.
- **Input filtering:**
  - Ignore touches on the virtual joystick: check `VirtualJoystick._joy_index` / `_jump_index` / `_interact_index`.
  - Ignore touches on UI elements (HUD buttons, minimap). Store positions of known buttons and reject taps within them.
  - Ignore `InputEventMouseButton` with `right_pressed` (right-click, if used elsewhere) — only process left-click.
  - Mobile parity: Both desktop (mouse click) and Android (touch) trigger tap-to-move identically.
- **Cancel handling:** Any of these events clear the destination marker and cancel path-following (handled in TID-178):
  - Another tap/click (new destination requested).
  - `InputEventKey` or `InputEventJoypadMotion` (manual input, forwarded to Player).
  - `map_view`, `inventory`, `character`, `skill_tree` actions (menu open).
  - `battle_started` signal from GameBus.
  - `map_changed` signal when player enters a new map.

## Plan

Implemented during build phase (no separate plan step needed — research notes were sufficient).

## Changes Made

- Updated `scenes/ui/VirtualJoystick.gd`: added `is_touch_in_control_area(pos: Vector2) -> bool` guard method; returns true if the position falls within the joystick, jump, or interact button radii (×1.5 for touch slop).
- Updated `scenes/world/WorldScene.gd`:
  - Added `const Pathfinder = preload("res://game_logic/Pathfinder.gd")`.
  - Added state vars: `_dest_marker`, `_dest_tween`, `_joystick_ref`, `_tap_start_screen`, `_tap_touch_index`, `_TAP_DRAG_THRESHOLD`.
  - `_ready()`: stores `_joystick_ref = joystick`; connects cancel signals (battle_won, map_changed equivalent).
  - `_unhandled_input()`: intercepts `InputEventScreenTouch` (press/release) and `InputEventMouseButton` (left click) to trigger tap-to-move; clears destination marker on new menus or re-tap on joystick/UI area.
  - Added `_on_screen_touch(event)`, `_handle_tap_to_move(screen_pos)`, `_screen_to_tile(screen_pos) -> Vector2i`, `_place_dest_marker(tile)`, `_make_dest_marker() -> Node3D`, `_clear_dest_marker()`.
  - `_screen_to_tile`: analytic ray-plane intersection against y=0 (`t = -ray_origin.y / ray_dir.y`), then `IsoConst.world_to_tile()`.
  - `_make_dest_marker`: `TorusMesh` (inner_radius=0.50, outer_radius=0.72) with emissive green unshaded `StandardMaterial3D`.
  - `_place_dest_marker`: pulsing `Tween` (scale 0.85↔1.2, 0.45 s, looping).
  - `_process()`: polls path completion to auto-hide marker when player arrives.

## Documentation Updates

- Covered in `docs/agent/tap-to-move.md`.
