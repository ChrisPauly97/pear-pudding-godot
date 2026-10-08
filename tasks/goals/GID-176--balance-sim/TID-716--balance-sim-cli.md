# TID-716: tools/balance_sim.gd — batch runner, sweeps, CSV

**Goal:** GID-176
**Type:** agent
**Status:** done
**Depends On:** TID-715

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The tool the user runs: many seeded fights at a fixed timestep, with a summary table and a CSV.

## Research Notes

- From TID-715: one fight is already `BalanceFight.run(cfg, policy)` (pure, seeded, returns per-fight stats). The CLI only parses args, loops seeds and sweeps, aggregates (Wilson CI, percentiles) and writes the summary + CSV. Measured about 30 fights/s, so the TID-716 100 fights/s target is optimistic; record the real rate.
- From TID-714: build each fight with `BattleSetup.build({player_level, learned, deck, weapon, offhand, enemy_type, enemy_level, is_boss, tuning, seed})` → `{state, rt, tier}`. On each `"round"` event for the enemy side call `BattleSetup.enemy_round(state, enemy_type, tier, n)` (fight traits), and after an enemy play `resolver.flush_auto_spells(side)` (see `BattleRealtime._after_enemy_play`). `BattleSetup.starter_deck()` is the default deck.
- From TID-713: drive the player with `PlayerCaster` (`game_logic/battle/PlayerCaster.gd`). Per tick: `caster.tick(DT)` then `rt.advance(DT)`; act with `caster.play(card, resolver, target)`, where target is `{}`, `{"type":"minion","card":c}` or `{"type":"hero"}`; check legality with `caster.play_blocker(card)`; `caster.notify` gives combo / proc / interrupt / fizzled / resolved{dealt} / technique events for stats. A resolver is `SpellEffectResolver.new()` + `setup(state)`.
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

Medium complexity, so I proceeded without an approval stop.
1. Pure `BalanceStats` (Wilson, percentiles, summary / table / CSV rows) so the maths is unit-tested.
2. `tools/balance_sim.gd` CLI over `BalanceFight.run`: args, seeds, sweeps, output.
3. Docs.

## Changes Made

- New `game_logic/battle/BalanceStats.gd` and `tools/balance_sim.gd`, with the options documented in the header and in balance-sim.md. Sweeps cover `level`, `enemy_level`, any CombatTuning knob or a policy knob. An unknown enemy type aborts with the list of known types. The CSV defaults to `user://balance/<time>.csv`.
- `game_logic/battle/BattleSetup.gd`: new `level_deck(learned)` (starter deck + up to 3 known technique cards, as `learn_ability` deals them), now `build()`'s default deck. Without it a level-3 sim player had no Kick or Mend card.
- Tests: new `tests/unit/test_balance_stats.gd` (4). Full suite PASS with 0 SCRIPT ERROR; realtime_battle_smoke clean; gdlint and unsafe-hits clean.
- Speed: 28–48 fights/s headless (the 100/s target was optimistic). 200 fights per case take about 5 s.
- First matrix (recorded in balance-sim.md): L1 0 %, L2 100 %, L3 47 % (learning Kick enables heavy blows), L4–5 93 %, L10 100 % vs `undead_basic`. This is input for TID-718.

## Documentation Updates

New docs/agent/balance-sim.md; CLAUDE.md docs-table row + a Running Tests line.
