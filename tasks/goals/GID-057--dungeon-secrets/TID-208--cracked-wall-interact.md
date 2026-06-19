# TID-208: Cracked-Wall Visual Tell + Break-Open Interaction

**Goal:** GID-057
**Type:** agent
**Status:** done
**Depends On:** TID-207

## Lock

**Session:** claude/next-gid-filtering-xan993
**Acquired:** 2026-06-19T01:00:00Z
**Expires:** 2026-06-19T01:30:00Z

## Context

Cracked walls must be visually distinct so observant players notice them, and interacting must break them open permanently. The break is a one-time event per dungeon visit (dungeon is saved to disk after generation, so walls stay broken if revisited in same save).

## Research Notes

- **Interact flow** (docs/agent/ui-and-scene-management.md for scene context; WorldScene line 1150–1234):
  1. `_process()` throttles interaction checks at INTERACT_INTERVAL (0.15s, line 105) via `_interact_timer` countdown
  2. On interact (E key or tap), `_handle_interact(px, pz)` searches nearby entities in order: door → enemy → chest → NPC → scroll
  3. Door check (line 1161–1175): `_find_nearby_door()` → if found, `SceneManager.enter_map()` or `exit_map()`
  4. Enemy check (line 1177–1180): `_find_nearby_enemy()` → if found, `enemy.engage()` emits `GameBus.enemy_engaged`
  5. Chest check (line 1182–1206): `_find_nearby_chest()` → if `not opened`, set `opened=true`, call `mark_chest_opened()`, spawn cards
  6. NPC/scroll checks (line 1208–1234): similar pattern
  - **Interactive prompt** (line 109, label at $HUD/InteractPrompt): Shown near player when an interactive entity is nearby. Set via `_interact_label.text = "[E] Interact"` (desktop) or `"[Tap] Interact"` (Android).
  - **Proximity helper**: `IsoConst.INTERACT_RANGE = 1.5` world units (line 31). Used in all `_find_nearby_*` functions.

- **Tile interactability**: Currently only doors, enemies, chests, NPCs, and scrolls are "nearby" entities. **TILE_CRACKED is a map tile**, not an entity node. To make it interactive:
  1. **Option A (chosen)**: At dungeon load, spawn a `Node3D` child node at each TILE_CRACKED position to act as an invisible interactable target (like Chest/Door nodes). Mark it as `is_cracked_wall=true`. When `_handle_interact()` finds it, call a break function.
  2. **Option B (not chosen)**: Modify `_handle_interact()` to check `world_map.get_tile(px, pz) == TILE_CRACKED` after entity checks. Simpler but mixes tile/entity logic.
  - Chosen: **Option A — spawn a node** (e.g., `CrackedWall.gd` scene or inline node) at each TILE_CRACKED position during `_build_chunk_sync()`. The node registers itself with WorldScene via `register_cracked_wall(world_pos)`. On interact, `CrackedWall.break_open()` is called, which:
    1. Calls `world_map.set_tile(tx, tz, TILE_GRASS)` to change the tile
    2. Triggers a terrain mesh rebuild (see below)
    3. Plays particle/sound effect
    4. Hides/removes the node

- **Visual tell — cracked texture**:
  - **Terrain shader** (**assets/shaders/terrain.gdshader**): Per-vertex colour encoding encodes wall flag in G channel (line 51–56 of terrain-rendering.md). Wall quads are rendered by `build_wall_mesh()` (TerrainMath).
  - **Cracked wall variant**: Simplest approach (v1): Apply an overlay texture or shader variant that modulates wall quads based on tile type. **Or**: Use TextureGen to generate a cracked wall texture with visible crack lines at runtime.
    - `TextureGen.wall_side()` (game_logic/TextureGen.gd line 29) generates wall_side texture. Create a new function `TextureGen.wall_side_cracked()` that adds visible cracks (white lines on darker base).
    - In `build_wall_mesh()`, detect TILE_CRACKED and apply a different UV offset or material flag so the shader samples the cracked variant.
  - **Implementation**: Add to **game_logic/TextureGen.gd** a function `wall_side_cracked() -> ImageTexture` that generates a wall texture with prominent diagonal/horizontal white crack lines. Modify **game_logic/TerrainMath.gd** `build_wall_mesh()` to check if the tile is TILE_CRACKED and pass a flag to the mesh colour or material to select the cracked texture. Shader samples `is_cracked` flag and blends in crack texture.
  - **Simpler alternative (v1)**: Apply a tint to TILE_CRACKED wall vertices (e.g., darker or reddish) in the wall mesh builder. Add a condition: `if tile == TILE_CRACKED: vertex_color.r -= 0.2` to darken or shift hue. This is visible but subtle.

- **Terrain mesh rebuild after tile change**:
  - **Current architecture**: WorldScene builds all chunks once at load via `_build_chunk_sync()`. No runtime rebuild shown in the code.
  - **Problem**: After `world_map.set_tile()` converts TILE_CRACKED to TILE_GRASS, the visual mesh is stale.
  - **Solution (chosen)**: For named maps (dungeons are named maps), add a **public method `rebuild_terrain_mesh()` to WorldScene**:
    ```gdscript
    func rebuild_terrain_mesh() -> void:
        # Rebuild all chunks covering the dungeon
        var chunk_key := Vector2i(int(px / chunk_world), int(pz / chunk_world))
        _chunk_renderers[chunk_key].rebuild()  # or clear and rebuild
    ```
    Call this from the CrackedWall node after `set_tile()`. Cost: O(chunk_size²) per break, acceptable for a 1–2 event per dungeon.
  - **Simpler alternative**: Don't rebuild. Hide the wall mesh node and spawn a flat TILE_GRASS plane mesh at the cracked position. Less correct, but avoids rebuild cost. **Not recommended.**
  - **Actual implementation**: Check if ChunkRenderer has a `rebuild()` method or if we need to clear and re-run `prepare_terrain() + build_visual()`. If not, add one.

