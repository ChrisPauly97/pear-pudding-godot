# TID-072: Update Biome Spawn Tables

**Goal:** GID-021
**Type:** agent
**Status:** done
**Depends On:** TID-069

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The infinite world currently spawns only the 4 original enemy types regardless of biome. This task updates the spawn tables so each biome uses its biome-appropriate enemy pool, making exploration feel distinct.

## Research Notes

- `game_logic/world/InfiniteWorldGen.gd` or `game_logic/world/BiomeDef.gd` — find where enemy types are assigned to spawned entities; search for enemy type strings like `"undead_basic"`
- `game_logic/world/ChunkData.gd` may hold the entity list for a chunk
- Target enemy distribution per biome:
  - grasslands: undead_basic, undead_horde, wraith
  - forest: undead_basic, forest_shade, ghoul_pack
  - desert: sand_stalker, undead_horde
  - scorched: scorched_revenant, undead_elite
  - mountains: mountain_troll, stone_golem
- Boss enemies should NOT appear in the infinite world spawn tables — they are named-map only
- Keep spawn weights so some biomes feel harder (mountains/scorched = tougher enemies predominantly)
- Strict mode: if enemy type is stored as a String, use `EnemyRegistry.get_enemy(type_id)` to validate the ID exists before using it

## Plan

**Located the real spawn table:** `game_logic/world/BiomeDef.gd`'s
`ENEMY_POOLS: Array` — one `Array` of type-id strings per biome (index
matches biome id). `EnemyRegistry.type_for_biome(biome_id, dist)` indexes it
with `clamp(dist / 8, 0, pool.size() - 1)`, so later entries are the
tougher/farther-out ones and pool length varies per biome without any other
code change needed (`ChunkData.gd`/`InfiniteWorldGen.gd` just call
`type_for_biome()`, they don't hardcode pool sizes).

**Before this task**, every biome pool held only the original 4 core types,
and **Mountains held `["undead_elite", "undead_elite"]` — the literal same
type twice**, so deep-mountain exploration had zero variety at all (worse
than the other biomes, which at least alternated between 2 real types).

**Applying the exact target distribution from Research Notes:**
```
grasslands: ["undead_basic", "undead_horde", "wraith"]
forest:     ["undead_basic", "forest_shade", "ghoul_pack"]
desert:     ["sand_stalker", "undead_horde"]
scorched:   ["scorched_revenant", "undead_elite"]
mountains:  ["mountain_troll", "stone_golem"]
```

**Resolved the stone_golem/boss ambiguity** (flagged during TID-069's Plan):
Research Notes' blanket "boss enemies should NOT appear in the infinite
world spawn tables" reads as targeting the 2 *dedicated story bosses*
(`hollow_steward`/`martarquas_vanguard`, TID-071 — named-map-only,
consistent with that line) — its own target distribution explicitly places
`stone_golem` in the mountains pool despite `stone_golem.is_boss == true`.
Followed the explicit table over the general guidance line: `stone_golem`
is a legitimate infinite-world "mini-boss" spawn, same category as
`roaming_terror` (also `is_boss = true` and world-spawnable, just via
`WorldEvents` instead of a biome pool).

**Verified every listed type_id resolves** via `EnemyRegistry.get_deck()`
returning a real (non-fallback) deck for each — `undead_basic`,
`undead_horde`, `ghoul_pack`, `undead_elite` (pre-existing) plus
`wraith`/`forest_shade`/`sand_stalker`/`scorched_revenant`/`mountain_troll`/
`stone_golem` (TID-069). No `EnemyRegistry.get_enemy()` method exists to
validate against (checked — the registry exposes typed getters, not a
generic lookup), so validation is "does `get_deck()` return this type's
real deck, not the fallback" per-type via a throwaway script, not a new
runtime guard (`type_for_biome()` already only ever returns a literal from
this const array, so there's no possibility of an invalid id reaching it
at runtime — validating at edit time is sufficient).

## Changes Made

- `game_logic/world/BiomeDef.gd`: `ENEMY_POOLS` updated to the target
  distribution (grasslands/forest now 3 entries, desert/scorched/mountains
  2) — every biome now has a distinct pool including at least one GID-021
  type; fixed mountains' literal `["undead_elite", "undead_elite"]`
  duplicate.
- Verified every listed type resolves to a real (non-fallback) deck via
  `EnemyRegistry.get_deck()` and checked `is_tracking()` per type with a
  throwaway headless script — all 10 pool entries confirmed correct.
- Verified: headless editor import clean; `tests/runner.gd` — 2355 passed
  (unchanged), 0 failed, 1 pending (pre-existing).

## Documentation Updates

- `docs/agent/enemies-and-npcs.md`: added the "Biome Enemy Pools" section
  (the actual `ENEMY_POOLS` table + rationale) that TID-069's doc edit had
  left as a forward-reference placeholder pending this task.
