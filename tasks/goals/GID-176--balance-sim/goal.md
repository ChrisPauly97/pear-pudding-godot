# GID-176: Balance Simulation Harness

## Objective

A headless, seeded simulator that runs thousands of real-time battles with a scripted player, so balance can be measured and guarded without manual play.

## Context

User (2026-10-08): "do many simulations of battles to fix battle balancing… deterministic so we can do balance testing without token cost and without me manually battling many many times." Decisions: real time only. **Balance targets (user, 2026-10-08)** replace the "current baseline" plan:
- Enemy of the **same level**, full HP and mana, average play (the default `BalanceBot`): **win 100%**.
- Enemy **one level above**: **win about 75%**.

Fidelity rule: the simulator runs the **same** rules code as the game (pure `RealtimeCombat`, `SpellEffectResolver`, plus the extracted `PlayerCaster` and `BattleSetup` that the scene also calls), never a sim-only copy.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-712](TID-712--headless-deterministic-core.md) | Headless-safe, seeded battle core | agent | done | — |
| [TID-713](TID-713--player-caster.md) | Extract player cast rules into a pure PlayerCaster | agent | done | TID-712 |
| [TID-714](TID-714--battle-setup.md) | Shared pure battle setup | agent | done | TID-712 |
| [TID-715](TID-715--balance-bot.md) | Simulated player (fixed policy) | agent | done | TID-713, TID-714 |
| [TID-716](TID-716--balance-sim-cli.md) | tools/balance_sim.gd — batch runner, sweeps, CSV | agent | pending | TID-715 |
| [TID-717](TID-717--balance-bands.md) | CI balance bands from the user's targets | agent | pending | TID-716 |
| [TID-718](TID-718--tune-to-targets.md) | Tune combat numbers to hit the targets | agent | pending | TID-716 |

## Acceptance Criteria

- [x] Same seed → identical fight (test)
- [x] Scene and simulator share player cast rules and battle setup
- [ ] `tools/balance_sim.gd` runs N fights with sweeps and writes summary + CSV
- [ ] CI fails when win rates miss the targets (same level 100%, +1 level ~75%)
- [ ] Combat numbers tuned so the targets hold across the level ladder
- [ ] docs/agent/balance-sim.md; tests, gdlint and unsafe-hits clean
