# TID-005: Add `drop_pool` Field to EnemyData Resource

**Goal:** GID-002
**Type:** agent
**Status:** done
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

1. Add `drop_pool: PackedStringArray` export field to `data/EnemyData.gd`.
2. Add `drop_pool = PackedStringArray(...)` to each of the four `.tres` files per the spec.
3. Add `get_drop_pool(type_id)` static helper to `EnemyRegistry.gd` (since no `get_enemy()` exists).

## Changes Made

- `data/EnemyData.gd`: added `@export var drop_pool: PackedStringArray = PackedStringArray()`.
- `data/enemies/undead_basic.tres`: `drop_pool = PackedStringArray("ghost", "skeleton")`.
- `data/enemies/undead_horde.tres`: `drop_pool = PackedStringArray("skeleton", "zombie")`.
- `data/enemies/ghoul_pack.tres`: `drop_pool = PackedStringArray("zombie", "ghoul")`.
- `data/enemies/undead_elite.tres`: `drop_pool = PackedStringArray("ghoul")`.
- `autoloads/EnemyRegistry.gd`: added `get_drop_pool(type_id)` static method; falls back to `["ghost"]` for unknown types.

## Documentation Updates

Updated `docs/agent/inventory-and-deck.md` to note battle card drops via `EnemyRegistry.get_drop_pool()`.
