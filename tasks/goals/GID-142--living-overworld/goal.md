# GID-142: Living Overworld — Rolling Terrain, Trees, Occluded Silhouette

## Objective

User feedback (2026-09-28): the world read flat, buildings were mostly ruins,
short grass but no trees; when the hero is hidden, show a silhouette outline
instead of cutting the terrain away.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-591 | Rolling terrain — raise per-biome hill coverage (`BiomeDef.PARAMS`) | agent | done | — |
| TID-592 | Tree groves — `TreeScatter`, generated tree sprites, prop pipeline | agent | done | — |
| TID-593 | Occluded silhouette — `sprite_xray` next_pass; remove wall cutaway | agent | done | — |

## Changes Made

- `BiomeDef.PARAMS` hill thresholds lowered / heights raised; `TREE_SETS`,
  `TREE_GROVE_CHANCE`, `TREE_LONE_CHANCE`.
- `game_logic/world/TreeScatter.gd` merged into `ChunkRenderer` prop scatter;
  10 tree sprites from `scripts/gen_tree_sprites.py`, registered in `SpriteRegistry`.
- `assets/shaders/sprite_xray.gdshader` + `SpriteOutline.apply_xray()` on Player
  and RemotePlayer; terrain `occlusion_focus` cutaway removed.
- Tests: `test_tree_scatter`, `test_sprite_xray`. Docs: world-generation.md,
  camera-and-player.md.

## Follow-ups (not done)

- Towns/buildings still mostly ruins — needs intact-building generation.
- Trees have no collision (decorative).
