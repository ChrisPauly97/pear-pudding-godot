# TID-745: Vendor counter: slide-to-sell, reactions, coin pile, Sell basket

**Goal:** GID-180
**Type:** agent
**Status:** pending
**Depends On:** TID-742

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Selling happens only at vendors, and should be a fun moment. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- `ShopScene.gd` (extends CardBrowserOverlay, 473 lines) — add a Sell section/tab as a counter: bag cards (and `for_sale_uids` basket) listed; drag or tap to slide onto counter; vendor reaction line per card (pure table keyed by rarity/roll quality/duplicate count, e.g. perfect roll vs 'another Ghost'); coins tween into a pile; confirm sells via `SaveManager.sell_card_instance`.
- 'Sell basket': one tap sells all flagged cards with cascade animation.
- Cards in decks/unique can't be sold (reuse `_is_selectable` logic → move to `BagOps`).
- Put counter UI in new `scenes/ui/shop/VendorCounter.gd` to keep ShopScene small.

Shared context:
- Inventory UI: `scenes/ui/InventoryScene.gd` (1103 lines, `max-file-lines` debt — put new code in `scenes/ui/inventory/` modules, not here). Opened via `SceneManager.open_menu_hub("deck")` (`MenuHubScene.gd`, `hub_mode`). Tiles: `inventory/CardTile.gd`, reused via `inventory/TileCache.gd`. Craft/Items tabs: `CraftPanel.gd`, `ItemsPanel.gd`. Bag logic: `game_logic/inventory/BagOps.gd`. Auto-fill: `game_logic/DeckAutoFill.gd`.
- Card instances: `owned_cards: Array[Dictionary]` (uid, template_id, rarity, attack, health, cost, kills, custom_name…; `game_logic/CardInstanceUtil.gd`). Deck = `player_deck` uids + `loadouts`. Stats roll per rarity: `IsoConst.RARITY_CONFIG` (multiplier/variance), `CardDropUtil.roll_stats`.
- Current deck editing uses `_working_deck` committed by Save Deck; drag uses `_DRAG_KIND = "inv_card"` + `_drop_into_deck/_drop_into_collection`. `DragScroll` autoload already lets horizontal card drags through.
- Rules: UI sizes as viewport fractions, `UiUtil` factories, preload not class_name, explicit types, gdlint (120 cols), headless import + `scripts/unsafe-hits.sh` + `godot --headless --path . -s tests/runner.gd` after edits. Mobile parity: every drag has a tap equivalent.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
