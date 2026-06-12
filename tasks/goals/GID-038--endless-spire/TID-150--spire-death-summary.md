# TID-150: Death/Exit Flow + Run Summary Integration

**Goal:** GID-038
**Type:** agent
**Status:** done
**Depends On:** TID-147, TID-148

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The run's ending is its payoff: death (or voluntary retreat) ends the climb, discards the draft deck, and shows the run summary. Without a satisfying ending screen the mode feels like punishment instead of a score chase.

## Research Notes

- **Death in the Spire:** Hero death in a spire battle must NOT route to the standard GameOverScene flow. Branch in `scenes/battle/BattleScene.gd`'s defeat handler: if a spire run is active → `SaveManager.end_spire_run()` → transition to RunSummaryScene with the stats dict. The player respawns at the Spire entrance (use `SceneManager.exit_spire()` from TID-149).
- **Voluntary retreat:** Each floor's entrance area includes a "Leave the Spire" door/prompt. Retreating banks nothing extra but still shows the summary — keep it simple for v1 (no partial rewards).
- **Permanent reward:** To make runs worthwhile, award coins on run end: e.g. `floor × 5` coins (uses the GID-007 economy). Stated on the summary screen.
- `scenes/ui/RunSummaryScene.gd` — exists from GID-024 (meta-progression session stats). Check its input contract; extend with a spire variant: floors cleared, enemies defeated, cards drafted (names list), coins earned. Reuse layout; mobile-first sizing.
- **Best-floor record:** Add `spire_best_floor: int` to SaveManager (with migration) and show "New record!" on the summary when beaten. Cheap, high-motivation.
- **Achievement hooks:** `game_logic/AchievementRegistry.gd` (GID-024): e.g. "Reach floor 5", "Reach floor 10". Follow existing registration pattern.
- `autoloads/GameBus.gd` — `spire_run_ended(stats: Dictionary)` signal so the summary and achievements decouple from BattleScene.
- **Tests:** Headless test for `end_spire_run()` stat payload and `spire_best_floor` update logic.
- `docs/agent/meta-progression.md` — document the spire summary variant and achievements.

## Plan

1. Add `spire_run_ended(stats)` signal to GameBus.
2. Add `spire_best_floor` to SaveManager (v16→v17 migration). Extend `end_spire_run()` to award floor×5 coins, update best floor, set achievement flags, and return enriched stats dict.
3. Add "Spire Ascendant" (floor 5) and "Spire Master" (floor 10) achievements to AchievementRegistry using `specific_flag` condition type with `spire_reached_floor_5` / `spire_reached_floor_10`.
4. Add `spire_stats: Dictionary` field + `_build_spire_ui()` to RunSummaryScene — shows title, floors, enemies, cards, coins, new-record badge, and a draft deck card name list.
5. Update `SceneManager._on_battle_lost()` — Spire branch restores entry point map, ends run, emits signal, shows Spire summary instead of GameOverScene.
6. Update `SceneManager.go_to_menu()` — Spire retreat branch mirrors death flow.
7. Add `SceneManager._restore_spire_entry_point()` — pops entry map from stack so continuing after a run ends resumes at the Spire entrance (madrian), not inside a floor.
8. Extend `tests/unit/test_spire_run.gd` with v16→v17 migration tests, coins reward tests, best-floor tracking tests, is_new_record tests, and achievement flag tests.

## Changes Made

- **`autoloads/GameBus.gd`** — added `signal spire_run_ended(stats: Dictionary)`.
- **`autoloads/SaveManager.gd`** — added `var spire_best_floor: int = 0`; bumped `CURRENT_SAVE_VERSION` to 17; added `_migrate_v16_to_v17()` backfilling `spire_best_floor`; updated `_apply_migrations()`, `load_save()`, and `save()` for the new field; extended `end_spire_run()` to award `floors_cleared * 5` coins, update `spire_best_floor`, set achievement story flags, and return `coins_earned`, `is_new_record`, `best_floor`, `draft_deck_ids` in stats.
- **`game_logic/AchievementRegistry.gd`** — added `spire_floor_5` ("Spire Ascendant") and `spire_floor_10` ("Spire Master") achievements using `specific_flag` type.
- **`scenes/ui/RunSummaryScene.gd`** — added `const CardRegistry` preload; added `var spire_stats: Dictionary = {}`; `_ready()` branches to `_build_spire_ui()` when `spire_stats` is non-empty; added `_build_spire_ui()` rendering Spire-specific layout (purple title, floors/enemies/cards/coins grid, "New Record!" badge, draft deck card names list).
- **`autoloads/SceneManager.gd`** — updated `go_to_menu()` to check `is_spire_active()` before regular session summary: restores entry point, ends run, emits `spire_run_ended`, shows Spire summary; updated `_on_battle_lost()` Spire branch to route death to Spire summary instead of GameOverScene; added `_restore_spire_entry_point()` helper that pops the pre-Spire map from the stack and sets `save_manager.current_map` so continue-after-death loads madrian.
- **`tests/unit/test_spire_run.gd`** — added 25 new tests covering v16→v17 migration, coin rewards, `spire_best_floor` updates, `is_new_record` flag, `draft_deck_ids` in stats, and achievement flag thresholds. Fixed `test_apply_migrations_reaches_v16_from_v15` → `test_apply_migrations_reaches_current_from_v15` to reflect v17.

## Documentation Updates

- **`docs/agent/meta-progression.md`** — updated to document the Spire summary variant, `spire_best_floor` field, coin reward formula, achievement entries, and `spire_run_ended` signal.
- **`docs/agent/ui-and-scene-management.md`** — updated `_on_battle_lost()` Spire branch and `go_to_menu()` Spire retreat branch descriptions.
