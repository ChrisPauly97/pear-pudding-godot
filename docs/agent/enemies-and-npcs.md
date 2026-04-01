# Enemies and NPCs

## Key Features

- Four enemy types with escalating difficulty, each carrying a specific deck composition
- Enemy type selection driven by biome and distance from the world origin
- Enemies wander the map and begin tracking the player when in range
- Auto-battle trigger when the player walks within `AUTO_BATTLE_RANGE` (1.5 world units) of an enemy
- Defeated enemies are persisted in `SaveManager` so they do not respawn on reload
- Town-person NPCs are static, non-hostile, and display biome-flavoured dialogue on interaction

---

## How It Works

### Enemy Types (`autoloads/EnemyRegistry.gd`)

`EnemyRegistry` is an autoload that loads all `EnemyData` resources from `data/enemies/*.tres` at startup and exposes `get_enemy(type_id)` and `type_for_biome(biome, distance)`.

| Type ID | Deck | Intended zone |
|---|---|---|
| `undead_basic` | 4× Ghost + 4× Skeleton | Early game (grasslands, close to origin) |
| `undead_horde` | 4× Skeleton + 4× Zombie | Mid game (forest, medium distance) |
| `ghoul_pack` | 4× Zombie + 4× Ghoul | Late game (desert, scorched, far) |
| `undead_elite` | 8× Ghoul | End game (mountains, very far) |

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
