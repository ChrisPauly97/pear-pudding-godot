# TID-117: TutorialRegistry — Data Store for Popup Content

**Goal:** GID-031
**Type:** agent
**Status:** done
**Depends On:** TID-116

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

All popup guide content lives in one place so adding a new popup never requires touching UI code. Any future developer (or agent session) just adds one entry to the registry dict.

## Research Notes

**File location:** `game_logic/TutorialRegistry.gd`  
- Pure static script, no Node inheritance needed (`extends RefCounted` or `class_name` block).
- Single public function: `static func get_entry(popup_id: String) -> Dictionary` returning `{ "title": String, "body": String }`, or empty dict if not found.
- Internal: a `const _DATA: Dictionary` mapping popup IDs to content dicts.

**Initial entries to implement:**

| popup_id | title | body |
|---|---|---|
| `"skill_tree"` | "Skill Tree" | "Spend Skill Points to unlock passive and active abilities. Skill Points are earned by leveling up — check the XP bar at the bottom of the screen. Unlock skills from top to bottom; each row requires the previous one." |
| `"coins"` | "Coins" | "Coins are the main currency. Earn them by winning battles and finding chests. Spend them at Merchant NPCs to buy new cards for your collection." |
| `"essence"` | "Essence" | "Essence is a crafting resource earned by scrapping cards you don't need. Use it in the Inventory to craft specific cards directly, saving you from relying on drops." |
| `"mana"` | "Mana" | "Mana is your battle resource. You start each game with 1 mana and gain 1 more each turn, up to a maximum of 10. Play cards that fit within your mana budget each turn." |
| `"card_rarity"` | "Card Rarity" | "Cards come in four rarities: Common (grey), Uncommon (green), Rare (blue), and Legendary (gold). Rarer cards have stronger effects and are harder to obtain — but you can craft any card using Essence." |

**class_name not needed** — callers will `preload("res://game_logic/TutorialRegistry.gd")` per the CLAUDE.md pattern.

## Plan

Populate `game_logic/TutorialRegistry.gd` (stub created in TID-116) with all 5 initial entries. No other files need changing.

## Changes Made

- `game_logic/TutorialRegistry.gd`: filled `_DATA` with entries for `skill_tree`, `coins`, `essence`, `mana`, `card_rarity`.

## Documentation Updates

None — TID-116 already documented the registry in the agent docs.
