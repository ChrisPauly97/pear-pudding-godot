# Ancient Colossi — Discoverable Mega-Landmarks

## Key Features

- **Deterministic placement**: ~1 in 50 chunks hosts a mega-landmark, decided by an independent hash of `(cx*16769023)^(cz*6972593)^world_seed` modulo `LANDMARK_RARITY`. No chunk's existing RNG stream is disturbed.
- **Safe zone**: chunks within Manhattan distance 3 of the origin never host landmarks so the player spawns in open terrain.
- **Ruin exclusion**: chunks detected as ruin chunks (31-bit masked `_chunk_seed+2` → `randi_range(0,2)==0`) are skipped to prevent overlap.
- **5 biome variants**: `obelisk_ring` (Grasslands), `stone_head` (Forest), `kneeling_colossus` (Desert), `shattered_spire` (Scorched), `broken_arch` (Mountains).
- **Footprint flattening**: a 5×5 tile area centred at chunk tile (8,8) is stamped `TILE_GRASS` at height 0 before terrain height generation so structures always sit on flat ground.
- **Procedural names**: "The `<epithet>` `<noun>` of `<place>`" — deterministic from world seed and chunk coordinates.
- **One-time discovery**: approaching within 9 world units auto-fires toast, Journal log, 50 coins, and a random rare card. Re-visits never re-reward.
- **Journal "Discoveries" tab**: lists all found landmarks with regenerated names and biome info.

## How It Works

### Placement pipeline (`InfiniteWorldGen.gd`)

```
generate_chunk()
  └─ _gen_tile_grid()
  └─ _gen_ruins()          ← ruins first
  └─ _gen_landmarks()      ← stamps footprint, appends to chunk.landmarks
  └─ _gen_entities()
```

`landmark_for_chunk(cx, cz, world_seed) -> Dictionary` is the public pure function; returns `{}` if the chunk has no landmark. All other systems call this instead of calling `_gen_landmarks` directly.

Returned dict keys: `id`, `variant`, `biome`, `tx`, `tz`, `x`, `z`, `cx`, `cz`.

### Mesh construction (`LandmarkMesh.gd`)

`LandmarkMesh.build(variant, biome) -> ArrayMesh` — pure CPU SurfaceTool mesh, no textures, stone-grey colour tinted by biome. `collision_size(variant) -> Vector3` returns a box approximating each structure.

Heights range from 8 units (obelisk ring pillars) to 14 units (kneeling colossus) to read clearly in the fixed isometric view.

### Chunk rendering (`ChunkRenderer.gd`)

When `_spawn_entities()` processes `_chunk_data.landmarks`, it creates `Node3D > MeshInstance3D + StaticBody3D` positioned at the world coordinate stored in the landmark dict. `visibility_range_end = 200.0` keeps structures visible several chunks away. On creation it calls `world_scene.register_landmark(lid, l_data)`.

### Discovery system (`WorldScene.gd`)

`_active_landmark_data: Dictionary` maps landmark id → data dict, populated/erased as chunks load/unload. Every frame, `_check_interactions()` calls `_check_nearby_landmark(px, pz)` which loops active landmarks and, within 9 units, calls `_discover_landmark()`.

`_discover_landmark()`:
1. `SaveManager.mark_landmark_discovered(lid)` — persists to save
2. Emits `GameBus.landmark_discovered(lid, display_name)`
3. Shows `AchievementToast` with the landmark name
4. Grants 50 coins + random rare card
5. Emits `GameBus.hud_message_requested`

### Name generation (`LandmarkNames.gd`)

```gdscript
LandmarkNames.get_name(cx, cz, world_seed) -> String
LandmarkNames.name_from_id("landmark_cx_cz", world_seed) -> String
```

Uses the same hash formula as `landmark_for_chunk` to seed a local RNG, then picks independently from:
- `_EPITHETS` (10 words, shared)
- `_NOUNS_BY_VARIANT` (per variant)
- `_PLACES_BY_BIOME` (per biome int)

### Save persistence (`SaveManager.gd`)

- Field: `discovered_landmarks: Array[String]` (list of `"landmark_cx_cz"` ids)
- Save version bumped 38 → 39; migration `_migrate_v38_to_v39()` adds `discovered_landmarks: []` to old saves
- API: `mark_landmark_discovered(id)`, `is_landmark_discovered(id) -> bool`

## Integrations with Other Features

| System | How it integrates |
|--------|-------------------|
| `InfiniteWorldGen` | `_gen_landmarks()` runs after `_gen_ruins()` in both sync and data-only paths |
| `ChunkData` | New `landmarks: Array[Dictionary]` field alongside `entities`, `burial_mounds`, etc. |
| `ChunkRenderer` | Spawns landmark mesh + collision from `_chunk_data.landmarks` in `_spawn_entities()` |
| `WorldScene` | Registers active landmarks, auto-fires discovery on proximity |
| `SaveManager` | `discovered_landmarks` field, v39 migration, idempotent mark/check API |
| `GameBus` | `landmark_discovered(landmark_id, display_name)` signal |
| `JournalScene` | "Discoveries" tab lists found landmarks, names regenerated on demand |

## Asset Requirements

No new textures or audio assets. All geometry is CPU-built `ArrayMesh`. New files:
- `game_logic/world/LandmarkMesh.gd` + `.uid`
- `game_logic/world/LandmarkNames.gd` + `.uid`
- `tests/unit/test_landmark_system.gd`
