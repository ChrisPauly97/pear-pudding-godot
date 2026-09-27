# TID-566: Fix Story Waypoint Chain

**Goal:** GID-138
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

After `story_intro_complete` the objective "Leave Madrian" points at madrian (50,50),
an empty grass strip. `chapter1_left_madrian` is set only when taking madrian's
south door (door_9 at 50,99 → maykalene) in `WorldScene._handle_interact`.

## Research Notes

- `game_logic/ObjectiveTracker.gd` — `current_objective(flags)`, most-advanced flag first.
- Wildcard (−1,−1) objectives (camp, fire, Isfig, ambush) are open-world events in `main`
  spawned near the player by `StoryCast`; they have no pointable tile until TID-572.
- Test: `tests/unit/test_objective_tracker*.gd` (grep).

## Plan

Point "Leave Madrian" at madrian's south door (door_9, 50,99 → maykalene), the
door whose use sets `chapter1_left_madrian`. Wild-event beats get real positions in TID-572.

## Changes Made

- `ObjectiveTracker`: "Leave Madrian" tile (50,50) → (50,99).

## Documentation Updates

- None (superseded by the realm objectives in TID-572).
