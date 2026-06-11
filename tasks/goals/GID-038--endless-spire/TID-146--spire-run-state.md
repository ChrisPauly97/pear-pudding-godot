# TID-146: Spire Run State Model + SaveManager Migration

**Goal:** GID-038
**Type:** agent
**Status:** done
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

1. Add `spire_run: Dictionary = {}` member var to `SaveManager.gd`.
2. Add migration v15→v16: backfill `spire_run` as `{"active": false}` for old saves; bump `CURRENT_SAVE_VERSION` to 16.
3. Load `spire_run` from JSON in `load_save()`; write it back in `save()`.
4. Reset `spire_run = {"active": false}` in `new_game()`.
5. Add helper functions on `SaveManager`:
   - `start_spire_run(seed: int)` — initialise all fields, mark dirty
   - `advance_spire_floor()` — increment `floor` and `enemies_defeated`, mark dirty
   - `add_drafted_card(card_id: String)` — append to `draft_deck`, increment `cards_drafted`, mark dirty
   - `end_spire_run() -> Dictionary` — return stats snapshot, set `active = false`, mark dirty
   - `get_spire_run() -> Dictionary` — read-only accessor
   - `is_spire_active() -> bool` — convenience predicate
6. Write `tests/unit/test_spire_run.gd` covering migration and lifecycle.
7. Register the new test in `tests/runner.gd`.
8. Update `docs/agent/save-system.md` with the new field and migration entry.

## Changes Made

- `autoloads/SaveManager.gd`: added `spire_run: Dictionary` member var; bumped `CURRENT_SAVE_VERSION` to 16; added `_migrate_v15_to_v16` static func and wired it into `_apply_migrations`; added `spire_run` to `load_save()`, `save()`, and `new_game()` reset; added helper functions `is_spire_active`, `get_spire_run`, `start_spire_run`, `advance_spire_floor`, `add_drafted_card`, `set_spire_hero_hp`, `end_spire_run`.
- `tests/unit/test_spire_run.gd`: 30 unit tests covering migration (v15→v16), default state, and full start/advance/draft/hp/end lifecycle.
- `tests/runner.gd`: registered `test_spire_run.gd` in the SUITES array.

## Documentation Updates

- `docs/agent/save-system.md`: added `spire_run` field to the Field Descriptions table; added v15 and v16 entries to the Migration History table.
