# TID-146: Spire Run State Model + SaveManager Migration

**Goal:** GID-038
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The foundation of the Spire: a persisted run record so a climb survives app restarts (critical on Android, where the OS kills backgrounded apps). Pure data work — no scenes, no UI. Everything else in GID-038 builds on this.

## Research Notes

- **Run record:** A dictionary under `SaveManager.spire_run`:
  - `active: bool`
  - `floor: int` (1-based)
  - `draft_deck: Array` (card ID strings; run-local, never merged into collection)
  - `hero_hp: int` (carried between floors — persistent damage is the roguelike tension)
  - `seed: int` (drives floor layout and enemy/draft RNG for determinism on resume)
  - `enemies_defeated: int`, `cards_drafted: int` (for run summary)
- `autoloads/SaveManager.gd` — study the field migration pattern (GID-034 battle pause/resume added similar mid-activity state; `docs/agent/save-system.md` documents the dirty-flag and migration approach). Default for old saves: `{"active": false}`.
- **API surface:** Add helper funcs on SaveManager (or a small `game_logic/spire/SpireRun.gd` static helper preloaded where needed):
  - `start_spire_run(seed: int)` — initialise record, mark dirty
  - `advance_spire_floor()` — increment floor + enemies_defeated
  - `add_drafted_card(card_id: String)`
  - `end_spire_run() -> Dictionary` — returns final stats, clears record
- **Battle-state interaction:** GID-034 persists mid-battle state. A Spire battle should also pause/resume correctly — verify the GID-034 record can coexist with `spire_run` (they're independent fields; the battle record needs to know it's a spire battle so resume routes back to the spire floor, not the world). Check `docs/agent/save-system.md` and the GID-034 task files for the resume routing.
- **Tests:** Add a headless test in `tests/` covering migration (old save without `spire_run` loads cleanly) and the start/advance/end lifecycle. Follow existing test patterns in `tests/`.
- `docs/agent/save-system.md` — document the new field.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
