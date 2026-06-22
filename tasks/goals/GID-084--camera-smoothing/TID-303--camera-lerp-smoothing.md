# TID-303: Add lerp smoothing to camera follow

**Goal:** GID-084
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`WorldScene.gd:1028` sets `_camera.position = _player.position + Vector3(20, 20, 20)` directly each `_process` frame. On 90/120 Hz displays, this samples the physics body position between ticks, causing micro-stutter.

Fix: maintain a `_smooth_camera_target: Vector3` and lerp toward it each frame with a high speed factor (e.g. 20.0 × delta), so the camera glides smoothly at any refresh rate. Never touch camera rotation per CLAUDE.md.

## Plan

1. Add `var _smooth_camera_target: Vector3` field alongside the weather-tint variables.
2. In `_spawn_player()` after line 438, set `_smooth_camera_target = _player.position + Vector3(20, 20, 20)` so the camera starts already at the right position (no initial snap).
3. In `_process()` at line 1286, replace the direct assignment with:
   ```
   var _cam_target := _player.position + Vector3(20, 20, 20)
   _smooth_camera_target = _smooth_camera_target.lerp(_cam_target, clampf(20.0 * delta, 0.0, 1.0))
   _camera.position = _snap_to_pixel(_smooth_camera_target)
   ```
   This keeps pixel-snapping for crisp pixel-art but the lerped intermediate value makes the movement frame-smooth.

## Changes Made

- `scenes/world/WorldScene.gd`: Added `_smooth_camera_target: Vector3` class field (line ~131).
- `scenes/world/WorldScene.gd`: `_spawn_player()` now initialises `_smooth_camera_target` to the starting offset and calls `_snap_to_pixel` on it (replacing the bare direct assignment).
- `scenes/world/WorldScene.gd`: `_process()` now lerps `_smooth_camera_target` toward the per-frame target with `clampf(20.0 * delta, 0.0, 1.0)` before passing it to `_snap_to_pixel`. Camera rotation is never touched, preserving the baked isometric angle.

Pre-existing test failures (12) are unrelated to this task — they are caused by missing pixel-art texture files (`grass_pixel.png`, etc.) and missing SaveManager static functions, both from in-flight GID-089 and GID-085 tasks.

## Documentation Updates

None required — camera follow behaviour is documented in `docs/agent/camera-and-player.md`; the lerp smoothing is a bug-fix-level enhancement that doesn't change the documented architecture.
