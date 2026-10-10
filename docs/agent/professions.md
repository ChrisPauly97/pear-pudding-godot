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

### Gathering (TID-760)

Gathering nodes are the herb, ore and fish sources of `MATERIALS`. They are placed by chunk generation and harvested in the world.

| Piece | Where | Notes |
|---|---|---|
| `GatherDefs` (`game_logic/professions/GatherDefs.gd`) | Pure tables and `plan_chunk(chunk_seed, biome, water_near)` | Returns `[{kind, material, pick}]`, deterministic per chunk seed (worker-thread safe). `pick % grass_tiles.size()` gives the tile. |
| Yields | `GatherDefs.YIELDS` (biome → kind → materials) | Herbs in grassland, forest and desert; ore in scorched lands and mountains; fishing spots only in grassland or forest with water beside the chunk (`Rivers.touches_chunk` / `Coast.touches_chunk`). Bog moss is not yet planted. |
| Profession | `GatherDefs.profession_for(material)` | Herb → Alchemy (wild grain → Cooking), ore → Crafting, fish → Cooking. |
| Node data | `ChunkData.gather_nodes` `{id, x, z, kind, material}` | Written by `InfiniteWorldGen._gen_entities` (`g_<cx>_<cz>_<i>`). Towns are excluded through `grass_tiles`. |
| Entity | `scenes/world/entities/GatherNode.gd` (+ `.tscn`) | Placeholder coloured mound. `interact()` harvests: adds 1 material, grants the node's XP through `save_manager.professions.add_xp`, and shows a HUD message. |
| Respawn | `GatherNode` (session-only) | A harvest hides the node for `respawn_seconds` (real time: herb 240 s, ore 360 s, fish 180 s). Nothing is saved, and the node comes back when its chunk reloads. |
| Registry | `scenes/world/modules/GatherNodes.gd` (`WorldScene.gather_nodes`) | `register(id, node)` from ChunkRenderer; `find_nearby(px, pz, r)` skips depleted and freed nodes. |
| Interact | `WorldScene.INTERACT_PRIORITY` entry `gather_node` (after `riddle_spot`, before `mana_well`) | Prompt verb `GATHER`. It runs through `_try_simple_interaction`, so touch uses the same HUD interact button. |
| XP | `SaveProfessions.add_xp(profession, n)` | Raw XP grant. Returns the new level on a level-up and emits `GameBus.profession_level_up`. |

Not done yet: co-op harvests are not broadcast (each peer can harvest the same node), and gathering takes no hold-time.

## Integrations

- The garden (`GardenDefs`): plants are inputs. Potions share `SaveManager.potions` with the battle quick slots.
- Foods (`HeroVitality.FOODS`): crafted foods share `SaveManager.foods` with the world quick use.
- Gathering nodes (TID-760) are described above. Planned: enemy drops (TID-761), station panel (TID-762), cooking buffs (TID-763), alchemy migration (TID-764), gear (TID-765), trainers + Character tab (TID-766).

## Asset Requirements

None yet. The station and gathering-node sprites come with TID-760 / TID-762.

## Tests

`tests/unit/test_professions.gd` checks that the tables are valid, the XP curve round-trips and the bands behave, and covers the craft flow (inputs, outputs, refusals, level-up) and the v49 migration. `tests/unit/test_gathering.gd` covers gathering: deterministic planning per chunk seed, biome and water gating, yields that are valid materials of the matching source, `add_xp`, and the harvest-then-depleted cycle.
