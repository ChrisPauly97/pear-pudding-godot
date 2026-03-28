# TID-016: Merchant NPC and Shop Overlay

**Goal:** GID-007
**Type:** agent
**Status:** pending
**Depends On:** TID-015

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players can now earn coins but have nowhere to spend them. This task adds a Merchant NPC entity type (placeable in named maps via the `MERCHANT` directive and spawnable in procedural towns) and a ShopScene overlay where cards can be purchased.

## Research Notes

**Relevant files:**
- `scenes/world/WorldScene.gd` — spawns NPCs and handles `E` interaction; model after `TownspersonNPC` for the entity type
- `scenes/world/TownspersonNPC.gd` — existing NPC with dialogue; MerchantNPC will show dialogue then open shop
- `autoloads/SceneManager.gd` — `push_overlay(scene)` pattern used by InventoryScene; ShopScene uses the same pattern
- `autoloads/SaveManager.gd` — `owned_cards`, `coins`, `add_coins()`, `mark_dirty()`
- `autoloads/CardRegistry.gd` — provides all available cards for shop listing
- `assets/maps/*.txt` — `MERCHANT x z` directive needs parsing in WorldMap
- `docs/agent/ui-and-scene-management.md` — overlay and viewport-relative sizing patterns

**Design:**
- **MerchantNPC entity:** new `.gd` script similar to TownspersonNPC; on `E` press opens ShopScene overlay
- **ShopScene:** vertical list of all cards (via CardRegistry), each row shows card name + cost in coins + Buy button; buy deducts coins and adds to owned_cards
- **Pricing:** base 15 coins per card (same for all cards initially; rarity differentiation is a future goal)
- **Map directive:** `MERCHANT x z` in `.txt` files; WorldMap parser emits a merchant entity; WorldScene spawns MerchantNPC at that position
- **Procedural spawning:** InfiniteWorldGen can optionally place 0–1 merchant per chunk (low probability, ~5%) in grassland/forest biomes

**UI sizing:** follow viewport-relative rules from CLAUDE.md — button height ~5% vh, font ~2% vh.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
