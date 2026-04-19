# TID-057: Register New Cards in Drop Pools, Shop, and Rewards

**Goal:** GID-018
**Type:** agent
**Status:** pending
**Depends On:** TID-055, TID-056

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

New Dawn and Dusk cards exist as .tres files but won't appear in the game until they are wired into enemy drop pools, the merchant shop, and owned_cards starting options. This task updates those registries.

## Research Notes

- `autoloads/CardRegistry.gd` loads all cards from `data/cards/` — should auto-discover new .tres files if it uses `dir.list_dir_begin()`. Verify this; if it has a hardcoded list, add new IDs.
- `data/enemies/*.tres` each have a `drop_pool: Array[String]` of card IDs — add Dawn/Dusk card IDs to appropriate enemies (e.g. Dawn cards drop from grasslands enemies, Dusk from scorched/mountains)
- `scenes/ui/ShopScene.gd` or its data source lists available cards for purchase — add all 16 new cards
- `autoloads/SaveManager.gd` `_new_save()` sets `owned_cards` starter list — optionally add 1-2 Dawn/Dusk cards to starter collection so new players see them immediately
- Do NOT add new cards to the starter deck (player.build_deck) — starter deck stays as 12 undead minions per original design

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
