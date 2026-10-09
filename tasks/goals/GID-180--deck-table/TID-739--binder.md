# TID-739: Binder: stacks, pages, silhouettes, shimmer, gilding

**Goal:** GID-180
**Type:** agent
**Status:** done
**Depends On:** TID-736, TID-737

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Collection becomes a binder worth browsing: stacked copies, pages per magic type, silhouettes of unowned cards, perfect-roll shimmer, veterancy gilding. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- Stack: group instances by template_id+rarity into one tile showing ×N, sorted best `roll_quality` first; tap adds best non-deck copy; hold opens copies list (existing detail popup per copy).
- Pages: tabs per magic type (`MagicTypes.TYPES`) + Neutral; unowned templates from `CardRegistry` as dark silhouettes (count owned/total per page).
- `CardTile.gd`: shimmer overlay for `DeckInsights.is_perfect_roll`; veterancy (`VeterancyUtil`) as wear → gilded edge.
- `TileCache` reuse must key on stack id now.

Shared context:
- Inventory UI: `scenes/ui/InventoryScene.gd` (1103 lines, `max-file-lines` debt — put new code in `scenes/ui/inventory/` modules, not here). Opened via `SceneManager.open_menu_hub("deck")` (`MenuHubScene.gd`, `hub_mode`). Tiles: `inventory/CardTile.gd`, reused via `inventory/TileCache.gd`. Craft/Items tabs: `CraftPanel.gd`, `ItemsPanel.gd`. Bag logic: `game_logic/inventory/BagOps.gd`. Auto-fill: `game_logic/DeckAutoFill.gd`.
- Card instances: `owned_cards: Array[Dictionary]` (uid, template_id, rarity, attack, health, cost, kills, custom_name…; `game_logic/CardInstanceUtil.gd`). Deck = `player_deck` uids + `loadouts`. Stats roll per rarity: `IsoConst.RARITY_CONFIG` (multiplier/variance), `CardDropUtil.roll_stats`.
- Current deck editing uses `_working_deck` committed by Save Deck; drag uses `_DRAG_KIND = "inv_card"` + `_drop_into_deck/_drop_into_collection`. `DragScroll` autoload already lets horizontal card drags through.
- Rules: UI sizes as viewport fractions, `UiUtil` factories, preload not class_name, explicit types, gdlint (120 cols), headless import + `scripts/unsafe-hits.sh` + `godot --headless --path . -s tests/runner.gd` after edits. Mobile parity: every drag has a tap equivalent.

## Plan

Pure BinderOps (pages, stacks, missing templates, progress); BagFilters module (filters + page, out of InventoryScene); CardTile count pill, perfect star, gilding, silhouette; InventoryScene stacked rendering + expand view.

## Changes Made

- New `game_logic/inventory/BinderOps.gd` + `tests/unit/test_binder_ops.gd`.
- New `scenes/ui/inventory/BagFilters.gd` (filter state/buttons moved out of InventoryScene).
- `CardTile`: `add_count`, `add_perfect_mark`, `build_silhouette`, veterancy `_gild`.
- `CardJuice.twinkle`.
- `InventoryScene`: page tabs + Found X/Y, stacked binder, All-copies expand view, silhouettes with how-to-get message.
- `tools/capture_inventory.gd`: duplicates + `PAGE` env. Verified visually.

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: Binder section.
