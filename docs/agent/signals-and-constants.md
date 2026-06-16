# Signals and Constants

## Key Features

- `GameBus` is a global autoload that acts as a signal hub — all cross-system communication goes through it, keeping scenes decoupled from each other
- `IsoConst` is a global autoload that is the single source of truth for every tile type, camera parameter, distance range, and gameplay constant
- No system holds a direct reference to another system's scene node; all coordination flows through these two autoloads
- Adding a new cross-system event means adding one signal to `GameBus` and connecting listeners independently — no need to modify senders or receivers

---

## How It Works

### GameBus (`autoloads/GameBus.gd`)

`GameBus` is an `Object`-derived autoload with no state of its own — only signal declarations:

```gdscript
# World ↔ Battle
signal enemy_engaged(enemy_data: Dictionary)
signal battle_won(result: Dictionary)
signal battle_lost()

# World navigation
signal map_transition_requested(map_name: String, target_door_id: String)

# UI
signal inventory_requested()
signal chest_opened(card_id: String)

# Battle state updates (for UI refresh)
signal card_played(player_idx: int, card: CardInstance, slot: int)
signal card_attacked(attacker: CardInstance, target)
signal turn_ended(active_player_idx: int)
signal battle_ended(winner_idx: int)
```

**Usage pattern:**

Emitting (sender does not know who listens):
```gdscript
GameBus.enemy_engaged.emit({ "type": "undead_horde", "enemy_node": self })
```

Listening (receiver does not know who emitted):
```gdscript
func _ready() -> void:
    GameBus.enemy_engaged.connect(_on_enemy_engaged)
```

This means `EnemyNPC` never imports `SceneManager`, and `BattleScene` never imports `WorldScene`. The dependency graph stays flat.

### Signal Reference Table

| Signal | Emitted by | Listened to by | Payload |
|---|---|---|---|
| `enemy_engaged` | `EnemyNPC` | `SceneManager` | `{ type, enemy_node }` |
| `battle_won` | `GameState` / `BattleScene` | `SceneManager`, `EnemyNPC` | `{ winner_idx }` |
| `battle_lost` | `GameState` / `BattleScene` | `SceneManager` | _(none)_ |
| `map_transition_requested` | `Door` entity | `SceneManager` | `map_name, target_door_id` |
| `inventory_requested` | `WorldScene` (I key) | `SceneManager` | _(none)_ |
| `hud_message_requested` | `SceneManager` | `WorldScene` | `text: String` |
| `chest_opened` | `Chest` entity | `SceneManager` / `SaveManager` | `card_id: String` |
| `card_played` | `GameState` | `BattleScene` | `player_idx, card, slot` |
| `card_attacked` | `GameState` | `BattleScene` | `attacker, target` |
| `turn_ended` | `GameState` | `BattleScene` | `active_player_idx` |
| `battle_ended` | `GameState` | `BattleScene`, `SceneManager` | `winner_idx` |
| `story_flag_set` | `SaveManager` | `WorldScene` (tutorial hints) | `flag: String` |
| `story_scroll_collected` | `StoryScroll.interact()` | `WorldScene` (HUD toast + achievement) | `scroll_id: String` |
| `all_scrolls_collected` | `WorldScene._on_scroll_collected` | _(future achievements system)_ | _(none)_ |
| `journal_requested` | `WorldScene` (J key / Journal btn) | `SceneManager` | _(none)_ |
| `dialogue_state_changed` | `WorldScene._show_dialogue()` / timer | `AudioManager` (suppress narration) | `active: bool` |
| `level_up` | `SaveManager.add_xp()` | `SceneManager` (toast) | `new_level: int` |
| `xp_changed` | `SaveManager.add_xp()` | HUD XP bar | `new_xp: int, new_level: int` |
| `corruption_points_changed` | `SaveManager.add_corruption_points()` | _(future UI listeners)_ | `new_amount: int` |
| `redemption_points_changed` | `SaveManager.add_redemption_points()` | _(future UI listeners)_ | `new_amount: int` |
| `world_event_started` | `WorldEventManager._fire_event()` | minimap marker, HUD toast (TID-152..154) | `event_id: String` |
| `world_event_ended` | `WorldEventManager.end_event()` | cleanup listeners (TID-152..154) | `event_id: String` |
| `traveling_shop_requested` | `WorldScene._handle_interact()` | `SceneManager._on_traveling_shop_requested()` | `stock: Array[String], price: int` |
| `weather_changed` | `WeatherManager._change_weather()` | `WorldScene` (visuals), `BattleScene` (banner) | `weather_id: String, duration: float` |
| `fragment_collected` | `SaveManager.collect_treasure_fragment()` | `SceneManager` (toast) | _(none)_ |
| `treasure_map_assembled` | `SaveManager._assemble_treasure_map()` | `SceneManager` (toast) | _(none)_ |
| `treasure_excavated` | `SaveManager.complete_treasure()` | `SceneManager` (toast) | `coins: int, card_id: String` |
| `waystone_activated` | `Waystone.mark_activated()` | `WorldScene` (toast + visual update) | `waystone_id: String` |
| `mount_state_changed` | `SaveManager.summon_mount()` / `dismiss_mount()` | HUD mount button (TID-180), `WorldScene` visuals (TID-181) | `mounted: bool, mount_id: String` |
| `pack_purchased` | `ShopScene._on_buy_pack()` | `SceneManager._on_pack_purchased()` | `pack_id: String, rolled_cards: Array[Dictionary]` |
| `blacksmith_requested` | `WorldScene._handle_interact()` | `SceneManager._on_blacksmith_requested()` | _(none)_ |
| `weapon_upgraded` | `SaveManager.upgrade_weapon()` | _(listeners: future HUD)_ | `weapon_id: String, new_level: int` |
| `weapon_salvaged` | `SaveManager.salvage_weapon()` | _(listeners: future HUD)_ | `weapon_id: String, coins: int, essence: int` |
| `biome_changed` | `WorldScene` (on biome transition) | `AudioManager.set_ambience()` | `biome_id: int` |
| `entered_named_map` | `WorldScene` (on map load) | `AudioManager.set_ambience(-1)` | `map_name: String` |
| `exited_to_world` | `WorldScene` (on pop to infinite world) | _(future listeners)_ | _(none)_ |

