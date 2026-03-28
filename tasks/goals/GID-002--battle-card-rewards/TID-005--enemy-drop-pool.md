# TID-005: Add `drop_pool` Field to EnemyData Resource

**Goal:** GID-002
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`EnemyData` is a lightweight `Resource` with `id`, `display_name`, and `deck`. It needs a `drop_pool` field so each enemy type can specify which cards it may drop on defeat.

## Research Notes

**EnemyData** (`data/EnemyData.gd`):
```gdscript
extends Resource
@export var id: String = ""
@export var display_name: String = ""
@export var deck: PackedStringArray = PackedStringArray()
```
Add:
```gdscript
## Cards that may be dropped when this enemy is defeated. One is chosen at random.
@export var drop_pool: PackedStringArray = PackedStringArray()
```

**Enemy .tres files** (`data/enemies/`):
- `undead_basic.tres` — early game; drop pool: `["ghost", "skeleton"]`
- `undead_horde.tres` — mid game; drop pool: `["skeleton", "zombie"]`
- `ghoul_pack.tres` — late game; drop pool: `["zombie", "ghoul"]`
- `undead_elite.tres` — end game; drop pool: `["ghoul"]`

Check the exact `.tres` serialisation format used in existing files — Godot text resources use `[resource]` section headers and `field = value` lines. Add `drop_pool = PackedStringArray(["ghost", "skeleton"])` (or equivalent) to each.

**EnemyRegistry** (`autoloads/EnemyRegistry.gd`):
- Exposes `get_enemy(id)` returning the `EnemyData` resource.
- No changes needed here — callers can read `.drop_pool` directly from the returned resource.
- Verify `get_enemy()` exists (vs only `get_deck()` and `type_for_biome()`). If only `get_deck()` exists, a `get_drop_pool(type_id)` helper may be needed.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
