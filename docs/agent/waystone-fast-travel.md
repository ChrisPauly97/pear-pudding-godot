# Waystone Fast Travel Network

## Key Features

- Discoverable waystone pillars placed in named maps and rare infinite-world chunks
- Player activates a dormant waystone by interacting with it (E key / tap)
- Activated waystones are stored in `SaveManager.activated_waystones` and persist across sessions
- `MapViewOverlay` (M key / minimap tap) gains a fast-travel panel listing all activated waystones
- Selecting a waystone teleports the player, correctly routing named-map ↔ infinite-world transitions
- Fast travel is blocked during battles and inside dungeons
- All UI is touch-operable (mobile parity)

---

## How It Works

### Entity: Waystone.gd + Waystone.tscn

`scenes/world/entities/Waystone.gd` is a `Node3D` entity that follows the same pattern as `Chest` and `Door`:

- **Shared static resources:** `_dormant_mat` (stone gray, unshaded), `_active_mat` (gold, unshaded), `_pillar_mesh` (BoxMesh 1×1.5×1) are created once via `_ensure_shared_resources()` and reused across all instances.
- **`init_from_data(data: Dictionary)`** — called after spawn to set `waystone_data` and restore active state from save.
- **`mark_activated()`** — guards against double-activation, flips to gold visual, persists to `SaveManager.activated_waystones`, and emits `GameBus.waystone_activated(waystone_id)`.
- `Waystone.tscn` is a minimal scene: `Node3D` root + `MeshInstance3D` child; the mesh and materials are assigned in `_ready()`.

### Waystone IDs

Each waystone has a stable string ID used as the persistence key:

| Context | Format | Example |
|---|---|---|
| Named map | `"map:<map_name>"` | `"map:main"`, `"map:blancogov"` |
| Infinite world | `"world:<tile_x>:<tile_z>"` | `"world:128:64"` |

These IDs are used in `SaveManager.activated_waystones`, as dictionary keys in `_waystone_nodes`, and as the argument to `GameBus.waystone_activated`.

### SaveManager

```gdscript
var activated_waystones: Array[String] = []

func activate_waystone(waystone_id: String) -> void:
    if not activated_waystones.has(waystone_id):
        activated_waystones.append(waystone_id)
    _dirty = true

func is_waystone_activated(waystone_id: String) -> bool:
    return activated_waystones.has(waystone_id)
```

Version 21 migration adds `activated_waystones = []` for old saves.

---

## Placement

### Named Maps

The named-map `.tres` files (`assets/maps/*.tres`) are large binary-text blobs that cannot be reliably edited outside the Godot editor. Instead, `WorldScene._spawn_named_map_waystones()` injects one waystone per named map:

1. If `world_map.waystones` is non-empty (i.e., the .tres had waystone data authored via editor), use those.
2. Otherwise, look up the map name in the static `_NAMED_MAP_WAYSTONE_LABELS` dict and place one waystone near the player spawn point.

```gdscript
const _NAMED_MAP_WAYSTONE_LABELS: Dictionary = {
    "main": "Main Outpost",
    "madrian": "Madrian",
    "maykalene": "Maykalene",
    "blancogov": "Blancogov",
    "farsyth_mansion": "Farsyth Mansion",
    "blancogov_temple": "Temple of Blancogov",
}
```

The waystone ID for named maps is always `"map:<map_name>"`. The map name is the key in `MapRegistry`.

### Infinite World

`InfiniteWorldGen._gen_entities()` appends a waystone to `chunk.waystones` at a 2.5% rate (1-in-40 chunks) after all other entities are placed:

```gdscript
var waystone_rng := RandomNumberGenerator.new()
waystone_rng.seed = _chunk_seed(p_cx, p_cz, world_seed) + 7
if waystone_rng.randi_range(0, 39) == 0 and grass_tiles.size() > 0:
    # pick random grass tile, compute absolute world coords
    chunk.waystones.append({ "id": "world:TX:TZ", ... })
```

