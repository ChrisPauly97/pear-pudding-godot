# TID-627: Loose enemy spawns, terrain and chunk lookups

**Goal:** GID-150
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Seven code-placed enemy spawns (night hunts, siege waves + boss, nocturnal spectres, starter camps, Barrow King, town siege raiders) each re-implemented instance → init → stand on terrain → parent → register. get_height_at / get_height_at_grid repeated the hill smoothstep tail; get_tile_global / get_height_global repeated chunk lookup. A second tile-centre spelling, (float(t) + 0.5) * TILE_SIZE, survived TID-625.

## Plan

See Context.

## Changes Made

New `scenes/world/LooseEnemySpawner.gd` (`spawn` / `spawn_at`) used by CoopActivities, NocturnalSpawner, StarterCamps, TownSiege. `TerrainMath._hill_blend`. `ChunkStreamingManager._chunk_for_tile`. 13 more tile-centre copies → `IsoConst.tile_center` (ObjectiveTracker, RealmLayout, SpawnPoint, TreeScatter, Player, StarterCamps, TapToMove).

## Documentation Updates

CLAUDE.md (helper pointers).
