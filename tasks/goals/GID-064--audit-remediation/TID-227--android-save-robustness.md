# TID-227: Android save robustness

**Goal:** GID-064
**Type:** agent
**Status:** pending
**Depends On:** TID-226

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The save system can silently lose or wipe progress on Android, the primary platform:

1. **No background flush.** `SaveManager._notification` (autoloads/SaveManager.gd:113-115)
   handles only `NOTIFICATION_WM_CLOSE_REQUEST` and `NOTIFICATION_EXIT_TREE`. On Android
   the app is backgrounded (onPause) and then killed by the OS with no close request or
   tree teardown — up to 2 s of dirty state (`SAVE_INTERVAL`) is lost on every
   background-kill, the most common exit path on the platform.
2. **Non-atomic write + destructive recovery.** `save()` (SaveManager.gd:458-460) opens
   `user://save.json` with `FileAccess.WRITE` (truncate-then-write). A process kill
   mid-write leaves truncated/invalid JSON, and `continue_game()`
   (autoloads/SceneManager.gd:144-146) reacts to any load failure with
   `start_new_game()` — silently wiping the entire save.
3. **Stale time_of_day.** `time_of_day` is copied into SaveManager only by
   `flush_time_of_day()`, called solely from `go_to_menu()`
   (WorldScene.gd:378-379 + SceneManager.gd:86-89). The 2 s dirty-flush persists a stale
   clock while `days_elapsed` (SaveManager.gd:877-886) updates live — after a crash the
   clock rewinds to the last menu visit but the day counter doesn't, desyncing
   enemy-respawn logic.
4. **sync_stacks misses the dirty flag.** `sync_stacks()` (SaveManager.gd:472-474) is the
   only mutator that does not set `_dirty` — latent race for future callers relying on
   the documented dirty-batching.

## Research Notes

Fixes, in order:
1. Add `NOTIFICATION_APPLICATION_PAUSED` (and `NOTIFICATION_APPLICATION_FOCUS_OUT` as a
   belt-and-braces) to the flush condition in `_notification`. BattleScene already uses
   FOCUS_OUT for pending-battle saves (BattleScene.gd:701-707) — same pattern.
2. Atomic write: write to `user://save.json.tmp`, then `DirAccess.rename_absolute()`
   over the real file. Additionally keep `user://save.json.bak` (copy the previous good
   file before rename) and make `load_save()` fall back to the `.bak` when the primary
   fails to parse, instead of letting `continue_game()` reset. Only start a new game if
   *both* are unreadable.
3. Set `save_manager.time_of_day` inside the same throttled block as `update_position`
   in WorldScene (WorldScene.gd:1083-1087) so the dirty-flush always carries a fresh
   clock. Keep `flush_time_of_day()` for the immediate menu path.
4. Add `_dirty = true` to `sync_stacks()` like every other mutator.

Constraints:
- Depends on TID-226 — there must be exactly one SaveManager before touching
  notification handling.
- The 2 s dirty-batching design itself is correct and timer-driven (verified — no
  `_process` polling in autoloads); don't restructure it.
- All 14 existing migrations and the defaulted `get()`s in `load_save()` are sound;
  no migration work needed here.
- Test by simulating: write a truncated save.json, verify `.bak` fallback loads;
  verify `NOTIFICATION_APPLICATION_PAUSED` triggers a flush (can be unit-tested by
  calling `_notification` directly).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
