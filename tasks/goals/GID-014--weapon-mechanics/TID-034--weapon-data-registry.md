# TID-034: WeaponData resource + WeaponRegistry

**Goal:** GID-014
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Defines the data model for weapons and a registry that loads them — the foundation every other weapon task depends on. Mirrors the existing `CardData.gd` + `CardRegistry.gd` pattern exactly so the rest of the system has a consistent API.

## Research Notes

**Pattern to mirror:** `data/CardData.gd` + `autoloads/CardRegistry.gd`

- `CardData.gd` is a `Resource` with `@export` fields; saved as `.tres` files under `data/cards/`
- `CardRegistry.gd` is a static/autoload that lazy-scans the directory on first access and caches resources in a dict keyed by id
- `CardRegistry` is registered in `project.godot` under `[autoload]`

**WeaponData fields needed:**
```
id: String                  # unique key, e.g. "rusty_dagger"
display_name: String        # shown in UI
description: String         # flavor text
battle_effect_type: String  # "deck_inject" | "starting_mana" | "starting_hp" | "passive_atk"
battle_effect_value: int    # mana/HP/atk bonus amount (unused for deck_inject type)
injected_card_id: String    # card id to inject (deck_inject only, else "")
injected_card_count: int    # how many copies to inject (deck_inject only, else 0)
```

**First weapon to create — rusty_dagger:**
- battle_effect_type = "deck_inject"
- injected_card_id = "dagger_throw"
- injected_card_count = 3

**File locations:**
- `data/WeaponData.gd` — resource class
- `autoloads/WeaponRegistry.gd` — autoload
- `data/weapons/rusty_dagger.tres` — first weapon resource
- `data/weapons/rusty_dagger.tres.uid` — uid sidecar
- Register `WeaponRegistry` in `project.godot`

**UID sidecar format:**
```
uid://xxxxxxxxxxxx
```
Generate with: `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`

**project.godot autoload pattern** (look at how CardRegistry is registered — copy the same format):
```
[autoload]
CardRegistry="*res://autoloads/CardRegistry.gd"
WeaponRegistry="*res://autoloads/WeaponRegistry.gd"
```

**Strict-mode GDScript notes:**
- Use explicit types on all variables (no `:=` on Variant-returning expressions)
- `ResourceLoader.load()` returns `Resource` — cast to `WeaponData` explicitly
- Directory scan: use `DirAccess.open("res://data/weapons/")` then `get_next()` loop

## Plan

1. Create `data/WeaponData.gd` — `extends Resource` with `@export` fields matching the schema. Include `to_dict()` method for BattleScene use.
2. Create `data/WeaponData.gd.uid` sidecar.
3. Create `autoloads/WeaponRegistry.gd` — static class mirroring CardRegistry exactly. `get_weapon(id)` returns `WeaponData` (or null). `get_all_ids()` returns `Array[String]`.
4. Create `data/weapons/rusty_dagger.tres` — first weapon resource (deck_inject, dagger_throw × 3).
5. Create `data/weapons/rusty_dagger.tres.uid` sidecar.
6. WeaponRegistry is NOT registered as a global autoload — it's used via `preload()` at call sites, matching the CardRegistry pattern.

## Changes Made

- Created `data/WeaponData.gd` — Resource subclass with 7 @export fields (id, display_name, description, battle_effect_type, battle_effect_value, injected_card_id, injected_card_count)
- Created `data/WeaponData.gd.uid` (uid://xd6jf242qe6z)
- Created `autoloads/WeaponRegistry.gd` — static class mirroring CardRegistry; `get_weapon(id)` returns WeaponData or null; `get_all_ids()` returns Array[String]; lazy-scans `res://data/weapons/` on first call
- Created `data/weapons/rusty_dagger.tres` — deck_inject weapon, injects 3 dagger_throw cards
- Created `data/weapons/rusty_dagger.tres.uid` (uid://fe0gn9cy5fkb)
- WeaponRegistry uses `preload()` at call sites (not a global autoload), consistent with CardRegistry pattern

## Documentation Updates

_No agent doc changes — TID-038 handles docs for the full weapon system._
