# TID-167: Waystone Entity + Activation Flow + Save Tracking

**Goal:** GID-044  
**Type:** agent  
**Status:** pending  
**Depends On:** —

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

The interactive waystone entity that sits in the world, can be activated by the player, and persists that activation state across restarts. Serves as the anchor for the fast-travel feature.

## Research Notes

- **New waystone entity scene:** `scenes/world/entities/Waystone.gd` modeled on **`scenes/world/entities/Chest.gd`** and **`scenes/world/entities/Door.gd`**:
  - Extends `Node3D` like other interactables; uses `find_child("MeshInstance3D")` pattern and shared static material/mesh resources.
  - **Dormant visual:** simple pillar mesh (BoxMesh ~1.0 × 1.5 × 1.0) in stone gray (`Color(0.6, 0.6, 0.65)`), unshaded.
  - **Active visual:** same mesh, glowing gold (`Color(1.0, 0.95, 0.3)`) — achieved by swapping the material override on activation (no post-process glow needed for v1).
  - **Sprite3D glow indicator (optional for v1):** could add a small yellow star above the waystone when active; see **`docs/human/CLAUDE.md`** Sprite3D y-offset rule — sprite at `y = 1.1` or higher to clear floor.
  - `var waystone_data: Dictionary` field (like chest_data/door_data); stores id and active flag.
  - `func init_from_data(data: Dictionary)` — called from `WorldScene` after entity spawn (follows pattern from Chest/Door).
  - `func mark_activated()` — sets visual active state and `waystone_data["active"] = true`.

- **Waystone identity (stable string):**
  - **Named-map waystones:** `"map:<map_name>"` e.g. `"map:main"`, `"map:blancogov"`.
  - **Infinite-world waystones:** `"world:<tile_x>:<tile_z>"` e.g. `"world:128:64"` (absolute world coords, not chunk-relative).
  - Stored in `waystone_data["id"]` and persisted to `SaveManager.activated_waystones`.

- **SaveManager additions:**
  - `var activated_waystones: Array[String] = []` — list of waystone IDs that have been activated.
  - **Migration:** Add default `activated_waystones = []` for old saves in `_migrate()`.
  - See **`autoloads/SaveManager.gd`** lines 1–150 for field layout and migration pattern.

- **GameBus signal:**
  - Add `signal waystone_activated(waystone_id: String)` to **`autoloads/GameBus.gd`**.
  - Emit from `Waystone.mark_activated()` via `GameBus.waystone_activated.emit(waystone_data["id"])`.
  - Update **`docs/agent/signals-and-constants.md`** signal table.

- **Activation interaction flow:**
  - `WorldScene._handle_interact()` (line ~1158 in **`scenes/world/WorldScene.gd`**) checks nearest entity (similar to Chest).
  - On interaction with a dormant waystone: call `waystone.mark_activated()`.
  - Show toast via **`SceneManager._toast`** (see **`scenes/ui/AchievementToast.gd`** line 67 `show_text(title: String, desc: String)`): `SceneManager.save_manager._toast.show_text("Waystone", "Activated: " + waystone_data.get("label", "Unknown"))`.
  - Play SFX: check **`autoloads/AudioManager.gd`** lines 4–16 for existing SFX keys; add `"waystone_activate"` if not present (or reuse an existing activation sound like "scroll_pickup").

- **Waystone placement in entity data:**
  - New resource class **`game_logic/world/resources/MapWaystone.gd`** (extends Resource, fields: `entity_id: String`, `tile_x: int`, `tile_z: int`, `label: String` for the friendly name).
  - Create **`game_logic/world/resources/MapWaystone.gd.uid`** sidecar.
  - Add to **`MapData.gd`** (line ~40–50): `@export var waystones: Array[Resource] = []`.

- **WorldMap loader integration:**
  - In **`game_logic/world/WorldMap.gd`** `load_from_resource()`: cast `md.waystones` entries to `_MapWaystone`, convert tile coords to world coords, append dicts to `self.waystones`.
  - In `to_map_data()` (save path): convert `self.waystones` dicts back to `_MapWaystone` instances, append to `md.waystones`.
  - Add `var waystones: Array[Dictionary] = []` to WorldMap.

- **WorldScene spawning:**
  - In **`scenes/world/WorldScene.gd`** entity spawn loop (where doors, chests, NPCs are instantiated), iterate `world_map.waystones` and instantiate Waystone nodes from a packed scene **`scenes/world/entities/Waystone.tscn`** (or create dynamically like Chest does).
  - Pass `waystone_node.init_from_data(waystone_dict)` after spawn.
  - Store waystone nodes in `_waystone_nodes: Dictionary` (keyed by id) for later interaction checking.

- **Headless tests:**
  - Test activation persistence: spawn a waystone, call `mark_activated()`, check `SaveManager.activated_waystones` contains the id, save, reload, verify id still in list.
  - Test toast and signal: verify `GameBus.waystone_activated` is emitted on `mark_activated()`.
  - Test visual state: verify dormant material differs from active material.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
