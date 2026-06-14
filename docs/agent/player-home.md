# Player Home & Trophy Hall (GID-046)

## Key Features

- **Purchasable house** in the madrian map — costs 500 coins, persists as `home_owned: bool` in SaveManager.
- **Interior map** (`player_home.tres`) — small walled room with a bed entity and trophy pedestals.
- **Trophy framework** — 3 data-driven trophies evaluated against save state; earned trophies shown as gold pedestals, unearned as gray placeholders.
- **Bed rest** — sets a persistent respawn point; on game over the player returns to their home bed instead of the world default.

## How It Works

### Door Gating (WorldScene)

When the player interacts with a door whose `entity_id` is `"house_door"` (placed at madrian tile 40,50), `_show_house_door_panel()` is called instead of the normal door flow:

- If `save_manager.home_owned == true`: play door SFX and call `SceneManager.enter_map("player_home", "exit_door")`.
- If `home_owned == false`: show an inline CanvasLayer panel with the price (500 coins), a Buy button (disabled if insufficient), and Cancel. On confirm, `add_coins(-500)`, set `home_owned = true`, mark dirty, then enter the map.

### Interior Map (`assets/maps/player_home.tres`)

- 100×100 tile grid (PackedInt32Array, all values WALL=1 except tiles x:41–59, z:45–54 which are GRASS=0).
- `spawn_x = 50`, `spawn_z = 53` — player lands inside the room.
- Exit door entity: `entity_id = "exit_door"`, tile (50,44), `target_map = ""` → pops map stack back to madrian.
- Bed NPC entity: `entity_id = "npc_bed"`, `npc_type = "bed"`, tile (57,50).
- Registered in `MapRegistry._BUNDLED` as `"player_home"` via a `const` preload (Android-safe).

### Trophy Registry (`game_logic/TrophyRegistry.gd`)

Static class with a typed `_DATA: Array[Dictionary]`. Each entry has:
- `id` — unique string key
- `display_name` — shown on pedestal Label3D
- `description` — shown in dialogue on interact
- `predicate_key` — internal dispatch key for `is_earned()`

Current trophies:

| id | predicate |
|----|-----------|
| `champion` | `defeated_duelists.size() > 0` |
| `spire_7` | `spire_best_floor >= 7` |
| `first_boss` | any `defeated_enemies` entry is a boss per `EnemyRegistry` |

`is_earned(trophy_id, save_mgr)` returns false gracefully for unknown ids or missing save fields.

### Trophy Pedestal Spawning (WorldScene)

After loading the player_home map, `_spawn_player_home_trophies()` is called:
- Iterates `["champion", "spire_7", "first_boss"]` with tile positions `(44,49)`, `(47,49)`, `(50,49)`.
- Calls `TrophyRegistry.is_earned()` for each.
- Builds a `Node3D` via `_make_trophy_pedestal(earned, display_name)`: BoxMesh base + top pillar, `MeshInstance3D` colored gold (earned) or gray (not earned), `Label3D` showing the display name or `"???"`.
- Registers each pedestal as an NPC via `register_npc()` with `npc_type = "trophy_pedestal"`.
- Interact dispatch in `_handle_interact()` → `_show_trophy_info(npc)` → `_show_dialogue()`.

### Bed Rest (WorldScene)

`_handle_bed_interaction()`:
1. Calls `save_manager.set_respawn_point("player_home", 100.0, 106.0)` (tile 50,53 × TILE_SIZE 2.0).
2. Sets `save_manager.time_of_day = 0.25` (sunrise).
3. Shows dialogue: "You rest peacefully at home. Respawn point set!"

### Game-Over Respawn (GameOverScene)

`_on_menu()` calls `_apply_respawn_if_available()` before `SceneManager.go_to_menu()`:
- Checks `save_manager.has_respawn_point()` (requires `respawn_map != ""` AND `home_owned == true`).
- If true: sets `current_map`, `player_x`, `player_z` to respawn values; calls `sync_stacks([], [])` to clear the map/door stacks; calls `mark_dirty()`.
- `go_to_menu()` saves to disk unconditionally, so the respawn routing persists.

### SaveManager Fields & Migrations

| Version | Migration | Fields Added |
|---------|-----------|--------------|
| v21→v22 | `_migrate_v21_to_v22()` | `home_owned: bool = false` |
| v22→v23 | `_migrate_v22_to_v23()` | `respawn_map: String = ""`, `respawn_x: float = 0.0`, `respawn_z: float = 0.0` |

Current `CURRENT_SAVE_VERSION = 23`.

API methods on SaveManager:
- `set_respawn_point(map: String, x: float, z: float) -> void` — sets respawn fields and marks dirty.
- `has_respawn_point() -> bool` — returns true only if `respawn_map != ""` AND `home_owned == true`.

## Integrations with Other Features

- **Coin economy (GID-007/GID-028):** House purchase deducts 500 coins via `add_coins(-500)`.
- **Map stack navigation (GID-015/GID-017):** `player_home` uses the existing `enter_map` / pop-stack door flow. Exit door has empty `target_map` to pop back to madrian.
- **Champion duels (GID-037):** `defeated_duelists` field used by champion trophy predicate.
- **Endless Spire (GID-038):** `spire_best_floor` field used by spire_7 trophy predicate.
- **Enemy system:** `EnemyRegistry.is_boss(enemy_type)` used by first_boss trophy predicate.
- **Game-over flow:** GameOverScene routes to home bed if `has_respawn_point()` is true.

## Asset Requirements

- `assets/maps/player_home.tres` + `player_home.tres.uid` — must exist and be preloaded in MapRegistry.
- `game_logic/TrophyRegistry.gd` + `.uid` — static class, no `.tres` resources needed.
- No sprite assets required for v1 — trophy pedestals use procedural BoxMesh geometry.
