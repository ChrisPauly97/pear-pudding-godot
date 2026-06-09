# TID-152: Roaming Boss Event + Minimap Marker

**Goal:** GID-039
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