---

### IsoConst (`autoloads/IsoConst.gd`)

All gameplay constants in one place. Other files reference them as `IsoConst.CONSTANT_NAME`.

#### Tile Types

```gdscript
const TILE_GRASS: int = 0
const TILE_WALL:  int = 1
const TILE_HILL:  int = 2
```

#### World Geometry

```gdscript
const TILE_SIZE:    float = 2.0   # world units per tile
const CHUNK_SIZE:   int   = 16    # tiles per chunk side
const WALL_FACE_H:  float = 2.0   # height of vertical wall faces (world units)
```

#### Camera

```gdscript
const CAM_ELEVATION_DEG: float = -35.264   # arcsin(tan(30°))
const CAM_AZIMUTH_DEG:   float = -45.0
const CAM_ORTHO_SIZE:    float = 15.0
const CAM_OFFSET:        Vector3 = Vector3(20.0, 20.0, 20.0)
```

#### Gameplay Ranges

```gdscript
const AUTO_BATTLE_RANGE: float = 1.5   # distance to trigger battle
const INTERACT_RANGE:    float = 1.5   # distance for E-key prompt
const TRACKING_RANGE:    float = 4.0   # enemy starts chasing player
```

#### Deck Constraints

```gdscript
const DECK_MIN: int = 8    # minimum cards required to start a battle
const DECK_MAX: int = 20   # maximum cards allowed in a deck
```

#### Hero Stats (defaults)

```gdscript
const HERO_MAX_HP:   int = 30
const HERO_START_MANA: int = 1
const HERO_MAX_MANA: int = 10
```

### WorldMap Aliases

`WorldMap` re-exports tile constants for backward compatibility:

```gdscript
const TILE_WALL: int  = IsoConst.TILE_WALL
const TILE_GRASS: int = IsoConst.TILE_GRASS
const TILE_HILL: int  = IsoConst.TILE_HILL
```

These aliases exist only for files that were written before the constants were centralised. **Do not add new copies elsewhere** — always use `IsoConst.*` directly in new code.

---

## Integrations with Other Features

`GameBus` and `IsoConst` are dependencies of virtually every other system:

| System | Uses GameBus | Uses IsoConst |
|---|---|---|
| EnemyNPC | Emits `enemy_engaged` | `AUTO_BATTLE_RANGE`, `TRACKING_RANGE` |
| BattleScene | Listens to `card_played`, `battle_ended`, etc. | `HERO_MAX_HP`, `HERO_MAX_MANA` |
| SceneManager | Listens to all routing signals | — |
| WorldScene | Emits `inventory_requested`; listens to battle signals | `TILE_SIZE`, `CHUNK_SIZE`, `CAM_OFFSET` |
| TerrainMath | — | `TILE_GRASS`, `TILE_HILL`, `TILE_WALL`, `TILE_SIZE`, `WALL_FACE_H` |
| InfiniteWorldGen | — | `CHUNK_SIZE`, `TILE_*` constants |
| Chest entity | Emits `chest_opened` | `INTERACT_RANGE` |
| Door entity | Emits `map_transition_requested` | `INTERACT_RANGE` |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| `GameBus.gd` | `autoloads/GameBus.gd` | Autoload singleton; registered in `project.godot` under the name `GameBus` |
| `IsoConst.gd` | `autoloads/IsoConst.gd` | Autoload singleton; registered under the name `IsoConst` |
| `AudioManager.gd` | `autoloads/AudioManager.gd` | Autoload singleton; registered under the name `AudioManager` — see [audio-manager.md](audio-manager.md) |

No textures, shaders, or data files are required. Both scripts contain only declarations and constants — they have no runtime cost beyond registration.
