# TID-748: Profession core: defs, save fields, module

**Goal:** GID-181
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Foundation for GID-181. Every profession, material and recipe lives in one pure data table (same pattern as `MagicTypes` / `UnlockLadder`) so stations, UI, gathering and drops all read it.

## Research Notes

- New `game_logic/professions/ProfessionDefs.gd` (extends RefCounted, pure static, no autoloads — it is read from chunk-gen worker threads in TID-749).
  - `PROFESSIONS`: `alchemy`, `cooking`, `crafting` → display name, colour, station kind.
  - `MATERIALS`: id → {display_name, sell_value, source: herb|ore|fish|meat|hide|core|plant}. Garden plants (`GardenDefs.PLANTS`) count as alchemy inputs — reference, don't duplicate.
  - `RECIPES`: id → {profession, skill_req, inputs {mat: n}, output {kind: food|potion|gear, id, count}, xp}.
  - XP curve: `level_for_xp(xp)`, cap ~50; recipes give less XP once they're far below your skill (grey recipes, as in WoW).
- SaveManager: add `profession_xp: {}` and `materials: {}` to `PERSISTED_FIELDS` + `var` declarations; bump `SaveMigrations.CURRENT_VERSION` + one row (the defaults are enough).
- New module `autoloads/save_manager/SaveProfessions.gd` (RefCounted, typed `_save` back-ref) built in `SaveManager._init` as `professions`: `add_material`, `has_inputs`, `craft(recipe_id) -> Dictionary` (consumes inputs, grants output + XP, returns a result), `level(prof)`.
- Outputs: food → `HeroVitality.FOODS` counts (find the save field the foods are stored in), potion → `potions`, gear → reuse the equipment grant path (TID-754 fills it in).
- Tests: `tests/test_profession_defs.gd` (every input is a known material/plant, every output resolves, skill_req ≤ cap) + a save round-trip covered by `test_save_manager`.
- Signal: `GameBus.profession_level_up(prof, level)` (emit literally — `test_gamebus_signal_coverage`).

## Plan

1. `game_logic/professions/ProfessionDefs.gd` — pure static tables: PROFESSIONS, MATERIALS, RECIPES (starter set: 3 alchemy recipes mirroring the garden potions but with herbs as alt input left to TID-753, 2 cooking recipes → existing foods, gear recipes left to TID-754), XP curve (`level_for_xp`, `xp_for_level`, cap 50), `recipe_xp(recipe, level)` with grey falloff, `difficulty(recipe, level)` colour band.
2. SaveManager: `profession_xp`, `materials` fields; migration v49 backfill.
3. `autoloads/save_manager/SaveProfessions.gd` (`professions`): level/xp, add/remove material, can_craft, craft (inputs from `materials` + `plants`; outputs to `foods`/`potions`; gear deferred to TID-754 → refused).
4. `GameBus.profession_level_up` signal, emitted in craft.
5. Tests: `tests/test_professions.gd` (table validity, curve, craft flow, level-up).

## Changes Made

- `game_logic/professions/ProfessionDefs.gd` (new): PROFESSIONS, SOURCES, 10 MATERIALS, 4 starter RECIPES (2 alchemy, 2 cooking; crafting has none until TID-754), XP curve, difficulty bands, input/output validation.
- `autoloads/save_manager/SaveProfessions.gd` (new): `SaveManager.professions` — xp/level, count (materials + garden plants), add/remove_material, craft_block, craft.
- `SaveManager.gd`: `profession_xp`, `materials` in PERSISTED_FIELDS + vars + new_game reset; module built in `_init`.
- `SaveMigrations.gd`: CURRENT_VERSION 49, backfill row.
- `GameBus.gd`: `profession_level_up(profession, level)`.
- `tests/unit/test_professions.gd` (new, 12 tests). Full suite 3232 passed, 0 SCRIPT ERRORs; gdlint + unsafe-hits clean.
- Not done here (left to the tasks that own it): gear outputs (`craft_block` → "unsupported"); trainer gating (TID-755).

## Documentation Updates

- New `docs/agent/professions.md`; CLAUDE.md docs table row + `professions` in the save-module list; `docs/agent/save-system.md` v49 row.
