# TID-764: Alchemy: potions move to profession recipes

**Goal:** GID-182
**Type:** agent
**Status:** done
**Depends On:** TID-760, TID-762

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Fold the existing garden potions into the Alchemy profession and widen the potion roster.

## Research Notes

- Today: `GardenDefs.POTION_RECIPES` (3 potions, 2 plants + 5 essence each), crafted in the Inventory Craft tab (`CraftPanel._potion_row`), surfaced through `CraftingRegistry.get_potion_recipes()`. Potions are used from the battle quick slots (`BattleConsumables.gd`, Q/E, TID-542) and as a world heal (`HeroVitality.WORLD_POTION_HEAL`).
- Move the recipes into `ProfessionDefs.RECIPES` (profession `alchemy`), drop the essence cost, and accept gathered herbs as well as garden plants. Remove the potion rows from `CraftPanel` (card crafting stays) — or point them at the alchemy table.
- Add 3–5 new potions with effects that fit real-time combat (e.g. haste, shield, cleanse) — implement the effects in `BattleConsumables.gd`.
- Update `docs/agent/home-garden-potions.md`.

## Plan

- Recipes: edit `brew_healing_draught` / `brew_clarity_brew` in place (garden plant as an `alt_inputs` set); append an `# Alchemy (TID-764)` block at the end of `ProfessionDefs.RECIPES`; drop essence costs.
- Herbs: `ironbark`, `starsage`, `emberwort` at the end of `MATERIALS`, added to the `GatherDefs.YIELDS` herb lists so they can be gathered.
- Potions: three new (Stoneskin Tonic, Cleansing Salve, Mana Draught). Effects are pure in `game_logic/battle/PotionEffects.gd`, shared by BattleConsumables and BattleNet. Haste was dropped (needs real-time tuning).
- Remove `GardenDefs.POTION_RECIPES`, `CraftingRegistry.get_potion_recipes()` and the CraftPanel potion section. Keep `GameBus.potion_crafted`, now emitted from `SaveProfessions.craft`.
- Save: no new fields, no migration bump.

## Changes Made

- `game_logic/professions/ProfessionDefs.gd`: herbs `ironbark`, `starsage`, `emberwort`; `brew_healing_draught` / `brew_clarity_brew` edited in place with `alt_inputs`; new `# Alchemy (TID-764)` recipe block (ember, stoneskin, cleansing salve, mana draught); `input_sets()` and `recipes_using()`.
- `game_logic/GardenDefs.gd`: `POTIONS` without essence costs, plus `stoneskin_tonic`, `cleansing_salve`, `mana_draught`; `POTION_RECIPES` removed. `pear_pudding` untouched.
- `game_logic/professions/GatherDefs.gd`: new herbs added to grassland, forest and desert yields.
- `game_logic/battle/PotionEffects.gd` (+ `.uid`): pure `apply_hero()` and `FLOATS`.
- `scenes/battle/modules/BattleConsumables.gd`, `scenes/battle/net/BattleNet.gd`: hero potions go through `PotionEffects`.
- `autoloads/save_manager/SaveProfessions.gd`: `inputs_for()` picks the payable input set; craft consumes that set; potion crafts emit `GameBus.potion_crafted`.
- `autoloads/CraftingRegistry.gd`: `get_potion_recipes()` removed.
- `scenes/ui/inventory/CraftPanel.gd`: potion section and `_potion_row` / `_do_craft_potion` removed (cards unchanged).
- `scenes/ui/inventory/ItemsPanel.gd`: "Used in" hints from `ProfessionDefs.recipes_using`.
- `scenes/ui/ProfessionPanel.gd`: shows the input set a craft would use.
- Tests: new `tests/unit/test_alchemy.gd` (+ `.uid`), 19 cases. `test_potion_recipes.gd` rewritten for alchemy data. `test_legendary_potions.gd` checks recipes by output.
- Validation: parse check clean, `unsafe-hits.sh` clean, gdlint clean. `tests/runner.gd`: 3277 passed, 0 failed, 0 SCRIPT ERROR. `battle_input_flow_smoke.gd` exit 0.
- Not touched: WorldScene.gd, BattleVictory.gd, save version, cooking and gear entries, tasks/index.md, goal.md.

## Documentation Updates

- `docs/agent/home-garden-potions.md`: Alchemy Brewing section (recipe table, alt inputs, effects), potion tables and effects list, quick-slot effects, integrations, GameBus row. `POTION_RECIPES` marked removed.
- `docs/agent/professions.md`: Alchemy subsection, starter recipe line, tests line.
