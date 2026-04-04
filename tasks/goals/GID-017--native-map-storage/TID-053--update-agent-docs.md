# TID-053: Update Agent Docs

**Goal:** GID-017
**Type:** agent
**Status:** pending
**Depends On:** TID-052

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`docs/agent/named-maps-and-dungeons.md` documents the text map format, BundledMaps, and the bundle_maps.py pipeline. After the migration is complete, this doc needs to be rewritten to reflect the `.tres` resource system.

## Research Notes

**File to update:** `docs/agent/named-maps-and-dungeons.md`

**Sections to rewrite:**
1. **Map Format** — replace `.txt` description with `MapData` Resource class hierarchy and field descriptions
2. **Bundling / Android export** — remove; replace with MapRegistry preload pattern
3. **Loading priority** — update to: MapRegistry bundled → `user://maps/*.tres` → `user://maps/*.txt` (legacy shim) → fallback
4. **DungeonGen** — update to reflect `.tres` output
5. **Map Editor** — update to reflect `.tres` save/load
6. **Extensibility** — add section on `TriggerData` and `MapRegion` for future use

**New sections to add:**
- Resource class hierarchy diagram/table
- How to add a new built-in map (update MapRegistry)
- How to add a new entity type (create new Resource subclass, add array field to MapData, update WorldMap.load_from_resource and to_map_data)

**Key files:**
- `docs/agent/named-maps-and-dungeons.md` — primary update target

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

This task IS the documentation update task.
