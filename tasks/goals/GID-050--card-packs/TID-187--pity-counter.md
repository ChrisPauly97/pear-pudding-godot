# TID-187: Legendary Pity Counter

**Goal:** GID-050
**Type:** agent
**Status:** done
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

1. Add `packs_since_legendary: int = 0` field to SaveManager.
2. Add `increment_pity()` and `reset_pity()` methods to SaveManager.
3. Add migration `_migrate_v24_to_v25()` (actual version was 24 at implementation time, not 14).
4. Add pity check to `PackDefs.roll_pack()` via `current_pity` parameter.
5. Wire up `_on_buy_pack()` in ShopScene to increment before rolling, reset after if legendary.
6. Add pity hint label in `_make_pack_row()`.
7. Add pity reset in `PackOpenScene._populate_face()` when rarity is legendary.
8. Write unit tests for all pity counter behaviour.

## Changes Made

- **`autoloads/SaveManager.gd`**:
  - Added `var packs_since_legendary: int = 0` field.
  - `CURRENT_SAVE_VERSION` bumped from 24 → 25.
  - Added `static func _migrate_v24_to_v25(data: Dictionary) -> void` — adds `packs_since_legendary: 0` if absent, bumps version to 25.
  - Added `if ver < 25: _migrate_v24_to_v25(data)` to `_apply_migrations()`.
  - Added `packs_since_legendary = int(data.get("packs_since_legendary", 0))` to `load_save()`.
  - Added `"packs_since_legendary": packs_since_legendary` to `save()` dict.
  - Added `packs_since_legendary = 0` to `new_game()`.
  - Added `increment_pity()` and `reset_pity()` public methods.
- **`game_logic/PackDefs.gd`**: `roll_pack()` accepts `current_pity: int` parameter; forces last slot to legendary when `current_pity >= PITY_THRESHOLD`.
- **`scenes/ui/ShopScene.gd`**: `_make_pack_row()` shows pity hint label when `packs_since_legendary > 0`; `_on_buy_pack()` calls `increment_pity()` before rolling and `reset_pity()` if threshold reached.
- **`scenes/ui/PackOpenScene.gd`**: `_populate_face()` calls `reset_pity()` when revealed card rarity is legendary.

## Documentation Updates

- Covered in `docs/agent/card-packs.md` (see TID-185 docs update).
- `docs/agent/save-system.md` should be updated to note the packs_since_legendary field and v24→v25 migration (covered in card-packs.md).
