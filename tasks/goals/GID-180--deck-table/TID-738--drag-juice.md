# TID-738: Drag juice: lift, snap, sounds, sparkle

**Goal:** GID-180
**Type:** agent
**Status:** done
**Depends On:** TID-737

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Make moving cards feel physical and satisfying. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- On grab: card scales ~1.08, tilts toward drag velocity, drop shadow; on drop into deck: tween snap + small screen-less thud (scale punch on the pile), pile height grows.
- Sounds from `assets/audio/sfx` (card_draw*, card_play*) via `AudioManager` (check autoload API); shuffle sound on shuffle.
- Rarity sparkle: `GPUParticles2D`/CPUParticles2D burst coloured by rarity on pickup; legendary idle shimmer/hum (low-volume loop) — gate by Settings reduced effects if one exists.
- Keep tweens off when `DisplayServer` headless tests run (or harmless).

Shared context:
- Inventory UI: `scenes/ui/InventoryScene.gd` (1103 lines, `max-file-lines` debt — put new code in `scenes/ui/inventory/` modules, not here). Opened via `SceneManager.open_menu_hub("deck")` (`MenuHubScene.gd`, `hub_mode`). Tiles: `inventory/CardTile.gd`, reused via `inventory/TileCache.gd`. Craft/Items tabs: `CraftPanel.gd`, `ItemsPanel.gd`. Bag logic: `game_logic/inventory/BagOps.gd`. Auto-fill: `game_logic/DeckAutoFill.gd`.
- Card instances: `owned_cards: Array[Dictionary]` (uid, template_id, rarity, attack, health, cost, kills, custom_name…; `game_logic/CardInstanceUtil.gd`). Deck = `player_deck` uids + `loadouts`. Stats roll per rarity: `IsoConst.RARITY_CONFIG` (multiplier/variance), `CardDropUtil.roll_stats`.
- Current deck editing uses `_working_deck` committed by Save Deck; drag uses `_DRAG_KIND = "inv_card"` + `_drop_into_deck/_drop_into_collection`. `DragScroll` autoload already lets horizontal card drags through.
- Rules: UI sizes as viewport fractions, `UiUtil` factories, preload not class_name, explicit types, gdlint (120 cols), headless import + `scripts/unsafe-hits.sh` + `godot --headless --path . -s tests/runner.gd` after edits. Mobile parity: every drag has a tap equivalent.

## Plan

CardJuice statics (preview, sparkle, pop, shimmer, sound) + DragCardPreview; hook drag start, deck landing and binder/pile legendary tiles.

## Changes Made

- New `scenes/ui/inventory/CardJuice.gd`, `scenes/ui/inventory/DragCardPreview.gd`.
- `DeckPile`: `tile_for`, `land` (bounce + sparkles + count thump), legendary shimmer.
- `InventoryScene`: card drag preview replaces the coloured square; pick sound + sparkle; place/return sounds in `_edit_deck`; binder shimmer.
- `tools/capture_inventory.gd`: `DRAG=1` preview capture (verified visually).
- Legendary 'hum' kept visual only (shimmer); no looping audio in menus.

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: Card juice section.
