# TID-569: Town Entities in the Overworld

**Goal:** GID-138
**Type:** agent
**Status:** done
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

Chunk-streamed kinds (enemies, chests, doors, NPCs, authored waystones) already
flow through `InfiniteWorldGen._append_realm_entities` (TID-568). Place the rest
(scrolls, shrines, injected town waystones, mailboxes) once at overworld load via
`NamedMapProps.spawn_realm()`. De-duplicate generic NPC ids across towns.

## Changes Made

- `NamedMapProps`: spawners take (town, WorldMap, shift, entries); new `spawn_realm()`
  called from `WorldScene._populate_world` for the infinite world. Waystone ids stay
  `map:<town>` so activation carries over; larik/marsax_hold get injected waystones too.
- `RealmLayout.entities("npcs")`: generic `npc_N` ids become `<town>:npc_N`
  (every town has an npc_1; WorldScene keys NPC nodes by id). Duelist/merchant ids unchanged.
- Test updates in `test_realm_layout`.

## Documentation Updates

- Deferred to TID-573.
