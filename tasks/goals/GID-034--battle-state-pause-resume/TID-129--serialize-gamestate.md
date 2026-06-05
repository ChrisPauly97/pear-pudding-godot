# TID-129: Serialize GameState to/from Dictionary

**Goal:** GID-034
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

All battle state lives in pure GDScript `RefCounted` objects with no rendering dependency, making them straightforward to serialize to a `Dictionary` (and thus to JSON). This task adds `to_dict()` / `from_dict()` to every layer of the model so that a full snapshot can be saved and restored.

`CardInstance.to_dict()` already exists at line 111 of `game_logic/battle/CardInstance.gd`, but it only records display fields — it omits `summoning_sick`, `attack_count`, `shroud_active`, `out_of_play`, `status_effects`, and `keywords`. It needs to be extended and a matching `from_dict()` added.

## Research Notes

**Files to modify:**
- `game_logic/battle/CardInstance.gd` — extend `to_dict()`, add static `from_dict(d)`
- `game_logic/battle/HeroState.gd` — add `to_dict()`, add static `from_dict(d, pid)`
- `game_logic/battle/ZoneState.gd` — add `to_dict()`, add static `from_dict(d)`
- `game_logic/battle/PlayerState.gd` — add `to_dict()`, add static `from_dict(d)`
- `game_logic/battle/GameState.gd` — add `to_dict()`, add static `from_dict(d)`

**CardInstance fields to serialize (complete list):**
`instance_id`, `template_id`, `name`, `cost`, `attack`, `health`, `max_health`,
`card_class`, `description`, `magic_type`, `magic_branch`, `spell_effect`, `spell_power`,
`auto_resolve`, `keywords` (Array[String]), `shroud_active`, `armor`,
`summoning_sick`, `attack_count`, `out_of_play`, `status_effects` (Dictionary)

`from_dict()` must be `static` and return a new `CardInstance`. Because `CardInstance._init(tmpl)` increments `_next_id` and derives fields from a template dict, `from_dict` should call `_init({})` first to skip template lookup, then set every field directly from the dict. `instance_id` is written directly (preserves cross-reference equality).

**HeroState fields:** `player_id`, `health`, `max_health`, `mana`, `max_mana`, `attack`, `status_effects`

**ZoneState:** serialize as an Array of 5 entries — either `null` or the CardInstance dict. `from_dict` rebuilds each slot.

**PlayerState fields:** `player_id`, `is_ai`, `bonus_draw`, `hero` (dict), `board` (dict), `hand` (array of dicts), `draw_deck` (array of dicts), `discard` (array of dicts), `pending_auto_spells` (array of dicts)

**GameState fields:** `current_player_idx`, `turn_number`, `players` (array of 2 PlayerState dicts)

**GDScript type notes:**
- `keywords: Array[String]` serializes fine via `JSON`; restore with `keywords.assign(d.get("keywords", []))`.
- `status_effects: Dictionary` is plain string→int, serializes directly.
- `from_dict` static methods cannot use `class_name` self-reference in Godot 4 strict mode; use `preload` of the same file where needed.
- `ZoneState.from_dict` must call `preload("res://game_logic/battle/CardInstance.gd")` at the top of ZoneState.gd (it already has `const CardInstance = preload(...)` so this is already available).

**Existing snapshot stubs in ZoneState (lines 46-50):**
```gdscript
func snapshot() -> void:
    _snapshot = slots.duplicate()

func restore_snapshot() -> void:
    slots = _snapshot.duplicate()
```
These are in-memory only — the new `to_dict`/`from_dict` replaces their role for persistence. Leave the stubs in place (they may still be used for undo within a session in future).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
