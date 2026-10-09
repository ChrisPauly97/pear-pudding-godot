# TID-746: Vendor magic-type preferences + buyback shelf

**Goal:** GID-180
**Type:** agent
**Status:** done
**Depends On:** TID-745

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Small decisions and forgiveness: each town's vendor pays a bonus for some magic types; recently sold cards can be bought back. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- Pure `game_logic/inventory/VendorPrefs.gd`: town → preferred magic types + bonus % (madrian, maykalene, blancogov, larik, marsax_hold; traveling merchant none). Price = `RARITY_CONFIG.sell_gold` × bonus.
- Town key: `SceneManager._on_shop_requested` passes `current_map`, which is `main` for stitched outdoor towns (GID-138) — use `WorldScene.story_place()` / `realm_regions.current_town` instead (see BID-096).
- Buyback: persisted `buyback_cards: Array` (full instance dicts, cap ~8, FIFO) in `PERSISTED_FIELDS`; buy back at sell price; respects bag full.

Shared context:
- Inventory UI: `scenes/ui/InventoryScene.gd` (1103 lines, `max-file-lines` debt — put new code in `scenes/ui/inventory/` modules, not here). Opened via `SceneManager.open_menu_hub("deck")` (`MenuHubScene.gd`, `hub_mode`). Tiles: `inventory/CardTile.gd`, reused via `inventory/TileCache.gd`. Craft/Items tabs: `CraftPanel.gd`, `ItemsPanel.gd`. Bag logic: `game_logic/inventory/BagOps.gd`. Auto-fill: `game_logic/DeckAutoFill.gd`.
- Card instances: `owned_cards: Array[Dictionary]` (uid, template_id, rarity, attack, health, cost, kills, custom_name…; `game_logic/CardInstanceUtil.gd`). Deck = `player_deck` uids + `loadouts`. Stats roll per rarity: `IsoConst.RARITY_CONFIG` (multiplier/variance), `CardDropUtil.roll_stats`.
- Current deck editing uses `_working_deck` committed by Save Deck; drag uses `_DRAG_KIND = "inv_card"` + `_drop_into_deck/_drop_into_collection`. `DragScroll` autoload already lets horizontal card drags through.
- Rules: UI sizes as viewport fractions, `UiUtil` factories, preload not class_name, explicit types, gdlint (120 cols), headless import + `scripts/unsafe-hits.sh` + `godot --headless --path . -s tests/runner.gd` after edits. Mobile parity: every drag has a tap equivalent.

## Plan

Pure VendorPrefs; story-place town for the shop (BID-096); persisted buyback shelf + buy_back; counter pitch + shelf.

## Changes Made

- New `game_logic/inventory/VendorPrefs.gd` + `tests/unit/test_vendor_prefs.gd` (incl. buyback round trip).
- `SaveManager`: `buyback_cards` (PERSISTED_FIELDS), `BUYBACK_CAP`, shelving in `sell_card_instance`, `buy_back`; `new_game` clears for-sale + buyback.
- `SceneManager._on_shop_requested`: story place (fixes BID-096 — resolved, archived).
- `VendorCounter`: `setup(ref, place)` with town pricing, pitch line, buyback shelf; tighter sizes so the shop panel fits.
- `ShopScene` stays under 500 lines (wiring moved into the counter).
- Capture env `TOWN`. Verified visually.

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: Vendor tastes + buyback section.
