# TID-770: Distribution: drop pools, vendors, packs

**Goal:** GID-183
**Type:** agent
**Status:** done
**Depends On:** TID-768, TID-769

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

New Allies must reach players: thematic drops, shops and packs.

## Research Notes

- Drop pools: `autoloads/EnemyRegistry.gd` per-type `drop_pool` (forest/bog types → verdant Allies; scorched/rift-touched types → rift Allies). Keep `test_enemy_school_profiles` passing.
- Packs: `game_logic/PackDefs.gd` (docs/agent/card-packs.md). Vendors: merchant stock + vendor magic-type preferences (GID-180 TID-746, docs/agent/inventory-and-deck.md).
- Soulbind/signature cards: optional — only if an enemy's signature theme clearly fits.
- Balance bands must still pass (enemy decks unchanged; only drops).

## Plan

1. Drop pools (`EnemyRegistry.gd`, `drop_pool` only; no enemy deck touched): 14 types gained Allies. Verdant on the forest/bog/thorn types (`wolf_pack`, `cactus_worm`, `imbued_stag`, `forest_shade`, `bog_hag`); Rift on the spectral/scorched/ember/rift types (`spectre_wisp`, `wraith`, `scarab_swarm`, `spectre_haunt`, `ember_cultist`, `scorched_revenant`, `rift_echo`, `spectre_dread`, `roaming_terror`). Cost 1-2 on tier-1/2 types, cost 3 mid, cost 4-5 on tier 3-4 types. Deviation: no forest/bog type is tier 3+, so the two verdant cost-5 Allies sit on `bog_hag` (tier 2).
2. Packs: `PackDefs.gd` builds its pool from every `is_craftable()` card, and none of the 16 set `can_craft = false`, so they are already in both packs. No table edit.
3. Shop: `ShopScene` lists every unlocked, non-signature card, so the Allies are sold in all towns. Vendor tastes (`VendorPrefs`) stay sell-side only. Added the four cost-5 Allies to `WorldEvents._MERCHANT_CARD_POOL` (traveling merchant premium stock).
4. Test: `tests/unit/test_ally_distribution.gd` (4 tests).

## Changes Made

- `autoloads/EnemyRegistry.gd`: `drop_pool` additions on 14 enemy types (every new Ally in at least one pool; 0 enemy decks changed).
- `game_logic/WorldEvents.gd`: `_MERCHANT_CARD_POOL` + `bloom_elder_root`, `thorn_briarwall`, `flux_temporal_rider`, `fracture_unmaker`.
- `tests/unit/test_ally_distribution.gd`: new.
- Validation: parse check clean, `scripts/unsafe-hits.sh` clean, gdlint clean, runner RESULT: PASS (0 SCRIPT ERROR), `balance_bands.gd` RESULT: PASS.

## Documentation Updates

- `docs/agent/magic-system.md`: Distribution table under the Ally roster (replaces "drop biomes are TID-770's call").
- `docs/agent/card-packs.md`: integration row notes the Allies flow in via `is_craftable()`.
- `docs/agent/inventory-and-deck.md`: Ally stock under vendor tastes.
- `docs/agent/enemies-and-npcs.md`: traveling merchant pool size 18 -> 22.
