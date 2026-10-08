# TID-719: Story-route zones with level ranges, enemy sub-ranges, camps from zones

**Goal:** GID-176
**Type:** agent
**Status:** pending
**Depends On:** TID-716

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

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

**Approved by the user (2026-10-08): zones follow the story route, and Chapter 1 = levels 1–10.** This replaces the distance-band plan. Distance bands would put Blancogov (end of Chapter 1) at about 21 and Marsax (Chapter 2) at about 16, against the story order.

| Zone | Levels | Story |
|---|---|---|
| Madrian outskirts (starter camps) | 1–5 | help_townsfolk, speak_maiteln |
| South road and wilds | 4–7 | leave_madrian, make_camp, learn_fire |
| Farsyth lands and Isfig road | 6–9 | find_farsyth, meet_isfig |
| Blancogov approach | 8–10 | reach_blancogov, enter_temple, council (`chapter1_complete`) |
| Larik | 10–14 | Chapter 2: eldar_charge → search_larik |
| Marsax Hold and war-camp | 13–17 | Chapter 2: west_to_marsax → war_camp |
| Wild land off the route | nearest route zone's max + distance ramp | — |

1. **Zone table:** `ZoneLevels.ZONES` holds the story regions, each with an anchor (a town via `RealmLayout` offsets, or a story site from `RealmLayout` / StoryQuests `site`), a radius and a level range. `zone_at_tile` / `range_at_tile` / `level_at_tile`: inside a zone, the level ramps from its min (nearest the previous zone on the route) to its max. Off the route, the nearest zone's max plus a distance ramp (about 1 level per 12 tiles), capped at 60. Towns themselves stay safe ground (no spawns), as today.
2. **Enemy sub-ranges:** `EnemyRegistry` gets a `level_range`. Hand-authored for starter types (undead_basic 1–2, undead_horde 2–4, ghoul_pack 3–5); tier defaults otherwise (1 → 1–12, 2 → 5–24, 3 → 12–40, 4 → 20–60). Enemy level = the tile level clamped to zone ∩ type (the zone wins if they don't overlap).
3. **Starter camps:** the authored `level` is dropped and derived from the camp tile and type within the outskirts' 1–5. `camp_for_level` becomes nearest; `test_starter_zone` checks every level 1–5 has a camp within one level. The Barrow King keeps a fixed level (unique boss); re-check it against Chapter 1 (14 is above the cap; consider 10).
4. **Consumers:** EnemyNPC `enemy_level()`, ChestLoot, StarterCamps, XP / con colour: no API change beyond the new level source. Keep `level_at_tile` pure and thread-safe (chunk gen).
5. **Tests:** every Chapter 1 story step's location is within 1–10; zones along the route are non-decreasing in story order; every camp level is inside its zone; level_at_tile is continuous enough (no jump over 2 between neighbouring tiles off town edges).
6. **Docs:** world-generation, starter-zone-and-training, enemies-and-npcs, balance-sim (enemy-of-level-L definition).

Out of scope here, now in GID-177 / TID-722: camps and repeatable quests in the road zones.

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
