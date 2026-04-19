# TID-093: Keyword Data Model — Add Keywords to CardData and CardInstance

**Goal:** GID-025
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
