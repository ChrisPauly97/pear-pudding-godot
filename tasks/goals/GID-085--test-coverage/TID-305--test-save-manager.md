# TID-305: Add test_save_manager.gd suite

**Goal:** GID-085
**Type:** agent
**Status:** done
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

1. Create `tests/unit/test_save_manager.gd` extending `test_case.gd`.
2. Test `_apply_migrations` (static) using a preloaded script reference:
   - v0 dict → all fields filled with defaults, version bumped to CURRENT_SAVE_VERSION
   - v1 dict (string IDs in player_deck/owned_cards) → card instances promoted to dicts
   - partial version dict (e.g. v5) → only post-v5 fields added, earlier ones preserved
3. Test dirty-flag lifecycle:
   - `_dirty` is false on a freshly-manipulated-from-outside state
   - After `update_position()`, `_dirty` is true
   - `_flush_if_dirty()` with `_loaded=false` leaves `_dirty` unchanged
4. Test corrupt-file fallback:
   - Write invalid JSON to `user://test_corrupt_sm.json`
   - `SaveManager._read_save_json(path)` returns null
   - Write HMAC-wrapped JSON with mismatched signature → also returns null
5. Runner auto-discovers the file; no registration needed.

## Changes Made

- Created `tests/unit/test_save_manager.gd` with 20 tests covering:
  - `_apply_migrations` from v0 (all fields filled, version bumped to CURRENT)
  - `_apply_migrations` from v1 (string card IDs promoted to instance dicts with uid keys)
  - Partial-version migration (post-v5 fields added, earlier preserved)
  - Dirty-flag: `update_position()` sets `_dirty`; `_flush_if_dirty()` no-ops when `_loaded=false`
  - Corrupt-file fallback: malformed JSON, missing file, and HMAC mismatch all return null
  - Valid unwrapped JSON parses correctly (backward-compat path)

## Documentation Updates

None required — no new architecture introduced.
