# GID-176: Balance Simulation Harness

## Objective

A headless, seeded simulator that runs thousands of real-time battles with a scripted player, so balance can be measured and guarded without manual play.

## Context

User (2026-10-08): "do many simulations of battles to fix battle balancing… deterministic so we can do balance testing without token cost and without me manually battling many many times." Decisions: real time only. **Balance targets (user, 2026-10-08)** replace the "current baseline" plan:
- Enemy of the **same level**, full HP and mana, average play (the default `BalanceBot`): **win 100%**.
- Enemy **one level above**: **win about 75%**.

Fidelity rule: the simulator runs the **same** rules code as the game (pure `RealtimeCombat`, `SpellEffectResolver`, plus the extracted `PlayerCaster` and `BattleSetup` that the scene also calls), never a sim-only copy.

## Design decisions (user, 2026-10-08)

1. **A zone has a level range, and each enemy type has a sub-range inside it.** An enemy's level is rolled or placed within its sub-range clipped to the zone. Starter camps take their level from that, not from their own authored ladder.
2. **Enemies behave the same whatever the player has learned.** No more `heavy_enabled = learned.has("kick")` or an enemy minion cap tied to `feat_minions`.
3. **Heavy blows scale with enemy level:** weaker on early enemies (or only from a level threshold up).
4. **Weaker enemies may still cast (cast-time abilities), but those hit less hard.** So when the player learns Kick, casts are already familiar.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-712](TID-712--headless-deterministic-core.md) | Headless-safe, seeded battle core | agent | done | — |
| [TID-713](TID-713--player-caster.md) | Extract player cast rules into a pure PlayerCaster | agent | done | TID-712 |
| [TID-714](TID-714--battle-setup.md) | Shared pure battle setup | agent | done | TID-712 |
| [TID-715](TID-715--balance-bot.md) | Simulated player (fixed policy) | agent | done | TID-713, TID-714 |
| [TID-716](TID-716--balance-sim-cli.md) | tools/balance_sim.gd — batch runner, sweeps, CSV | agent | done | TID-715 |
| [TID-717](TID-717--balance-bands.md) | CI balance bands from the user's targets | agent | pending | TID-716 |
| [TID-719](TID-719--zone-level-ranges.md) | Story-route zones with level ranges (Chapter 1 = 1–10), enemy sub-ranges, camps from zones | agent | done | TID-716 |
| [TID-720](TID-720--enemy-level-scaling.md) | Enemies independent of player unlocks; casts/heavies scale by enemy level | agent | pending | TID-716 |
| [TID-718](TID-718--tune-to-targets.md) | Tune combat numbers to hit the targets | agent | pending | TID-719, TID-720 |

## Acceptance Criteria

- [x] Same seed → identical fight (test)
- [x] Scene and simulator share player cast rules and battle setup
- [x] `tools/balance_sim.gd` runs N fights with sweeps and writes summary + CSV
- [ ] CI fails when win rates miss the targets (same level 100%, +1 level ~75%)
- [x] Zones have level ranges; enemies a sub-range; starter camps follow the zone
- [ ] Enemy behaviour independent of player unlocks; casts / heavy blows scale with enemy level
- [ ] Combat numbers tuned so the targets hold across the level ladder
- [ ] docs/agent/balance-sim.md; tests, gdlint and unsafe-hits clean
