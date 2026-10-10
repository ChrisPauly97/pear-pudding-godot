# TID-765: Crafting: gear from ore and hide

**Goal:** GID-182
**Type:** agent
**Status:** done
**Depends On:** TID-760, TID-761, TID-762

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Lets the player make equipment, with quality that scales with crafting skill.

## Research Notes

- Equipment: `autoloads/WeaponRegistry.gd`, `data/WeaponData.gd`, slots in SaveManager (`# Non-weapon equipment slots`), upgrades in `game_logic/UpgradeDefs.gd` / `BlacksmithScene.gd`, and rolls in `game_logic/items/GearRolls.gd` (`roll(tier, level, rng)`, saved in `gear_rolls`, keeping the better roll).
- Crafted gear output: a recipe names an existing weapon/equipment id; the roll comes from a crafting-specific weight table: skill level → tier, item level = the recipe's level. It competes with drops but caps at `epic` (legendary stays drop-only).
- Grant through the same path drops use, so `GameBus.equipment_changed` fires and co-op appearance updates (`CoopAppearance`).
- The workbench is a station (TID-762); the Blacksmith keeps upgrades.

## Plan

- Recipes: a `# Crafting (TID-765)` block at the end of `ProfessionDefs.RECIPES`, nine gear recipes (leather and iron) naming real `WeaponRegistry` items, with `output {kind: "gear"}`.
- `output_valid` gains a `gear` branch (`WeaponRegistry.has_weapon`). Food and potion branches untouched.
- `game_logic/professions/CraftedGear.gd` (new, pure): skill → source tier, that tier's GearRolls weights with legendary folded into epic (the cap), item level = recipe `skill_req`.
- `SaveProfessions.craft(recipe, rng = null)` grants gear through `save.gear.grant` (the drop path) and returns `roll` / `grant`. `craft_block` already reports `unsupported` only for an invalid output, so no change there.
- Tests: drop the crafting exemption in `test_professions`; add `test_gear_crafting`.
- No save migration (`gear_rolls` exists), no WorldScene or BattleVictory edits.

## Changes Made

- `game_logic/professions/CraftedGear.gd` (+ `.uid`): new. `SKILL_TIERS`, `tier_for_skill`, `weights_for_skill` (epic absorbs legendary), `roll(skill, item_level, rng)`.
- `game_logic/professions/ProfessionDefs.gd`: `WeaponRegistry` preload; `# Crafting (TID-765)` recipe block (stitch_leather_cap, stitch_leather_vest, stitch_leather_pauldrons, stitch_travel_boots, forge_iron_helm, forge_iron_pauldrons, forge_iron_greaves, forge_iron_shield, forge_berserker_axe); `output_valid` `gear` branch.
- `autoloads/save_manager/SaveProfessions.gd`: `CraftedGear` preload; `craft(recipe, rng = null)` gear branch rolls from the crafter's skill, calls `save.gear.grant` per piece, emits `GameBus.equipment_dropped` on new/upgraded (as ChestLoot does); result gains `roll` and `grant`.
- `tests/unit/test_professions.gd`: crafting exemption removed (every profession now has a recipe).
- `tests/unit/test_gear_crafting.gd` (+ `.uid`): 10 tests (recipes name real gear, output_valid, tier steps, epic cap over 2000 seeded rolls, item level, grant + roll saved, duplicate keeps better roll both ways, refusal without inputs).
- `docs/agent/professions.md`: table rows updated; "Crafting (gear, TID-765)" and "Tests (gear)" subsections appended.
- No save version bump, no WorldScene / BattleVictory / tasks index edits.

Validation: parse check clean; `scripts/unsafe-hits.sh` no output; gdlint no problems on changed files; full suite exit 0, 3275 passed, 0 failed, 0 `SCRIPT ERROR`.
One test assertion was first wrong (it used a skill-5 recipe, so the skill check fired before the inputs check); fixed in the test, not the code.

## Documentation Updates

- `docs/agent/professions.md`: `output_valid` and `craft` rows updated for gear; new "Crafting (gear, TID-765)" section and "Tests (gear)" section.
