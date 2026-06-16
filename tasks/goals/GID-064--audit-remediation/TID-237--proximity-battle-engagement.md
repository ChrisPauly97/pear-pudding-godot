# TID-237: Proximity battle engagement for tracking enemies

**Goal:** GID-064
**Type:** agent
**Status:** done
**Depends On:** TID-236

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The tutorial tip says "Walk into an enemy to start a battle"
(scenes/world/WorldScene.gd:1123-1125), but enemies have no collision shape, no Area3D,
and no tracking AI — engagement only happens via the interact key/button
(`engage()` from `_handle_interact`). The `"tracking": true` field written by every
generator (InfiniteWorldGen.gd:251, WorldMap.gd:250, DungeonGen.gd:108) and the
constants `AUTO_BATTLE_RANGE` / `TRACKING_SPEED` (autoloads/IsoConst.gd:30-32) are dead.

**User decision:** implement mixed engagement — enemies with `tracking: true` start
battles on proximity; non-tracking enemies remain interact-first. Update the tutorial
tip to describe both.

## Research Notes

- EnemyNPC scene (`scenes/world/entities/EnemyNPC.tscn`) is a bare Node3D + mesh
  (head/legs added in EnemyNPC.gd:43-54). The idiomatic Godot approach: add an
  `Area3D` + `CollisionShape3D` (SphereShape3D, radius = `IsoConst.AUTO_BATTLE_RANGE`)
  to tracking enemies and connect `body_entered` to trigger `engage()`. The player is a
  CharacterBody3D (scenes/world/entities/Player.gd) — verify its collision layer and
  give the Area3D a matching mask; check project.godot `[layer_names]` for existing
  layer conventions before assigning.
- The `tracking` flag already flows from all three generators into the spawn data the
  ChunkRenderer/WorldScene use to instantiate enemies — find where enemy spawn dicts are
  consumed (ChunkRenderer.gd entity spawn section, around :268) and pass the flag into
  EnemyNPC (e.g. `set_meta` or an exported var set at spawn).
- Optional but in-spirit: tracking enemies can also *move toward* the player within a
  pursuit radius using `TRACKING_SPEED` — keep it simple (lerp position in
  `_physics_process` when player within range, no pathfinding; GID-047 tap-to-move owns
  real pathfinding later). If implemented, respect named-map walls via
  `get_terrain_height` walkability or skip movement on named maps. If too risky, ship
  proximity-engage only and leave `TRACKING_SPEED` for a follow-up — note it in
  Changes Made.
- Engagement guards to preserve: defeated-enemy persistence
  (SaveManager.defeated_enemies — defeated enemies must not re-engage), the
  battle-already-active state (`SceneManager._state`), and the pending-battle resume
  path (WorldScene.gd:238-239) — don't let a proximity trigger fire during resume or
  while an overlay is open.
- Debounce: after losing/fleeing a battle the player respawns near the enemy — add a
  short immunity window (e.g. 2 s SceneTreeTimer or require exiting and re-entering the
  Area3D) so they aren't chain-engaged.
- Tutorial tip: WorldScene.gd:1123-1125 — reword to cover both modes (e.g. "Some
  enemies attack on sight — others wait. Press [interact] to start a battle.").
  Mobile parity rule: interact already has a touch button; proximity engagement is
  input-free, so parity holds.
- Decide the tracking/non-tracking split per enemy type: generators currently write
  `tracking: true` unconditionally — change them to set it per enemy type (suggestion:
  aggressive types true, e.g. dungeon enemies and bosses; overworld wanderers false).
  Check EnemyRegistry data for type names after TID-228 lands. Document the chosen
  split in docs/agent/enemies-and-npcs.md.

Depends on TID-236 only to avoid merge conflicts (TID-236 explicitly preserves the
tracking fields for this task).

## Plan

1. **EnemyRegistry.gd**: add `is_tracking(type_id)` — returns true for `undead_elite`, `ghoul_pack`, `roaming_terror`.
2. **InfiniteWorldGen.gd**: change `"tracking": true` → `"tracking": EnemyRegistry.is_tracking(etype)`.
3. **WorldMap.gd** lines 265 + 559: change to `"tracking": EnemyRegistry.is_tracking(...)`. Keep line 766 (depth-placed dungeon enemies) as `true`.
4. **DungeonGen.gd** + **SpireFloorGen.gd**: keep `"tracking": true` (dungeon/spire = always aggressive).
5. **WorldEvents.gd**: add `"tracking": true` to roaming boss spawn dict.
6. **EnemyNPC.gd**: add `_tracking` field; `init_from_data` reads it; in `_ready()` if tracking, create Area3D (collision_mask=1) + SphereShape3D (radius=AUTO_BATTLE_RANGE); connect `body_entered` → `_on_body_entered`; `_on_body_entered` guards: alive, SceneManager.can_proximity_engage(), not already defeated.
7. **SceneManager.gd**: add `_proximity_engage_blocked`, `can_proximity_engage()`, arm 2s immunity in `_restore_world()`.
8. **WorldScene.gd** line 1426: reword tutorial tip to cover both modes.
9. **docs/agent/enemies-and-npcs.md**: document tracking split and proximity engagement system.

## Changes Made

- `autoloads/EnemyRegistry.gd`: added `is_tracking(type_id)` — returns true for `undead_elite`, `ghoul_pack`, `roaming_terror`; false for wanderers.
- `game_logic/world/InfiniteWorldGen.gd`: changed `"tracking": true` → `"tracking": EnemyRegistry.is_tracking(etype)`.
- `game_logic/world/WorldMap.gd` (resource-based and text-based enemy paths): changed to `EnemyRegistry.is_tracking(...)`. Depth-placed enemies (line 766) kept `true` (always aggressive in dungeon-style maps).
- `game_logic/WorldEvents.gd`: added `"tracking": true` to roaming boss spawn dict.
- `scenes/world/entities/EnemyNPC.gd`:
  - Added `_tracking: bool = false` field.
  - `init_from_data()` reads `tracking` from spawn data.
  - `_ready()` calls `_setup_proximity_area()` when `_tracking`.
  - `_setup_proximity_area()`: adds `Area3D` (collision_mask=1, no layer) + `CollisionShape3D` (SphereShape3D, radius=AUTO_BATTLE_RANGE), connects `body_entered`.
  - `_on_body_entered()`: guards on `_alive`, `CharacterBody3D` type, `SceneManager.can_proximity_engage()`, `is_enemy_defeated(id)` before calling `engage()`.
- `autoloads/SceneManager.gd`:
  - Added `_proximity_engage_blocked: bool = false`.
  - Added `can_proximity_engage() -> bool` (returns `_state == State.WORLD and not _proximity_engage_blocked`).
  - `_restore_world()` now arms 2 s post-battle immunity via `SceneTreeTimer`.
- `scenes/world/WorldScene.gd` line 1426: updated tutorial tip to "Some enemies attack on sight — others wait. Press E / Tap to challenge any enemy."
- DungeonGen, SpireFloorGen: kept `"tracking": true` unchanged (always aggressive in those contexts).
- TRACKING_SPEED constant kept for future movement AI; not implemented in this task (noted in doc).

## Documentation Updates

- `docs/agent/enemies-and-npcs.md`: rewrote EnemyNPC section to document the mixed engagement model, tracking split, Area3D approach, immunity window, and `can_proximity_engage()` guard. Updated key features bullet and integrations table.
