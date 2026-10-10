# Professions — Alchemy, Cooking, Crafting (GID-182)

## Key Features

- **Three levelled professions**: Alchemy (potions), Cooking (foods with well-fed battle buffs) and Crafting (rolled
  gear, capped at epic). Each levels 1–50 by crafting.
- **Materials from the world**: gathering nodes (herb / ore / fish, TID-760) and enemy drops (meat / hide / core,
  TID-761). Garden plants also count as recipe inputs.
- **Stations**: a cooking fire, an alchemy table and a workbench in each stitched town square and in the player home
  (TID-762). One panel lists the profession's recipes.
- **Trainers**: the Master Artisan in Madrian teaches all three for gold (UnlockLadder, TID-766). Gathering is never
  gated; only the stations are.
- **Character screen**: a Professions block shows each profession's level, XP bar and known-recipe count (TID-766).
- **Skill gates recipes**: a recipe has a `skill_req`. Its XP falls off as you outlevel it (WoW-style orange →
  yellow → green → grey bands).

## How It Works

### ProfessionDefs (`game_logic/professions/ProfessionDefs.gd`)

Pure static tables (no autoloads; safe on chunk-gen worker threads). The single source of truth for professions,
materials and recipes.

| Table / function | Purpose |
|---|---|
| `PROFESSIONS` | id → `{display_name, color, station}`: `alchemy` / `alchemy_table`, `cooking` / `cooking_fire`, `crafting` / `workbench` |
| `MATERIALS` | id → `{display_name, sell_value, source, description}`; `source` ∈ `SOURCES` (herb, ore, fish, meat, hide, core) |
| `RECIPES` | id → `{profession, display_name, skill_req, inputs {id: n}, alt_inputs, output {kind, id, count}, xp}` |
| `WELL_FED` | food id → `{stat, amount, fights}` (see Cooking) |
| `xp_for_level(lv)` / `level_for_xp(xp)` | Total XP to reach a level: `n·XP_BASE + XP_STEP·n(n−1)/2` with n = lv−1, capped at `MAX_LEVEL` 50 |
| `band(recipe, lv)` / `recipe_xp(recipe, lv)` | Gap = lv − skill_req: <0 locked, <5 orange, <10 yellow (full XP), <15 green (half), else grey (0). Colours in `BAND_COLORS` |
| `recipes_for(prof)` / `recipes_using(input)` | Lookups used by the panel, the Character block and the Items tab |
| `is_input(id)` / `input_name(id)` | A material or a `GardenDefs.PLANTS` id |
| `output_valid(output)` | `food` → `HeroVitality.FOODS`, `potion` → `GardenDefs.POTIONS`, `gear` → `WeaponRegistry.has_weapon` |

Recipes are grouped by block at the end of `RECIPES`: starters (Healing Draught, Clarity Brew, Travel Bread, Roast
Fowl), alchemy (Ember Tonic, Stoneskin Tonic, Cleansing Salve, Mana Draught), cooking (Trout Fillet, Herb Stew, Bog
Pie) and crafting (gear from leather, iron and copper).

### Save (`autoloads/save_manager/SaveProfessions.gd` → `SaveManager.professions`)

The persisted fields live on SaveManager and are listed in `PERSISTED_FIELDS`: `profession_xp` (profession → xp,
v49), `materials` (material → count, v49) and `well_fed` (`{food, stat, amount, fights}`, `{}` = none, v50). The
learned feature ids are in `learned_abilities` (see Trainers). `new_game()` resets the profession fields.

