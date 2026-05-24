# TID-101: Sell & Scrap Actions (Gold + Essence)

**Goal:** GID-028
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
