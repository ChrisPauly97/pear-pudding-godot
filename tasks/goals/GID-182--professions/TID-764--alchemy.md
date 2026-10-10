# TID-764: Alchemy: potions move to profession recipes

**Goal:** GID-182
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
