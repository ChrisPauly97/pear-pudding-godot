# TID-157: PuzzleShrine World Entity + Interaction Flow

**Goal:** GID-040
**Type:** agent
**Status:** pending
**Depends On:** TID-156

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The world-facing half: a glowing shrine the player finds in named maps. Approach → hint text; interact → launch the puzzle; solved → permanent gold glow and a "Solved" line. The shrine is the discovery moment, so it must read clearly in the isometric view.

## Research Notes

- **New entity:** `scenes/world/entities/PuzzleShrine.gd` + `.tscn`. Model on `StoryScroll.gd` (GID-013) — it has the closest interaction pattern: proximity detection, interact prompt, one-shot state tracked in SaveManager. Export var: `puzzle_id: String`.
- **Visual:** A `MeshInstance3D` (CylinderMesh or BoxMesh pillar, ~1.5 units tall) with an emissive StandardMaterial3D — blue-violet glow unsolved, gold once solved. Build the material in `_ready` (no new shader files / .uid sidecars needed). Optionally a small idle `GPUParticles3D` shimmer. Verify height/placement against the tile plane (y=0) per the Sprite3D clipping note in CLAUDE.md.
- **Interaction flow:**
  - On proximity: show the puzzle `title` + `hint_text` from PuzzleRegistry (TID-155) in the same prompt UI StoryScroll/NPCs use — check how prompts render (`docs/agent/enemies-and-npcs.md`, `docs/agent/story-narration-scrolls.md`).
  - On interact (key E + tap target, mobile parity rule): if `puzzle_id` in `SaveManager.solved_puzzles` → "The shrine's magic is spent." Else emit `GameBus.puzzle_requested(puzzle_id)`.
  - Listen for `GameBus.puzzle_solved` to swap to the gold material live when the player returns.
- **Map entity schema:** Shrines are placed in named maps. Check `game_logic/world/WorldEntity.gd` + `MapRegistry.gd` / map `.tres` schema (GID-017) for how entity types are registered and instantiated by WorldScene — a new entity type string (`"puzzle_shrine"`) with a `puzzle_id` property, following however CHEST/SCROLL entities declare theirs. Also add it to the MapEditorScene palette if entity palettes exist there (check `scenes/ui/MapEditorScene.gd`).
- **Placement in this task:** Just one test shrine wired to the TID-155 fixture puzzle in `madrian.tres` to prove the flow; the real 5 are TID-158.
- `docs/agent/named-maps-and-dungeons.md` — document the new entity type; `docs/agent/battle-system.md` — shrine → puzzle flow.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
