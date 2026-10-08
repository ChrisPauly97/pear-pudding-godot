# TID-718: Tune combat numbers to hit the targets

**Goal:** GID-176
**Type:** agent
**Status:** pending
**Depends On:** TID-716

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User targets (2026-10-08): with full HP, full mana and average play, the player beats an enemy of the same level 100% of the time and one level above about 75%. The first measurement (TID-715) is far off at the bottom: a level-1 player with only Strike lost 20/20 to `undead_basic` (dead in about 24 s), while level 5 with Allies won 20/20.

## Research Notes

- **First, define "an enemy of level L" for the sim.** The relevant pieces:
  - zone level: `enemy_data.enemy_level`, `ZoneLevels.scaled_tier` / `scaled_hero_hp`;
  - type tier: `EnemyRegistry.get_difficulty_tier`, `type_for_chunk_dist`, `type_for_biome`;
  - starter camps: `StarterZone` levelled camp enemies (GID-141);
  - real-time enemy level-equivalent: `BattleSetup.enemy_level_for_tier`.

  Pick the enemies a level-L player actually meets, and check that `BattleSetup.build` maps `enemy_level` the way the world does.
- **Player at level L:** `learned` = UnlockLadder rows with `level_req <= L`, deck = starter + Strike + what a level-L player plausibly owns (start with the starter deck), no gear (worst case), then a gear sweep.
- **Sweep with `tools/balance_sim.gd`** before changing anything; record the matrix.
- **Levers, in order of preference:**
  1. `CombatTuning` knobs (player / enemy unarmed damage, swing speeds, mana regen, draw interval, GCD) — global and cheap.
  2. Technique real-time values (`TechniqueDefs.rt_value`).
  3. Enemy scaling (`ZoneLevels`, tier HP / attack).
  4. Onboarding caps (`CombatOnboarding`: enemy minion cap, ally cap, opening hand).

  Prefer few, global changes over per-enemy hacks. Keep changes small and re-run the matrix after each.
- `docs/agent/combat-model.md` tables must reflect any changed defaults. `test_combat_momentum` / `test_realtime_combat` may assert old numbers; update with the reason.
- Turn-based mode is out of scope (real time only).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
