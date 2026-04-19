# TID-057: Register New Cards in Drop Pools, Shop, and Rewards

**Goal:** GID-018
**Type:** agent
**Status:** done
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

- **CardRegistry**: no changes — auto-discovers .tres files via DirAccess.
- **ShopScene**: no changes — uses `CardRegistry.get_all_ids()`, so new cards appear automatically.
- **Enemy drop pools**: add Dawn/Dusk cards to each enemy's `drop_pool` in their .tres files:
  - `undead_basic`: add `mend`, `wither` (cheap accessible cards)
  - `undead_horde`: add `dawn_acolyte`, `dusk_wraith` (minion drops)
  - `undead_elite`: add `restore`, `drain` (mid-power drops)
  - `ghoul_pack`: add `dawn_paladin`, `dusk_vampire` (strong minion drops)
- **SaveManager**: add `dawn_acolyte` and `dusk_wraith` to the starter `owned_cards` only (not player_deck) so new players see one of each branch immediately.

## Changes Made

- `data/enemies/undead_basic.tres`: drop_pool += `mend`, `wither`
- `data/enemies/undead_horde.tres`: drop_pool += `dawn_acolyte`, `dusk_wraith`
- `data/enemies/undead_elite.tres`: drop_pool += `restore`, `drain`
- `data/enemies/ghoul_pack.tres`: drop_pool += `dawn_paladin`, `dusk_vampire`
- `autoloads/SaveManager.gd`: starter `owned_cards` gains `dawn_acolyte` and `dusk_wraith` (battle deck unchanged — still 12 undead minions)
- No changes to CardRegistry or ShopScene — both already auto-discover cards from `data/cards/`.

## Documentation Updates

- Updated `docs/agent/inventory-and-deck.md` to note that drop pools now include Dawn/Dusk cards.
