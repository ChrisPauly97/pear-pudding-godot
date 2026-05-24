# TID-104: Crafting Screen UI

**Goal:** GID-028
**Type:** agent
**Status:** done
**Depends On:** TID-101, TID-103

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players need a place to browse available crafting recipes and spend essence to create cards. This task adds a "Craft" tab to InventoryScene (alongside the existing Cards and Weapons tabs) that lists all craftable recipes grouped by template, shows the essence cost, and has a Craft button that produces a fresh stat-rolled instance.

## Research Notes

**Entry point**: InventoryScene already has a tab bar (`_tab_cards_btn`, `_tab_weapons_btn`). Add a third tab: `_tab_craft_btn` with text "Craft". The tab switches the visible panel to a new `_craft_panel: Control`.

**Craft panel layout**:
- Top: essence balance label ("Essence: X") — updates via `GameBus.essence_changed` signal
- Scrollable list of recipes grouped by template name
- Per recipe row: card name, rarity badge (coloured), essence cost, "Craft" button
- "Craft" button disabled when `SaveManager.essence < recipe.essence_cost`
- After crafting: show brief "+1 [R] Ghost added to collection" toast or inline message, refresh essence label

**`CraftingRegistry`** (TID-103): `get_all_recipes()` returns all `CraftingRecipe` resources. Sort by template name then rarity tier order (common < rare < epic < legendary).

**Craft action**:
1. Check `SaveManager.essence >= recipe.essence_cost`
2. Call `CardDropUtil.roll_stats(recipe.template_id, recipe.rarity)` for fresh stats
3. Call `SaveManager.add_card_instance(recipe.template_id, recipe.rarity, attack, health, cost)`
4. `SaveManager.essence -= recipe.essence_cost` — add a `spend_essence(amount: int) -> bool` helper to SaveManager that returns false if insufficient
5. Refresh the panel

**`SaveManager.spend_essence(amount: int) -> bool`** — new helper:
```gdscript
func spend_essence(amount: int) -> bool:
    if essence < amount:
        return false
    essence -= amount
    GameBus.essence_changed.emit(essence)
    _dirty = true
    return true
```

**Scene file**: `scenes/ui/InventoryScene.tscn` already exists and InventoryScene.gd drives it entirely in code — no `.tscn` changes needed; all new UI nodes are added in `_build_ui()`.

**Mobile/desktop parity**: Craft button must be a proper `Button` node so it receives touch events on Android (not just keyboard). Follow existing tab patterns.

**No new resource files** in this task (CraftingRegistry and recipes were created in TID-103).

## Plan

1. Add `spend_essence(amount) -> bool` to SaveManager.
2. Add `_tab_craft_btn`, `_craft_panel`, `_craft_list`, `_craft_essence_label` members to InventoryScene.
3. Build the craft panel in `_build_ui()` after the weapons panel.
4. Add `_on_tab_craft()`, `_refresh_craft()`, `_make_craft_row()`, `_do_craft()` methods.
5. Update existing tab handlers to hide the craft panel.

## Changes Made

- **`autoloads/SaveManager.gd`**: Added `spend_essence(amount) -> bool`.
- **`scenes/ui/InventoryScene.gd`**:
  - Preloads `CraftingRegistry` and `_CardDropUtil`.
  - Added `_tab_craft_btn`, `_craft_panel`, `_craft_list`, `_craft_essence_label` members.
  - `_build_ui()`: adds "Craft" tab button and builds a scrollable craft panel.
  - `_on_tab_craft()`: shows craft panel, hides others, calls `_refresh_craft()`.
  - `_refresh_craft()`: rebuilds recipe rows sorted by card name then rarity; shows essence balance.
  - `_make_craft_row()`: renders colour swatch, card name, rarity badge, essence cost, Craft button (disabled if insufficient essence).
  - `_do_craft()`: calls `spend_essence()`, rolls stats, creates instance, refreshes panel.

## Documentation Updates

No new agent docs needed.
