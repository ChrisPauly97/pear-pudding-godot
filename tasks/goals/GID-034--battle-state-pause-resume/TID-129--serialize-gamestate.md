# TID-129: Serialize GameState to/from Dictionary

**Goal:** GID-034
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

All battle state lives in pure GDScript `RefCounted` objects with no rendering dependency, making them straightforward to serialize to a `Dictionary` (and thus to JSON). This task adds `to_dict()` / `from_dict()` to every layer of the model so that a full snapshot can be saved and restored.

`CardInstance.to_dict()` already existed at line 111 of `game_logic/battle/CardInstance.gd`, but it only recorded display fields — it omitted `summoning_sick`, `attack_count`, `shroud_active`, `out_of_play`, `status_effects`, and `keywords`. It was extended and a matching `from_dict()` was added.

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

1. **CardInstance.gd** — replace the existing minimal `to_dict()` with a full one covering all battle-state fields; add `static func from_dict(d) -> CardInstance` that calls `new()` (which hits the empty-dict path of `_init`, a no-op) then sets every field from the dict.
2. **HeroState.gd** — add `to_dict()` and `static func from_dict(d) -> HeroState`.
3. **ZoneState.gd** — add `to_dict() -> Array` (5 entries, null or CardInstance dict) and `static func from_dict(slots_arr: Array) -> ZoneState`.
4. **PlayerState.gd** — add `to_dict()` and `static func from_dict(d) -> PlayerState`; derives all sub-objects via their own `from_dict`.
5. **GameState.gd** — add `to_dict()` and `static func from_dict(d) -> GameState`; calls `new()` to get an empty shell, then replaces `players` array with restored `PlayerState` objects.

## Changes Made

- `game_logic/battle/CardInstance.gd`: replaced minimal `to_dict()` with full serialization of all 21 fields; added `static func from_dict(d: Dictionary) -> CardInstance` that constructs via `new()` (empty-dict no-op path) then sets all fields directly.
- `game_logic/battle/HeroState.gd`: added `to_dict()` and `static func from_dict(d: Dictionary) -> HeroState`.
- `game_logic/battle/ZoneState.gd`: added `to_dict() -> Array` (5 entries, null or card dict) and `static func from_dict(slots_arr: Array) -> ZoneState` using the existing `CardInstance` preload const.
- `game_logic/battle/PlayerState.gd`: added `to_dict()` and `static func from_dict(d: Dictionary) -> PlayerState` with full sub-object restoration.
- `game_logic/battle/GameState.gd`: added `to_dict()` and `static func from_dict(d: Dictionary) -> GameState` — calls `new()` then clears and rebuilds `players` from restored `PlayerState` objects.
- Tests: 283 passed / 6 failed (6 pre-existing failures; my changes fixed 2 that were previously failing).

## Documentation Updates

None — agent docs updated in TID-133.
