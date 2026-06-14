# TID-174: Trophy Framework — Feats from Save Data Rendered as Pedestal Entities

**Goal:** GID-046  
**Type:** agent  
**Status:** done  
**Depends On:** TID-173

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

A data-driven trophy system that reads save state predicates and spawns visual pedestal entities in the player home interior. Each trophy shows earned achievements; unearned pedestals remain empty placeholders.

## Research Notes

- **Trophy data schema:** Create **`game_logic/TrophyRegistry.gd`** (not a .tres resource — v1 uses a simple const table to avoid .uid overhead). Define a static `_DATA` dict with entries:
  ```gdscript
  {
    "champion": {
      "display_name": "Regional Champion",
      "description": "Defeat all duelist NPCs in the world.",
      "predicate": Callable(self, "_check_defeated_duelists"),
    },
    "spire_7": {
      "display_name": "Spire Climber",
      "description": "Reach floor 7 or higher in the Endless Spire.",
      "predicate": Callable(self, "_check_spire_floor_7"),
    },
    "first_boss": {
      "display_name": "Boss Slayer",
      "description": "Defeat your first boss.",
      "predicate": Callable(self, "_check_first_boss_defeated"),
    },
  }
  ```
- **Predicate callables:** Each predicate is a `Callable` that takes `SaveManager` as an argument and returns bool:
  - `_check_defeated_duelists(sm: SaveManager) -> bool`: Check if `sm.story_flags.get("defeated_champion", false)` exists (or similar field from GID-037's planned implementation — cite **`tasks/goals/GID-037--tavern-duels/goal.md`** which states "defeated duelists are tracked per save in `SaveManager.defeated_duelists`"). Fallback: if the field doesn't exist yet, return false gracefully.
  - `_check_spire_floor_7(sm: SaveManager) -> bool`: Check if `sm.spire_run.get("best_floor", 0) >= 7` (cite **`tasks/goals/GID-038--endless-spire/goal.md`** "SaveManager.spire_run persists an active run"). If `spire_run` dict doesn't exist, return false.
  - `_check_first_boss_defeated(sm: SaveManager) -> bool`: Check if any enemy in `sm.defeated_enemies` has the boss flag set. Iterate through `SaveManager.defeated_enemies` and look up each enemy ID via `EnemyRegistry.get_enemy(type)` to check if `is_boss` is true. If no boss enemies defeated, return false.
- **TrophyRegistry API:**
  ```gdscript
  static func get_all() -> Array: return _DATA.values()
  static func get(trophy_id: String) -> Dictionary: return _DATA.get(trophy_id, {})
  static func is_earned(trophy_id: String, save_mgr: SaveManager) -> bool:
    var pred = _DATA.get(trophy_id, {}).get("predicate")
    if pred == null: return false
    return pred.call(save_mgr)
  ```
- **Pedestal entity spawning in player_home:** On **`WorldScene._ready()`**, after loading `player_home.tres`, check if current map is "player_home". If so:
  - Iterate through `TrophyRegistry.get_all()` (order by trophy_id or display_name for consistency).
  - For each trophy, check `is_earned()` via the predicate.
  - If earned: spawn a pedestal Sprite3D at a fixed tile position (e.g. tiles `(4,4)`, `(6,4)`, `(8,4)` in a row) with a glowing material and the trophy name label.
  - If not earned: spawn an empty pedestal at the same position with a grayed-out material.
  - Cite **`scenes/world/entities/EnemyNPC.gd`** or **`scenes/world/entities/TownspersonNPC.gd`** for the entity spawning pattern.
- **Pedestal scene/script:** Create **`scenes/world/entities/TrophyPedestal.gd`** extending `Node3D` with:
  - `@export var trophy_id: String = ""` — the trophy key.
  - `@export var is_earned: bool = false` — set during spawn.
  - Sprite3D child node with a simple pedestal sprite (or placeholder colored rect if sprite unavailable).
  - Interaction prompt on E / touch: show the trophy name + description in a label (reuse WorldScene dialogue label, cite line 1236+), then hide after 3 seconds.
  - Material variation: earned trophies use a golden/white material; unearned use gray/muted material (can be set via shader parameter or material override).
- **Spawning logic in WorldScene:** After `WorldScene.load_from_resource(current_map_data)`, add:
  ```gdscript
  if current_map_name == "player_home":
    _spawn_trophies()
  
  func _spawn_trophies() -> void:
    var save_mgr = SceneManager.save_manager
    var trophy_ids = ["champion", "spire_7", "first_boss"]
    var positions = [Vector3(4, 0, 4), Vector3(6, 0, 4), Vector3(8, 0, 4)]
    for i in range(trophy_ids.size()):
      var tid = trophy_ids[i]
      var is_earned = TrophyRegistry.is_earned(tid, save_mgr)
      var pedestal = TrophyPedestal.instantiate()
      pedestal.trophy_id = tid
      pedestal.is_earned = is_earned
      pedestal.position = positions[i]
      _world_map_node.add_child(pedestal)
  ```
  Adjust tile positions based on the actual interior map layout.
- **Predicates and field verification:** 
  - **GID-037 (champion):** Goal states "Defeated duelists are tracked per save in `SaveManager.defeated_duelists`" — but this may not exist yet. Plan assumes the field will be added in GID-037. If it doesn't exist at build time, degrade gracefully: `sm.defeated_duelists.size() > 0 if sm.has("defeated_duelists") else false`.
  - **GID-038 (Spire):** Goal states "`SaveManager.spire_run` persists an active run (floor, draft deck, hp, seed)". Predicate: `sm.spire_run.get("best_floor", 0) >= 7 if sm.has("spire_run") else false`.
  - **Boss defeat:** `EnemyRegistry.get_enemy(enemy_type)` returns an `EnemyData` dict with `is_boss: bool`. Check each defeated enemy's type.
- **Tests:** Headless test for:
  - Trophy predicate evaluation against a synthetic SaveManager state (with/without fields).
  - Graceful fallback when predicates reference fields that don't exist (return false).
  - is_earned() correctly reflects each trophy's earned status based on save state.
  - Pedestal node instantiation and material assignment (earned vs unearned).

## Plan

1. Create `game_logic/TrophyRegistry.gd` as a static class with `_DATA: Array[Dictionary]` defining 3 trophies (champion, spire_7, first_boss) each with id, display_name, description, predicate_key.
2. Implement `get_all()`, `get_trophy()`, `is_earned()` static methods; predicates check `defeated_duelists`, `spire_best_floor`, `defeated_enemies` + EnemyRegistry.is_boss().
3. In WorldScene, after loading player_home map, call `_spawn_player_home_trophies()` which iterates trophy ids, checks `TrophyRegistry.is_earned()`, and spawns `_make_trophy_pedestal()` Node3D at fixed tile positions registered with `register_npc()`.
4. In `_handle_interact()` NPC dispatch: branch on `npc_type == "trophy_pedestal"` → `_show_trophy_info(npc)`.
5. Add TrophyRegistry unit tests (get_all size, get_trophy per id, is_earned predicates for each trophy type).

## Changes Made

- **`game_logic/TrophyRegistry.gd`** (new): Static registry with 3 trophy definitions. `is_earned()` dispatches to `_check_champion()` (defeated_duelists.size() > 0), `_check_spire_7()` (spire_best_floor >= 7), `_check_first_boss()` (any defeated_enemy matches EnemyRegistry.is_boss()). Unknown trophy IDs and missing save fields return false gracefully.
- **`game_logic/TrophyRegistry.gd.uid`** (new): `uid://wzsfpzs80b2z`
- **`scenes/world/WorldScene.gd`**: Added `const TrophyRegistry = preload("res://game_logic/TrophyRegistry.gd")`; added `_spawn_player_home_trophies()` called when loading player_home; added `_make_trophy_pedestal(earned, display_name)` creating a Node3D with BoxMesh base+top and Label3D; added `trophy_pedestal` branch in NPC interact dispatch; added `_show_trophy_info(npc)` delegating to `_show_dialogue()`.
- **`tests/unit/test_player_home.gd`**: Contains TrophyRegistry tests: get_all returns 3, get_trophy for each id, get_trophy("nonexistent") empty, is_earned for champion/spire_7/first_boss/unknown.

## Documentation Updates

- `docs/agent/player-home.md` (new) — covers trophy data schema and pedestal spawning.
