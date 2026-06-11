# Enemies and NPCs

## Key Features

- Four enemy types with escalating difficulty, each carrying a specific deck composition
- Enemy type selection driven by biome and distance from the world origin
- Enemies wander the map and begin tracking the player when in range
- Auto-battle trigger when the player walks within `AUTO_BATTLE_RANGE` (1.5 world units) of an enemy
- Defeated enemies are persisted in `SaveManager` so they do not respawn on reload
- Town-person NPCs are static, non-hostile, and display biome-flavoured dialogue on interaction
- **Boss system**: `is_boss` flag on `EnemyData` triggers enhanced battle presentation, optional phase-2 deck swap at 50% HP, and guaranteed full drop_pool rewards

---

## How It Works

### Enemy Types (`autoloads/EnemyRegistry.gd`)

`EnemyRegistry` is an autoload that loads all `EnemyData` resources from `data/enemies/*.tres` at startup and exposes `get_enemy(type_id)` and `type_for_biome(biome, distance)`.

| Type ID | Deck | Coin reward | Intended zone |
|---|---|---|---|
| `undead_basic` | 4× Ghost + 4× Skeleton | 5 | Early game (grasslands, close to origin) |
| `undead_horde` | 4× Skeleton + 4× Zombie | 8 | Mid game (forest, medium distance) |
| `ghoul_pack` | 4× Zombie + 4× Ghoul | 12 | Late game (desert, scorched, far) |
| `undead_elite` | 8× Ghoul | 20 | End game (mountains, very far) |

`type_for_biome()` uses a distance threshold table per biome to return the appropriate type ID:

```gdscript
# Example (simplified)
func type_for_biome(biome: String, distance: float) -> String:
    match biome:
        "grasslands": return "undead_basic" if distance < 200 else "undead_horde"
        "forest":     return "undead_horde" if distance < 300 else "ghoul_pack"
        "scorched":   return "ghoul_pack"   if distance < 400 else "undead_elite"
        "mountains":  return "undead_elite"
        _:            return "undead_basic"
```

### EnemyData Resource

Each `data/enemies/<type>.tres` stores:
- `id: String` — matches the type ID key above
- `display_name: String`
- `deck: Array` — card ID strings (converted to `Array[String]` with `assign()` on load)
- `drop_pool: PackedStringArray` — cards that can drop on defeat
- `coin_reward: int` — coins awarded on victory
- `is_boss: bool` — enables boss battle presentation (default false)
- `boss_hp: int` — override enemy hero HP (0 = default 30)
- `phase2_deck: PackedStringArray` — if non-empty, swapped in when enemy HP ≤ 50%

### Boss Battle Framework

When `is_boss` is true in the engaged `enemy_data` dict, `BattleScene` applies:

1. **HP override**: sets enemy hero HP to `boss_hp` (if `boss_hp > 0`)
2. **Boss banner**: fading label showing the enemy's display name at the top of the screen for 2.5 s
3. **Enemy name**: shows the boss's display name in the hero panel instead of "ENEMY"
4. **Phase 2**: when enemy HP first drops to ≤ 50%, discards enemy hand, rebuilds draw deck from `phase2_deck`, draws 4 cards, shows "PHASE 2" banner
5. **Full drop**: on victory, drops all cards in `drop_pool` (emits `{"card_rewards": [...]}` instead of `{"card_reward": "..."}`)

`EnemyNPC` in the world scene: boss enemies render at 1.3× scale with gold materials to distinguish them visually.

`SceneManager._on_battle_won()` handles both `"card_reward"` (single string, regular) and `"card_rewards"` (list, boss).

### EnemyNPC Scene (`scenes/world/entities/EnemyNPC.gd`)

State machine with three modes:

**Wander:**
- Picks a random tile within 3 tiles of spawn point
- Moves toward it at `WANDER_SPEED` (0.8 units/s)
- Waits 1–3 s then picks a new target
- Transitions to **Track** when `player.position.distance_to(position) < TRACKING_RANGE` (4.0 units)

