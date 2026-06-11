# TID-148: Spire Floor Scene + Enemy Difficulty Scaling

**Goal:** GID-038
**Type:** agent
**Status:** done
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

1. Create `game_logic/spire/SpireFloorGen.gd` — static funcs:
   - `map_name_for(floor, run_seed)`, `cleared_flag_for(floor, run_seed)` — pure string helpers
   - `pick_enemy_type(floor)` — tier ladder: floors 1-3 undead_basic, 4-6 undead_horde, 7-9 ghoul_pack, 10+ undead_elite; every 7th floor is boss
   - `is_boss_floor(floor)` — floor % 7 == 0
   - `generate(floor, run_seed)` — fills 100×100 WorldMap with walls, carves 12×8 arena in centre, places enemy + flag-gated exit door, saves to user://maps/
2. Modify `scenes/world/WorldScene.gd` — add `spire_floor_` map-name branch in `_ready()` (mirror of dungeon_ branch); update map label.
3. Modify `scenes/battle/BattleScene.gd` — apply `spire_run.hero_hp` as starting HP after opening hand; include `"hero_hp"` in `battle_won` result dict.
4. Modify `autoloads/SceneManager.gd` — Spire battle won: save hero HP, set cleared flag, show SpireDraftScene overlay; Spire battle lost: end run; `exit_map()` Spire branch: advance floor.
5. Update `docs/agent/named-maps-and-dungeons.md` with Spire floor section.

## Changes Made

- **`game_logic/spire/SpireFloorGen.gd`** (new) — static helpers: `map_name_for`, `cleared_flag_for`, `pick_enemy_type`, `is_boss_floor`; `generate(floor, run_seed)` builds a 12×8 arena WorldMap, places enemy + flag-gated exit door, saves to user://maps/.
- **`scenes/world/WorldScene.gd`** — added `const SpireFloorGen` preload; `spire_floor_` branch in `_ready()` (mirrors dungeon_ branch); updated map label.
- **`scenes/battle/BattleScene.gd`** — applies `spire_run.hero_hp` after opening hand; includes `"hero_hp"` in both `battle_won` result dicts (normal + boss).
- **`autoloads/SceneManager.gd`** — `_spire_draft_scene_packed` preload; `_spire_draft_overlay` member; Spire branch in `_on_battle_won()` (save HP, set cleared flag, show draft overlay); `end_spire_run()` in `_on_battle_lost()`; `exit_map()` Spire branch → `_advance_spire_floor()`; new methods: `_show_spire_draft()`, `_on_spire_draft_picked()`, `_advance_spire_floor()`.

## Documentation Updates

- **`docs/agent/named-maps-and-dungeons.md`** — added "Endless Spire Floors" section covering map naming, WorldScene integration, floor contents, enemy ladder, exit door flow, draft integration, and hero HP carry-over.
