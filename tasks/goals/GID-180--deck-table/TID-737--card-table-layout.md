# TID-737: Card table layout + auto-save/undo

**Goal:** GID-180
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

One screen: binder (collection) on top, deck pile strip along bottom. Tap adds/removes, hold inspects. No Save Deck button — every change commits immediately with an Undo. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- Rework `InventoryScene._build_ui` into a table layout; extract into `scenes/ui/inventory/DeckTable.gd` (deck strip) and keep InventoryScene as coordinator; shrink InventoryScene where possible.
- Auto-save: write `player_deck`/active loadout on every add/remove (`SaveManager` dirty flush is batched, cheap). Undo stack (last ~20 ops) with an Undo button + Ctrl+Z.
- Keep deck size min 5 / max 30 validation and technique rules (`_technique_violation_with`) — show violations inline on the strip rather than blocking save.
- Collapse search/sort/filters/select behind one filter button.
- Tests: update existing inventory tests that press Save Deck (`grep -rn "Save Deck\|_on_save" tests/`).

Shared context:
- Inventory UI: `scenes/ui/InventoryScene.gd` (1103 lines, `max-file-lines` debt — put new code in `scenes/ui/inventory/` modules, not here). Opened via `SceneManager.open_menu_hub("deck")` (`MenuHubScene.gd`, `hub_mode`). Tiles: `inventory/CardTile.gd`, reused via `inventory/TileCache.gd`. Craft/Items tabs: `CraftPanel.gd`, `ItemsPanel.gd`. Bag logic: `game_logic/inventory/BagOps.gd`. Auto-fill: `game_logic/DeckAutoFill.gd`.
- Card instances: `owned_cards: Array[Dictionary]` (uid, template_id, rarity, attack, health, cost, kills, custom_name…; `game_logic/CardInstanceUtil.gd`). Deck = `player_deck` uids + `loadouts`. Stats roll per rarity: `IsoConst.RARITY_CONFIG` (multiplier/variance), `CardDropUtil.roll_stats`.
- Current deck editing uses `_working_deck` committed by Save Deck; drag uses `_DRAG_KIND = "inv_card"` + `_drop_into_deck/_drop_into_collection`. `DragScroll` autoload already lets horizontal card drags through.
- Rules: UI sizes as viewport fractions, `UiUtil` factories, preload not class_name, explicit types, gdlint (120 cols), headless import + `scripts/unsafe-hits.sh` + `godot --headless --path . -s tests/runner.gd` after edits. Mobile parity: every drag has a tap equivalent.

## Plan

DeckPile view module; DeckUndo pure stack; route every deck edit through _edit_deck (undo snapshot + immediate save); remove Save Deck; fold filters behind a toggle; Ctrl+Z.

## Changes Made

- New `scenes/ui/inventory/DeckPile.gd` (deck side: count, Undo, Best deck, loadout slot, mini card tiles).
- New `game_logic/inventory/DeckUndo.gd` + `tests/unit/test_deck_undo.gd`.
- `InventoryScene.gd`: deck list rows replaced by DeckPile tiles (tap removes, hold inspects, drag back); `_edit_deck`/`_commit_deck`/`_on_undo`; Save Deck removed; Filters toggle; Ctrl+Z; prune after scrap/sell. File shrank 1103 → ~1046 lines.
- `tests/inventory_tiles_smoke.gd`: auto-save + undo check.
- Full suite: 3194 passed, 0 failed.

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: Card table layout section; bag paragraph updated (no Save Deck).
