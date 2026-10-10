# Professions — Alchemy, Cooking, Crafting (GID-182)

## Key Features

- Three levelled professions: **Alchemy** (potions), **Cooking** (foods), **Crafting** (gear, TID-765).
- Materials come from gathering nodes (herb / ore / fish, TID-760) and enemy drops (meat / hide / core, TID-761). Garden plants also count as recipe inputs.
- Each profession levels 1–50 by crafting. A recipe has a `skill_req`; its XP falls off as you outlevel it (WoW-style orange → yellow → green → grey bands).

## How It Works

### ProfessionDefs (`game_logic/professions/ProfessionDefs.gd`)

Pure static tables (no autoloads; safe on chunk-gen worker threads). It is the single source of truth.

| Table / function | Purpose |
|---|---|
| `PROFESSIONS` | id → `{display_name, color, station}` (`alchemy_table`, `cooking_fire`, `workbench`) |
| `MATERIALS` | id → `{display_name, sell_value, source, description}`; `source` ∈ `SOURCES` (herb, ore, fish, meat, hide, core) |
| `RECIPES` | id → `{profession, display_name, skill_req, inputs {id: n}, output {kind, id, count}, xp}` |
| `xp_for_level(lv)` / `level_for_xp(xp)` | Total XP to reach a level: `n·XP_BASE + XP_STEP·n(n−1)/2` with n = lv−1, capped at `MAX_LEVEL` 50 |
| `band(recipe, lv)` / `recipe_xp(recipe, lv)` | Gap = lv − skill_req: <0 locked, <5 orange, <10 yellow (full XP), <15 green (half), else grey (0). Colours in `BAND_COLORS` |
| `is_input(id)` / `input_name(id)` | A material or a `GardenDefs.PLANTS` id |
| `output_valid(output)` | `food` → `HeroVitality.FOODS`, `potion` → `GardenDefs.POTIONS` (`gear` lands with TID-765) |

The starter recipes are Healing Draught and Clarity Brew (alchemy), and Travel Bread and Roast Fowl (cooking).

### Save (`autoloads/save_manager/SaveProfessions.gd` → `SaveManager.professions`)

The fields live on SaveManager (`PERSISTED_FIELDS`, migration v49): `profession_xp` (profession → xp) and `materials` (material → count). `new_game()` resets both.

| API | Notes |
|---|---|
| `xp(prof)` / `level(prof)` | Level derived from XP, never stored |
| `count(id)` | Material count, or the garden plant count for a plant id |
| `add_material(id, n)` / `remove_material(id, n)` | Unknown ids are ignored; an emptied stack is erased |
| `craft_block(recipe)` | `""` or `unknown` / `unsupported` / `skill` / `inputs` |
| `craft(recipe)` | Consumes inputs (plants via `garden.remove_plants`), grants food → `foods`, potion → `garden.add_potions`, adds XP. Returns `{ok, reason, id, count, xp, level}`; `level` is the new level on a level-up, else 0 |

Signals: `GameBus.profession_level_up(profession, level)` on a level-up, and `inventory_changed` after a craft or a material gain.

## Integrations

- The garden (`GardenDefs`): plants are inputs. Potions share `SaveManager.potions` with the battle quick slots.
- Foods (`HeroVitality.FOODS`): crafted foods share `SaveManager.foods` with the world quick use.
- Planned: gathering nodes (TID-760), enemy drops (TID-761), station panel (TID-762), cooking buffs (TID-763), alchemy migration (TID-764), gear (TID-765), trainers + Character tab (TID-766).

## Asset Requirements

None yet. The station and gathering-node sprites come with TID-760 / TID-762.

## Tests

`tests/unit/test_professions.gd` checks that the tables are valid, the XP curve round-trips and the bands behave, and covers the craft flow (inputs, outputs, refusals, level-up) and the v49 migration.

## Stations & panel (GID-182 / TID-762)

- **Stations** are the cooking fire (`cooking_fire`), alchemy table (`alchemy_table`) and workbench (`workbench`) kinds. Each station's profession comes from `ProfessionDefs.PROFESSIONS` through `StationSites.profession_for(kind)`, never a second list.
- **Placement** (`game_logic/professions/StationSites.gd`, pure): `SITES` rows `{id, kind, town, tile}`. Town rows (`madrian`: cooking fire, alchemy table, workbench in the square, clear of the fountain) use town-local tiles, translated by `RealmLayout.to_world_tile()`. Home rows (`town` = "") use player-home interior tiles. `test_crafting_stations` checks each tile is open ground, clear of entities, the set pieces and the home fixtures.
- **Entity** `scenes/world/entities/CraftingStation.gd`: a `CampfireVisual` fire, or a plank table in the profession colour, with a name tag. Static scenery: not saved, not synced, no collision.
- **Module** `scenes/world/modules/CraftingStations.gd` (`crafting_stations`): `spawn_overworld()` (on "main") and `spawn_home()` place the nodes into `WorldScene._crafting_station_nodes`; `show_panel(station)` opens the panel. Nodes are cleared and respawned on each spawn.
- **Interaction**: `crafting_station` in `WorldScene.INTERACT_PRIORITY`, after `garden_plot` and before the hostiles. Prompt verb `CRAFT`. Reached by the HUD interact button, so touch and keyboard share it. Not gated on learned abilities yet (TID-766).
- **Panel** `scenes/ui/ProfessionPanel.gd` (BaseOverlay): opened with `crafting_stations.show_panel(node)`, or directly with `ProfessionPanel.new()` then `setup(profession, save_manager)` and `add_child`. It shows the level and XP bar, then each recipe in its band colour (grey and disabled when the skill or inputs are missing), with inputs owned/needed and Craft x1 / Craft x All. `craft_recipe(recipe_id, all) -> int` drives `SaveProfessions.craft()` and reports on the HUD. Esc or Close dismisses it.
- **Not yet**: the Cooking/Alchemy/Crafting unlocks (TID-766), the wilderness camp fires as cooking fires, and the old potion panel in `CraftPanel.gd` (TID-764 moves it).
- **Asset note**: the stations are procedural (no sprites). The fire reuses `CampfireVisual`.
