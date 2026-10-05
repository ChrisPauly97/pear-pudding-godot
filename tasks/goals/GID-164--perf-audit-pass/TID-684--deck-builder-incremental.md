# TID-684: Deck builder: debounced search, persistent tiles, incremental add/remove

**Goal:** GID-164
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every keystroke / add / remove / filter rebuilds the whole collection UI. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `scenes/ui/InventoryScene.gd:324-368` `_refresh_cards` frees + rebuilds loadout bar, backpack grid, deck list.
- Callers: search `:253-255`, add/remove/filter/tab `:458, :501, :941`.
- Fix: 150 ms debounce timer on search; tiles in dict keyed by uid, filtering toggles `visible`; add/remove updates the affected tile + deck list row only; loadout bar rebuilt only when loadouts change.
- Use UiUtil factories; keep drag-scroll behaviour.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