| API | Notes |
|---|---|
| `xp(prof)` / `level(prof)` | Level derived from XP, never stored |
| `count(id)` | Material count, or the garden plant count for a plant id |
| `add_material(id, n)` / `remove_material(id, n)` | Unknown ids are ignored; an emptied stack is erased |
| `inputs_for(recipe)` | The first fully owned input set (`alt_inputs` lets a garden plant stand in for a herb) |
| `craft_block(recipe)` | `""` or `unknown` / `unsupported` (output names no real item) / `skill` / `inputs` |
| `craft(recipe, rng = null)` | Consumes inputs (plants via `garden.remove_plants`), grants food → `foods`, potion → `garden.add_potions`, gear → `gear.grant`. Adds XP. Returns `{ok, reason, id, count, xp, level, roll, grant}`; `level` is the new level on a level-up, else 0 |
| `add_xp(prof, n)` | Raw XP grant (gathering uses it). Returns the new level on a level-up |

Signals: `GameBus.profession_level_up(profession, level)` on a level-up, `GameBus.potion_crafted` for potion crafts,
and `inventory_changed` after a craft or a material gain.

### Gathering (TID-760)

Gathering nodes are the herb, ore and fish sources of `MATERIALS`, placed by chunk generation and harvested in the world.

| Piece | Where | Notes |
|---|---|---|
| `GatherDefs` (`game_logic/professions/GatherDefs.gd`) | Pure tables and `plan_chunk(chunk_seed, biome, water_near)` | Returns `[{kind, material, pick}]`, deterministic per chunk seed (worker-thread safe). `pick % grass_tiles.size()` gives the tile |
| Yields | `GatherDefs.YIELDS` (biome → kind → materials) | Herbs in grassland, forest and desert; ore in scorched lands and mountains; fishing spots only in grassland or forest with water beside the chunk (`Rivers.touches_chunk` / `Coast.touches_chunk`). Herbs `ironbark`, `starsage` and `emberwort` came with alchemy |
| Profession | `GatherDefs.profession_for(material)` | Herb → Alchemy (wild grain → Cooking), ore → Crafting, fish → Cooking |
| Node data | `ChunkData.gather_nodes` `{id, x, z, kind, material}` | Written by `InfiniteWorldGen._gen_entities` (`g_<cx>_<cz>_<i>`). Towns are excluded through `grass_tiles` |
| Entity | `scenes/world/entities/GatherNode.gd` | Placeholder coloured mound. `interact()` adds 1 material, grants the node's XP and shows a HUD message |
| Respawn | `GatherNode` (session-only) | A harvest hides the node for `respawn_seconds` (herb 240 s, ore 360 s, fish 180 s). Nothing is saved; the node returns when its chunk reloads |
| Registry | `scenes/world/modules/GatherNodes.gd` (`WorldScene.gather_nodes`) | `register(id, node)` from ChunkRenderer; `find_nearby(px, pz, r)` skips depleted and freed nodes |
| Interact | `WorldScene.INTERACT_PRIORITY` entry `gather_node` | Prompt verb `GATHER`, through `_try_simple_interaction` so touch uses the same interact button |

Not done: co-op harvests are not broadcast (each peer can harvest the same node), and gathering takes no hold-time.

### Enemy drops (TID-761)

`game_logic/professions/MaterialDrops.gd`: pure static data and a seeded roll. Beasts drop meat and hide, magical
foes drop cores.

| Table / function | Purpose |
|---|---|
| `FAMILY_BY_ENEMY` | Enemy type id → family (`beast` or `magical`). EnemyRegistry has no family field, so it is listed here. Unlisted types (undead, humanoids, bosses, rivals, training dummy) drop nothing |
| `TABLES` | Family → entries `{material, chance, min, max}`: `game_meat` and `rough_hide` for beasts, `arcane_core` for magical |
| `roll(enemy_type, tier, rng, allowed)` | `{material: count}`. Tier 1..4 (clamped) adds `CHANCE_PER_TIER` (0.1) per tier above 1 to each chance, and one piece per two tiers above 1 |
| `roll_into(bag, enemy_data, enemy_type, tier, rng)` | Adds one fight's roll to a bag. `allowed` comes from `HeroVitality.carries_over`, so practice fights and friendly duels drop nothing |
| `describe(drops)` | Toast text, e.g. `+2 Game Meat, +1 Rough Hide` |

