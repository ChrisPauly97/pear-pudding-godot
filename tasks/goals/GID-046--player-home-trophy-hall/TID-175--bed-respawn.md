# TID-175: Bed Rest — Heal + Set Respawn Point Used by Game-Over Flow

**Goal:** GID-046  
**Type:** agent  
**Status:** done  
**Depends On:** TID-173

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

A bed in the player home that heals the player and sets a persistent respawn point. On game over, if the player has purchased the home and rested there, they respawn at the bed instead of the default location.

## Research Notes

- **Player HP in overworld:** Check **`docs/agent/camera-and-player.md`** and **`scenes/world/entities/Player.gd`** for whether the player has persistent HP outside of battles. If HP is battle-only (most likely), the "heal" action is cosmetic: show a fade-to-black transition with "You rest..." text, then optionally set time to morning (if trivial) — skip actual HP healing for v1 if no overworld HP system exists.
- **SaveManager respawn fields:** Add to **`autoloads/SaveManager.gd`**:
  - `var respawn_map: String = ""` — destination map (default "" = use starting map from world_seed).
  - `var respawn_x: float = 0.0`
  - `var respawn_z: float = 0.0`
  - Add migration: `_migrate_v15_to_v16()` backfilling all three to defaults. Update `CURRENT_SAVE_VERSION` to 16 and add to `_apply_migrations()`.
  - Provide API: `func set_respawn_point(map: String, x: float, z: float) -> void` that sets all three and marks dirty.
- **Bed entity spawning:** Add a `MapDoor`-like or custom entity to **`assets/maps/player_home.tres`** for the bed. Alternatively, create it as a hardcoded entity in `_spawn_trophies()` (simpler for v1). Model it on **`scenes/world/entities/TownspersonNPC.gd`** or a new **`scenes/world/entities/Bed.gd`** extending `Node3D`:
  - Sprite3D child with a bed sprite (or placeholder quad).
  - On E / touch interaction (handled by WorldScene `_handle_interact()`):
    - Show a fade-to-black ColorRect overlay for 1.5 seconds with text "You rest at home..." (cite **`SceneManager.gd`** for transition helpers; if none exist, use `Tween` or simple `_process()` with a timer).
    - After fade completes, call `SaveManager.set_respawn_point("player_home", 6.0, 5.0)` (bed position).
    - Optionally: advance `time_of_day` to 0.25 (sunrise) if a time-of-day API exists (cite the day/night update in **`docs/agent/ui-and-scene-management.md`** line 95+ for `_apply_lighting()`). Drop if not trivial.
    - Show a brief toast/label: "Respawn point set!" for 2 seconds (reuse dialogue label system).
- **Game-over respawn routing:** In **`scenes/ui/GameOverScene.gd`**, modify `_on_menu()` or the continue/retry logic:
  - Check `SaveManager.respawn_map != ""` — if set and map is "player_home", and `SaveManager.home_owned` is true, teleport player to `(respawn_x, respawn_z)` in "player_home" on game over instead of the default spawn.
  - Citation: **`scenes/ui/GameOverScene.gd`** lines 1–18 shows the current structure. Currently only has "Return to Menu" button. If retry/continue is added in a future version, route through respawn check.
  - Fallback: if respawn_map is not set or home is not owned, use the default world spawn.
  - Cite **`SceneManager.enter_map(map_name, target_door_id)`** in **`docs/agent/ui-and-scene-management.md`** line 54–57 for the map entry flow. On game over, instead of showing the menu, call something like `SceneManager.enter_world_at_respawn()` or inline: `SceneManager.continue_game()` then manually teleport player to respawn point.
- **Interaction flow:** Bed is a static entity in the room. Interaction is handled by **WorldScene._handle_interact()** (cite line ~1236+), which checks entity type. Create a new entity type in the map or use a flag-based NPC approach:
  - Option A: Add `npc_type = "bed"` to an NPC resource in player_home.tres, handled as a special case in WorldScene.
  - Option B: Spawn bed as a Node3D child with an INTERACT_RANGE trigger; on interaction, emit a signal caught by WorldScene.
  - Simpler (for v1): use a custom entity in **player_home.tres** with `npc_type = "bed"`, and in **WorldScene._handle_interact()**, check `npc["npc_type"] == "bed"` → call `_handle_bed_interaction()`.
- **Mobile parity:** The bed interaction must work via the touch interact prompt (cite **`docs/agent/ui-and-scene-management.md`** line 113–114: Android interact button at center-bottom). No special handling needed if the bed is treated as a standard interactable NPC.
- **Time of day optional enhancement:** If **WorldScene** has a method like `set_time_of_day(value)`, call it to advance to 0.25 (sunrise). Citation: **`docs/agent/ui-and-scene-management.md`** line 95 shows time_of_day update in _process(). Check if SaveManager.time_of_day can be set directly. Drop if not available.
- **Tests:** Headless test for:
  - `set_respawn_point(map, x, z)` persists across save/load cycles.
  - Respawn point defaults correctly in migrations for old saves.
  - Game-over logic: if respawn_map is set and home is owned, load that map and teleport player (mock the game-over trigger).
  - Fade transition completes and respawn point is set (can be unit-tested by mocking the Tween/timer).

## Plan

1. Add `respawn_map`, `respawn_x`, `respawn_z` to SaveManager with v22→v23 migration. Increment CURRENT_SAVE_VERSION to 23.
2. Add `set_respawn_point(map, x, z)` and `has_respawn_point()` API methods to SaveManager.
3. In WorldScene `_handle_interact()`: branch on `npc_type == "bed"` → `_handle_bed_interaction()` which calls `set_respawn_point()` and shows a dialogue.
4. In GameOverScene `_on_menu()`: call `_apply_respawn_if_available()` before `SceneManager.go_to_menu()` to set `current_map/player_x/player_z` from respawn fields when `has_respawn_point()` is true.
5. Add unit tests for respawn migration, set_respawn_point, has_respawn_point, and game-over routing.

## Changes Made

- **`autoloads/SaveManager.gd`**: Added `var respawn_map: String = ""`, `var respawn_x: float = 0.0`, `var respawn_z: float = 0.0`; added `_migrate_v22_to_v23()` backfilling all three to defaults, bumping version to 23; CURRENT_SAVE_VERSION → 23; updated `new_game()`, `load_save()`, `save()`; added `set_respawn_point()` and `has_respawn_point()` methods.
- **`scenes/world/WorldScene.gd`**: Added `_handle_bed_interaction()` which calls `sm.set_respawn_point("player_home", 100.0, 106.0)` (tile 50,53 × TILE_SIZE=2.0), sets `sm.time_of_day = 0.25`, and shows a dialogue.
- **`scenes/ui/GameOverScene.gd`**: Added `_apply_respawn_if_available()` that checks `has_respawn_point()` via dynamic call; if true, updates `current_map`, `player_x`, `player_z` and calls `sync_stacks` + `mark_dirty` before `go_to_menu()` saves to disk.
- **`tests/unit/test_player_home.gd`**: Contains v22→v23 migration tests, `set_respawn_point` stores values, `has_respawn_point` logic (requires both respawn_map and home_owned), `_apply_migrations` chain from v21 reaches v23.

## Documentation Updates

- `docs/agent/player-home.md` (new) — covers respawn fields, bed interaction, game-over routing.
