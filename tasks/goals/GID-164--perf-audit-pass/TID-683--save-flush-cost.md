# TID-683: Save flush: section-dirty copies, compact JSON, flat HMAC, .bak once per session

**Goal:** GID-164
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every 2 s while dirty: full `duplicate(true)` on main thread; worker writes indented JSON, double stringify, copies .bak each time. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `autoloads/SaveManager.gd:453` — `duplicate(true)` of entire save on main thread.
- `game_logic/save/SaveFile.gd:63-67` — `JSON.stringify(..., "\t")`, payload stringified then nested as escaped string for the HMAC, `.bak` copy every write.
- Fix: no indent; store HMAC beside payload (new envelope version) — **reader must still accept the old envelope** (legacy saves) and test both; rotate `.bak` once per session/load; dirty-section tracking so only changed fields are deep-copied (rest reuse last snapshot).
- Existing: single-flight worker flush, sync `_flush_now()` at shutdown (CLAUDE.md chest-open hitch learning). `test_save_manager` round-trip must stay green; add old-format load test.
- `docs/agent/save-system.md` update.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
