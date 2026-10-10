# TID-754: Player school sources: skill-tree nodes, gear affixes, conversion

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-749, TID-751

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The horizontal reward: players collect ways to deal and resist different schools rather than bigger flat numbers. Spec identity says progression grants cards, not stat bars — keep sources card-centric where possible.

## Research Notes

- Skill tree: `game_logic/battle/SkillMods.gd` (GID-179) builds per-fight card modifiers from unlocked skills (`add(effect_type, value, filter)`, `matches(card, filter)`). Add effect types `school_power` (+% to cards of a school) and `school_resist`; nodes in skill .tres files under data/skills (preload rule for Android). Real-time only (skill_mods is null in turn-based) — check whether turn-based needs parity.
- Gear: rolls in `game_logic/items/GearRolls.gd` `roll(tier, level, rng)` L37, stored via `autoloads/save_manager/SaveGear.gd` (`roll_of`, `mult`, `grant`); applied in `BattleSetup` equipment effects (~L49–85 `UpgradeDefs.effective_stat(weapon, level, gm)`). Add an affix slot to the roll dict: `{school_dmg: {school, pct}}`, `{school_resist: {school, pct}}`, rare `{convert: school}` (weapon auto-attack / Strike deals that school). Old saves: missing affix = none (SaveMigrations row only if shape changes).
- Decision for Plan (flagged to user at goal creation): keep flat item-level stat rolls but smaller, or replace them with affixes. Default: affixes replace part of the stat budget; levels uncapped, no enemy scaling.
- Gear tooltip/paper doll: `game_logic/character/PaperDollGear.gd`, drop message `SaveGear.drop_message`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
