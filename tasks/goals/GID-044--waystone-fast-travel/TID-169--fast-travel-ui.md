# TID-169: Fast Travel UI in MapViewOverlay + SceneManager Teleport Routing

**Goal:** GID-044  
**Type:** agent  
**Status:** pending  
**Depends On:** TID-167

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

The UI overlay that lists activated waystones and handles teleportation, with correct routing between named maps and infinite world.

## Research Notes

- **MapViewOverlay.gd structure:**
  - Located at **`scenes/ui/MapViewOverlay.gd`** lines 1–100.
  - Opened by M key press in named maps (see **`docs/human/CLAUDE.md`** Mobile/Desktop parity section: M key opens map, tap minimap button on mobile).
  - Current layout: full-screen dim background, central panel with tile grid texture, entity dot layer on top.
  - Emits `closed` signal when dismissed (Escape key or outside click).
  - `setup(world_map, map_name, player, npc_nodes, npc_data, enemy_nodes, chest_nodes, door_nodes)` populates entity references.

- **Fast travel panel (new UI):**
  - Add a vertical ScrollContainer below the map texture showing activated waystones.
  - Size: width `vh * 0.20`, height `vh * 0.40` (see **`docs/human/CLAUDE.md`** UI sizing — all sizes relative to viewport height, not fixed pixels).
  - List format: Button per activated waystone, labeled with friendly name (e.g. "Main Town", "Grasslands Waystone").
  - On button press: call `_teleport_to_waystone(waystone_id)`.
  - Mobile parity is inherent (buttons are touch-operable).
  - **Blocking conditions:** If player is in a battle (`SceneManager._state == State.BATTLE`) or in a dungeon (current map name contains "dungeon" OR check a flag in `SaveManager`), disable all travel buttons or hide the panel entirely.
  - Button sizing per **`docs/human/CLAUDE.md`**: width `vh * 0.15`, height `vh * 0.055`.

- **Reading activated waystones:**
  - Access `SaveManager.activated_waystones: Array[String]` to get list of ids.
  - Filter by context: if currently in a named map, show only map waystones and world waystones; if in infinite world, show all world waystones.
  - Lookup friendly name: for map waystones, hardcode map names or store in a static dict; for world waystones, parse the id string `"world:<x>:<z>"` and format e.g. "Waystone at (128, 64)".

- **SceneManager teleport routing:**
  - Add public method `func teleport_to_waystone(waystone_id: String) -> void` to **`autoloads/SceneManager.gd`**.
  - **Named-map waystone (id = "map:main"):**
    - Extract map name from id: `map_name = waystone_id.split(":")[1]`.
    - Call `enter_map(map_name, "")` (empty target_door_id means use map spawn).
    - This pushes current map to stack (standard door entry flow per **`docs/agent/ui-and-scene-management.md`** lines 54–62).
  - **World waystone (id = "world:128:64"):**
    - Parse coords: `var parts := waystone_id.split(":")`, `var tx := int(parts[1])`, `var tz := int(parts[2])`.
    - If currently in infinite world: set `player.position = Vector3(float(tx) * IsoConst.TILE_SIZE, 0, float(tz) * IsoConst.TILE_SIZE)` and recenter chunks (see **`scenes/world/WorldScene.gd`** `_stream_chunks()` pattern).
    - If currently in a named map: first `exit_map_via_door(null)` to pop back to infinite world, then set player position (may need to add a `pop_without_door()` method or similar if exit_map_via_door assumes a door node).

- **WorldScene integration:**
  - In **`scenes/world/WorldScene.gd`**, listen for `GameBus.waystone_activated` signal (emitted from TID-167).
  - On signal, update `MapViewOverlay` if it's currently open (store reference in WorldScene or pass via setup).
  - Alternatively, rebuild the waystone list lazily when overlay is opened (simplest for v1).

- **Chunk streaming (infinite world teleport):**
  - When player position changes to a world waystone, `_stream_chunks()` (or similar method in WorldScene) should reload chunks around new position.
  - Verify **`scenes/world/WorldScene.gd`** has a method to update chunk visibility based on player position; call it after teleport.

- **Battle/dungeon blocking:**
  - Before showing or accepting waystone travel, check: `if SceneManager._state == State.BATTLE: return`.
  - For dungeons: check if `current_map` contains "dungeon" (see **`docs/agent/named-maps-and-dungeons.md`** lines 77–83 for dungeon map naming: `dungeon_<seed>`).
  - Gray out or hide travel buttons when blocked.

- **Headless tests:**
  - Test teleport ID parsing: `"world:128:64"` → correct coords extracted.
  - Test map-to-world transition: player in named map, select world waystone, verify map stack is popped and player position is updated.
  - Test world-to-map transition: player in infinite world, select named-map waystone, verify map stack is pushed and map loads.
  - Test blocking: set `SceneManager._state = State.BATTLE`, verify travel buttons are disabled or unavailable.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
