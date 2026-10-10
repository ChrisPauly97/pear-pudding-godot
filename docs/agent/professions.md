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

## Integrations

- The garden (`GardenDefs`): plants are inputs. Potions share `SaveManager.potions` with the battle quick slots.
- Foods (`HeroVitality.FOODS`): crafted foods share `SaveManager.foods` with the world quick use.
- Planned: gathering nodes (TID-760), enemy drops (TID-761), station panel (TID-762), cooking buffs (TID-763), alchemy migration (TID-764), gear (TID-765), trainers + Character tab (TID-766).

## Asset Requirements

None yet. The station and gathering-node sprites come with TID-760 / TID-762.

## Tests

`tests/unit/test_professions.gd` checks that the tables are valid, the XP curve round-trips and the bands behave, and covers the craft flow (inputs, outputs, refusals, level-up) and the v49 migration.
