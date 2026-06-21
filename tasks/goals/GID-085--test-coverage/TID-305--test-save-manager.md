# TID-305: Add test_save_manager.gd suite

**Goal:** GID-085
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

No tests exist for `SaveManager`. High-risk untested paths per BID-011:
- Field migration: loading a v1-shaped save dict (missing newer fields) should fill in defaults
- Dirty-flag flush: changes should be batched and flushed within the 2 s window
- Corrupt-file fallback: a malformed JSON `save.json` should not wipe progress (return defaults)

Reference `tests/runner.gd` to register the new suite.

## Plan

## Changes Made

## Documentation Updates