`BattleVictory._on_battle_won` rolls the main kill at the fight's drop tier (boss = 4, night and gambit bonuses
included), and each joined enemy at its own tier (`_reward_joined_enemies`). The bag is banked with
`save_manager.professions.add_material`. Spire, siege and mimic wins return before the roll, so they drop nothing.
Each peer rolls its own materials locally, with no need/greed.

### Stations and the panel (TID-762)

- **Stations** are the `cooking_fire`, `alchemy_table` and `workbench` kinds. A station's profession comes from
  `ProfessionDefs.PROFESSIONS` through `StationSites.profession_for(kind)`, never a second list.
- **Placement** (`game_logic/professions/StationSites.gd`, pure): `SITES` rows `{id, kind, town, tile}`. Town rows
  (`madrian`: cooking fire, alchemy table, workbench in the square, clear of the fountain) use town-local tiles,
  translated by `RealmLayout.to_world_tile()`. Home rows (`town` = "") use player-home interior tiles.
  `test_crafting_stations` checks each tile is open ground, clear of entities, set pieces and home fixtures.
- **Entity** `scenes/world/entities/CraftingStation.gd`: a `CampfireVisual` fire, or a plank table in the profession
  colour, with a name tag. Static scenery: not saved, not synced, no collision.
- **Module** `scenes/world/modules/CraftingStations.gd` (`crafting_stations`): `spawn_overworld()` (on "main") and
  `spawn_home()` place the nodes into `WorldScene._crafting_station_nodes`. `show_panel(station)` opens the panel
  unless the profession is not learned (see Trainers).
- **Interaction**: `crafting_station` in `WorldScene.INTERACT_PRIORITY`, after `garden_plot` and before the hostiles.
  Prompt verb `CRAFT`. Reached by the HUD interact button, so touch and keyboard share it.
- **Panel** `scenes/ui/ProfessionPanel.gd` (BaseOverlay): the level and XP bar, then each recipe in its band colour
  (grey and disabled when the skill or inputs are missing), with inputs owned/needed and Craft x1 / Craft x All.
  `craft_recipe(recipe_id, all)` drives `SaveProfessions.craft()` and reports on the HUD. Esc or Close dismisses it.
  Headless callers use `ProfessionPanel.new()`, `setup(profession, save_manager)`, then `_build_ui()`.
- **Asset note**: the stations are procedural (no sprites). The fire reuses `CampfireVisual`.
- **Not done**: the wilderness camp fires do not act as cooking fires.

### Cooking and well-fed buffs (TID-763)

- **Recipes**: Trout Fillet (skill 1, 2 river trout → 2), Herb Stew (skill 3, game meat + wild grain + 2 silverleaf),
  Bog Pie (skill 8, 2 game meat + 2 bog moss + 2 wild grain). With the starters (Travel Bread, Roast Fowl), cooking has
  five recipes. Foods are `HeroVitality.FOODS` entries.
- **Foods**: the cooked foods have `price` 0, so `ShopScene` skips them. Merchants still sell Travel Bread and Roast
  Fowl. Eating works as before: a meal heals over time, and a fight interrupts it.
- **Well fed** (`game_logic/professions/WellFed.gd`, pure): `WELL_FED` maps a food to `{stat, amount, fights}`. Only
  `max_hp` is a stat so far: Roast Fowl +4 for 3 fights, Trout Fillet +3 for 2, Herb Stew +5 for 3, Bog Pie +8 for 4.
- **Eating** (`HeroHealth.use_quick`) sets `well_fed` and shows the buff in a HUD message. `WorldHUD.set_well_fed`
  shows a line under the HP bar ("Well fed: +4 max HP, 2 fights left"), hidden when there is no buff. Eating a food
  with a buff replaces the current one; a plain food leaves it alone.
