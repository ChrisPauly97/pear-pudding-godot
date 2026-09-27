# TID-569: Town Entities in the Overworld

**Goal:** GID-138
**Type:** agent
**Status:** pending
**Depends On:** TID-568

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

NPCs, scrolls, shrines, waystones, chests, enemies and interior doors from each
town `.tres` must appear in the overworld at world coords with the same ids.

## Research Notes

- Chunk entities flow through `ChunkData` → `ChunkRenderer._spawn_entities`.
- Named maps load entities via `WorldMap.load_from_resource()`; NamedMapProps
  spawns scrolls/shrines/waystones/mailbox.
- Doors between stitched towns (madrian door_9/door_10, etc.) are dropped.

## Plan

## Changes Made

## Documentation Updates
