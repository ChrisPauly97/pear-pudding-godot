# TID-785: Turn-based sim and bands

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-778

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Turn-based fights are never simulated, yet they are the solo option and **every co-op fight** (networked fights
never run real time). GID-186 also changed their enemy tiers (`BattleSetup.base_tier` = 1) unmeasured. Build a
turn-based `BalanceFight` variant (a turn bot that plays cards / attacks like the enemy AI does) and band it with the
same targets.

## Research Notes

- Turn flow: `GameState` (`start_turn`, `end_turn`, `is_game_over`), `SpellEffectResolver.resolve_spell`, attacks in
  `BattleInput` (~l.464, `DamageResolver.deal` between minions / heroes) — extract the pure part.
- Enemy AI personas (`EnemyRegistry.get_ai_persona`: basic / aggro / control); reuse the AI turn code for the
  player bot if it is pure.
- `BattleRealtime.eligible()` decides mode; `CombatOnboarding.battle_mode`.

## Plan

## Changes Made

## Documentation Updates
