# TID-096: Keyword Card Content — New .tres Files Bearing Keywords

**Goal:** GID-025
**Type:** agent
**Status:** pending
**Depends On:** TID-094, TID-095

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The keyword system is only meaningful if cards use it. This task creates at least 6 new minion cards that showcase each keyword, spread across the existing magic branches, and registers them in drops and the shop.

## Research Notes

- Follow the same .tres format and .uid sidecar requirement as existing cards in `data/cards/`
- Generate uid: `python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"`
- Keywords field in .tres: `keywords = PackedStringArray(["ward"])` or `Array[String]` — check exact GDScript 4 .tres syntax by looking at an existing typed array field in a .tres file
- Spread keywords across branches so all branch archetypes benefit:

**Planned keyword cards (6 minimum):**

| ID | Display Name | Branch | Cost | ATK | HP | Keywords | Notes |
|---|---|---|---|---|---|---|---|
| iron_revenant | Iron Revenant | Ash | 3 | 1 | 5 | ward | Cheap Ward for ash/control decks |
| surge_spirit | Surge Spirit | Ember | 2 | 3 | 1 | surge | Fragile but hits immediately |
| shrouded_wraith | Shrouded Wraith | Dusk | 3 | 2 | 3 | shroud | Trades safely once |
| dawn_guardian | Dawn Guardian | Dawn | 4 | 2 | 6 | ward | Durable Ward for healing decks |
| blitz_ghoul | Blitz Ghoul | Ash | 4 | 4 | 2 | surge | High-damage rush threat |
| veiled_paladin | Veiled Paladin | Dawn | 5 | 3 | 4 | shroud, ward | Expensive but very resilient |

- `veiled_paladin` has two keywords — verify the `keywords` Array field handles multiple values correctly before creating it
- Register all 6 in enemy drop pools (spread appropriately by enemy tier) and in ShopScene
- Do NOT add keyword cards to the starter deck

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
