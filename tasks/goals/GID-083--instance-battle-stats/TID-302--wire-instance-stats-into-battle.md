# TID-302: Wire get_deck_instances() into BattleScene and PlayerState

**Goal:** GID-083
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`BattleScene._ready()` calls `SaveManager.get_deck_template_ids()` which returns plain `Array[String]` template IDs, discarding instance UIDs. `PlayerState.build_deck(ids)` then fetches base stats from `CardRegistry.get_template(cid)`. Per-instance rolled stats are never used.

`SaveManager.get_deck_instances()` returns `Array[Dictionary]` with keys `{template_id, uid, rarity, attack, health, cost}` but has zero callers.

## Plan

## Changes Made

## Documentation Updates
