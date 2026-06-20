# Home Garden & Potion Brewing

## Key Features

- Three garden plots in the player home interior grow seeds into harvestable plants over 2–3 in-game days.
- Growth advances on every day rollover via `days_elapsed`, so plants ripen even while the player is away.
- Three seed types (sunpetal, moonroot, embercap) produce three plant types and three craftable potions.
- Seeds are purchased from merchants (30 coins each); plants are crafted into potions via the Inventory crafting tab.
- In battle, one potion may be consumed per battle from a HUD button; three effects are available (heal, draw, mana).

## How It Works

### GardenDefs (`game_logic/GardenDefs.gd`)

Static-only class (extends Object). Source of truth for all garden constants.

**`SEEDS: Dictionary`** — seed_id → `{display_name, growth_days, yield, plant_id}`

| seed_id | growth_days | yield | plant_id |
|---|---|---|---|
| `sunpetal` | 2 | 1 | `sunpetal_plant` |
| `moonroot` | 3 | 2 | `moonroot_plant` |
| `embercap` | 2 | 2 | `embercap_plant` |

**`PLANTS: Dictionary`** — plant_id → `{display_name, sell_value}`

**`POTIONS: Dictionary`** — potion_id → `{display_name, essence_cost}` (static metadata; essence cost is 0 here since cost lives in POTION_RECIPES)

**`POTION_RECIPES: Dictionary`** — potion_id → `{display_name, essence_cost: 5, ingredients: {plant_id: count}}`

| potion_id | ingredient | effect |
|---|---|---|
| `healing_draught` | 2× sunpetal_plant | +8 hero HP (capped at max) |
| `clarity_brew` | 2× moonroot_plant | draw 2 cards |
| `ember_tonic` | 2× embercap_plant | +1 mana this turn |

**`growth_stage(planted_day, growth_days, current_days_elapsed) -> int`**

Returns 1–3 (never 0 — callers must check plot emptiness first):
- `age = current_days_elapsed - planted_day`
- If `age >= growth_days` → 3 (mature)
- Else → `1 + age / max(1, growth_days - 1)` (early or mid growth)

### SaveManager Fields (save version 33)

| Field | Type | Default | Purpose |
|---|---|---|---|
| `garden_plots` | Array[Dictionary] | `[{}, {}, {}]` | Per-plot state: `{seed_id, planted_day}` or `{}` when empty |
| `seeds` | Dictionary | `{}` | seed_id → count owned |
| `plants` | Dictionary | `{}` | plant_id → count owned |
| `potions` | Dictionary | `{}` | potion_id → count owned |

Migration added in `_migrate_v32_to_v33` — backfills all four fields on old saves.

**Public API:**

```gdscript
SaveManager.set_plot(plot_idx, seed_id, planted_day)   # plant a seed
SaveManager.clear_plot(plot_idx)                        # empty after harvest
SaveManager.add_seeds(seed_id, count)
SaveManager.remove_seeds(seed_id, count) -> bool        # false if insufficient
SaveManager.add_plants(plant_id, count)
SaveManager.remove_plants(plant_id, count) -> bool
SaveManager.add_potions(potion_id, count)
SaveManager.remove_potions(potion_id, count) -> bool
SaveManager.get_plot_growth_stage(plot_idx) -> int      # 0 = empty, 1–3 = growing/mature
```

`get_plot_growth_stage` returns 0 for empty plots and delegates to `GardenDefs.growth_stage` for planted ones.

### GardenPlot Entity (`scenes/world/entities/GardenPlot.gd`)

`extends Node3D`. Three instances are spawned by WorldScene when the `player_home` map loads.

- `init_from_data({plot_idx: int})` links the node to the correct save slot.
- Visual: a brown soil trough (`MeshInstance3D`, 0.9×0.1×0.9 units) plus a coloured plant box that scales across stages. Stage 3 adds a yellow flower box on top.
- `refresh_visual()` reads the current stage from `SaveManager.get_plot_growth_stage(plot_idx)` and rebuilds the plant mesh only when the stage changes.
- Connects to `GameBus.plant_harvested` for auto-refresh after harvest.
- A `Label3D` above the plot shows the seed name and stage ("Sunpetal (ready!)", etc.).

**Spawn positions** (tile coordinates in `player_home` map):

| plot_idx | tile (tx, tz) |
|---|---|
| 0 | (52, 54) |
| 1 | (55, 54) |
| 2 | (58, 54) |

### WorldScene Interaction (`scenes/world/WorldScene.gd`)

`_spawn_player_home_garden()` is called in the `player_home` map branch (after `_spawn_player_home_trophies()`). It creates three GardenPlot nodes and appends them to `_garden_plot_nodes: Array[Node3D]`.

