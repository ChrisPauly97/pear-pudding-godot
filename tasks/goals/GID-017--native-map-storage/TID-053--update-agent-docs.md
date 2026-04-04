# TID-053: Update Agent Docs

**Goal:** GID-017
**Type:** agent
**Status:** done
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

Rewrite `docs/agent/named-maps-and-dungeons.md` in full, replacing all `.txt`/BundledMaps references with the new `.tres`/MapRegistry system. Cover: resource class hierarchy, MapData fields, load priority, DungeonGen .tres output, Map Editor, adding built-in maps, adding new entity types, integrations table, asset requirements.

## Changes Made

- **`docs/agent/named-maps-and-dungeons.md`** — full rewrite:
  - Replaced `.txt` format description with `MapData` resource class hierarchy table and field listing.
  - Documented load priority: bundled preloads → `user://maps/*.tres` → `user://maps/*.txt` (legacy shim) → fallback.
  - Updated DungeonGen section: describes `save_to_file()` call and WorldScene re-entry check.
  - Added "Adding a New Built-in Map" and "Adding a New Entity Type" step-by-step guides.
  - Updated integrations table and asset requirements.

## Documentation Updates

`docs/agent/named-maps-and-dungeons.md` rewritten (see Changes Made).
