# TID-751: Enemy attack schools + hero school resistances

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-749, TID-750

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Resistance only matters both ways if enemies hit with a school and the player can resist it. Sets up the defensive half that TID-754 feeds.

## Research Notes

- **Also in scope (gap after TID-749/750):** nothing fills `PlayerState.school_profile` yet. At battle setup (BattleSetup / BattleModifiers) set the enemy side's `school_profile = EnemyRegistry.get_school_profile(type_id)` and swap to phase 2 when the boss phase changes; set the player side's from the hero resists below. Resolver: `game_logic/battle/DamageResolver.gd` (`deal(defender, target, amount, school, tune)`). Balance bands WILL move once profiles are live — re-run `tools/balance_sim.gd -- --write-baseline` only if bands still pass their absolute targets; report the numbers.

- Enemy unit hits: school from the attacking card (`CardInstance.magic_type`, else physical); enemy hero swings/heavy (`RealtimeCombat.heavy_damage` L747, main_hand_damage L495): add optional `attack_school` per enemy type in EnemyRegistry (default physical).
- Player profile: `HeroState` gets a `school_resist: Dictionary` (school → fraction 0..0.75 cap) filled at battle start by `BattleModifiers` (equipment/skills/companion live there); the TID-749 resolver reads it for player-side targets. Allies (player minions) use their own card school? — decide in Plan; default neutral.
- Cap total resist in CombatTuning (`max_player_resist`).
- Co-op/PvP: HeroState is serialized via to_dict/from_dict — add the field there (see CLAUDE.md: reconnect signals when replacing from_dict state).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
