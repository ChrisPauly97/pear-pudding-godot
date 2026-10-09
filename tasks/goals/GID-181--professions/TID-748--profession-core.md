# TID-748: Profession core: defs, save fields, module

**Goal:** GID-181
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
