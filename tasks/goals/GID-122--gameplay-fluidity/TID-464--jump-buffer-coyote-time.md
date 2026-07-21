# TID-464: Jump Buffer & Coyote Time

**Goal:** GID-122
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none · **Acquired:** — · **Expires:** —

## Context

`Player._physics_process()` only jumps on the exact frame
`Input.is_action_just_pressed("jump") and _was_on_floor` is true
simultaneously. Two standard forgiveness windows are missing:

- **Coyote time**: pressing jump within a short window *after* walking off a
  ledge (already airborne, `_was_on_floor` just went false) is dropped.
- **Jump buffering**: pressing jump slightly *before* landing (still
  airborne, about to touch down) is dropped — the press has to land on the
  exact landing frame.

Both are small, well-established feel fixes (~0.1-0.15s windows) that read
as "the game responds to what I meant," not "the game demands frame-perfect
timing." This is prose/tuning inside the same function already touched by
TID-428 (Locomotion Feel) and the slope-handling notes in CLAUDE.md — no
architectural change.

## Plan

1. Add two timer fields alongside the existing movement constants:
   `_coyote_timer: float = 0.0`, `_jump_buffer_timer: float = 0.0`, and
   constants `_COYOTE_TIME: float = 0.12`, `_JUMP_BUFFER_TIME: float = 0.12`.
2. Each `_physics_process(delta)` tick, before the existing jump check:
   - Decrement both timers by `delta` (clamped at 0).
   - If `Input.is_action_just_pressed("jump")`, set
     `_jump_buffer_timer = _JUMP_BUFFER_TIME`.
   - After computing `_was_on_floor` (already captured before gravity is
     applied): if `_was_on_floor`, reset `_coyote_timer = _COYOTE_TIME`.
3. Replace the jump condition:
   `if Input.is_action_just_pressed("jump") and _was_on_floor:` →
   `if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:` — and on a
   successful jump, zero both timers immediately (`_jump_buffer_timer = 0.0;
   _coyote_timer = 0.0`) so one buffered press can't double-fire across two
   landings.
4. No change to `floor_max_angle` / `floor_snap_length` / slope handling —
   this only widens the input timing window, not the ground detection rule
   CLAUDE.md documents.

## Changes Made

- `scenes/world/entities/Player.gd`: `_coyote_timer` / `_jump_buffer_timer`
  fields + constants; jump condition now checks both timers instead of a
  same-frame `is_on_floor()` match.

## Documentation Updates

- `docs/agent/camera-and-player.md`: note the jump-buffer/coyote-time window
  under "Locomotion Feel (TID-428)".
