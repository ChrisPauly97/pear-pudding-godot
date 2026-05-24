# TID-100: Inventory Rarity Display & Per-Instance Stat Readout

**Goal:** GID-028
**Type:** agent
**Status:** pending
**Depends On:** TID-098

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

After TID-098 the save stores per-instance card dicts. The InventoryScene still renders from the old string-based model. This task rewrites the collection panel to iterate card instances, shows each card's rarity tier with a colour-coded badge, and displays the rolled stat alongside its rarity range in smaller greyed text so the player can see how their copy rolled.

## Research Notes

**InventoryScene** (`scenes/ui/InventoryScene.gd`, ~21 KB): the collection panel iterates `SaveManager.get_owned_counts()` (a dict of template_id → count) and renders one row per unique template. After TID-098 this must change to iterate `SaveManager.get_owned_instances()` and render one row per instance.

**Rarity colour coding** (suggested):
- Common — `Color(0.8, 0.8, 0.8)` (light grey)
- Rare — `Color(0.2, 0.5, 1.0)` (blue)
- Epic — `Color(0.7, 0.2, 1.0)` (purple)
- Legendary — `Color(1.0, 0.75, 0.0)` (gold)

**Rarity badge**: a small Label before the card name showing `[C]`, `[R]`, `[E]`, or `[L]` in the rarity colour.

**Stat display format** (see approved design):
```
Ghost          [R]
Cost 2   ATK 7 (6–10)   HP 5 (4–7)
```
- The `(min–max)` range annotation is read from `CardData.rare_stats.attack_min / attack_max` etc.
- If both min and max equal the base stat (or the RarityStats field is null), omit the range annotation.
- If the rolled value equals the max of the range, show the stat in gold/highlight colour.

**"Add to Deck" behaviour change**: currently `_on_add_to_deck(card_id)` appends a template ID to the working deck. After TID-098, `player_deck` is a list of UIDs. The button must pass the instance UID. Each instance row needs the UID available.

**Deck panel**: currently lists by template ID with a count. After this task, list instances individually (same template may appear multiple times with different rarities). Alternatively, group by template but show a rarity breakdown — decide in Plan phase. Simplest: list individually, each with its UID for removal.

**"Remove from Deck" behaviour**: remove the UID from the working deck and return it to the collection panel.

**Sorting**: collection panel should sort instances by template_id alphabetically, then by rarity tier descending (legendary first), so highest-quality copies appear first in each template group.

**Viewport sizing**: follow CLAUDE.md pattern — all sizes as fractions of `_vh`/`_vw`. Existing code already does this; maintain the pattern.

**No new resource files** in this task — pure UI GDScript changes.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
