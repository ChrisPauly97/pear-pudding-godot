# TID-098: Owned Card Instances + Save Migration v9→v10

**Goal:** GID-028
**Type:** agent
**Status:** pending
**Depends On:** TID-097

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Currently `SaveManager.owned_cards: Array[String]` stores plain card IDs (e.g. `"ghost"`). There is no per-instance data — rarity, rolled stats, or a unique identifier. This task changes the format to `Array[Dictionary]` where each entry is a card instance, adds `essence: int` for the crafting resource, and provides a v9→v10 migration so old saves load cleanly.

## Research Notes

**SaveManager** (`autoloads/SaveManager.gd`):
- `owned_cards: Array[String]` — needs to become `Array[Dictionary]`
- `player_deck: Array[String]` — currently a list of card IDs; needs to become a list of instance UIDs (strings) pointing into `owned_cards` instances
- `CURRENT_SAVE_VERSION = 9` → bump to 10
- Add `essence: int = 0` field
- Migration pattern: `_migrate_v8_to_v9` is the most recent; add `_migrate_v9_to_v10` that converts each string in `owned_cards` to a dict with `{"uid": "<generated>", "template_id": "<old_string>", "rarity": "common", "attack": <base>, "health": <base>, "cost": <base>}` (stat values come from `CardRegistry.get_template(id)`)
- `player_deck` migration: each string ID in the old `player_deck` needs to be matched to one instance UID from the converted `owned_cards`. The safest approach: pick the first unmatched instance with that `template_id`.

**Card instance Dictionary format**:
```json
{
  "uid": "ghost_1716000000_0",
  "template_id": "ghost",
  "rarity": "common",
  "attack": 2,
  "health": 3,
  "cost": 1
}
```
`uid` format: `"<template_id>_<ticks>_<index>"` — use `Time.get_ticks_msec()` + a counter to guarantee uniqueness within a session.

**New SaveManager helpers needed**:
- `add_card_instance(template_id: String, rarity: String, attack: int, health: int, cost: int) -> String` — creates instance dict, appends to `owned_cards`, returns uid, marks dirty
- `remove_card_instance(uid: String) -> void` — removes from `owned_cards` and `player_deck` if present, marks dirty
- `get_owned_instances() -> Array[Dictionary]` — returns `owned_cards` directly (already the right type after migration)
- `get_instance_by_uid(uid: String) -> Dictionary` — linear scan, returns `{}` if not found
- `get_deck_instances() -> Array[Dictionary]` — resolves each UID in `player_deck` to its instance dict

**`get_owned_counts()` must be updated**: currently counts by string ID; after migration it should count by `template_id` field.

**`set_active_deck(new_deck: Array[String])` remains a list of UIDs** — callers that used to pass card IDs now pass UIDs. This means `InventoryScene` and anything that builds the active deck must be updated in TID-100.

**`add_cards_to_deck(card_ids: Array[String])`** — currently called by `SceneManager._on_battle_won()` with template IDs. After this migration it needs to call the new `add_card_instance()` helper instead. A new overload or a rename is needed. Discuss in Plan phase which callers need updating.

**`PlayerState` (battle)**: currently calls `CardRegistry.get_template(id)` to build `CardInstance` objects. The battle system does NOT need per-instance stats yet (TID-105 handles that). For now, keep battle using template base stats — the rarity stats only affect the collection display.

**Existing callers of `owned_cards` to audit**:
- `InventoryScene.gd` — iterates owned_cards; must switch to instance dicts (TID-100 handles full UI, but the data layer here must not crash it)
- `SaveManager.get_owned_counts()` — update in this task
- `SceneManager._on_battle_won()` — update to call `add_card_instance(...)` with rarity roll (TID-099 does the roll, but TID-098 must not break the existing path — temporarily default to "common" + base stats)
- `SaveManager.new_game()` — starter deck must be converted to instance format
- `SaveManager.grant_achievement_card()` — add as common instance

**UID sidecar**: no new resources in this task (all changes are to .gd scripts).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
