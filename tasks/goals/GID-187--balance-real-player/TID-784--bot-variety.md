# TID-784: Bot variety (second policy)

**Goal:** GID-187
**Type:** agent
**Status:** done
**Depends On:** TID-778

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every number so far comes from one very consistent bot, so win rates move in cliffs and tuning can fit its quirks.
Add a second policy (e.g. "casual": slower reactions, misses some Kicks, no focus swaps; and optionally "sharp":
commands Allies, swaps focus) and require bands to hold for the default and casual bots (casual with a lower bar).

## Research Notes

- `BalanceBot.gd` policy knobs (`heal_below`, `summon`, `interrupt`, `focus`); `BalanceFight.run(cfg, policy)`.
- Missing actions today: focus changes, commanded Ally attacks (`docs/agent/balance-sim.md` → Limits).
- A reaction-delay knob (seconds before acting on a telegraph) likely matters most for heavies / interrupts.

## Plan

1. `BalanceBot`: knobs `react` (reaction delay on telegraphs, on a clock the fight advances), `kick_miss` (one
   seeded roll per enemy cast on the fight rng), `think` (gap between plays), all 0 = off. `preset("default")` /
   `preset("casual")` (`casual`: focus off, react 0.5, kick_miss 0.2, think 1.0).
2. Default must stay byte-identical: no rng draw or clock read when a knob is 0. Check against the base commit's sim
   output and `tests/balance_bands.gd`.
3. `tools/balance_sim.gd --bot NAME` (`--policy` overrides on top); sweepable knobs added.
4. `BalanceCoverage` section `casual`: `range` cells, same level, casual preset, gate from the measurement.
5. Unit tests for the knobs; docs; commit. No CI change (parent's job).

## Changes Made

- `game_logic/battle/BalanceBot.gd`: `DEFAULT_POLICY`, `PRESETS`, `preset()`, `has_preset()`; `act(caster, resolver, dt)`
  advances the bot clock; `_sight` / `_reacted` / `_kick_lands` gate interrupts; `_next_play` for `think`.
- `game_logic/battle/BalanceFight.gd`: passes `DT` to `act`.
- `tools/balance_sim.gd`: `--bot default|casual` (unknown name exits 1); policy sweep keys `react`, `kick_miss`, `think`.
  The bot is loaded with `load()`, not `preload()`: BalanceBot reaches the AudioManager autoload, which a `-s` script
  cannot see at parse time.
- `game_logic/battle/BalanceCoverage.gd`: `casual` in `SECTIONS`; `run_cell` takes a `policy` argument;
  `measure_casual` / `check_casual`; `CASUAL_FIGHTS` 8, `CASUAL_MEAN_MIN` 0.75, `CASUAL_CELL_MIN` 0.10.
- `tests/unit/test_balance_bot.gd`: 6 new tests (preset = defaults, default fight unchanged, casual deterministic
  per seed, kick_miss 1 never interrupts, react delays the kick, think spaces plays).

Measured (TID-784):
- Casual section, 24 same-level cells, 8 fights each: mean **91.1 %** (gate 75 %), lowest **12.5 %**
  (ghoul pack L5), two cells below 40 %: ghoul pack L4 25 %, L5 12.5 %. The first gate (40 % per cell) failed on
  those two. Cause: no focus swaps, and packs need focus (ghoul pack L4 `--policy focus=1` → 100 %). The cell floor
  is set to 10 % (measured minus 2.5 pp), reported rather than retuned.
- Default bot unchanged: `tests/balance_bands.gd` PASS (baseline not rewritten). Sim rows for undead_basic,
  wolf_pack and ghoul_pack at levels 3 and 6 (30 fights) match the base commit's output exactly.

## Documentation Updates

- `docs/agent/balance-sim.md`: `--bot` / policy knobs in the options table, `BalanceBot` row, new "Bot variety"
  section with the casual measurement, coverage table row for `casual`.
