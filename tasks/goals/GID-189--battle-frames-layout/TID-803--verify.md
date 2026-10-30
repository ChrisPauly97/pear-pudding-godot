# TID-803: Verify with real-fight renders, tests, docs

**Goal:** GID-189
**Type:** agent
**Status:** done
**Depends On:** TID-802

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Prove the layout in a real fight, both layouts in CI.

## Plan

Xvfb renders of a level-1 South Field fight with Frames on (driver kept out of the repo); unit tests for the pure placement; realtime smoke in both layouts.

## Changes Made

- Renders found and fixed: target frame covering the enemy sprite (camera framing), frame tilt from the classic wind-up lean, warning plate over the minion frame (→ top-centre lane), world lunge invisible (→ sprite child).
- `tests/unit/test_frames_layout.gd` (on screen, no overlaps at 16:9 / 20:9 / two enemies; setting opt-in).
- `tests/realtime_battle_smoke.gd` reads `BATTLE_LAYOUT`; layout check is row-aware in frames. CI runs it a second time with `BATTLE_LAYOUT=frames`.
- Suite 3663 pass; realtime (both), in-world, input-flow, world, co-op PvE, net replay smokes clean; gdlint + unsafe-hits clean.

## Documentation Updates

- This file; goal + index.
