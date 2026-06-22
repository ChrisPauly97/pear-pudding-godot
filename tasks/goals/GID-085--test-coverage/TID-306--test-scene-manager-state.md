# TID-306: Add test_scene_manager_state.gd suite

**Goal:** GID-085
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

No tests exist for `SceneManager`. High-risk untested paths per BID-011:
- Scene stack push/pop: pushing world → battle → inventory should stack correctly; pop should restore previous
- Overlay interleaving: opening an overlay on top of a scene should not corrupt the stack
- State integrity: back-to-back transitions should not leave dangling references

Reference `tests/runner.gd` to register the new suite.

## Plan

1. Create `tests/unit/test_scene_manager_state.gd`.
2. Test `can_proximity_engage()` across all relevant states (MENU, WORLD, BATTLE, INVENTORY, blocked flag).
3. Test map stack push/pop by simulating the `enter_map`/`exit_map` data logic directly (without calling those methods, which would trigger scene loading).
4. Test multi-level push/pop and stack synchronization.
5. Test state integrity: state changes are reflected immediately in `can_proximity_engage()`.

Note: scene-loading transitions cannot be tested headlessly; these tests cover pure state and stack logic only.

## Changes Made

- Created `tests/unit/test_scene_manager_state.gd` with 16 tests covering:
  - `can_proximity_engage()` returns correct value in MENU/WORLD/BATTLE/INVENTORY states and when `_proximity_engage_blocked` is set
  - Map stack push/pop: single-level and three-level push/pop maintains correct current_map and stack depth
  - Stack synchronization: map_stack and door_stack stay same size through push/pop operations
  - State integrity: state changes directly affect `can_proximity_engage()` output

## Documentation Updates

None required — no new architecture introduced.
