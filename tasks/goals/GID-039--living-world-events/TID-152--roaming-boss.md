# TID-152: Roaming Boss Event + Minimap Marker

**Goal:** GID-039
**Type:** agent
**Status:** done
**Depends On:** TID-151

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The flagship event: a boss-tier enemy materialises near the player, marked on the minimap, daring them to engage. It's optional — wander away and it despawns — but defeating it drops a rare card. This creates the "drop everything" moment the open world lacks.

## Research Notes

- **Spawn:** Register `roaming_boss` with WorldEventManager (TID-151), interval ~15–25 min of overworld play. Spawn func instantiates `scenes/world/entities/EnemyNPC.tscn` at `find_spawn_tile(player_pos, 20, 40)` with a boss-tier EnemyData.
- **Boss EnemyData:** Check what boss-flagged enemies exist from GID-021/TID-070 (the boss framework is done; concrete bosses may be pending TID-068 human input). If no boss `.tres` exists yet, create one self-contained `roaming_terror.tres` + `.uid` with a strong deck from existing cards — don't block on GID-021.
- **Presentation:** `EnemyNPC.gd` — add `is_roaming_boss: bool`: sprite scale ×1.5 and an emissive tint (check how sprites are tinted; a modulate color is enough — avoid new shaders). Verify Sprite3D Y-offset rule from CLAUDE.md when scaling (bottom edge must clear y=0).
- **Minimap marker:** `scenes/world/Minimap.gd` — listens to `world_event_started("roaming_boss")`; the spawn func should stash the boss position somewhere readable (e.g. WorldEventManager exposes `get_event_position(id)`). Red dot drawn at the world→minimap transform — study how existing entity dots are drawn and respect the GID-006 rotation fix.
- **Resolution paths:**
  - Defeated → drop a rare card via the GID-002 reward flow + bonus coins; `WorldEventManager.end_event("roaming_boss")`.
  - Player walks > ~80 tiles away or 5 minutes pass → despawn quietly, `end_event`.
  - Player loses the battle → normal defeat flow; boss despawns.
- **Engagement:** Reuse the standard EnemyNPC track/engage AI (`docs/agent/enemies-and-npcs.md`) but with a shorter aggro radius — the boss should feel approachable on the player's terms, not a death sentence.
- `docs/agent/enemies-and-npcs.md` — document the roaming boss variant.

## Plan

1. Create `data/enemies/roaming_terror.tres` with `is_boss=true`, `boss_hp=50`, `difficulty_tier=4`, a strong deck, and a full rare drop pool.
2. Modify `EnemyNPC.gd`: add `_is_roaming_boss` bool set from `init_from_data` data dict; in `_ready()` apply crimson 1.5× visual when set (distinct from gold 1.3× regular boss).
3. Add `set_event_position(id, pos)` / `get_event_position(id)` to `WorldEventManager.gd` so minimap can show an edge indicator when boss is outside view radius.
4. Create `game_logic/WorldEvents.gd` with `static register_all(world_scene)` that registers `roaming_boss` (15–25 min interval) with WorldEventManager via `get_node_or_null`. Spawn fn: finds grass tile 20–40 world-units from player, instantiates EnemyNPC with `is_roaming_boss=true`, registers with WorldScene, emits HUD toast. Cleanup fn: queue_free boss, clear tracking vars.
5. Modify `WorldScene.gd`: preload WorldEvents, add `_roaming_boss_id`/`_roaming_boss_timer` vars, call `WorldEvents.register_all(self)` in `_ready()` if infinite world, add boss despawn check (>160 units or >300 s) to `_process()`, expose `get_entity_root()`.
6. Modify `Minimap.gd`: in `_on_draw()`, skip "roaming_boss" in `_draw_group`, then draw it separately — larger bright-red dot in range, edge indicator when outside.
7. Modify `SceneManager._on_battle_won()`: if `enemy_type == "roaming_terror"`, call `WorldEventManager.end_event("roaming_boss")` via `get_node_or_null`.
8. Update `docs/agent/enemies-and-npcs.md`.

## Changes Made

- `data/enemies/roaming_terror.tres` + `.uid` — new boss-tier EnemyData: is_boss=true, boss_hp=50, 16-card deck, phase-2 deck, 7-card rare drop pool, coin_reward=40, difficulty_tier=4.
- `scenes/world/entities/EnemyNPC.gd` — added `_is_roaming_boss: bool`; set from `init_from_data` data dict; `_ready()` applies `_apply_roaming_boss_visual()` (crimson, 1.5×) when set, before falling through to regular boss visual.
- `autoloads/WorldEventManager.gd` — added `_event_positions: Dictionary`, `set_event_position(id, pos)`, `get_event_position(id)`, and clear on `end_event()`.
- `game_logic/WorldEvents.gd` + `.uid` — new static-method script: `register_all(world_scene)` wires the roaming boss (15–25 min interval) into WorldEventManager; spawn fn finds a grass tile 20–40 units from player, instantiates EnemyNPC with crimson visuals, registers in WorldScene, emits HUD toast; cleanup fn queue_frees the boss node.
- `scenes/world/WorldScene.gd` — preloads WorldEvents, calls `WorldEvents.register_all(self)` at end of `_ready()` for infinite worlds, adds `_roaming_boss_timer` var, `get_entity_root()`, and `_tick_roaming_boss(delta)` (despawns if >160 units or >300 s).
- `scenes/world/Minimap.gd` — `_draw_group` accepts optional `skip_id`; boss drawn separately via `_draw_boss_dot()` — larger (7 px) in range, faded edge indicator when outside minimap.
- `autoloads/SceneManager.gd` — calls `WorldEventManager.end_event("roaming_boss")` in `_on_battle_won()` when `enemy_type == "roaming_terror"`; added roaming_terror to XP table (150 XP).

## Documentation Updates

- `docs/agent/enemies-and-npcs.md` — added "Roaming Boss" subsection under Boss Battle Framework; added roaming_terror.tres to asset table.
