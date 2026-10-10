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
| `output_valid(output)` | `food` → `HeroVitality.FOODS`, `potion` → `GardenDefs.POTIONS`, `gear` → `WeaponRegistry.has_weapon` |

The starter recipes are Healing Draught and Clarity Brew (alchemy), and Travel Bread and Roast Fowl (cooking).

### Save (`autoloads/save_manager/SaveProfessions.gd` → `SaveManager.professions`)

The fields live on SaveManager (`PERSISTED_FIELDS`, migration v49): `profession_xp` (profession → xp) and `materials` (material → count). `new_game()` resets both.

| API | Notes |
|---|---|
| `xp(prof)` / `level(prof)` | Level derived from XP, never stored |
| `count(id)` | Material count, or the garden plant count for a plant id |
| `add_material(id, n)` / `remove_material(id, n)` | Unknown ids are ignored; an emptied stack is erased |
| `craft_block(recipe)` | `""` or `unknown` / `unsupported` (output names no real item) / `skill` / `inputs` |
| `craft(recipe, rng = null)` | Consumes inputs (plants via `garden.remove_plants`), grants food → `foods`, potion → `garden.add_potions`, gear → `gear.grant` (TID-765), adds XP. Returns `{ok, reason, id, count, xp, level, roll, grant}`; `level` is the new level on a level-up, else 0; `roll` / `grant` are set for gear only |

Signals: `GameBus.profession_level_up(profession, level)` on a level-up, and `inventory_changed` after a craft or a material gain.

### Enemy drops (`game_logic/professions/MaterialDrops.gd`, TID-761)

Pure static data and a seeded roll (no autoloads). Beasts drop meat and hide, magical foes drop cores.

| Table / function | Purpose |
|---|---|
| `FAMILY_BY_ENEMY` | Enemy type id → family (`beast` or `magical`). EnemyRegistry has no family field, so it is listed here. Unlisted types (undead, humanoids, bosses, rivals, training dummy) drop nothing |
| `TABLES` | Family → entries `{material, chance, min, max}`: `game_meat` and `rough_hide` for beasts, `arcane_core` for magical |
| `roll(enemy_type, tier, rng, allowed)` | `{material: count}`. Tier 1..4 (clamped) adds `CHANCE_PER_TIER` (0.1) per tier above 1 to each chance, and one piece per two tiers above 1 |
| `roll_into(bag, enemy_data, enemy_type, tier, rng)` | Adds one fight's roll to a bag. `allowed` comes from `HeroVitality.carries_over`, so practice fights and friendly duels (`duel_npc_id` set) drop nothing |
| `describe(drops)` | Toast text, e.g. `+2 Game Meat, +1 Rough Hide` |

`BattleVictory._on_battle_won` rolls the main kill at the fight's drop tier (boss = 4, night and gambit bonuses included), and each joined enemy at its own tier (`_reward_joined_enemies`). The bag is banked with `save_manager.professions.add_material` and the text rides the in-world reward toast (or a HUD message on the result card path). Spire, siege and mimic wins return before the roll, so they drop nothing. Each peer rolls its own materials locally, with no need/greed.

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

## Crafting (gear, TID-765)

- **Recipes**: the `# Crafting (TID-765)` block at the end of `ProfessionDefs.RECIPES`. Each has `output {kind: "gear", id, count: 1}` naming a real `WeaponRegistry` item. Leather (rough hide): cap, vest, pauldrons, travel boots. Metal (iron ore, plus copper for the axe): iron helm, pauldrons, greaves, shield, berserker axe. `skill_req` runs 1 to 15.
- **Item level** is the recipe's `skill_req`, so the item level tracks the recipe's difficulty.
- **Roll** (`game_logic/professions/CraftedGear.gd`, pure): crafting skill → source tier (`SKILL_TIERS`: 1 to 14 → tier 1, 15 to 29 → 2, 30 to 44 → 3, 45+ → 4). The tier's `GearRolls.TIER_WEIGHTS` row is used with legendary folded into epic, so crafted gear caps at epic. Legendary stays drop-only. `roll(skill, item_level, rng)` returns `{rarity, ilvl}`.
- **Grant**: `SaveProfessions.craft` calls `save.gear.grant(id, roll)`, the same path as chest and battle drops. A duplicate keeps the better roll (`upgraded` / `kept`). `GameBus.equipment_dropped` fires on `new` or `upgraded`, as in `ChestLoot`. `GameBus.equipment_changed` fires on an upgrade of an equipped piece, which co-op appearance picks up. No save migration: `gear_rolls` already exists.
- **Panel**: the existing `ProfessionPanel` lists gear recipes like any other recipe. The toast reads `Crafted 1 x <recipe name>.`
- **Not yet**: the Crafting unlock and trainers (TID-766).

## Tests (gear)

`tests/unit/test_gear_crafting.gd` checks that gear recipes name real equipment, that skill maps to tier in steps, that epic is the cap (seeded, 2000 rolls), that item level follows the recipe, that a craft grants the item and roll, and that a duplicate keeps the better roll (both ways).

## Cooking (GID-182 / TID-763)

- **Recipes** (`ProfessionDefs.RECIPES`, block `# Cooking (TID-763)` at the end): Trout Fillet (skill 1, 2 river trout → 2), Herb Stew (skill 3, game meat + wild grain + 2 silverleaf), Bog Pie (skill 8, 2 game meat + 2 bog moss + 2 wild grain). With the starters (Travel Bread, Roast Fowl) cooking has five recipes. Foods are `HeroVitality.FOODS` entries.
- **Foods**: the cooked foods have `price` 0, so `ShopScene` skips them (merchants still sell Travel Bread and Roast Fowl). Eating works as before: a meal heals over time, and a fight interrupts it. Heal and time are in `FOODS`.
- **Well fed** (`game_logic/professions/WellFed.gd`, pure): `ProfessionDefs.WELL_FED` maps a food to `{stat, amount, fights}`. Currently only `max_hp`: Roast Fowl +4 for 3 fights, Trout Fillet +3 for 2, Herb Stew +5 for 3, Bog Pie +8 for 4.
- **Save**: `SaveManager.well_fed` (`{food, stat, amount, fights}`, `{}` = none), PERSISTED_FIELDS default `{}`, migration v50. Eating a food with a buff replaces the current one; a plain food leaves it alone.
- **Eating** (`HeroHealth.use_quick`): sets `well_fed` and shows the buff in a HUD message. `WorldHUD.set_well_fed` shows a text line under the HP bar ("Well fed: +4 max HP, 2 fights left"), hidden when there is no buff.
- **Applying** (`BattleModifiers._apply_well_fed`, called from `_apply_equipment_effects`): an ordinary solo fight (the same test as persistent HP, `_hp_carries`, with no puzzle or scripted fight) takes one charge and adds `amount` to max HP and current HP. It runs before `_apply_persistent_hp`, so the saved HP fraction is read against the raised max. The charge is spent when the fight starts, so a lost fight also uses it.
- **Not done**: the buff is not shown in battle, and only max HP is a stat (auto-attack damage and mana regen were left out). Eating does not wait for the meal to finish, so a buff is set even if a fight interrupts the meal. The balance sim and balance bands run unbuffed (`BattleSetup.build` never goes through `BattleModifiers`).
- **Tests**: `tests/unit/test_cooking.gd` checks the recipes, the cooked foods' shop status, the WELL_FED table, the pure buff math (set, apply, expire, describe), the v50 migration and that the field is persisted.
