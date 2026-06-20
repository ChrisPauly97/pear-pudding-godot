# TID-243: Blight Heart Entity — Cleanse Battle, Purification, Rewards

**Goal:** GID-066
**Type:** agent
**Status:** done
**Depends On:** TID-242

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The payoff loop of the blight system: the player tracks corruption to its source, finds a pulsing Blight Heart, beats a boss-tier battle, and watches the region permanently purify while earning redemption points. TID-241 decides where hearts are; TID-242 makes blight visible; this task makes hearts tangible, fightable, and rewarding.

## Research Notes

**Entity scene:**
- New entity `scenes/world/entities/BlightHeart.gd` + `.tscn`, patterned on `EnemyNPC.gd/.tscn` (Sprite3D billboard + interaction area). Sprite3D positioning rule: origin high enough that the bottom edge clears y=0 (`pixel_height * pixel_size * 0.5 + margin`, see CLAUDE.md — Player uses y=1.1 for a 48px sprite).
- Spawn: heart positions come from TID-241's `BlightField` placement logic. During chunk entity spawning in `game_logic/world/InfiniteWorldGen.gd`, if this chunk hosts a heart (query BlightField) and its `heart_id` is NOT in `SaveManager.blight_cleansed_hearts`, append a heart entity Dictionary to `ChunkData.entities` (follow the existing merchant spawn block as the pattern). `scenes/world/ChunkRenderer.gd` instantiates the node from the entity dict like it does enemies/chests.
- Place on a cleared walkable tile (force TILE_GRASS under/around it if needed) so the player can reach it.

**Cleanse battle:**
- Interaction → battle via `GameBus.enemy_engaged(enemy_data)`, same path EnemyNPC uses (WorldScene `_check_interactions()` / AUTO_BATTLE_RANGE proximity).
- Build the enemy_data dict with a boss-tier deck from `EnemyRegistry` (a strong existing type, or a dedicated "blight_heart" EnemyData `.tres` in `data/enemies/` — remember the `.uid` sidecar and a `preload()` const in EnemyRegistry per CLAUDE.md Android rules).
- Tag the dict with `enemy_data["blight_heart_id"] = heart_id` so the win handler knows this was a cleanse fight. Note: the enemy buff from TID-242 should NOT also apply to the heart fight (it's already boss-tier) — or apply deliberately, but decide and document.

**On victory:**
- The battle reward flow goes through `GameBus.battle_won(result: Dictionary)` (coin rewards via EnemyData.coin_reward established in GID-002/GID-007 — follow that pattern).
- When the result/engaged context carries `blight_heart_id`:
  1. Append the id to `SaveManager.blight_cleansed_hearts` (mark save dirty).
  2. Award redemption points: increment `SaveManager.redemption_points` and emit `GameBus.redemption_points_changed(new_amount)` (signal already exists).
  3. Emit the `blight_changed()` signal from TID-242 so loaded chunks re-tint immediately — the purification wave is just the uniform refresh, which reads as the region cleansing in real time.
  4. `GameBus.hud_message_requested("The blight recedes…")` and remove the heart node from the world (and skip respawning it forever via the cleansed list).
- Consider an achievement hook (`achievement_unlocked`) for the first cleanse if the achievements system has room — optional.

**On defeat:** nothing permanent — `battle_lost` flows to the existing game-over handling; the heart stays.

**Persistence:** `blight_cleansed_hearts` field + migration default added in TID-241. Defeated-enemy persistence patterns (GID-009, `SaveManager.defeated_enemies`) are the reference for "never comes back".

**Testing:**
- Headless: cleansing logic (append id → BlightField reports chunk un-blighted), reward grant, signal emission. Battle itself is covered by existing battle tests.
- Run `godot --headless --path . -s tests/runner.gd`; exit 0 required.

**Mobile parity:** interaction must work via the existing tap-prompt flow, not keyboard-only (E-key AND touch prompt — same as Chest/EnemyNPC).

## Plan

1. Create `scenes/world/entities/BlightHeart.gd` — pulsing sphere visual, `init_from_data()`, `engage()` emitting `GameBus.enemy_engaged` with `blight_heart_id` tag.
2. Create `scenes/world/entities/BlightHeart.tscn` + `.uid` sidecars.
3. Add `"blight_heart"` entry to `EnemyRegistry._enemies` (boss deck, `is_boss=true`, `boss_hp=40`, `coin_reward=30`).
4. Spawn BlightHeart in `ChunkRenderer._spawn_entities()` using `BlightField.get_heart_at_chunk()`.
5. Register heart nodes in `WorldScene` via `register_blight_heart()` + `_find_nearby_blight_heart()`.
6. Wire `_check_interactions()` and `_handle_interact()` in WorldScene.
7. In `SceneManager._on_battle_won()`: detect `blight_heart_id`, call `mark_heart_cleansed`, `add_redemption_points(10)`, emit `blight_changed`, HUD message.
8. Enemy buff in BattleScene skips blight_heart fights via `enemy_data.has("blight_heart_id")` check.

## Changes Made

- **`scenes/world/entities/BlightHeart.gd`** (new): Pulsing dark-purple sphere with transparent aura. `init_from_data(data)` stores `_heart_id`. `engage()` emits `GameBus.enemy_engaged` with boss deck from `EnemyRegistry`, `is_boss=true`, `boss_hp=40`, `blight_heart_id=_heart_id`; then `queue_free()`.
- **`scenes/world/entities/BlightHeart.gd.uid`** (new): `uid://7hk5nm8rnf6v`
- **`scenes/world/entities/BlightHeart.tscn`** (new): Simple 2-node scene format, `uid://9y1t7xri1t8y`.
- **`autoloads/EnemyRegistry.gd`**: Added `"blight_heart"` entry with 16-card dark void deck, `is_boss=true`, `boss_hp=40`, `coin_reward=30`, difficulty_tier 4, lore text.
- **`scenes/world/ChunkRenderer.gd`**: In `_spawn_entities()`, added BlightHeart spawn block after story scroll — calls `BlightField.get_heart_at_chunk(cx, cz, world_seed)`, skips cleansed hearts, instantiates `_BlightHeartScene`, calls `init_from_data()`, `register_blight_heart()`.
- **`scenes/world/WorldScene.gd`**: Added `register_blight_heart(heart_id, node)`, `_find_nearby_blight_heart(px, pz, range)`. `_check_interactions()` checks `_find_nearby_blight_heart`. `_handle_interact()` calls `blight_heart_node.engage()`.
- **`autoloads/SceneManager.gd`**: In `_on_battle_won()`, after veterancy block: checks `blight_heart_id` in `pending_battle_enemy_data`; calls `mark_heart_cleansed`, `add_redemption_points(10)`, `blight_changed.emit()`, HUD message.

## Documentation Updates

- `docs/agent/blight-system.md` documents full system including entity, rewards, and spawn flow.
