# TID-618: Directional Hero Frames (back view, attack/cast pose)

**Goal:** GID-137
**Type:** agent
**Status:** done
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

## Plan

1. `PaperDoll.BACK_ANIMS` (`idle_back`, `walk_back`) reuse the side poses with a
   `back` pose key; `build_frames` renders them (9 more textures per look).
2. Back rendering: hair-covered head, no front-only details, items behind the
   body, cloak over it, helmets without face details.
3. `HeroAnim.faces_away` / `facing` / `is_walk`; Player + RemotePlayer pick the
   twin; footsteps and hero bob accept either walk.
4. Cast pose for the battle token left out (token is a static idle texture).

## Changes Made

- `PaperDoll.gd` (BACK_ANIMS, `back` pose key, back branch in `render_pose`,
  `_draw_torso(back)`), `PaperDollGear.gd` (`_draw_head_back`, `_draw_cloak_over`,
  `_draw_helmet(back)`), `HeroAnim.gd`.
- `Player.gd` (`_back_facing`; trimmed a blank line to stay at 500), `RemotePlayer.gd`,
  `CharacterPresence.gd` (`is_walk`).
- Tests: `test_paper_doll` (back frames exist, eye hidden, gear changes the back
  view; `faces_away` / `facing` / `is_walk`).

## Documentation Updates

- `camera-and-player.md` → Back view.