- **Applying** (`BattleModifiers._apply_well_fed`): an ordinary solo fight (the same test as persistent HP) takes one
  charge and adds `amount` to max HP and current HP. It runs before `_apply_persistent_hp`. The charge is spent when
  the fight starts, so a lost fight also uses it.
- **Not done**: the buff is not shown in battle; auto-attack damage and mana regen are not stats yet. Eating does not
  wait for the meal, so a buff is set even if a fight interrupts the meal. The balance sim and balance bands run unbuffed.

### Alchemy (TID-764)

Alchemy owns every potion. The six recipes (Healing Draught, Ember Tonic, Stoneskin Tonic, Clarity Brew, Cleansing
Salve, Mana Draught) live in `ProfessionDefs.RECIPES` with no essence cost. The full table and the battle effects are
in `home-garden-potions.md` → **Alchemy Brewing**.

- Recipes may take a garden plant instead of the herb through `alt_inputs`.
- Pure potion effects are in `game_logic/battle/PotionEffects.gd`, shared by the local drink and the PvP host.
- Potion crafts emit `GameBus.potion_crafted`. The Inventory Craft tab no longer lists potions; they are brewed here.

### Crafting gear (TID-765)

- **Recipes**: the `# Crafting (TID-765)` block. Each has `output {kind: "gear", id, count: 1}` naming a real
  `WeaponRegistry` item. Leather (rough hide): cap, vest, pauldrons, travel boots. Metal (iron ore, plus copper for the
  axe): iron helm, pauldrons, greaves, shield, berserker axe. `skill_req` runs 1 to 15.
- **Item level** is the recipe's `skill_req`.
- **Roll** (`game_logic/professions/CraftedGear.gd`, pure): crafting skill → source tier (`SKILL_TIERS`: 1 to 14 →
  tier 1, 15 to 29 → 2, 30 to 44 → 3, 45+ → 4). The tier's `GearRolls.TIER_WEIGHTS` row is used with legendary folded
  into epic, so crafted gear caps at epic. Legendary stays drop-only. `roll(skill, item_level, rng)` returns
  `{rarity, ilvl}`.
- **Grant**: `SaveProfessions.craft` calls `save.gear.grant(id, roll)`, the same path as chest and battle drops. A
  duplicate keeps the better roll. `GameBus.equipment_dropped` fires on `new` or `upgraded`; `GameBus.equipment_changed`
  fires on an upgrade of an equipped piece, which co-op appearance picks up. No migration: `gear_rolls` already existed.

### Trainers, unlocks and the Character block (TID-766)

- **Ladder rows** (`game_logic/progression/UnlockLadder.gd`): `feat_cooking` (level 11, 90 gold), `feat_alchemy`
  (level 14, 120 gold), `feat_crafting` (level 17, 150 gold). All three are taught by the trainer `crafter`, shown as
  **Master Artisan**. The levels sit past 10 because the first ten levels each introduce exactly one thing
  (`test_levels_ascend_one_new_thing_early`).
- **Trainer NPC**: `crafter_madrian`, an `npc_type "trainer"` entry in the Madrian square (`assets/maps/madrian.tres`,
  town tile 38,30, clear of the stations). It has no sprite of its own yet, so it wears the townsperson sprite
  (`SpriteRegistry._NAMED_NPC_TEXTURES`). Talking to it opens the teach panel through `NpcInteractions`.
- **Gate** (`UnlockLadder.PROFESSION_FEATURES`, `profession_feature`, `station_block`): a profession maps to its
  feature. `station_block(profession, learned)` is pure: "" when open, else "Learn Alchemy from the Master Artisan
  (level 14) to use this station." `CraftingStations.show_panel` shows that text on the HUD and does not open the
  panel. It agrees with `SaveManager.has_learned`. Gathering has no gate.
- **Migration v51** (`SaveMigrations._m51_profession_trainers`): every save older than v51 is granted all three
  features, so a player who already had stations keeps them. New saves learn them at the trainer. Head Start learns
  them too.
