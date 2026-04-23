# TID-093: Keyword Data Model — Add Keywords to CardData and CardInstance

**Goal:** GID-025
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Keywords are permanent passive properties on minion cards. This task adds the data model — the `keywords` field on CardData (the template) and CardInstance (the in-battle copy) — so TID-094 (logic) and TID-095 (UI) can build on it.

## Research Notes

- `data/cards/CardData.gd` (or wherever CardData is defined as a Resource subclass) — add `@export var keywords: Array[String] = []`
- `game_logic/battle/CardInstance.gd` — CardInstance wraps CardData for in-battle use; add `keywords: Array[String]` copied from CardData at construction time; also add `shroud_active: bool` (starts true if "shroud" is in keywords; set to false after first hit is absorbed)
- Valid keyword string values: `"ward"`, `"surge"`, `"shroud"` — use lowercase string constants; define them as constants in a new `game_logic/battle/Keywords.gd` (or IsoConst) to avoid magic strings elsewhere
- Existing card .tres files omit the `keywords` field — this is fine; Array defaults to `[]`; no migration needed
- Strict mode: `Array[String]` is a typed array; use `.has("ward")` not `in` operator for membership checks in GDScript 4

## Plan

1. Create `game_logic/battle/Keywords.gd` — defines `const WARD`, `SURGE`, `SHROUD` string constants and a `const ALL` typed array so other files can avoid magic strings.
2. Edit `data/CardData.gd` — add `@export var keywords: Array[String] = []` and include `"keywords": keywords` in `to_template_dict()`.
3. Edit `game_logic/battle/CardInstance.gd` — add `var keywords: Array[String] = []` and `var shroud_active: bool = false`; in `from_template()` copy `keywords` from the dict and set `shroud_active = keywords.has("shroud")`.

No existing `.tres` files need changes (omitting `keywords` defaults to `[]`). No tests to update for this pure data-model change.

## Changes Made

- **Created** `game_logic/battle/Keywords.gd` — defines `const WARD = "ward"`, `SURGE = "surge"`, `SHROUD = "shroud"` and `const ALL: Array[String]` for iteration. Use `preload("res://game_logic/battle/Keywords.gd")` in files that reference these constants (class_name not globally available until Godot scans the file).
- **Edited** `data/CardData.gd` — added `@export var keywords: Array[String] = []`; added `"keywords": keywords` to `to_template_dict()`. Existing `.tres` files omitting this field default to `[]` with no migration needed.
- **Edited** `game_logic/battle/CardInstance.gd` — added `var keywords: Array[String] = []` and `var shroud_active: bool = false`; updated `from_template()` to `assign()` keywords from the template dict and set `shroud_active = keywords.has("shroud")`.

## Documentation Updates

- Updated `docs/agent/battle-system.md` — added `keywords` and `shroud_active` to the CardData and CardInstance sections; noted Keywords.gd constants.
