# TID-536: Zone Level Ranges & Enemy Levels

**Goal:** GID-136
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

WoW zones have level ranges; enemies show a level coloured relative to yours (grey/green/yellow/orange/red) and XP scales accordingly.

## Research Notes

- XP/level: `SaveManager.xp_for_level` / `_compute_level` (~L1163), XP granted on victory (~L1214). BID-049 context.
- Enemy difficulty: `EnemyRegistry.get_difficulty_tier(type)`; biomes in `BountyGen.BIOME_NAMES`; infinite world
  chunking in `docs/agent/world-generation.md`. Level = f(biome, distance from spawn) for infinite world; named maps
  get an authored range.
- Enemy level must affect battle (HP/attack scaling like `CoopBattleScaling.gd`) and XP (grey = 0 XP).
- Show level on enemy name tag (`SpriteRegistry.make_name_label`).

## Plan

1. Pure `ZoneLevels.gd`: distance-from-Madrian level ramp, con colours, XP / HP / tier scaling.
2. `EnemyNPC`: level (preset → zone → player level), coloured "Lv N" tag, level on the engage payload.
3. Battle: tier bump before deck build, HP scaling in `BattleModifiers`.
4. XP scaling in `BattleVictory` (main + joined enemies); grey = 0.

## Changes Made

- New `game_logic/world/ZoneLevels.gd`.
- `scenes/world/entities/EnemyNPC.gd`: `enemy_level()`, `_add_level_tag()`, `_refresh_level_tag()` (on `level_up`),
  `enemy_level` in the engage payload.
- `scenes/battle/BattleScene.gd`: `scaled_tier` before `build_deck`; calls `modifiers._apply_zone_level()`.
- `scenes/battle/modules/BattleModifiers.gd`: `_apply_zone_level()`.
- `autoloads/scene_manager/BattleVictory.gd`: `_level_scaled_xp()` for main + joined enemies.
- Tests: `tests/unit/test_zone_levels.gd` (6). Suite 2803 pass; smokes clean; gdlint + unsafe-hits clean.

## Documentation Updates

`docs/agent/enemies-and-npcs.md`: "Zone Levels & Enemy Levels" section.
