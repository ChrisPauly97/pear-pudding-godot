# TID-742: Forge: scrap + combine ritual; flag for sale replaces Sell

**Goal:** GID-180
**Type:** agent
**Status:** done
**Depends On:** TID-737, TID-738

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Cleanup becomes a reward. Selling moves to vendors only (user decision), so the bag offers Scrap and 'flag for sale'. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- Forge drop zone on the table: drag (or select + tap Forge) to scrap → burn dissolve shader/tween + essence spark particles flying to wallet. Uses `SaveManager.scrap_card_instance`.
- Combine 3: when ≥3 non-deck copies of template+rarity, a Combine affordance; 3 cards orbit, merge, flash into new tier (`SaveManager.combine_cards`).
- Remove Sell from detail popup (`_detail_action` "sell", InventoryScene ~757) and bulk sell (`_bulk_sell_btn`, `_apply_bulk` ~846). Mailbox sell (`SaveMailbox.sell_mailbox_card`, `MailboxScene`) → also vendor-only? Keep scrap there; route sell to flag.
- New persisted field `for_sale_uids: Array` in `SaveManager.PERSISTED_FIELDS`; flagged cards show a price tag, can't be added to deck while flagged (or unflag on add). Prune on `remove_card_instance`.
- Update `SceneManager` bag_full toast text ("Sell or scrap…" line ~222) and tests that call sell from the bag.

Shared context:
- Inventory UI: `scenes/ui/InventoryScene.gd` (1103 lines, `max-file-lines` debt — put new code in `scenes/ui/inventory/` modules, not here). Opened via `SceneManager.open_menu_hub("deck")` (`MenuHubScene.gd`, `hub_mode`). Tiles: `inventory/CardTile.gd`, reused via `inventory/TileCache.gd`. Craft/Items tabs: `CraftPanel.gd`, `ItemsPanel.gd`. Bag logic: `game_logic/inventory/BagOps.gd`. Auto-fill: `game_logic/DeckAutoFill.gd`.
- Card instances: `owned_cards: Array[Dictionary]` (uid, template_id, rarity, attack, health, cost, kills, custom_name…; `game_logic/CardInstanceUtil.gd`). Deck = `player_deck` uids + `loadouts`. Stats roll per rarity: `IsoConst.RARITY_CONFIG` (multiplier/variance), `CardDropUtil.roll_stats`.
- Current deck editing uses `_working_deck` committed by Save Deck; drag uses `_DRAG_KIND = "inv_card"` + `_drop_into_deck/_drop_into_collection`. `DragScroll` autoload already lets horizontal card drags through.
- Rules: UI sizes as viewport fractions, `UiUtil` factories, preload not class_name, explicit types, gdlint (120 cols), headless import + `scripts/unsafe-hits.sh` + `godot --headless --path . -s tests/runner.gd` after edits. Mobile parity: every drag has a tap equivalent.

## Plan

Remove Sell from bag + mailbox; persisted for_sale_uids + toggle; forge drop zone with ForgeFx burn; CombineRitual overlay for combine.

## Changes Made

- `SaveManager`: `for_sale_uids` (PERSISTED_FIELDS), `toggle_for_sale`, `is_for_sale`, pruning in `remove_card_instance` / `set_active_deck`.
- `SaveMailbox.sell_mailbox_card` + its test removed; `MailboxScene` Sell button removed; bag-full messages point to forge/vendor (`MailboxScene`, `SceneManager`).
- New `scenes/ui/inventory/ForgeFx.gd`, `CombineRitual.gd`; `CardJuice.sound("burn")`.
- `InventoryScene`: forge drop zone, `_forge_scrap`, `_combine`, flag toggle in popup + bulk, For-sale tag.
- Smoke: flag + forge scrap. Visual check of forge + ritual.

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: Forge / ritual / flag section.
