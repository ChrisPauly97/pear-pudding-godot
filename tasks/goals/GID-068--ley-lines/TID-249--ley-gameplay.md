# TID-249: Ley Gameplay — Speed Boost, Attuned Battle Buff, Mana Wells

**Goal:** GID-068
**Type:** agent
**Status:** done
**Depends On:** TID-247

## Context

Makes ley lines mechanical: route choice (follow the line for speed), combat positioning (engage while Attuned for a turn-one mana edge), and intersection rewards (Mana Wells).

## Plan

- Speed boost: multiply `_get_move_speed()` by 1.15 when on a line.
- Attuned buff: stamp `player_attuned` in `get_battlefield_context` → SceneManager → enemy_data → BattleScene applies +1 mana after `start_turn(1)`.
- HUD indicator: cyan Label in WorldScene HUD, toggled per-frame in `_is_infinite` path.
- Mana Wells: InfiniteWorldGen scans chunk for intersection tiles; ChunkRenderer spawns `ManaWell.tscn`; WorldScene handles collect interaction.

## Changes Made

- `scenes/world/entities/Player.gd`: added `TerrainMath` preload; `_get_move_speed()` multiplies by 1.15 on ley line in infinite world.
- `scenes/world/WorldScene.gd`: added `_ley_indicator` label (cyan HUD); per-frame toggle; `get_battlefield_context` includes `is_player_attuned`; `register_mana_well`, `_find_nearby_mana_well`; chunk unload cleans up `_mana_well_nodes`; `_check_interactions` includes mana wells; `_handle_interact` collects mana wells (+15 essence).
- `autoloads/SceneManager.gd`: stamps `enemy_data["player_attuned"]` in `_on_enemy_engaged`.
- `scenes/battle/BattleScene.gd`: after `start_turn(1)`, increments `hero.mana` by 1 (capped 10) and emits HUD message when `player_attuned`.
- `game_logic/world/InfiniteWorldGen.gd`: added `TerrainMath` preload; `_gen_entities` scans every 2nd tile for `ley_intersection_strength > 0` on TILE_GRASS, appends best to `chunk.mana_wells`.
- `game_logic/world/ChunkData.gd`: added `var mana_wells: Array[Dictionary] = []`.
- `autoloads/SaveManager.gd`: added `collected_mana_wells: Array[String]`; v38→v39 migration; `is_mana_well_collected` / `mark_mana_well_collected` helpers; updated `new_game`, `load_save`, `save`.
- `scenes/world/ChunkRenderer.gd`: preloads `_ManaWellScene`; `_spawn_entities` spawns uncollected mana wells and calls `register_mana_well`.
- `scenes/world/entities/ManaWell.gd`: procedural mesh entity (cylinder base + crystal prism); `init_from_data` sets `well_id` meta.
- `scenes/world/entities/ManaWell.tscn` + `ManaWell.tscn.uid`: scene file with UID `uid://f6svk3gkwd7d`.

## Documentation Updates

- `docs/agent/ley-lines.md` covers all gameplay systems.
- CLAUDE.md documentation table updated.
