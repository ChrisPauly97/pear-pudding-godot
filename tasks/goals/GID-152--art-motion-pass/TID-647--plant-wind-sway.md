# TID-647: Tree and plant wind sway

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Trees, ferns, flowers are static; grass already sways with weather wind. Part of GID-152 (art motion pass).

## Research Notes

- Props render as one MultiMeshInstance3D per prop key with a cached material (`ChunkRenderer._prop_visual_cache`, L47-50; positions from `_compute_prop_positions` + `game_logic/world/TreeScatter.gd`).
- New shader `assets/shaders/prop_sway.gdshader` (+ `.uid`): billboard like current material, vertex offset ∝ (UV.y from base)² × wind, phase from instance world position (`MODEL_MATRIX[3]` / `INSTANCE_ID`), stepped in time for pixel look. Reuse globals `grass_wind_scale`, `grass_wind_lean` (registered in `scenes/world/GrassBlades.gd` L108) and `wind_direction`.
- Sprite3D + custom material gotcha (CLAUDE.md): texture must be fed explicitly; keep alpha-cut + depth prepass.
- Rigid props (rock, boulder, ash pile, cactus, headstone) opt out; per-key stiffness table.

## Plan

1. `prop_sway` shader pair replicating the StandardMaterial billboard, plus a stepped, texel-snapped top lean.
2. `ChunkRenderer.PROP_SWAY` per-key knobs; sway keys get the ShaderMaterial; `set_lit_world` swaps its shader.
3. `plant_wind_dir` global fed from `GrassBlades.set_wind_direction`.

## Changes Made

- New `assets/shaders/prop_sway.gdshaderinc`, `prop_sway.gdshader`, `prop_sway_lit.gdshader` (+ `.uid`).
- `scenes/world/ChunkRenderer.gd`: `PROP_SWAY`, `_make_prop_material()` / `_make_sway_material()`, lit toggle.
- `scenes/world/GrassBlades.gd`: sets `plant_wind_dir`; `project.godot`: global declared.
- Test: `test_lit_world::test_sway_props_use_sway_shader`. Render check: at rest identical to the old material;
  under wind the tree top moves between frames.
- Logged BID-082 (prop mirror flip never rendered).

## Documentation Updates

- `docs/agent/visual-polish.md`: "Plant wind sway".
