# TID-205: Seeds in Shop + Potion Recipes

**Goal:** GID-056  
**Type:** agent  
**Status:** done  
**Depends On:** TID-203

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

Seeds are sold by merchants; plants are crafted into potions via the existing crafting system. This task extends the shop with a seed sales section and adds potion recipes to the crafting registry. No new crafting screen UI needed — the existing TID-028 crafting screen will auto-display the recipes.

## Research Notes

- **Seeds in ShopScene** (**`scenes/ui/ShopScene.gd`**):
  - Existing sections: Cards (~95–106), Weapons (~109–131), Armor (~132–135), Rings (~136–139), Trinkets (~140–142) — all built with `_add_equipment_section` or `_make_card_row` pattern
  - Cite lines **95–142** for the section-building pattern: each section calls `_make_section_header("— Name —")` then builds rows with `_make_*_row()`
  - Add new **Seeds section** after Trinkets (after line 142):
    - `_shop_list.add_child(_make_section_header("— Seeds —"))`
    - Loop through seed types (via GardenDefs.SEEDS dict):
      - For each seed (sunpetal, moonroot, embercap), build a row: `_make_seed_row(seed_id, seed_data, SEED_PRICE, coins)`
      - Cite **lines 164–188** `_make_equipment_row()` as the template — label + price + button
    - Implement `_make_seed_row()` similar to `_make_equipment_row()`: display name, price, "Buy" button
      - Price constant: `const SEED_PRICE: int = 30`
    - Implement `_on_buy_seed(seed_id: String, price: int)` — cite **line 312** `_on_buy_equipment()` for coin deduction pattern:
      - `if sm.coins < price: return`
      - `sm.add_coins(-price)` — cite line 299 example
      - `sm.add_seeds(seed_id, 1)` — new SaveManager method from TID-203
      - `_refresh()`
  - Cite **line 316–318** for the button signal connection pattern

- **Potion recipes in CraftingRegistry** (**`autoloads/CraftingRegistry.gd`**):
  - **Real structure check:** The existing registry (lines 1–46) loads CraftingRecipe resources. Each recipe is a CraftingRecipe instance (line 4 `const CraftingRecipe = preload(...)`) with fields: `template_id`, `rarity`, `essence_cost` (cite **`data/CraftingRecipe.gd`** lines 1–6).
  - **Current constraint:** recipes are **per-card (template_id) × rarity**, using essence only. TID-028 (GID-028) added card-to-card-rarity crafting. Potion recipes are **plant × plant → potion**, requiring a new ingredient type beyond essence.
  - **Design decision:** Rather than create a `PotionRecipe` resource class and CraftingRegistry v2, **add potion recipes as plain const dicts in GardenDefs** (alongside SEEDS/PLANTS/POTIONS defs from TID-203), keyed by potion_id:
    - `POTION_RECIPES: Dictionary` → `potion_id` → `{display_name, essence_cost: int, ingredients: Dictionary {plant_id: int count}}`
    - Example:
      - `"healing_draught"` → `{display_name: "Healing Draught", essence_cost: 5, ingredients: {"sunpetal_plant": 2}}`
      - `"clarity_brew"` → `{display_name: "Clarity Brew", essence_cost: 5, ingredients: {"moonroot_plant": 2}}`
      - `"ember_tonic"` → `{display_name: "Ember Tonic", essence_cost: 5, ingredients: {"embercap_plant": 2}}`
  - **CraftingRegistry extension:** Add a static method `get_potion_recipes()` that returns a copy of GardenDefs.POTION_RECIPES. This **does not modify the card-crafting logic** — it's a new parallel path in the crafting screen.
  - **Rationale:** Potion recipes are a new consumable category, distinct from card upgrading. Keeping them in GardenDefs (not as CraftingRecipe resources) avoids bloating the registry and keeps all garden data in one place. The crafting screen (TID-028) can iterate both `CraftingRegistry.get_all_recipes()` (cards) and `GardenDefs.POTION_RECIPES` (potions) separately.