- Uses seed offset +7 to avoid correlation with enemy/chest/NPC RNGs.
- Only placed on `TILE_GRASS` tiles.
- Placement is fully deterministic: same `world_seed` + same `(cx, cz)` always produces the same result.

### MapWaystone Resource

`game_logic/world/resources/MapWaystone.gd` is a `Resource` with `@export` fields for embedding waystone data into `.tres` map files:

```gdscript
@export var entity_id: String = ""
@export var tile_x: int = 0
@export var tile_z: int = 0
@export var label: String = ""
```

`MapData.gd` exposes `@export var waystones: Array[Resource] = []` to hold these. `WorldMap.load_from_resource()` reads them into `self.waystones: Array[Dictionary]`, and `ChunkData` carries them per chunk via `get_chunk_data()`.

---

## WorldScene Integration

- `_waystone_nodes: Dictionary` — maps `waystone_id → Waystone Node3D`.
- `_active_waystone_data: Dictionary` — maps `waystone_id → data dict` for all tracked waystones.
- `register_waystone(wid, node, data)` — called by `ChunkRenderer` during entity spawn.
- `_spawn_named_map_waystones()` — called in `_ready()` for named maps; creates Waystone instances near spawn.
- `_find_nearby_waystone(px, pz, range_dist)` — returns the first dormant waystone within range.
- `_check_interactions()` — shows interact button when near a dormant waystone.
- `_handle_interact()` — calls `waystone.mark_activated()` for the nearby waystone.
- `_on_waystone_activated(waystone_id)` — connected to `GameBus.waystone_activated`; shows toast with the waystone's label via `SceneManager.show_toast()`.
- `_open_map_view()` — passes `_waystone_nodes` as the 9th argument to `MapViewOverlay.setup()`.

---

## Fast Travel UI (MapViewOverlay)

`scenes/ui/MapViewOverlay.gd` gains:

- **Cyan dots** (`_DOT_WAYSTONE = Color(0.40, 0.90, 1.00)`) on the map canvas for all tracked waystones.
- **Fast travel panel** (`_travel_panel: ScrollContainer`) placed to the right of the map panel.
- Panel lists all `SaveManager.activated_waystones` as labelled buttons.
- **Blocked when:** inside a dungeon (`current_map.begins_with("dungeon_")`) or during battle (`SceneManager._state != State.WORLD`).
- Button labels via `_friendly_label(waystone_id)`: `"map:blancogov"` → `"Blancogov"`, `"world:128:64"` → `"Waystone (128, 64)"`.
- On press: calls `_teleport_to_waystone(waystone_id)` → dismisses overlay → calls `SceneManager.teleport_to_waystone()`.

---

## SceneManager Teleport Routing

`SceneManager.teleport_to_waystone(waystone_id: String)`:

| Waystone type | Action |
|---|---|
| `"map:<name>"` | Calls `enter_map(name, "")` — standard named-map entry, pushes current map to stack. |
| `"world:<tx>:<tz>"` | Sets `save_manager.player_x/z`, clears `map_stack`/`door_stack`, calls `_load_world("main", "")`. |

Also added: `SceneManager.show_toast(title, desc)` — thin wrapper around `_toast.show_text()`.

---

## Integrations with Other Features

| Feature | Integration |
|---|---|
| `MapViewOverlay` | Receives `_waystone_nodes` dict; draws dots and shows fast-travel panel |
| `SaveManager` | Stores `activated_waystones: Array[String]`, version 21 migration |
| `GameBus` | `waystone_activated(waystone_id)` signal |
| `SceneManager` | `teleport_to_waystone()` + `show_toast()` |
| `ChunkRenderer` | Spawns Waystone nodes from `chunk.waystones`, calls `register_waystone()` |
| `InfiniteWorldGen` | Seeds 1-in-40 waystone per chunk in `_gen_entities()` |
| `WorldScene` | Interaction checks, activation handler, named-map injection |

---

## Asset Requirements

- `scenes/world/entities/Waystone.tscn` — minimal scene, no external assets
- `scenes/world/entities/Waystone.gd` — procedural material/mesh, no textures
- No audio SFX added in v1; toast notification is the activation feedback
