# TID-761: Material drops from enemies

**Goal:** GID-182
**Type:** agent
**Status:** done
**Depends On:** TID-759

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Gives cooking and crafting a combat-fed source: beasts drop meat and hide, magical enemies drop cores.

## Research Notes

- Victory rewards: `autoloads/scene_manager/BattleVictory.gd` `_on_battle_won` (also `_reward_joined_enemies` for team fights). Add a material roll beside the coin/XP/card reward and show it in `_show_reward_toasts`.
- Drop table: per enemy family in `ProfessionDefs` (e.g. `DROPS_BY_FAMILY`), keyed by enemy_type/family read from `EnemyRegistry._ensure_loaded()` data (enemy data lives only there — no `.tres`). Quantity scales with the difficulty tier, like `GearRolls.TIER_WEIGHTS`.
- Co-op loot: check `game_logic/net/LootRoll.gd` — materials go to each peer locally (no need/greed).
- Exclude practice/duel/puzzle/scripted fights (mirror `HeroVitality.carries_over` rules).
- Test: pure drop-roll function with a seeded RNG.

## Plan

- Pure `game_logic/professions/MaterialDrops.gd`: family map (beast → game_meat + rough_hide, magical → arcane_core), tier-scaled seeded `roll`, `roll_into` (consequence gate via `HeroVitality.carries_over` + `duel_npc_id`), `describe`.
- `BattleVictory._on_battle_won` rolls the main kill and each joined enemy, banks via `professions.add_material`, shows the text in the reward toast.
- Test `tests/unit/test_material_drops.gd`.

## Changes Made

- New `game_logic/professions/MaterialDrops.gd` (+ `.uid`): `FAMILY_BY_ENEMY`, `TABLES`, `roll`, `roll_into`, `family_of`, `describe`.
- `autoloads/scene_manager/BattleVictory.gd`: rolls main + joined enemies, grants via `_sm.save_manager.professions.add_material`, `_show_reward_toasts` gains a `materials_text` argument (in-world toast), HUD message on the result card path. `_reward_joined_enemies` takes the bag and RNG.
- New `tests/unit/test_material_drops.gd` (10 tests): seeded determinism, family mapping, beast vs magical tables, enemy ids exist in EnemyRegistry, tier scaling, tier clamp, excluded fights drop nothing, `roll_into` duel/practice gate and stacking, unmapped enemies, `describe`.
- `BattleVictory.gd` went over 500 lines (498 → ~515); added the `max-file-lines` tracked-debt pragma with a note to shrink by extraction.

## Documentation Updates

- `docs/agent/professions.md`: added an "Enemy drops" subsection (appended before Integrations).
