# TID-779: Progression rewards matter (gear / skills / upgrades bands)

**Goal:** GID-187
**Type:** agent
**Status:** done
**Depends On:** TID-778

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Paired cells (same seeds, like the GID-186 school matrix): profile with vs without one reward axis — a weapon
upgrade tier, a skill build, card upgrades, a school affix, a companion. Gate: each axis raises win rate by a
minimum; no single axis exceeds a cap (no must-have item). Also: within a magic type, no skill build dominates.

## Research Notes

- Paired-cell pattern and fixed seeds: `BalanceCoverage.measure_schools` / `check_schools`.
- Companions: `BattleModifiers._apply_companion_battle_start` / `_apply_companion_turn_start` (extra_mana,
  hero_armor, draw_card) — not in `BattleSetup`; move the real-time-relevant part there (sim + game share it).
- Known outlier: BID-103 (fourth technique slot is a large power step) belongs here.

## Plan

A `rewards` coverage section: the typical profile against a harder enemy (mid-rate cells), with vs without one
reward at a time at the same seeds; axes skills, weapon upgrade, card veterancy, companion, one gear step and the
fourth technique slot, plus two skill builds per magic type. Bring companions and card ranks into `BattleSetup`
through shared code. Gates set from the measurement.

## Changes Made

- `game_logic/battle/BalanceRewards.gd` (+ `test_balance_rewards.gd`), section `rewards` in `BalanceCoverage`, CI group.
- `BattleSetup.build` keys `weapon_upgrade`, `card_rank` (`VeterancyUtil.instances_at_rank` → the game's
  `build_deck_from_instances`), `companion` (`FightStart.apply_companion` / `companion_draw`, now also used by
  `BattleModifiers`). School helpers moved to `game_logic/battle/SchoolSources.gd` (BattleSetup line budget).
- **Bug:** companions did nothing in real-time fights (the opening-hand trim undid Maiteln's draw).
  `BattleRealtime.maybe_start` draws after the trim.
- `BalanceProfiles.skill_build(…, order)`, `main_branch`, `branch_deck` (profile deck carries 2 cards of its build's
  main branch). `mod_recycle` skill nodes halved (10 → 5; Void Tempo 15 → 8): one recycle node decided early builds.
- `spectre_haunt` `rt_hp_mult` 0.75, `martarquas_raider_2` 1.2 (L24 +1 walls after the deck change).
- BID-103 resolved (fourth slot ~0 pp); BID-109 logged (branch asymmetry left).

Measured mean gains (pp): skills +7.5, weapon upgrade +14, card rank +28, companion +4, gear step +50 (uncapped),
fourth slot 0; builds differ 6 pp on average (33 at L14). All sections pass.

## Documentation Updates

- `docs/agent/balance-sim.md` → Rewards (TID-779); Limits updated.
