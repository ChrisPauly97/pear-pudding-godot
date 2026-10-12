# TID-783: Runs: rift / spire ladders and siege gauntlets

**Goal:** GID-187
**Type:** agent
**Status:** done
**Depends On:** TID-781

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Multi-fight sims with HP carried between fights: a rift tier ladder (floors, guardian floor, boons, drafted picks)
and a town-siege gauntlet. Bands: clear rate per rift tier falls smoothly; a level-appropriate siege is clearable.

## Research Notes

- `game_logic/spire/RiftDefs.gd`, `SpireFloorGen.gd`, `SpireDraft.gd`; `BattleModifiers._build_rift_deck` (own deck +
  run picks + buff boons); `docs/agent/rifts.md`; `autoloads/save_manager/SaveSpire.gd`.
- Siege: `SaveSiege.gd` (`get_active_siege`, `hero_hp` carry-over — BattleScene ~l.502), `TownSiege.gd` module.
- Draft picks need a bot policy (simple: best-power pick).

## Plan

`BalanceRuns`: a rift tier run (5 floors, boons from the game's seeded draft, HP carried) and a 3-wave siege, as the
typical profile; section `runs` with ladder (own tier clearable, smooth fall) and siege bands. Fix whatever the game
does differently from what the sim needs to share.

## Changes Made

- `game_logic/battle/BalanceRuns.gd` (+ `test_balance_runs.gd`), section `runs`, CI group. Cfg keys `boons`,
  `enemy_hp_mult`.
- **Bug:** rift runs and sieges carried an absolute 30 HP (sieges also capped max HP at 30). Now a fraction
  (`spire_run.hero_hp_frac`, `siege.hero_hp_frac`) through `BattleModifiers._apply_persistent_hp` /
  `record_persistent_hp`; `SaveSpire.hp_frac` / `set_hp_frac`, `SaveSiege.hp_frac` / `set_hp_frac`; interstitial
  shows a percent.
- **Bug:** siege waves 2-3 had no enemy level (fell back to 4 / 7). `SiegeDefs.stage_level`, `siege.level`,
  `SaveSiege.stage_level()` feed both the spawned raiders and the chained waves.
- Breathers: `RiftDefs.FLOOR_HEAL` / `SiegeDefs.WAVE_HEAL` 25 % between fights.
- Rift tiers are half a level (`TIERS_PER_LEVEL` 2, `HALF_TIER_HP` 1.3, `hp_mult`, `MAX_TIER` 93); floors share the
  tier level; rewards rescaled (`first_clear_xp`, `clear_coins`, `clear_drop_tier`); quests remapped (tier 3 → 9,
  5 → 17); save migration v52 (`RiftDefs.migrate_tier`).
- Boons as percentages via `RiftDefs.apply_boons` (shared), `PlayerState.boon_hp_mult` / `start_armor_frac`.

Measured: own tier 95-100 %, ladder falls 25-60 pp per half level; sieges 87.5-100 %.

## Documentation Updates

- `docs/agent/balance-sim.md` → Runs (TID-783); `rifts.md`; `town-siege.md`.