- **Crafting screen integration** (**`scenes/ui/CraftingScene.gd`** or equivalent):
  - Find the existing crafting UI script by searching `scenes/ui/` for "craft" or "Craft" (grep if needed)
  - Verify it builds recipe rows from `CraftingRegistry.get_all_recipes()`
  - Extend it to also iterate `GardenDefs.POTION_RECIPES` and add a "Potions" section
  - For each potion recipe:
    - Check if player owns sufficient plants via `SaveManager.plants[ingredient_id] >= count`
    - Build a row: potion name, ingredients list (e.g. "2× Sunpetal Plant"), essence cost, "Craft" button
    - On "Craft" button press:
      - Verify sufficient plants and essence via `SaveManager.remove_plants()` and `SaveManager.spend_essence()`
      - Call `SaveManager.add_potions(potion_id, 1)` (new method from TID-203)
      - Emit `GameBus.potion_crafted(potion_id)` for toast "Crafted Healing Draught"
      - Refresh the UI
  - **UI layout:** Reuse the existing row pattern from TID-028: HBox with ingredients label, essence cost, button
  - Cite the real row-building function name and line numbers once you locate the crafting screen

- **GameBus signal** (**`autoloads/GameBus.gd`**):
  - Add `signal potion_crafted(potion_id: String)` — used for toast notification

- **Headless tests** (**`tests/potion_recipes_test.gd`**):
  - Test recipe consumption: plant inventory reduced by recipe ingredient count
  - Test essence spending: essence reduced by recipe essence_cost
  - Test insufficient ingredients: craft attempt rejected if plant count < required
  - Test insufficient essence: craft attempt rejected if essence < cost
  - Test SaveManager round-trip: potion inventories persist

## Plan

1. Add `POTION_RECIPES` dict to `game_logic/GardenDefs.gd` (three recipes with plant ingredients + essence cost).
2. Add `get_potion_recipes()` static method to `autoloads/CraftingRegistry.gd`.
3. Add `signal potion_crafted(potion_id: String)` to `autoloads/GameBus.gd`.
4. Add Seeds section to `scenes/ui/ShopScene.gd`: `_make_seed_row()` and `_on_buy_seed()`.
5. Extend `_refresh_craft()` in `scenes/ui/InventoryScene.gd` to show a "— Potions —" section after card recipes, with `_make_potion_craft_row()` and `_do_craft_potion()`.
6. Write tests in `tests/unit/test_potion_recipes.gd` and register in `tests/runner.gd`.

## Changes Made

- **`game_logic/GardenDefs.gd`**: Added `POTION_RECIPES` dict with three recipes (healing_draught → 2 sunpetal_plant + 5e, clarity_brew → 2 moonroot_plant + 5e, ember_tonic → 2 embercap_plant + 5e).
- **`autoloads/CraftingRegistry.gd`**: Added `GardenDefs` preload and `get_potion_recipes() -> Dictionary` static method.
- **`autoloads/GameBus.gd`**: Added `signal potion_crafted(potion_id: String)`.
- **`scenes/ui/ShopScene.gd`**: Added `GardenDefs` preload, `SEED_PRICE = 30` constant, Seeds section in `_refresh()` after Trinkets, `_make_seed_row()` and `_on_buy_seed()` methods.
- **`scenes/ui/InventoryScene.gd`**: Added `GardenDefs` preload; extended `_refresh_craft()` to append a "— Potions —" section after card recipes; added `_make_potion_craft_row()` and `_do_craft_potion()` methods (with safe rollback if essence spend fails after plants removed).
- **`tests/unit/test_potion_recipes.gd`** (new): 27 tests covering POTION_RECIPES data integrity, plant consumption, essence spending, potion inventory accumulation, and CraftingRegistry round-trip.
- **`tests/unit/test_potion_recipes.gd.uid`** (new): UID sidecar.
- **`tests/runner.gd`**: Registered `test_potion_recipes` suite.

## Documentation Updates

No agent docs created yet — full garden system doc will be written after TID-206 completes the feature (per TID-203 plan note).
