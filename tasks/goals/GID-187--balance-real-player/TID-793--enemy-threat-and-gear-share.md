# TID-793: Enemy threat scaling and the 60 % gear share

**Goal:** GID-187
**Type:** agent
**Status:** done
**Depends On:** TID-787

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User target (2026-10-11): gear ≈ 60 % of a level-30 player's power. TID-787 measured ~7 % with build-fitted gear.
Moving power from levels to gear (cheaper ratings, lower `power_track`) reaches the share but makes high-level
fights 70-270 s and unlosable: enemy threat does not scale with the hero's growth.

## Research Notes

- Level-46 frost wendigo vs a typical light player (TID-787 probe): enemy 1091 HP; hero 250 HP took 302 damage in
  65 s and won (leech). Bot used Guard ×10 and Kick ×10 — heavies and casts are mostly nullified, swings are tiny.
- `enemy_dmg_per_level` (swings + spells past `power_from_level`) has no effect up to 0.1. Threat must come from
  sources the bot can't fully cancel: unblockable / partial heavies, enemy unarmed growth, minion attack growth with
  level, or Guard / Kick costs and cooldowns that scale.
- Knobs ready: `stat_rating_base`, `stat_rating_growth`, `stat_pct_cap`, `stamina_hp`, `armor_per_point`,
  `power_track`, `enemy_dmg_per_level`. Measurement: `BalanceProfiles.gear_share(level, enemy)`; fight length
  matters (same-level median 30-60 s).
- Also: magic types are uneven with full builds (rift strongest, dark weakest — TID-787 probes) and the casual bot
  loses packs (BID-107).

## Plan

Move the hero's growth past level 8 from levels to gear by item level, and make enemy threat grow with level so a
geared hero is still threatened. User (2026-10-12): enemy power is tied to level, not gear, so tune the gear supply
(drops) so players stay close enough to geared.

## Changes Made

- **Item power** (`GearCurve.gear_power` / `items_power`, `CombatTuning.item_power_log`): each worn stat item adds its
  slot share × upgrades × ln(enemy growth at its item level); `gear_track` / `gear_hp_track` 0.7 give
  `PlayerState.gear_power` (outgoing damage, in `DamageResolver.power_mult`) and `gear_hp_power` (max HP,
  `RealtimeCombat._scale_hero_hp`). Real time only (`BattleSetup.apply_gear`, shared with the game).
  `power_track` 0.8 → 0.3.
- **Enemy threat, level only:** `enemy_dmg_growth` × growth(L − `enemy_dmg_lag` 4) ^ `enemy_dmg_track` 0.7 (swings,
  minion swings, spells). Heavy blows are a share of the pre-gear max HP times that growth (before: a share of the
  geared max HP, so HP gear never helped against them).
- **Gear supply:** 42 fill-in items (ilvl 14/25/29/40/44/55 in every non-weapon slot, generated from same-band stat
  mixes, registry preloads, paper-doll looks). `GearDrops.behind_slots` by item level (`PITY_BEHIND` 8).
  `LootRoll.equipment_chance(tier, behind)`: ×2 catch-up chest chance while a slot is behind (`ChestLoot`).
  `GearSupply.simulate` (pure): at `TARGET_DROPS_PER_HOUR` 4 the worn loadout stays ≥ 0.85 of the curve from L20.
- **Bands:** `schools` / `conditions` cells wear expected gear (`cell_cfg` `geared`, `BalanceProfiles.gear_cfg`);
  school matrix levels re-picked. `rival_isfig_2` `rt_hp_mult` 1.25, `scarab_swarm` 0.6.
- Tests: new `test_gear_power.gd`; updated slot counts (13 → 19), enemy spell scale, heavy cap and boss phase-2 tests.

Measured: gear share 0.66 at L30, 0.84 at L46. All core bands and coverage sections pass; world +1 means 81 / 88 %;
same-level medians ~30 s. Not measured: the real chest rate per hour (the 4 drops / hour target assumes it).
Pre-existing: `inventory_tiles_smoke` fails on main too (BID-106).

## Documentation Updates

- `docs/agent/balance-sim.md` → Gear power and enemy threat (TID-793).
- `docs/agent/inventory-and-deck.md` → fill-in tiers, chest catch-up, Item power and the gear supply.
