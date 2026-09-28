# TID-597: Rift Model — Per-Biome Rifts & Tier Ladders

**Goal:** GID-142
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Replace the single endless climb with five separate rifts (one per biome), each tracking its own best tier. Floors, no
timer: pick a tier ≤ best + 1, clear N floors, beat the guardian → tier complete, next tier unlocked.

## Research Notes

- Current Spire: `autoloads/save_manager/SaveSpire.gd` (`start_spire_run(seed)` L67, `advance_spire_floor` L80,
  `end_spire_run` L103 → coins floor*5, `spire_best_floor`, flags `spire_reached_floor_5/10`); fields on SaveManager
  `spire_run` (L217) and `spire_best_floor` (L220), both in `PERSISTED_FIELDS` (L64).
- Floor gen: `game_logic/spire/SpireFloorGen.gd` — `map_name_for(floor, run_seed)`, `cleared_flag_for`,
  `enemy_id_for(floor, run_seed)` (unique per instance — see CLAUDE.md "Spire floor 2+ was an empty locked room"; keep
  that rule), `pick_enemy_type(floor)` hard-codes undead types, `is_boss_floor` = every 7th.
- Entry: `SceneManager.enter_spire()` (L1117) resumes or starts; world panel in `WorldScene.gd` ~L1900 ("Enter"/"Resume").
- Biome enemy pools: `game_logic/world/BiomeDef.gd` `ENEMY_POOLS` (L77) — Grasslands, Forest, Desert, Scorched,
  Mountains. Rift = biome index; its floors draw from that pool, guardian from a biome boss (stone_golem for Mountains,
  etc.; pick one per biome, `EnemyRegistry` holds all enemy data — no .tres).
- New pure logic `game_logic/spire/RiftDefs.gd`: `RIFTS` (id, biome, name, pool, guardian), `FLOORS_PER_TIER`
  (e.g. 5 with guardian on the last), `enemy_level(tier, floor)` / stat scaling (reuse the TID-536 enemy-level scaling
  if landed, else a multiplier like `CoopBattleScaling.gd`).
- Save: replace `spire_best_floor` with `rift_best_tiers: Dictionary` (rift_id → int) + `spire_run` gains
  `rift_id`, `tier`. Migration row in `game_logic/save/SaveMigrations.gd`: old `spire_best_floor` → Grasslands rift tier
  `best_floor / FLOORS_PER_TIER`; keep `spire_best_floor` readable for achievements (`AchievementRegistry` L92–107 keyed on
  flags — keep setting those flags from rift progress) and trophy `spire_7` (`TrophyRegistry` L21, `PlayerHome.TROPHY_IDS`).
- Rename is UI-level ("Rift"); keep file/module names (`SaveSpire`, `save_manager.spire`) to avoid churn.
- Tests: `tests/unit/test_spire*` update; new rift-defs tests (every biome has a rift, pools exist in EnemyRegistry,
  tier cap best+1, migration).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
