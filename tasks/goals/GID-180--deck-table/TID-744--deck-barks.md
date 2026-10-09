# TID-744: Maiteln deck barks in the builder

**Goal:** GID-180
**Type:** agent
**Status:** pending
**Depends On:** TID-736, TID-737

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The mentor comments on your deck, teaching curve/synergy without text walls. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- Pure `game_logic/inventory/DeckBarkRules.gd` mirroring `game_logic/battle/BarkRules.gd` (LINES table, eligibility, rate-limit, pick_line with seen counts). Inputs: `DeckInsights` outputs (curve top-heavy, no early plays, too few spells, strong synergy, deck full).
- Eligibility like BarkRules.is_eligible (Maiteln companion / low level) or always-on light version — decide in plan.
- Speech bubble on the table; tests for rule selection.

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
