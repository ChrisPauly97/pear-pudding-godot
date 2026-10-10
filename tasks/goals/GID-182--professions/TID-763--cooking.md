# TID-763: Cooking recipes + well-fed buffs

**Goal:** GID-182
**Type:** agent
**Status:** done
**Depends On:** TID-761, TID-762

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Cooking turns meat, fish and herbs into foods that heal out of combat and give a 'well fed' buff for the next fights.

## Research Notes

- Foods are now `HeroVitality.FOODS` (`travel_bread`, `roast_fowl`; merchant-only). Extend that table with cooked foods (or have `ProfessionDefs` outputs point at new FOODS ids); keep the eat-over-time behaviour (`meal_rate`, `best_world_item`).
- Well fed: eating a cooked food sets a buff (stat + remaining fights or minutes) stored in a new persisted field; applied at battle start in `scenes/battle/modules/BattleModifiers.gd` (next to equipment/companion modifiers). Examples: +max HP, +auto-attack damage, faster mana. The HUD shows a small icon with the time left.
- Real-time combat timings come from `CombatTuning.gd` — buff magnitudes go there or in ProfessionDefs, not as magic numbers.
- Re-run `tools/balance_sim.gd`; buffs must not break `tests/balance_bands.gd` (the bands run unbuffed — keep it that way and note it in `docs/agent/balance-sim.md`).

## Plan

- Cooked foods are `HeroVitality.FOODS` entries with `price` 0 (made, not bought). ShopScene skips them.
- Recipes at the end of `ProfessionDefs.RECIPES` under `# Cooking (TID-763)`: Trout Fillet (skill 1), Herb Stew (skill 3), Bog Pie (skill 8). The starters Travel Bread and Roast Fowl stay.
- Well-fed buff: a pure module `game_logic/professions/WellFed.gd` over `ProfessionDefs.WELL_FED` (food → `{stat, amount, fights}`). Only `max_hp` for now. Buff = `{food, stat, amount, fights}` in `SaveManager.well_fed` (PERSISTED_FIELDS, migration v50).
- Eating (`HeroHealth.use_quick`) sets the buff. An ordinary solo fight takes one charge at start (`BattleModifiers._apply_well_fed`, before persistent HP), so no BattleScene or BattleVictory edit.
- HUD: `WorldHUD.set_well_fed` text line under the HP bar, driven from HeroHealth.
- Balance: the sim and bands never reach `BattleModifiers`, so they stay unbuffed (noted in balance-sim.md).

## Changes Made

- `game_logic/professions/WellFed.gd` (new): `make`, `active`, `hp_bonus`, `after_fight`, `describe`.
- `game_logic/professions/ProfessionDefs.gd`: 3 cooking recipes at the end of RECIPES; `WELL_FED` const (above the functions, for gdlint).
- `game_logic/HeroVitality.gd`: `trout_fillet`, `herb_stew`, `bog_pie` in FOODS (price 0). The roast fowl description now mentions its buff.
- `game_logic/save/SaveMigrations.gd`: CURRENT_VERSION 49 → 50, row `[50, {"well_fed": {}}]`.
- `autoloads/SaveManager.gd`: `well_fed` var, PERSISTED_FIELDS default, reset in `new_game()`.
- `scenes/ui/ShopScene.gd`: food list skips price-0 foods.
- `scenes/battle/modules/BattleModifiers.gd`: `_apply_well_fed` (called from `_apply_equipment_effects`).
- `scenes/world/modules/HeroHealth.gd`: eating sets the buff and shows its message; per-frame HUD line.
- `scenes/world/WorldHUD.gd`: `_well_fed_label` and `set_well_fed()`.
- `tests/unit/test_cooking.gd` (new): 8 tests (recipes, cooked foods unsold, WELL_FED matches FOODS, eat sets buff, pure apply, expiry and describe, v50 migration, persisted field).
- Not touched: WorldScene.gd, BattleVictory.gd, tasks/index.md, goal.md.

Validation: parse check clean, `scripts/unsafe-hits.sh` clean, gdlint clean on all changed files, `tests/runner.gd` exit 0 with 0 SCRIPT ERROR (3273 PASS, 0 FAIL), `world_scene_smoke.gd` exit 0 with 0 SCRIPT ERROR, `balance_bands.gd` exit 0.
Not covered by tests: the eat path itself (needs a live world scene), the HUD label, and the battle-start application (needs a battle scene). Those were checked only by the smoke run.

## Documentation Updates

- `docs/agent/professions.md`: new "Cooking (GID-182 / TID-763)" section.
- `docs/agent/balance-sim.md`: note that well-fed buffs stay out of the sim and bands.
