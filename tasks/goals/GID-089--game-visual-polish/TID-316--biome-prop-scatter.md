# TID-316: Environmental prop scatter per biome

**Goal:** GID-089
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** claude/GID-089--game-visual-polish
**Acquired:** 2026-06-25T00:34:08Z
**Expires:** 2026-06-25T01:04:08Z

## Context

Terrain between entities is empty — just flat grass tiles with the FBM shader texture. This task adds per-biome billboard props (rocks, flowers, tall grass tufts, mushrooms, cacti) scattered on `TILE_GRASS` cells, GPU-instanced and density-capped for Android performance. Props are purely decorative — no collision, no interaction, no logic.

## Research Notes

**Where to hook in (ChunkRenderer.gd):**
- `ChunkRenderer` builds the terrain mesh per chunk on a worker thread, then places entities
- After the terrain mesh is built is the right place to also emit prop `MultiMeshInstance3D`
- Each chunk gets one `MultiMeshInstance3D` per prop type — destroyed and rebuilt when the chunk reloads

**MultiMeshInstance3D approach:**
- `MultiMesh.mesh` = a flat quad or tiny cylinder `PlaneMesh`
- `MultiMesh.transform_format = MultiMesh.TRANSFORM_3D`
- Each instance: a `Transform3D` with random position + Y-axis rotation within the tile
- Material: `StandardMaterial3D` with `billboard_mode = BILLBOARD_ENABLED` + prop texture from `TextureGen`
- Android: cap at 8–12 instances per chunk (~256 tiles per chunk); LOD via `GeometryInstance3D.visibility_range_end`

**BiomeDef reference:**
- `BiomeDef` already carries `grass_tint`, `hill_tint`, `wall_tint`; add a `prop_set: Array[String]` listing which prop types to scatter (e.g. `["rock", "flower"]` for Grasslands, `["cactus", "rock"]` for Desert)
- `IsoConst.TILE_GRASS` and `IsoConst.TILE_SIZE` for placement math

**Prop types to implement:**
| Biome | Props |
|---|---|
| Grasslands | round rock, daisy flower, clover patch |
| Forest | mushroom, fern frond, mossy rock |
| Desert | cactus, dry thorn bush, sandstone shard |
| Scorched | ash pile, ember rock, dead branch |
| Mountains | angular boulder, snow cap rock, lichen patch |

**TextureGen approach:**
Each prop is a 16×24 pixel sprite painted procedurally with `Image.set_pixel()`, cached by key like `"prop_rock"`. Silhouette-style, 2–3 colors maximum.

**Android constraint:** `MultiMeshInstance3D` is the standard Android-safe GPU instancing path. Keep `MultiMesh.instance_count` ≤ 12 per chunk per prop type. Use `visibility_range_end = 40.0` to pop them off before they fill the draw queue.

## Plan

Add `PROP_SETS` to `BiomeDef` (2 prop types per biome). Add 10 prop texture generators to `TextureGen` (16×16 RGBA8 pixel art). Add `_compute_prop_positions()` static to `ChunkRenderer.prepare_terrain()` (worker-thread safe). Add `_build_props()` to `ChunkRenderer.build_visual()` using `MultiMeshInstance3D` with `QuadMesh` + billboard material.

## Changes Made

- `game_logic/world/BiomeDef.gd`: Added `PROP_SETS` array (2 prop types per biome) and `ADJ_PARAMS` array (brightness/contrast/saturation per biome).
- `game_logic/TextureGen.gd`: Added `prop(key)` static + 10 per-prop 16×16 pixel-art generators: rock, flower, mushroom, fern, cactus, thorn, ash_pile, ember, boulder, lichen.
- `scenes/world/ChunkRenderer.gd`: Added `TextureGen` preload, `_compute_prop_positions()` static method (seeded RNG, 15% spawn chance per TILE_GRASS, ≤12 per type, returns `prop_type -> Array[Vector3]`), added `"props"` key to `prepare_terrain()` return dict, added `_build_props()` which creates one `MultiMeshInstance3D` per prop type with billboard material and visibility range.

## Lock

**Session:** none
**Acquired:** —
**Expires:** —
