# TID-245: Landmark Meshes — CPU ArrayMesh Structures

**Goal:** GID-067
**Type:** agent
**Status:** done
**Depends On:** TID-244

## Lock

**Session:** —
**Acquired:** —
**Expires:** —

## Context

Landmarks must be physically imposing — tall enough to read as "something is over there" from several chunks away in the fixed orthographic isometric view. This task builds the 3D structures for each variant chosen in TID-244 and hooks them into chunk rendering with collision.

## Research Notes

**Mesh construction:**
- Godot 4 has NO geometry shaders — build geometry on the CPU as `ArrayMesh`, exactly like `game_logic/TerrainMath.gd` does for terrain and walls. Add builders either as new methods there or in a new `game_logic/world/LandmarkMesh.gd` (preload it where used — `class_name` from freshly created files isn't globally available until the editor rescans, per CLAUDE.md).
- Each variant is a static builder returning an ArrayMesh assembled from simple primitives (boxes, tapered columns, tilted slabs):
  - Obelisk ring: 6–8 tapered pillars (~6–8 units tall) in a circle, one or two toppled.
  - Kneeling colossus: stacked boxes forming torso/head/arms in a kneeling pose, ~12–15 units tall.
  - Shattered spire: tapering tower broken at an angle, debris slabs at the base.
  - Overgrown stone head: large box head half-sunk, grass-tinted top.
  - Broken arch/bridge: two pylons + partial span.
- Heights of ~10–15 world units read well: tiles are 2.0 units, walls are short, and the orthographic camera size is 15 — a 12-unit structure dominates the frame edge from far away. The iso camera is FIXED (offset `player + (20,20,20)`, never `look_at`) so silhouettes from the (-1,-1,-1) view direction matter most.

**Rendering integration:**
- `scenes/world/ChunkRenderer.gd` builds meshes and entity nodes per chunk from `ChunkData`. When `entities` contains a `{"type": "landmark", ...}` dict (from TID-244), instantiate a `MeshInstance3D` with the variant's ArrayMesh at the footprint position (tile coords × TILE_SIZE relative to chunk origin), sitting on the height field's local ground height.
- Material: simple `StandardMaterial3D` with a stone-grey albedo tinted slightly by biome hue (BiomeDef tint colors), or reuse the terrain shader material. Avoid new texture assets; flat colors fit the pixel aesthetic. If any new shader/resource file is added it needs a `.uid` sidecar and `preload()` (Android export rules).
- Frees with the chunk automatically when added under the ChunkRenderer node (chunk streaming: load radius 6, unload 7).

**Collision:**
- Add a `StaticBody3D` + box `CollisionShape3D`(s) approximating the structure base so the player can't walk through it. TerrainMath already builds chunk collision via HeightMapShape3D — landmark collision is separate, parented to the landmark node.

**Performance:**
- One ArrayMesh per landmark instance is fine at 1/60 chunk density. Build it on the same WorkerThreadPool path the chunk meshes use if convenient; otherwise the main-thread cost of a few boxes is negligible.

**Testing:**
- Headless: builders return non-null ArrayMesh with surfaces > 0 for every variant; vertex counts sane. Visual check manual.
- GDScript strict mode reminders: explicit types for `max`/`min`/`clamp` results; `PackedVector3Array` for vertex arrays.

## Plan

- Create `game_logic/world/LandmarkMesh.gd` with static `build(variant, biome) -> ArrayMesh` and `collision_size(variant) -> Vector3`
- Implement `_build_obelisk_ring`, `_build_stone_head`, `_build_kneeling_colossus`, `_build_shattered_spire`, `_build_broken_arch` builders using SurfaceTool + `_add_box` / `_add_tapered_box` helpers
- Create `game_logic/world/LandmarkMesh.gd.uid` sidecar
- Hook into `ChunkRenderer.gd` `_spawn_entities()`: detect `chunk.landmarks`, build MeshInstance3D + StaticBody3D, set `visibility_range_end=200.0`, call `world_scene.register_landmark()`

## Changes Made

- **`game_logic/world/LandmarkMesh.gd`** (NEW): Pure static utility; builds CPU ArrayMesh for each of 5 landmark variants using SurfaceTool. Functions: `build()`, `collision_size()`, `_stone_color()`, `_add_box()`, `_add_tapered_box()`, `_add_quad()`, and one builder per variant
- **`game_logic/world/LandmarkMesh.gd.uid`** (NEW): `uid://s2m6nwfeutzu`
- **`scenes/world/ChunkRenderer.gd`**: Added `const LandmarkMesh = preload(...)`, spawning block in `_spawn_entities()` that creates `Node3D > MeshInstance3D + StaticBody3D` per landmark with `visibility_range_end=200.0` and calls `world_scene.register_landmark()`

## Documentation Updates

- Created `docs/agent/ancient-colossi.md` covering the full system
- Added row to CLAUDE.md docs table
