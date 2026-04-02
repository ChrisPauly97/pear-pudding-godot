# TID-028: WeaponData resource + WeaponRegistry

**Goal:** GID-013
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
