# TID-747: World loop: fly-in new cards, HUD bag badge, campfire table

**Goal:** GID-180
**Type:** agent
**Status:** done
**Depends On:** TID-737, TID-739

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Close the loop with the world so deck building feels part of the adventure. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- 'New' tracking: persisted `new_card_uids: Array` set in `add_card_instance`/`grant_card_reward`; cleared when the tile is viewed/hovered. Binder tiles glow while new.
- Post-fight: `autoloads/scene_manager/BattleVictory.gd` grants rewards; on return to world show cards flying to the HUD bag (Menu/Bag entry in `WorldHUD` ZONE_NAV ~line 132) — use the `_restore_world(after)` callable for post-swap work (see CLAUDE.md Spire draft learning).
- HUD badge: count of new cards on the Menu/Bag button (`WorldHUD` registry; no bare add_child).
- Campfire: `WildernessCamp.interact()` / camp campfires → offer 'Tend your deck' opening `open_menu_hub("deck")`; add to INTERACT_PRIORITY only if a new entity is introduced.

Shared context:
- Inventory UI: `scenes/ui/InventoryScene.gd` (1103 lines, `max-file-lines` debt — put new code in `scenes/ui/inventory/` modules, not here). Opened via `SceneManager.open_menu_hub("deck")` (`MenuHubScene.gd`, `hub_mode`). Tiles: `inventory/CardTile.gd`, reused via `inventory/TileCache.gd`. Craft/Items tabs: `CraftPanel.gd`, `ItemsPanel.gd`. Bag logic: `game_logic/inventory/BagOps.gd`. Auto-fill: `game_logic/DeckAutoFill.gd`.
- Card instances: `owned_cards: Array[Dictionary]` (uid, template_id, rarity, attack, health, cost, kills, custom_name…; `game_logic/CardInstanceUtil.gd`). Deck = `player_deck` uids + `loadouts`. Stats roll per rarity: `IsoConst.RARITY_CONFIG` (multiplier/variance), `CardDropUtil.roll_stats`.
- Current deck editing uses `_working_deck` committed by Save Deck; drag uses `_DRAG_KIND = "inv_card"` + `_drop_into_deck/_drop_into_collection`. `DragScroll` autoload already lets horizontal card drags through.
- Rules: UI sizes as viewport fractions, `UiUtil` factories, preload not class_name, explicit types, gdlint (120 cols), headless import + `scripts/unsafe-hits.sh` + `godot --headless --path . -s tests/runner.gd` after edits. Mobile parity: every drag has a tap equivalent.

## Plan

Persisted new_card_uids + GameBus.new_cards_changed; NEW tag/glow in binder, cleared on leaving; BagBadge helper on the HUD Menu button with fly-in catch-up after battles; rest-site campfire deck option.

## Changes Made

- `SaveManager`: `new_card_uids`, `_mark_new`, `mark_cards_seen`, `is_new_card`; starter paths clear it.
- `GameBus.new_cards_changed(count)`.
- New `scenes/world/BagBadge.gd`; `WorldHUD` sets it up on the Menu/Bag button (3 lines).
- `InventoryScene`: NEW tag + `CardJuice.new_glow`; `_exit_tree` marks seen.
- `DungeonSessionUI`: Tend-your-deck button; used fires still open the panel.
- New `tests/unit/test_new_cards.gd`. Full suite 3216 passed, 0 failed.
- Fixed `tests/menu_hub_smoke.gd`: the detail panel check expected a Sell button (removed in TID-742); it now checks For sale. All CI scene smoke tests pass.

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: World loop section.