`_check_interactions()` and `_handle_interact()` detect the nearest plot within `IsoConst.INTERACT_RANGE` via `_find_nearby_garden_plot()`.

`_show_garden_plot_panel(plot)` presents stage-appropriate UI (all sized viewport-relative per CLAUDE.md):
- **Stage 0 (empty):** seed picker listing owned seeds with counts; "Plant" button calls `SaveManager.set_plot` + `remove_seeds`, emits `GameBus.plant_harvested(plot_idx, 0)` for a toast.
- **Stage 1–2 (growing):** info panel "Growing — come back later."
- **Stage 3 (mature):** "Harvest" button calls `SaveManager.add_plants(plant_id, yield)`, `clear_plot`, emits `GameBus.plant_harvested(plot_idx, yield)` for a toast.

### Seeds in ShopScene (`scenes/ui/ShopScene.gd`)

A "— Seeds —" section is appended after Trinkets in `_refresh()`. `_make_seed_row()` shows the seed name, owned count, and a "Buy" button (30 coins, disabled if insufficient funds). `_on_buy_seed()` deducts coins and calls `SaveManager.add_seeds(seed_id, 1)`.

### Potion Crafting in InventoryScene (`scenes/ui/InventoryScene.gd`)

`_refresh_craft()` appends a "— Potions —" section after card recipes, iterating `GardenDefs.POTION_RECIPES`. `_make_potion_craft_row()` shows ingredient requirements (plant counts + essence), highlighting shortfalls in red. `_do_craft_potion()` removes plants, spends essence (with rollback if essence is insufficient), calls `SaveManager.add_potions(potion_id, 1)`, and emits `GameBus.potion_crafted(potion_id)`.

### Potion Use in BattleScene (`scenes/battle/BattleScene.gd`)

- `_potion_btn: Button` added to `$SidePanel` in `_add_potion_button()`. Visible only when the player owns at least one potion.
- `_used_potion_this_battle: bool` is a local battle flag (not persisted — resuming a battle gives a fresh use).
- `_refresh_potion_button()` disables the button when: already used this battle, no potions owned, or it is the enemy's turn. Called on `_ready()`, after effect application, and in `_on_turn_ended()`.
- `_show_potion_picker()` opens a CanvasLayer overlay listing owned potions with Use/Cancel.
- `_apply_potion_effect(potion_id)` applies the effect, decrements the potion count, sets `_used_potion_this_battle = true`, emits `GameBus.potion_used(potion_id)`:
  - `healing_draught` — `hero.health = mini(hero.health + 8, hero.max_health)`
  - `clarity_brew` — calls `player_state.draw_card()` twice
  - `ember_tonic` — `hero.mana = mini(hero.mana + 1, hero.max_mana)` (resets at next turn normally)
- AI never uses potions (v1 constraint).

## Integrations with Other Features

- **Player home (GID-046):** Garden plots are spawned exclusively in the `player_home` interior map. Requires `home_owned = true` to be reachable (GID-046 gate).
- **Day/night cycle:** `SaveManager.days_elapsed` drives growth. Incremented by `WorldScene` at midnight. Growth stages update whenever the player re-enters the home — no real-time tick needed.
- **Bounty system:** Uses the same `days_elapsed` counter as the garden (no coupling — purely shared save field).
- **Crafting system (GID-028):** The existing InventoryScene crafting tab gains a Potions section; the card-recipe path is unchanged. `CraftingRegistry.get_potion_recipes()` delegates to `GardenDefs.POTION_RECIPES`.
- **Battle system:** Potion effects integrate with `HeroState.health`/`mana` and `PlayerState.draw_card()`. Float labels and `_refresh_all()` follow the same pattern as other battle events.
- **GameBus signals:** Four new signals added:

| Signal | Emitted by | Used for |
|---|---|---|
| `plant_harvested(plot_idx, plants_count)` | WorldScene on harvest; plot_idx set, count 0 on plant | GardenPlot auto-refresh; toast |
| `inventory_changed` | SaveManager.add_seeds | General inventory toast hook |
| `potion_crafted(potion_id)` | InventoryScene._do_craft_potion | Toast notification |
| `potion_used(potion_id)` | BattleScene._apply_potion_effect | Battle log / toast |

## Asset Requirements

No external art assets. All visuals are programmatic `StandardMaterial3D` coloured boxes:
- Soil trough: `Color(0.45, 0.28, 0.10)`
- Stage 1 (sprout): `Color(0.35, 0.70, 0.20)`
- Stage 2 (growing): `Color(0.20, 0.65, 0.15)`
- Stage 3 (mature stalk): `Color(0.10, 0.55, 0.10)`
- Stage 3 flower: `Color(0.95, 0.85, 0.10)`

Materials are cached as `static var` on `GardenPlot` to avoid re-allocation per instance.
