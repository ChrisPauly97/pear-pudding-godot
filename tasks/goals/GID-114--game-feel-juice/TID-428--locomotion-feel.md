# TID-428: Locomotion Feel — Accel/Decel, Walk Dust, Landing Feedback, Anim-Synced Footsteps

**Goal:** GID-114
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The player is the thing you touch for hours, and its motion is analytically
stiff. `scenes/world/entities/Player.gd:_physics_process` sets
`velocity.x = dir.x * move_speed` directly — movement starts and stops in a
single physics frame. Camera smoothing shipped in GID-084, so the camera now
glides while the body it follows snaps; the body is the remaining source of
rigidity. Additional gaps:

- Footsteps tick a fixed `_footstep_timer = 0.4` (Player.gd:196-200) with no
  connection to the 6 FPS walk animation — feet and sound drift apart (and the
  SFX is currently silent anyway; TID-425 fixes audibility independently).
- Dust particles exist (`_dust_particles`, Player.gd:130-148) but emit **only
  while mounted** (Player.gd:218).
- Jump/landing (`JUMP_VELOCITY`, `GRAVITY`, Player.gd:185-193) has zero
  feedback — no dust, no sprite squash, no sound.

## Research Notes

**Acceleration/deceleration:**
- Replace direct velocity assignment with `move_toward`-based ramping:
  `velocity.x = move_toward(velocity.x, dir.x * move_speed, ACCEL * delta)`
  (same for z). Suggested: `ACCEL ≈ 40.0` (reaches 6 u/s in ~0.15s),
  `DECEL ≈ 50.0` (slightly snappier stop) — tune so it feels responsive, not
  floaty; this is an isometric RPG, not a platformer.
- Tap-to-move interplay: waypoint arrival check uses `_WP_ARRIVE_DIST_SQ = 0.09`
  (Player.gd:36) — deceleration must not cause orbiting around the final
  waypoint. Keep full steering authority while pathing (only ramp on
  start/stop), or shrink decel near the terminal waypoint. Verify with the
  existing pathfinding tests + manual reasoning; `cancel_path()` on manual
  input must still feel instant.
- `_is_moving` (drives walk/idle anim swap, Player.gd:203) should key off
  *input/path intent* (`dir`), not residual velocity, so the idle anim doesn't
  lag the stop.

**Walk dust (unmounted):**
- Reuse `_dust_particles` for walking too: lower `amount`/opacity when on foot
  vs mounted (mounted kicks more dust). Emit when `_is_moving and is_on_floor()`.
  Tint: current `Color(0.72, 0.60, 0.42, 0.75)` is sandy — acceptable
  everywhere as a v1; per-biome tint is a stretch goal.

**Landing feedback:**
- Track airborne state: was `not is_on_floor()` last frame and `is_on_floor()`
  now, with downward velocity beyond a threshold (~4.0) → landing. On landing:
  one-shot dust burst (restart `_dust_particles` with a burst or a dedicated
  one-shot emitter), `play_sfx("land")` (new key from TID-425 — graceful no-op
  until it lands, so no hard dependency), and a quick sprite squash:
  tween `_sprite.scale` to `(1.08, 0.9)` and back over ~0.15s.
  CAUTION: `AnimatedSprite3D` — scale the node, never touch its `position.y`
  math (feet anchoring at Player.gd:107-108) and never `modulate` a bare Node3D
  (CLAUDE.md rule; `_sprite` is a SpriteBase3D so `modulate` is legal, scale is
  simpler).
- Jump takeoff: tiny stretch `(0.94, 1.06)` for symmetry (cheap, optional).

**Anim-synced footsteps:**
- `AnimatedSprite3D.frame_changed` signal: connect once in `_build_sprite()`;
  when `animation == "walk"` and the new frame is a contact frame (frames 0
  and 2 of the 4-frame cycle), fire `play_sfx("footstep")`. Delete
  `_footstep_timer`. At 6 FPS this gives a step every ~0.33s while walking —
  close to today's cadence but locked to the visual. Mounted: suppress
  footsteps (hooves later; silence is better than wrong).

**Multiplayer note:** remote avatars (`AvatarSprite.gd`) mirror position only —
no changes needed there; keep all new feel logic local-only in Player.gd.

**Constraints:**
- Variant inference: annotate `move_toward` / `max` results (CLAUDE.md).
- Player.gd is preloaded by WorldScene — parse error = blue screen; run the
  headless import after every edit.
- Physics changes can break `tests/` movement/pathfinding suites — run the full
  headless test runner (`godot --headless --path . -s tests/runner.gd`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
