# TID-743: Never lose loot + overstuffed satchel

**Goal:** GID-180
**Type:** agent
**Status:** pending
**Depends On:** TID-737

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Make sure loot is never lost and a full bag is charming, not a red warning. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- Overflow already exists: `SaveManager.grant_card_reward` routes to `mailbox_cards` when full (`GameBus.card_routed_to_mailbox`). Audit remaining `add_card_instance` callers: SaveManager 519/522/658 (starter/seed paths), combine (1079 — after removing 3 cards, fine), ShopScene 348 and CraftPanel 164 (player spends, intended to block). Confirm none silently drop.
- Satchel visual on the wallet line: fill level art (bulging when ≥90%, cards poking out at full) + tap opens mailbox count.
- Companion grumble: one-liner from active companion when bag hits full / card routed to mailbox (use existing toast/HUD message path; text table in a pure file).

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