**Track:**
- Each frame: `velocity = (player.position - position).normalized() * TRACKING_SPEED` (2.5 units/s)
- Transitions to **Engage** when `distance < AUTO_BATTLE_RANGE` (1.5 units)
- Returns to **Wander** if player moves beyond `TRACKING_RANGE * 1.5` (de-aggro)

**Engage:**
- Calls `GameBus.emit_signal("enemy_engaged", { "type": type_id, "enemy_node": self })`
- Freezes movement until battle resolves
- On `GameBus.battle_won`: enemy node queues free; `SaveManager.mark_enemy_defeated(unique_id)` called
- On `GameBus.battle_lost`: enemy returns to **Wander**

`EnemyNPC` is placed as a child of the relevant `ChunkRenderer` node (infinite world) or directly under `WorldScene` (named maps). A unique ID is generated from chunk coordinates + spawn index: `"enemy_cx{cx}_cz{cz}_{i}"`.

### TownspersonNPC Scene (`scenes/world/entities/TownspersonNPC.gd`)

- Static `CharacterBody3D` (no movement)
- Shows dialogue string above head for 4 seconds after the player presses E within `INTERACT_RANGE`
- Dialogue is supplied by `BiomeDef.npc_dialogue[]` (randomly picked at spawn time)
- Re-triggers on each new interaction; no branching or quest state

### Duelist NPC (MapNpc variant)

Duelists are regular TownspersonNPCs that have `npc_type = "duelist"` in their `MapNpc` resource. They are wired entirely in data — no separate scene is needed.

**MapNpc duelist fields:**
- `duelist_enemy_id: String` — key into `EnemyRegistry` (e.g. `"duelist_novice"`)
- `wager_coins: int` — coins at stake per duel
- `required_duelist_ids: PackedStringArray` — `entity_id`s that must appear in `SaveManager.defeated_duelists` before this NPC will accept a duel (champion gate)
- `champion_reward_card: String` — card ID awarded once on first defeat (leave empty for regular duelists)

**Interact flow (`WorldScene._show_duel_offer_panel`):**
1. **Champion gate**: if `required_duelist_ids` is non-empty and any listed ID is not in `defeated_duelists` → shows "I only duel proven players. Beat the others in town first. (N more to go.)" — only Decline button shown.
2. If the player has fewer coins than the wager → shows "Come back when you can cover the wager."
3. If the NPC's `entity_id` is in `SaveManager.defeated_duelists` → rematch: wager is halved, prompt changes to "A rematch?".
4. Otherwise → "Care for a friendly duel? Wager: N coins."
5. **Duel** button: builds `enemy_data` dict (deck from `EnemyRegistry`, `duel_npc_id`, `champion_reward_card`) and emits `GameBus.duel_requested(enemy_data, wager)`.
6. **Decline** button: dismisses the panel.

Buttons are sized relative to viewport height (18 % × 7 %) for mobile parity.

**Save tracking:**
- `SaveManager.defeated_duelists: Array[String]` — list of `entity_id` strings for beaten duelists.
- Populated by `SaveManager.mark_duelist_defeated(npc_id)`, called from `SceneManager._on_duel_won()`.

**Champion legendary reward (`SceneManager._on_duel_won`):**
- If `champion_reward_card` is set and the NPC's `entity_id` is NOT already in `defeated_duelists` (first win), `add_card_instance(card_id, "legendary")` is called.
- Story flag `"champion_blancogov_defeated"` is set, which triggers the `regional_champion` achievement.
- A HUD message confirms the legendary award.

**Duelist enemy resources (placed in `data/enemies/`):**

