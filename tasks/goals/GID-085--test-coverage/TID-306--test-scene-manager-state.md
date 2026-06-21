# TID-306: Add test_scene_manager_state.gd suite

**Goal:** GID-085
**Type:** agent
**Status:** pending
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

## Changes Made

## Documentation Updates