- **Character block** (`scenes/ui/CharacterProfessions.gd`, built from `CharacterScene` under the Mentor slot): per
  profession, its name in colour, `Level N - XP a / b` with a bar, and `Recipes known: k / n` (any recipe whose band is
  not locked). A profession not yet learned shows the station gate text instead. The Character screen has no tab bar,
  so this is a section, not a tab.
- **Side quests**: the optional starter side quest per profession is not done (skipped as too large for this task).

## Integrations

- **The garden** (`GardenDefs`): plants are recipe inputs. Potions share `SaveManager.potions` with the battle quick
  slots. The Items tab lists garden herbs with the recipes that use them.
- **Foods** (`HeroVitality.FOODS`): crafted foods share `SaveManager.foods` with the world quick use. Well-fed buffs
  are read by `HeroHealth`, `WorldHUD` and `BattleModifiers`.
- **Battle drops** (`BattleVictory`): material rolls ride the victory reward path (see Enemy drops).
- **Gear** (`GearRolls`, `gear.grant`): crafted items use the same grant path as drops.
- **Unlocks** (`UnlockLadder`, `NpcInteractions`, `SaveMigrations`, `QuestLog`): the trainer panel lists the three
  features; the training quest and "!" marks pick them up like any other ladder row.
- **Character screen** (`CharacterScene` → `CharacterProfessions`).
- **Inventory** (`inventory-and-deck.md`): the Craft tab is cards only; the Items tab lists potions and herbs.

## Asset Requirements

- Stations are procedural. The cooking fire reuses `CampfireVisual`; the alchemy table and workbench are plank boxes in
  the profession colour.
- Gathering nodes are placeholder coloured mounds.
- The Master Artisan uses the townsperson sprite. A dedicated artisan sprite would go through `docs/agent/art-sprites.md`.
- No new audio or textures beyond that.

## Tests

- `tests/unit/test_professions.gd`: the tables are valid, the XP curve round-trips, the bands behave, the craft flow
  (inputs, outputs, refusals, level-up) and the v49 migration.
- `tests/unit/test_gathering.gd`: deterministic planning per chunk seed, biome and water gating, yields that are valid
  materials of the matching source, `add_xp`, and the harvest-then-depleted cycle.
- `tests/unit/test_material_drops.gd`: drop tables, tier scaling, allowed-fight gating and the seeded roll.
- `tests/unit/test_alchemy.gd`: potion effects (pure), recipe tables, alternative inputs and the new herbs.
- `tests/unit/test_crafting_stations.gd`: station placement on open ground, the station → profession map, and the
  panel building and crafting headless.
- `tests/unit/test_cooking.gd`: recipes, the cooked foods' shop status, the WELL_FED table, the pure buff math, the
  v50 migration and that `well_fed` is persisted.
- `tests/unit/test_gear_crafting.gd`: gear recipes name real equipment, skill maps to tier in steps, epic is the cap
  (seeded, 2000 rolls), item level follows the recipe, a craft grants the item, and a duplicate keeps the better roll.
- `tests/unit/test_profession_unlocks.gd`: the three features on the ladder, the Master Artisan wiring, the station
  gate (refuses until learned, agrees with `has_learned`), gathering ungated, the v51 migration (old saves only), the
  Character block's text, and that the trainer stands on open ground.
- `tests/unit/test_unlock_ladder.gd` and `test_starter_zone.gd` cover the ladder rules and trainer sprites that the
  new rows must also satisfy.

## Known gaps

- Co-op harvests are not broadcast; gathering has no hold-time.
- Bog moss is not planted yet, so Bog Pie's bog moss needs a source.
- Well-fed buffs are not shown in battle, and only max HP is a stat.
- Wilderness camp fires do not act as cooking fires.
- The optional starter side quest per profession was not built.
- No dedicated Master Artisan sprite.
