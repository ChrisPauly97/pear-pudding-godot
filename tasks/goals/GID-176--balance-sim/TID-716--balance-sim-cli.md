# TID-716: tools/balance_sim.gd — batch runner, sweeps, CSV

**Goal:** GID-176
**Type:** agent
**Status:** pending
**Depends On:** TID-715

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The tool the user runs: many seeded fights at a fixed timestep, with a summary table and a CSV.

## Research Notes

- From TID-712: seed a fight with `seed(n)` (global: shuffles, resolver picks) **before** building decks, plus `rt.rng.seed = n`; set `SpellEffectResolver.silent = true`. RealtimeCombat is at gdlint's 30-public-method cap, so put new logic elsewhere.
- Pattern: `tools/profile_world.gd` (extends SceneTree, `OS.get_cmdline_user_args()`). Prefer not to need autoloads (after TID-712); if CardRegistry/EnemyRegistry statics need `_ensure_loaded`, call them.
- Args: `--fights N` (default 200), `--seed S`, `--level L`, `--learned all|starter|<csv>`, `--deck starter|<csv of ids>`, `--weapon id`, `--enemy type|all`, `--enemy-level n`, `--tune key=val,...`, `--sweep key=v1,v2,...` (one tuning knob or `level`), `--policy key=val`, `--csv path` (default `user://balance/<timestamp>.csv`), `--max-seconds 300` per fight.
- Loop: fight i uses seed S+i; `BattleSetup.build`; tick `rt.advance(DT)` + `caster.tick(DT)` + `bot.decide`, with fixed `DT` 0.05; stop on `state.is_game_over()` or timeout (counted separately).
- Per fight: win/loss/timeout, duration, hero HP left, damage by source (auto, Ally, card, technique; reuse `FightStats` where possible), cards played, interrupts landed vs enemy casts completed, time at full mana.
- Summary: win rate (Wilson 95 % interval), median and p10/p90 duration, median HP left, damage split, per sweep value.
- Quiet output (the user prefers low token churn): one table, nothing per fight unless `--verbose`.
- Performance target: ≥ 100 fights/s headless for a typical fight. Measure and record it.
- Docs: new `docs/agent/balance-sim.md` (how to run, what it measures, limits: a bot, not a human) + a row in the CLAUDE.md docs table + a "Running Tests" line.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
