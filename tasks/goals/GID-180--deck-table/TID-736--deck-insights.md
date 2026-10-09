# TID-736: Pure logic: DeckInsights

**Goal:** GID-180
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Shared, unit-testable brains for the deck table: deck name + crest, synergy pairs, mana curve, roll quality, compare. Part of GID-180 (user request 2026-10-09: deck/inventory management must be intuitive and fun).

## Research Notes

- New `game_logic/inventory/DeckInsights.gd` (RefCounted, statics, no autoload state so `-s` tests can load it; get templates via a passed lookup or `CardRegistry` preload).
- `deck_name(instances) -> String`: deterministic from dominant magic type/branch (`MagicTypes`), dominant class (minion/spell), curve shape (low=tempo/swarm, high=ramp/titan). Word tables per branch, e.g. "Bone-Choir Swarm".
- `crest(instances) -> Dictionary`: {color from `MagicTypes.branch_color`, glyph id, border by avg rarity}.
- `synergy_pairs(instances) -> Array`: pairs of uids that combo — shared keywords/tribe/branch tags in card templates (check `CardRegistry` template fields: keywords, magic_branch, tags).
- `mana_curve(instances) -> Array[int]` buckets 0..7+.
- `roll_quality(inst) -> float` 0..1 within rarity variance band; `is_perfect_roll` at top of band (`RARITY_CONFIG.variance`, base stats × multiplier).
- `compare(a, b) -> Dictionary` stat deltas; `best_in_deck_twin(inst, deck)`; `is_upgrade(inst, deck)`.
- Tests: `tests/test_deck_insights.gd` registered in `tests/runner.gd`.

Shared context:
- Inventory UI: `scenes/ui/InventoryScene.gd` (1103 lines, `max-file-lines` debt — put new code in `scenes/ui/inventory/` modules, not here). Opened via `SceneManager.open_menu_hub("deck")` (`MenuHubScene.gd`, `hub_mode`). Tiles: `inventory/CardTile.gd`, reused via `inventory/TileCache.gd`. Craft/Items tabs: `CraftPanel.gd`, `ItemsPanel.gd`. Bag logic: `game_logic/inventory/BagOps.gd`. Auto-fill: `game_logic/DeckAutoFill.gd`.
- Card instances: `owned_cards: Array[Dictionary]` (uid, template_id, rarity, attack, health, cost, kills, custom_name…; `game_logic/CardInstanceUtil.gd`). Deck = `player_deck` uids + `loadouts`. Stats roll per rarity: `IsoConst.RARITY_CONFIG` (multiplier/variance), `CardDropUtil.roll_stats`.
- Current deck editing uses `_working_deck` committed by Save Deck; drag uses `_DRAG_KIND = "inv_card"` + `_drop_into_deck/_drop_into_collection`. `DragScroll` autoload already lets horizontal card drags through.
- Rules: UI sizes as viewport fractions, `UiUtil` factories, preload not class_name, explicit types, gdlint (120 cols), headless import + `scripts/unsafe-hits.sh` + `godot --headless --path . -s tests/runner.gd` after edits. Mobile parity: every drag has a tap equivalent.

## Plan

Pure statics in `game_logic/inventory/DeckInsights.gd` + unit suite; templates injectable for tests.

## Changes Made

- New `game_logic/inventory/DeckInsights.gd`: mana curve, dominant branch, archetype, deck name, crest, synergy pairs, roll quality / perfect roll, compare, power score, replace target, is_upgrade.
- New `tests/unit/test_deck_insights.gd` (7 tests).

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: new Deck Table section + DeckInsights table.
