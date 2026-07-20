# TID-465: Movement-Feel Doc Sweep + Archive BID-014

**Goal:** GID-122
**Type:** agent
**Status:** done
**Depends On:** TID-464

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

BID-014 ("Camera follows physics body from `_process` without
interpolation") was filed during the GID-064 audit. `tasks/index.md` already
shows its row struck through with "Promoted to GID-084 / TID-303, TID-304" —
GID-084 ("Camera Smoothing") shipped both fixes: TID-303 rewrote
`WorldScene._process()` to lerp `_smooth_camera_target` toward the player
position at rate `20.0 * delta` and pixel-snap the result via
`_snap_to_pixel()`, and TID-304 moved `Player.gd`'s walk animation onto a
real `AnimatedSprite3D` instead of a hand-stepped frame index. Both are
confirmed present in the current tree. The only actual gap, caught during
the GID-122 fluidity audit, is bookkeeping: the backlog file was left behind
in `tasks/backlog/` instead of `tasks/archive/backlog/`, and its index row
was never moved from the open Backlog table into Resolved Backlog, despite
already being struck through — the workflow's backlog rule ("when resolved,
move the file... update tasks/index.md") was only half-applied.

## Plan

1. Move `tasks/backlog/BID-014--camera-follow-stutter.md` to
   `tasks/archive/backlog/`, appending a short "Resolved" note pointing at
   the lerp/pixel-snap camera code and the `AnimatedSprite3D` conversion.
2. `tasks/index.md`: move its row from the open Backlog table to the
   Resolved Backlog table, same format as the other entries there.
3. No source changes — this task is documentation/workflow hygiene that
   depends on TID-464 only in the sense both touch player-movement-feel
   framing in the same goal; it's sequenced last so the goal's doc sweep
   covers everything TID-461-464 touched in one pass.

## Changes Made

- `tasks/backlog/BID-014--camera-follow-stutter.md` moved to
  `tasks/archive/backlog/` with a resolution note.
- `tasks/index.md` updated (row moved from Backlog to Resolved Backlog).

## Documentation Updates

- None beyond the task/backlog bookkeeping above.
