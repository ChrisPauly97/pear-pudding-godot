# TID-667: Remove Unreferenced Code

**Goal:** GID-159
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

List in `tasks/archive/backlog/BID-087--unreferenced-functions.md`. Scan: a function name with at most one word
occurrence across all `.gd` / `.tscn` / `.tres` (tests included, so string `call("…")` uses count).

## Plan

Delete each function with its doc comment; delete the constants; rescan for cascades.

## Changes Made

- 37 functions removed across 25 files (216 lines), 8 `IsoConst` display/camera constants removed.
- `SaveQuests.abandon` was the only emitter of `GameBus.quest_abandoned` (no UI ever called it), so the signal and
  `QuestTracker`'s listener went too (`test_gamebus_signal_coverage` caught it).
- Rescan after removal: no newly unreferenced functions or preload constants.

## Documentation Updates

`docs/agent/story-implementation.md`: dropped `abandon` / `quest_abandoned`.
