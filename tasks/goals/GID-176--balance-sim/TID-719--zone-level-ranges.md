# TID-719: Zone level ranges, enemy sub-ranges, camps from zones

**Goal:** GID-176
**Type:** agent
**Status:** in-progress
**Depends On:** TID-716

## Lock

**Session:** ccr-74960c86-ruw5if
**Acquired:** 2026-10-08T15:23:15Z
**Expires:** 2026-10-08T15:53:15Z

## Context

Defines what "an enemy of level L" is, which the balance targets (TID-718) depend on. Decision 1.

**Design decisions (user, 2026-10-08):**
1. **A zone has a level range, and each enemy type has a sub-range inside it.** An enemy's level is rolled or placed within its sub-range clipped to the zone. Starter camps take their level from that, not from their own authored ladder.
2. **Enemies behave the same whatever the player has learned.** No more `heavy_enabled = learned.has("kick")` or an enemy minion cap tied to `feat_minions`.
3. **Heavy blows scale with enemy level:** weaker on early enemies (or only from a level threshold up).
4. **Weaker enemies may still cast (cast-time abilities), but those hit less hard.** So when the player learns Kick, casts are already familiar.

## Research Notes

- Today `game_logic/world/ZoneLevels.gd` maps a tile to **one** level: the starter ring (radius 30 tiles around Madrian, `ORIGIN_TILE`) is all level 1, then +1 per 12 tiles (`LEVEL_STEP_TILES`), cap 60. There is no range.
- `game_logic/world/StarterZone.gd` authors 9 camps with their own `level` 1–9 (plus a level-14 crypt), all inside or near that level-1 ring, so they contradict the zone level.
- Enemy level is consumed as `enemy_data.enemy_level`: `BattleSetup.enemy_tier` → `ZoneLevels.scaled_tier`, `scaled_hero_hp`, XP via `scaled_xp`, con colour via `con`. Find every producer: chunk enemies in `InfiniteWorldGen` / `EnemyRegistry.type_for_chunk_dist` / `type_for_biome`, `StarterCamps`, `LooseEnemySpawner`, StoryCast, rifts.
- **Proposed shape (confirm with the user before building):** `ZoneLevels.range_at_tile(tx, tz) -> Vector2i(min, max)`. Madrian outskirts = 1–9 (the GID-141 unlock ladder's level band), split into rings or bands so camps further out sit higher. Each enemy type gets a `level_range` in EnemyRegistry. An enemy's level = a deterministic pick (chunk / camp seed) inside type range ∩ zone range. Camps keep their authored order but take the level from their tile's zone range.
- Keep chunk generation pure and thread-safe (CLAUDE.md "TerrainMath" → worker threads).
- Tests: range monotonic with distance; every camp's level inside its zone range; every enemy type's sub-range intersects a zone it spawns in.
- Docs: named-maps / world-generation / starter-zone-and-training / enemies-and-npcs.

## Plan

**Waiting for user approval (2026-10-08).** High complexity: existing camp and town levels move.

- **Zones:** `ZoneLevels.ZONES` distance bands with level ranges. Ranges overlap at the borders; the level ramps through the band.
  - Madrian outskirts: d 0–75 (flat 1 to 24), levels 1–9.
  - Maykalene march: d 75–150, levels 8–12 (Maykalene ≈ 9).
  - Marsax reach: d 150–225, levels 13–17 (Marsax ≈ 16).
  - Heartland: d 225–300, levels 18–24 (Blancogov / Larik ≈ 21).
  - Wilds: every 75 tiles further, +6 per band, cap 60.
- **Enemy sub-ranges:** `EnemyRegistry` `level_range`. Hand-authored: `undead_basic` 1–3, `undead_horde` 3–6, `ghoul_pack` 5–9. Default from tier: 1 → 1–12, 2 → 5–24, 3 → 12–40, 4 → 20–60. Enemy level = the tile level clamped to zone ∩ type (the zone wins if they don't overlap).
- **Camps:** the authored `level` is dropped and derived instead. New levels: grain 1, south 2, barrow 3, orchard 5, hedge 5, west 6, tor 7, road 7, copse 8. `camp_for_level` becomes nearest; `test_starter_zone` and the `test_side_quests` pacing test are updated. The Barrow King keeps level 14 (unique boss).

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