| ID | Deck | Wager | Placed in |
|---|---|---|---|
| `duelist_novice` | Ghost×3, Skeleton×3, Zombie×2, Ghoul, Mend | 15 | madrian (tile 30,20) |
| `duelist_adept` | Ghost×2, Skeleton×2, Zombie×2, Ghoul×2, Mend, Wither, SurgeSpirit, EmberImp | 25 | blancogov (tile 35,50) |
| `duelist_champion` | Ghoul×2, BlitzGhoul×2, ShroudedWraith, VoidWyrm, Wither×2, SoulRend, DarkPact | 50 | blancogov (tile 55,50) — gated behind adept |

### MerchantNPC Scene (`scenes/world/entities/MerchantNPC.gd`)

- Static NPC with gold-coloured robe to distinguish it from regular townspeople
- NPC data dictionary has `"npc_type": "merchant"` set in the data; `WorldScene._handle_interact()` checks this field and emits `GameBus.shop_requested` instead of showing dialogue
- Placeable in named maps via the `MERCHANT x z` directive in `.txt` map files; `WorldMap` parser adds the merchant to the `npcs` array with `npc_type: "merchant"`
- Spawned procedurally in infinite-world grassland and forest biomes at ~5% chance per chunk by `InfiniteWorldGen._gen_entities()`
- `ChunkRenderer._spawn_entities()` instantiates `MerchantNPC.tscn` when `npc_type == "merchant"`, `TownspersonNPC.tscn` otherwise
- Opening the shop: `SceneManager._on_shop_requested()` instantiates `ShopScene` as an overlay on the current world scene and tracks state `State.SHOP`

### Spawn Persistence

On `WorldScene._ready()`, before placing entities:
1. Query `SaveManager.defeated_enemies` for IDs
2. Skip instantiating any entity whose ID is in that set

This means defeated enemies stay gone across sessions.

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **EnemyRegistry** | Data source | Resolves `EnemyData` (deck array) by type ID at spawn and at battle start |
| **InfiniteWorldGen** | Spawner | Calls `EnemyRegistry.type_for_biome()` during `_gen_entities()` to pick enemy type per chunk |
| **WorldMap** | Spawner | Named-map ENEMY lines optionally include a type string; resolved via `EnemyRegistry` |
| **GameBus** | Signal hub | `enemy_engaged(data)` → SceneManager triggers BattleScene; `battle_won` / `battle_lost` → enemy reacts |
| **BattleScene** | Consumer | Reads `enemy_data["deck"]` from the engaged signal to build `PlayerState[1].draw_pile` |
| **SaveManager** | Persistence | `mark_enemy_defeated(id)` and `defeated_enemies` set prevent respawn |
| **BiomeDef** | Dialogue source | `BiomeDef.npc_dialogue[]` supplies TownspersonNPC dialogue lines |
| **GameBus** | Signal | `shop_requested` emitted when player interacts with a MerchantNPC; routed to `SceneManager._on_shop_requested()` |
| **GameBus** | Signal | `duel_requested(enemy_data, wager)` emitted from duel offer panel; `duel_won` / `duel_lost` resolve wager and update `SaveManager.defeated_duelists` |
| **ShopScene** | Overlay | Opened on `shop_requested`; lists all cards for 15 coins each; emits `closed` when player leaves |
| **IsoConst** | Constants | `AUTO_BATTLE_RANGE`, `INTERACT_RANGE`, `TRACKING_RANGE` |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Enemy data resources | `data/enemies/*.tres` | One per enemy type: `undead_basic.tres`, `undead_horde.tres`, `ghoul_pack.tres`, `undead_elite.tres` |
| `EnemyRegistry.gd` | `autoloads/EnemyRegistry.gd` | Autoload singleton; registered in `project.godot` |
| EnemyNPC scene | `scenes/world/entities/EnemyNPC.tscn` | `CharacterBody3D` + `Sprite3D` + `CollisionShape3D` |
| TownspersonNPC scene | `scenes/world/entities/TownspersonNPC.tscn` | Static NPC with dialogue label |
| Enemy sprite texture | `assets/textures/pixel_art/` | Per-enemy-type sprite; falls back to placeholder if missing |
| NPC sprite texture | `assets/textures/pixel_art/` | Townsperson sprite |
