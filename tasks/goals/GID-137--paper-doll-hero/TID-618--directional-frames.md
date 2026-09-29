# TID-618: Directional Hero Frames (back view, attack/cast pose)

**Goal:** GID-137
**Type:** agent
**Status:** pending
**Depends On:** TID-563

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Split from TID-563. The hero has one facing (right, mirrored by `flip_h`).
The camera is fixed iso, so walking "north" (screen-up) should show the back.

## Research Notes

- `PaperDoll.ANIMS` / `render_pose` draw a right-facing side view; a back view
  needs its own head (hair covers the face), torso (no collar/buckle) and gear
  draw paths (helmet back, cloak over the body, weapon behind).
- `HeroAnim.pick()` chooses the animation; `Player.gd` would pick `walk_back`
  / `idle_back` from the velocity's screen-up component (camera forward is
  `(−1, 0, −1)`, see compass notes in CLAUDE.md).
- Optional: a cast pose for the battle token (`RealtimeVisuals.gd`).
- `build_frames()` caches per look — added animations multiply texture count;
  keep poses few.
