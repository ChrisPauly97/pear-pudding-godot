# TID-103: Crafting Recipes Data Model

**Goal:** GID-028
**Type:** agent
**Status:** done
**Depends On:** TID-097

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Crafting lets players spend essence to create a specific card at a specific rarity without needing drop luck or combines. This task defines the data model: a `CraftingRecipe` resource, a `CraftingRegistry` autoload, and the initial recipe list. Cards with `can_craft = false` are excluded. The UI is in TID-104.

## Research Notes

**`CraftingRecipe`** (`data/CraftingRecipe.gd`) — new Resource subclass:
```gdscript
@export var template_id: String = ""   # which card to craft
@export var rarity: String = "common"  # which rarity tier to produce
@export var essence_cost: int = 0      # how much essence it costs
```

**Essence cost table (suggested)**:

| Rarity | Essence cost |
|--------|-------------|
| Common | 10 |
| Rare | 30 |
| Epic | 80 |
| Legendary | 200 |

**`CraftingRegistry`** (`autoloads/CraftingRegistry.gd`) — new autoload (add to project.godot):
- Scans `data/crafting/*.tres` on first access
- Exposes:
  - `get_all_recipes() -> Array[CraftingRecipe]`
  - `get_recipes_for_template(template_id: String) -> Array[CraftingRecipe]`
  - `get_recipe(template_id: String, rarity: String) -> CraftingRecipe` (null if not found)

**Recipe files**: one `.tres` per craftable (template, rarity) pair. Only create recipes for cards where `CardData.can_craft = true`. Default `can_craft = true` on all existing cards except: the 5 existing legendary cards (`ancient_guardian`, `void_wyrm`, `iron_revenant`, `phoenix_rise`, `time_warp`) which are achievement-gated and should have `can_craft = false`. Unique cards also `can_craft = false`.

**Directory**: `data/crafting/` — create this folder. Each file is e.g. `ghost_common.tres`, `ghost_rare.tres`, `ghost_epic.tres`.

**Craft output**: crafting always produces a fresh stat-rolled instance at the requested rarity, using `CardDropUtil.roll_stats()`. Crafting does NOT guarantee max roll — it just removes RNG from the rarity tier itself.

**`.uid` sidecars**:
- `data/CraftingRecipe.gd` → `data/CraftingRecipe.gd.uid`
- `autoloads/CraftingRegistry.gd` → `autoloads/CraftingRegistry.gd.uid`
- Each `data/crafting/*.tres` → companion `.uid` sidecar

**`project.godot` autoload entry**: `CraftingRegistry` must be added to the autoloads list in `project.godot` (same pattern as `CardRegistry`).

## Plan

Rather than creating 100+ static .tres recipe files (one per template × rarity pair), generate recipes dynamically from CardRegistry. This avoids file explosion while providing the same typed API. Costs are uniform per rarity tier, stored in IsoConst.RARITY_CONFIG.

1. Add `craft_essence` (10/30/80/200) to IsoConst.RARITY_CONFIG.
2. Add `CardRegistry.is_craftable(id)` to expose `can_craft` field without duplicating it.
3. Create `data/CraftingRecipe.gd` — Resource with `template_id`, `rarity`, `essence_cost`.
4. Create `autoloads/CraftingRegistry.gd` — builds recipe instances from CardRegistry on first access, filtered by `is_craftable()`.

## Changes Made

- **`autoloads/IsoConst.gd`**: Added `craft_essence` key to each rarity tier in `RARITY_CONFIG`.
- **`autoloads/CardRegistry.gd`**: Added `is_craftable(id) -> bool` static method.
- **`data/CraftingRecipe.gd`** (new): Resource with `template_id`, `rarity`, `essence_cost` exports.
- **`autoloads/CraftingRegistry.gd`** (new): Generates `CraftingRecipe` instances dynamically from `CardRegistry` on first access. Exposes `get_all_recipes()`, `get_recipes_for_template()`, `get_recipe()`. No .tres recipe files needed — costs are rarity-uniform.

## Documentation Updates

No new agent docs needed — extends save-system.md coverage.
