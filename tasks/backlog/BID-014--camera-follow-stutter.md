# BID-014: Camera follows physics body from _process without interpolation

**Category:** code-smell
**Discovered During:** GID-064 audit

## Description

The isometric camera follow runs in `_process` (scenes/world/WorldScene.gd:1028) off a
physics-driven CharacterBody3D without physics interpolation; on 90/120 Hz Android
displays this produces visible micro-stutter (camera samples the body's position at
render rate while the body only moves at the physics tick).

Related low item: the player's 4-frame walk animation is hand-stepped in
`_physics_process` (scenes/world/entities/Player.gd) instead of using
`AnimatedSprite3D`/`SpriteFrames`.

## Evidence

- scenes/world/WorldScene.gd:1028
- scenes/world/entities/Player.gd:72-76

## Suggested Resolution

Enable Godot's physics interpolation project setting (4.x supports 3D interpolation) or
smooth the camera target manually (lerp toward the body position in `_process`). Move
the walk animation to AnimatedSprite3D. Verify against the CLAUDE.md camera rule (fixed
iso rotation, position-only updates).
