# GID-186: Balance Coverage — Every Level, School and Resistance

## Objective

Expand the combat balance suite from 16 Chapter 1 cells to every level 1-60, every regular enemy type, every damage
school against weak / resisted enemies, and the bosses; then tune the game until it passes.

## Context

- User request (2026-10-10): "adjust balance and the tests for balance to test all levels, spell types, resistances
  etc, expand the scope of the combat balance suite to cover as much as possible".
- Targets (user, 2026-10-08, `docs/agent/balance-sim.md`): same level ~100 %, one level up ~75 %.
- Existing suite: `BalanceBands` (Chapter 1 cells + school bands), `tests/balance_bands.gd`, `tools/balance_sim.gd`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-777 | Balance coverage suite + level / school tuning | agent | done | — |

## Acceptance Criteria

- [x] `BalanceCoverage` sections: every Chapter 1 level, world types at low / mid / high of their range (5-60), a
  paired school x weak / resist matrix, bosses; gated in CI
- [x] Every section passes: same level ≥ 87 % per cell, one level up 65-90 % mean and no wall (< 25 %)
- [x] Existing bands still pass (baseline re-measured on purpose)
- [x] Docs and unit tests
