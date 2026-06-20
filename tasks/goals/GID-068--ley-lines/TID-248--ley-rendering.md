# TID-248: Ley Line Rendering — Terrain Shader Overlay + Minimap Hint

**Goal:** GID-068
**Type:** agent
**Status:** done
**Depends On:** TID-247

## Context

Ley lines must read clearly in the pixel-art isometric view without cluttering the terrain: a thin emissive band (cyan) that pulses slowly, plus a faint trace on the minimap so players can follow a line beyond the screen edge.

## Plan

Chose UV2 vertex attribute approach: bake per-vertex ley intensity into `UV2.x` on the CPU (worker thread) and read it in the shader. Guarantees visual/gameplay agreement without re-implementing simplex noise in GLSL or duplicating materials.

Minimap: no extra code needed — the SubViewport shares the World3D and the terrain's ley emission is visible from the top-down minimap camera automatically.

## Changes Made

- `assets/shaders/terrain.gdshader`: added `varying float v_ley`; reads `UV2.x` in vertex stage; adds cyan emissive pulse `v_ley * (0.8 + 0.2*sin(TIME*0.8)) * 0.45 * vec3(0.05, 0.85, 0.90)` in fragment.
- `game_logic/TerrainMath.gd` (`build_terrain_mesh`): added `ley_field: PackedFloat32Array` optional param; writes `UV2.x` per vertex; includes zero-filled `skirt_uv2s`.
- `scenes/world/ChunkRenderer.gd` (`prepare_terrain`): added `world_seed: int = 42` parameter; bakes `ley_field` array per vertex using `TerrainMath.ley_intensity`; passes to `build_terrain_mesh`.
- `scenes/world/ChunkRenderer.gd` (`rebuild_terrain`): added `world_seed: int = 42` parameter.
- `scenes/world/WorldScene.gd` (`_chunk_prepare_task`): added `p_world_seed: int` parameter; passes `WORLD_SEED` at bind time and to `prepare_terrain`.
- `scenes/world/WorldScene.gd` (synchronous build path ~line 1012): passes `WORLD_SEED`.
- `scenes/world/WorldScene.gd` (`_rebuild_terrain_around_tile`): passes `WORLD_SEED` to `rebuild_terrain`.

## Documentation Updates

- `docs/agent/ley-lines.md` covers rendering approach.
