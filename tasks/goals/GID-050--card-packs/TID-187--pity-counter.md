# TID-187: Legendary Pity Counter

**Goal:** GID-050
**Type:** agent
**Status:** pending
**Depends On:** TID-185

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Guarantee a legendary card within N packs (20) to prevent long drought streaks. Persisted counter, migration, UI hint.

## Research Notes

- **SaveManager field:** Add `packs_since_legendary: int = 0` to **`autoloads/SaveManager.gd`** (line ~95, near other counters). Migration: **`_migrate_v14_to_v15`** (current version is v14 per line 184; next version is v15 at implementation time). Function adds `if not data.has("packs_since_legendary"): data["packs_since_legendary"] = 0`. Call `_migrate_v14_to_v15(data)` in the migration chain (line ~349 in SaveManager, after v14). Update **`CURRENT_SAVE_VERSION`** to 15 (line 184).

- **Pity threshold:** `const PITY_THRESHOLD: int = 20` in `PackDefs.gd`. On purchase, increment counter after rolling. After opening ceremony completes (all cards added to owned_cards), check if any rolled card is legendary. If yes, reset counter to 0. If no, counter remains incremented.

- **Force legendary logic:** In `PackDefs.roll_pack(pack_id)` — at roll time, check if `SaveManager.packs_since_legendary >= PITY_THRESHOLD`. If true, force the "best slot" (highest rarity rolled, or last slot if tied) to be legendary: re-roll rarity to "legendary", call `CardDropUtil.roll_stats(template_id, "legendary")` to get boosted stats. Reset `packs_since_legendary = 0` *immediately* so the next pack doesn't double-force.

- **Premium guarantee + pity interaction:** Premium packs have `guaranteed_min_rarity: "rare"`. If pity fires, it overrides this (legendary > rare). Both can coexist: guaranteed is applied first during normal roll; if pity at purchase time, force one slot to legendary *after* rolling. Order: roll all 3 with tier weights → apply guaranteed_min_rarity to one slot → check pity, if triggered force a *different* slot (or same slot if it's higher than guaranteed). **Simplest:** pity always forces the last slot (index 2) to legendary if triggered. Guaranteed applies to one of the first two.

- **Counter increment timing:** Increment `SaveManager.packs_since_legendary += 1` in `PackDefs.roll_pack()` *before* checking pity, so the counter is incremented and then pity check happens on that fresh value. After opening ceremony, check rolled cards: if any is legendary, emit `GameBus.card_rarity_upgraded` (already exists from GID-028?) or a new `legendary_obtained` signal, and reset the counter via a new SaveManager method `reset_pity()`.

- **UI hint in shop:** In **`scenes/ui/ShopScene.gd`**, after building each pack row, add a small label below it showing the pity status: `"Legendary guaranteed in %d packs"` if counter > 0, or `"Pity active"` if counter == PITY_THRESHOLD. Position below the Buy button. Font size `vh * 0.018`, color grey. Only show if counter > 0 to avoid clutter.

- **Save round-trip:** On save/load cycle, the counter persists. If a save is made mid-pack (after purchase but before opening), the opened cards will reset it when the opening ceremony runs. If save happens after opening, counter is already reset or incremented.

- **Headless tests:** Roll 19 times without legendary → counter at 19, next roll forced → counter resets. Roll naturally hitting legendary → counter resets. Save/load with partial counter → persists. Premium guarantee + pity both trigger → both satisfied (legendary is >= rare).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
