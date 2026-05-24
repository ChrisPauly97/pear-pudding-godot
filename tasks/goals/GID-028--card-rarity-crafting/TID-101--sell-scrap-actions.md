# TID-101: Sell & Scrap Actions (Gold + Essence)

**Goal:** GID-028
**Type:** agent
**Status:** done
**Depends On:** TID-100

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players accumulate excess cards and need outlets. Selling a card yields gold; scrapping yields essence (the crafting resource added in TID-098). Both actions permanently remove the card instance from the collection. This task adds Sell and Scrap buttons to each collection card row in InventoryScene and implements the economy values.

## Research Notes

**Economy values (per rarity)**:

| Rarity | Sell (gold) | Scrap (essence) |
|--------|-------------|-----------------|
| Common | 5 | 5 |
| Rare | 15 | 15 |
| Epic | 40 | 40 |
| Legendary | 100 | 80 |
| Unique | not sellable | not scrappable |

Unique cards (`is_unique = true`) cannot be sold or scrapped — the buttons are hidden or disabled for them.

**SaveManager helpers needed**:
- `sell_card_instance(uid: String) -> void` — removes instance, calls `add_coins(sell_price)`, marks dirty
- `scrap_card_instance(uid: String) -> void` — removes instance, increments `essence`, emits a new `essence_changed(new_amount: int)` signal on GameBus, marks dirty
- `essence: int` was added in TID-098

**GameBus signal**: add `signal essence_changed(new_amount: int)` to `autoloads/GameBus.gd`.

**UI additions in InventoryScene** (extends work from TID-100):
- Each collection row gains two small buttons: "Sell (+Xg)" and "Scrap (+Xe)" where X is the rarity's value
- Buttons are hidden for cards currently in the active deck (can't scrap what's in use)
- After sell/scrap, call `_refresh()` to rebuild the list
- Add an essence balance label next to the existing coin label in the header bar

**Prevent double-dipping**: if the card UID is in `_working_deck`, disable the Sell and Scrap buttons for that row (the card is in use). This mirrors how "Add to Deck" works.

**ShopScene** (`scenes/ui/ShopScene.gd`): ShopScene sells cards TO the player (no changes needed here).

**Confirmation prompt**: a single-click sell/scrap with no confirm dialog is acceptable for common/rare. For epic and legendary, show a brief "Are you sure?" inline — a small panel that replaces the buttons with "Confirm / Cancel". Implement in Plan phase.

**No new resource files** in this task.

## Plan

1. Add `sell_gold` and `scrap_essence` to each rarity tier in `IsoConst.RARITY_CONFIG`.
2. Add `signal essence_changed(new_amount: int)` to `GameBus.gd`.
3. Add `sell_card_instance(uid)` and `scrap_card_instance(uid)` to `SaveManager.gd`.
4. Add `_essence_label` to `InventoryScene` and show `Essence: N` below the coin label.
5. Add a sell/scrap action row to each collection card row; epic/legendary show an inline confirm panel before executing.
6. Add `_show_confirm()`, `_do_sell()`, `_do_scrap()` helper methods.

## Changes Made

- **`autoloads/IsoConst.gd`**: Extended `RARITY_CONFIG` with `sell_gold` (5/15/40/100) and `scrap_essence` (5/15/40/80) per rarity.
- **`autoloads/GameBus.gd`**: Added `signal essence_changed(new_amount: int)`.
- **`autoloads/SaveManager.gd`**: Added `sell_card_instance(uid)` (removes instance, adds gold) and `scrap_card_instance(uid)` (removes instance, increments essence, emits `GameBus.essence_changed`).
- **`scenes/ui/InventoryScene.gd`**:
  - Added `_essence_label` member; rendered in collection panel header.
  - `_refresh_cards()` updates essence label.
  - `_make_collection_row()`: adds action row with Sell and Scrap buttons (gold/blue tint); unique cards skip this row; epic/legendary show inline confirm panel before acting.
  - Added `_show_confirm()`, `_do_sell()`, `_do_scrap()`.

## Documentation Updates

No new agent docs needed.
