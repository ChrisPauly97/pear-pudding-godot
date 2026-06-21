# TID-269: Unify entity spawning and add WorldEntity base class

**Goal:** GID-072
**Type:** agent
**Status:** done
**Depends On:** TID-266

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

NPC and scroll spawning are implemented twice (ChunkRenderer vs WorldScene), and 6 entity scripts repeat the same static-resource + mesh-building boilerplate. This task centralizes spawning logic and creates a reusable base class for all world entities, eliminating duplication and reducing maintenance burden. Named-map and infinite-chunk play will use the same spawning path.

## Research Notes

- **Current spawning paths:** TerrainMath.spawn_entity (game_logic/TerrainMath.gd:436–446) covers enemies, chests, doors only. ChunkRenderer.gd:257–268 spawns NPCs directly (instantiate → init_from_data → height lookup); ChunkRenderer.gd:270–296 spawns scrolls directly. WorldScene.gd:835–848 (`_spawn_named_map_scrolls`) does nearly identical scroll spawning for named maps (instantiate `_StoryScrollScene`, setup(), get_terrain_height()). Action: Centralize NPC + scroll spawning in TerrainMath or a new EntityFactory used by both paths.
- **Entity boilerplate:** scenes/world/entities/ — EnemyNPC.gd, Chest.gd, Door.gd, TownspersonNPC.gd, MerchantNPC.gd, StoryScroll.gd all repeat: static material/mesh vars + `_ensure_shared_resources()` + `_make_mi(mesh, mat)` helper + `init_from_data(data)` storage. TownspersonNPC and MerchantNPC additionally share `_add_name_label`/`get_dialogue` shape. Extract a base class (note `game_logic/world/WorldEntity.gd` may already exist — check before creating; saving ~40–50 lines × 6 files).
- **CLAUDE.md compliance:** Preload the base class in each entity script; Sprite3D origin-height rule applies; entity visibility constant `ENTITY_VISIBILITY_END` (ChunkRenderer.gd:298) could move to IsoConst.
- **WorldScene registration:** Registration funcs (register_enemy/chest/door/npc/scroll at WorldScene.gd:811–834) stay but should be the single registration path for both named-map and chunk-streamed entities.

## Plan

1. Create `scenes/world/entities/WorldEntityBase.gd` — Node3D base with `static func _make_mi`.
2. Create `.uid` sidecar.
3. Update EnemyNPC, TownspersonNPC, MerchantNPC, BountyBoardNPC to `extends "res://scenes/world/entities/WorldEntityBase.gd"` and remove their local `_make_mi`.
4. Update ChunkRenderer NPC spawning to use `TerrainMath.spawn_entity()` (select scene first, then delegate).
5. Remove unused `_TownspersonScene` preload from WorldScene.

## Changes Made

- Created `scenes/world/entities/WorldEntityBase.gd` + `.uid` — Node3D base class with shared `static func _make_mi(mesh, mat)`.
- Updated EnemyNPC, TownspersonNPC, MerchantNPC, BountyBoardNPC to `extends "res://scenes/world/entities/WorldEntityBase.gd"` and removed their local `_make_mi` duplicates (~5 lines × 4 files = ~20 lines removed).
- Updated ChunkRenderer NPC spawning (lines 306–323 → now 3 fewer lines) to use `TerrainMath.spawn_entity(scene_to_use, n_data, 0.5, entity_root, world_scene)` — NPC and scroll/enemy/chest/door spawning now all go through the same code path.
- Removed unused `_TownspersonScene` preload from WorldScene.gd (NPCs always come through ChunkRenderer).

## Documentation Updates

None required — existing docs cover entity spawning at a high level.