- **Break event**:
  1. **Node registration**: `register_cracked_wall(wall_pos: Vector3) -> void` in WorldScene. Stores in a dict `_cracked_wall_nodes[pos] = node` or appends to array.
  2. **Interaction**: When `_handle_interact()` is called near a cracked wall node, the node calls a callback on WorldScene: `world_scene.on_cracked_wall_broken(tx: int, tz: int)`.
  3. **Tile change**: `world_map.set_tile(tx, tz, TILE_GRASS)` (already done in TID-207 context)
  4. **Mesh rebuild**: `rebuild_terrain_mesh()` (implementation TBD by testing)
  5. **Particle burst**: `GPUParticles3D` at position, burst for 10 particles (rock chips). Use existing particle setup from ChunkRenderer or create inline in WorldScene.
  6. **Audio**: `AudioManager.play_sfx("wall_break")` (create new SFX or reuse existing "wall_hit" if available)
  7. **Node cleanup**: Remove the CrackedWall node from tree.

- **Persistence across dungeon re-entry**:
  - **Current behaviour**: DungeonGen saves dungeon map to **user://maps/dungeon_<seed>.tres** on first generation (line 173). On re-entry, `MapRegistry.get_map()` finds the saved .tres and reuses it (docs/agent/named-maps-and-dungeons.md line 106–108).
  - **Decision**: A **broken wall is permanent for that save's dungeon visit**. When the .tres is saved with `world_map.set_tile(tx, tz, TILE_GRASS)` already applied, the wall stays broken on re-entry. **No additional persistence tracking needed** — the tile grid change is saved to the .tres file.
  - **Implementation**: When breaking the wall, immediately call `world_map.save_to_file(map_name)` after `set_tile()` to persist the change to disk.

- **Mobile parity**:
  - CrackedWall node has no `engage()` method; it participates in the standard interact flow via proximity and E/tap.
  - The `_interact_label` prompt is already shown by WorldScene when any interactable is nearby, including cracked walls.
  - Android interaction via `_interact_btn` (TouchButton, line 302–309) calls `_handle_interact()` same as E key.
  - **No extra work needed** — cracked walls reuse the existing interact mechanic.

- **Headless tests**:
  1. **Tile swap walkability**: After `set_tile(tx, tz, TILE_GRASS)`, `world_map.get_tile(tx, tz) == TILE_GRASS`
  2. **Persistence**: Save dungeon, reload, broken wall still TILE_GRASS
  3. (Visual tests deferred — mesh rebuild is tested in integration, not headless)

## Plan

1. **terrain.gdshader**: Add `varying float v_cracked;` + set from `COLOR.a` in vertex(); darken cracked wall tint in fragment().
2. **TerrainMath.gd `build_wall_face_mesh()`**: Detect TILE_CRACKED per-tile in the loop and use `Color(0.0, 1.0, 0.0, 0.3)` (alpha < 0.5 → cracked) for those vertices; regular walls keep `Color(0.0, 1.0, 0.0, 1.0)`.
3. **ChunkRenderer.gd**: Add `rebuild_terrain(snap: Array) -> void` method that removes existing terrain children and rebuilds meshes + physics without re-spawning entities.
4. **WorldScene.gd**: Add cracked wall interact check in `_handle_interact()` after chest block; add `_break_cracked_wall(tx, tz)` (set tile, play SFX, show toast, rebuild, save); add `_rebuild_terrain_around_tile(tx, tz)` (rebuilds tile's chunk + 8 neighbours).
5. **Tests**: `tests/unit/test_cracked_wall_interact.gd` covering tile swap and persistence.
6. Add to `tests/runner.gd`.

## Changes Made

- **assets/shaders/terrain.gdshader**: Added `varying float v_cracked;`; set from `COLOR.a < 0.5` in `vertex()`; in `fragment()` darkens cracked wall pixels (`r*0.80+0.06, g*0.65, b*0.60`) for a warm brownish visual tell.
- **game_logic/TerrainMath.gd**: Added `cracked_col := Color(0.0, 1.0, 0.0, 0.3)` alongside `wall_col`; inside `build_wall_face_mesh()` loop, selects `face_col = cracked_col if TILE_CRACKED else wall_col` and uses `face_col` for all vertex color appends for that tile — encoding alpha < 0.5 as the cracked flag the shader reads.
- **scenes/world/ChunkRenderer.gd**: Added `rebuild_terrain(snap: Array) -> void` — removes all ChunkRenderer children (terrain meshes and collision only; entities live in entity_root), then calls `prepare_terrain()` and rebuilds visual + physics. Used by WorldScene on wall break without re-spawning entities.
- **scenes/world/WorldScene.gd**: Added cracked wall check in `_handle_interact()` (after chest block, before NPC block) — calls `world_map.find_nearby_cracked_wall()` and `_break_cracked_wall(tx, tz)` if found. Added `_break_cracked_wall(tx, tz)` (set tile to TILE_GRASS, play SFX, show toast, rebuild, save). Added `_rebuild_terrain_around_tile(tx, tz)` (rebuilds tile's chunk + 8 neighbours to update exposed wall faces correctly).
- **tests/unit/test_cracked_wall_interact.gd** + **.uid**: New test suite — 9 tests; all pass.
- **tests/runner.gd**: Added `test_cracked_wall_interact` preload.

## Documentation Updates

- `docs/agent/named-maps-and-dungeons.md` updated with cracked-wall visual tell (vertex color alpha encoding), break-open interaction flow, terrain rebuild, and persistence mechanism.
