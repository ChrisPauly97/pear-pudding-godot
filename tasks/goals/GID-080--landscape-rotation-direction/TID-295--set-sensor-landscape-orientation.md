# TID-295 — Set sensor_landscape orientation in project.godot

## Lock
Session: landscape-rotation-direction-hyvvgh | Acquired: 2026-06-19 | Expires: never (complete)

## Context
`project.godot` has `viewport_width=1920, viewport_height=1080` (landscape) but no `window/handheld/orientation` key. On Android, Godot's default is equivalent to `landscape` (one fixed direction). Players cannot rotate to the other landscape direction.

## Plan
Add `window/handheld/orientation="sensor_landscape"` to the `[display]` section of `project.godot`. `sensor_landscape` tells Android to allow both landscape-left and landscape-right based on the accelerometer.

## Changes Made
- `project.godot`: added `window/handheld/orientation="sensor_landscape"` to `[display]`
- `tasks/index.md`: added GID-080 row
- `tasks/goals/GID-080--landscape-rotation-direction/goal.md`: created
- `tasks/goals/GID-080--landscape-rotation-direction/TID-295--set-sensor-landscape-orientation.md`: created (this file)

## Documentation Updates
No agent doc changes needed — this is a one-line project setting.

## Status
done
