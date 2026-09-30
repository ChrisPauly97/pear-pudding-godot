# TID-651: Horse trot cycle

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`mount_horse.png` is static; mounted movement slides. Part of GID-152 (art motion pass).

## Research Notes

- `horse` quadruped rig in `generate_characters.py` (32×32, saddle at `Player._SADDLE_OFFSET_PX`). Add 4-frame trot; saddle point must move with bob — expose per-frame saddle y offsets (table in `game_logic`) so the rider tracks.
- Mount visuals: `scenes/world/modules/Mounts.gd`, `Player.gd` (mount sprite, flip_h offset negation note in CLAUDE.md). Play trot when moving, idle when still. Depth-offset rule for rider-over-horse (CLAUDE.md 'Rider invisible while mounted').

## Plan

Trot frames from the existing horse rig (full leg swing), placed on the idle's canvas so the saddle never moves;
reuse the TID-645 `WalkCycle` on `Player._mount_sprite`.

## Changes Made

- `tools/generate_characters.py`: `horse_frames()`, full leg swing; `mount_horse_walk_1..4.png` (idle unchanged).
- `game_logic/WalkFrames.gd`: horse entry. `scenes/world/entities/WalkCycle.gd`: `for_sprite()` factory.
- `scenes/world/entities/Player.gd`: `MountTrot` child (kept at the 500-line cap by tightening a comment).
- Test: `test_walk_cycle::test_horse_trots_in_place`.
- No per-frame saddle table needed (body rows identical across frames), unlike the task's research note.

## Documentation Updates

- `docs/agent/rideable-mounts.md`: Trot bullet.
