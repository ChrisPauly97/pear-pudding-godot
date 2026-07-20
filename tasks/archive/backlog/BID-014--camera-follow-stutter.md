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

## Resolved (GID-084 / TID-303, TID-304; archived by GID-122 / TID-465)

`tasks/index.md` already carried this row struck through with "Promoted to GID-084
/ TID-303, TID-304," but the file itself was left behind in `tasks/backlog/` and
the index row was never moved into the Resolved Backlog section — a pure
bookkeeping gap, caught during the GID-122 fluidity audit. Both halves are
confirmed fixed in the current tree:

- **Camera smoothing** (TID-303): `WorldScene._process()` lerps
  `_smooth_camera_target` toward the player position at rate `20.0 * delta` and
  pixel-snaps the result via `_snap_to_pixel()` (scenes/world/WorldScene.gd,
  "Camera pixel-snapping" section) — smooths the follow manually rather than
  enabling raw engine physics interpolation, per the suggested resolution's
  alternative path.
- **Walk animation** (TID-304): `Player.gd` builds a real `SpriteFrames` resource
  and drives it through a proper `AnimatedSprite3D` (`_build_sprite()`), not a
  hand-stepped frame index — see `docs/agent/camera-and-player.md` "Locomotion
  Feel (TID-428)".

No further code change needed; this task only fixes the index/archive
bookkeeping, done alongside TID-464 (jump buffer / coyote time) in the same
goal.
