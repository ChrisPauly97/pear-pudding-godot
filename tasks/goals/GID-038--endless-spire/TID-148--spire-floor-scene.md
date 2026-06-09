# TID-148: Spire Floor Scene + Enemy Difficulty Scaling

**Goal:** GID-038
**Type:** agent
**Status:** pending
**Depends On:** TID-146

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Each Spire floor is a small arena: a compact room with one enemy between the player and the stairs up. This task builds the floor generation/rendering and the enemy scaling curve. Draft UI (TID-147) and entrance routing (TID-149) plug into it.

## Research Notes

- **Floor generation:** Reuse `game_logic/world/DungeonGen.gd` with a small fixed size (e.g. 12×12) seeded from `spire_run.seed + floor`. Alternatively a handful of pre-authored floor layouts cycled by floor number — check DungeonGen's API first; reuse is preferred over new layouts.
- **Rendering:** Spire floors should render through the existing named-map path — `WorldMap` + the `TerrainMath` mesh pipeline (see `docs/agent/named-maps-and-dungeons.md` for how procedural dungeons become WorldMap instances and how the map stack works). The Spire floor is conceptually "a dungeon map with one enemy and one exit door".
- **Enemy scaling:** A `pick_floor_enemy(floor: int, rng) -> EnemyData` func:
  - Floors 1–3: base enemies (ghost/skeleton tier)
  - Floors 4–6: stronger decks (check `EnemyRegistry.gd` for available enemies; GID-021 enemies may not all exist yet — scale gracefully with what's registered)
  - Every 7th floor: boss-tier using the boss framework from TID-070 (boss flag on EnemyData; check `docs/agent/enemies-and-npcs.md` and the GID-021 goal folder for the boss presentation differences)
  - Beyond the roster, repeat the strongest tier — true "endless" stat inflation is out of scope for v1.
- **Hero HP carry-over:** `spire_run.hero_hp` (TID-146) is the hero's starting HP each floor — damage persists between floors. Check `game_logic/battle/HeroState.gd` for how starting HP is set (default 30).
- **Stairs up:** After the enemy dies, spawn a Door entity that advances the floor (`SaveManager.advance_spire_floor()`) — but the draft (TID-147) runs first; coordinate via GameBus: battle won → draft modal → stairs activate.
- **Entity reuse:** `scenes/world/entities/EnemyNPC.gd` and `Door.gd` work in named maps already; the floor is just a generated map with these two entities.
- `docs/agent/named-maps-and-dungeons.md` — primary design doc; update with the Spire floor variant.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
