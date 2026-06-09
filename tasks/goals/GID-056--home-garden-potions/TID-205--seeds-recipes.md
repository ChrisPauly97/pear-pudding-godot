# TID-205: Seeds in Shop + Potion Recipes

**Goal:** GID-056  
**Type:** agent  
**Status:** pending  
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
