# TID-209: Mimic Chests — Seeded Ambush Encounters

**Goal:** GID-057
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Mimic chests are rare, seeded variants of normal dungeon chests that trigger a battle instead of granting loot when opened. Winning against a mimic grants the original chest's loot at a boosted rarity tier plus bonus coins, creating a risk-reward moment. Mimics are deterministic per dungeon seed and do not require cross-session persistence — the mimic state is implicit in the dungeon's .tres file.

## Research Notes

- **Seeded mimic assignment during DungeonGen**:
  - During `DungeonGen.generate()` (game_logic/world/DungeonGen.gd line 29–175), each placed chest rolls a 15% mimic chance from the dungeon RNG
  - **Chest placement locations** (DungeonGen):
    - Treasure room chests: line 129–135, ID prefix `"dtr_<num>"`, placed during room population loop (line 89–147)
    - End room chest: line 154–160, ID prefix `"dc_0"`, placed after room population
  - **Mimic roll**: After creating each chest dict, add: `if rng.randi() % 100 < 15: chest["is_mimic"] = true`
  - **Chest entity structure** (already supports arbitrary fields): `{"id": ..., "x": float, "z": float, "card_ids": [...], "opened": false, "is_mimic": bool}`

- **Mimic EnemyData resource**:
  - Create new `.tres` file at **data/enemies/mimic.tres** with EnemyData schema (cite: docs/agent/enemies-and-npcs.md for EnemyData fields)
  - **Mimic stats**: difficulty_tier = 2 (mid-tier, comparable to dungeon mid-room enemies). Deck: 3–4 common cards (ghost, skeleton, ghoul) mixed from existing ids
  - **Card IDs in deck**: Use existing card ids (e.g., `["ghost", "skeleton", "ghoul"]`) already defined in CardRegistry
  - **Add to EnemyRegistry**:
    - const preload in **autoloads/EnemyRegistry.gd**: `const _MIMIC := preload("res://data/enemies/mimic.tres")`
    - Register in `_ensure_loaded()` or add to `_enemies` dict manually: `_enemies["mimic"] = _MIMIC`
  - **Create .uid sidecar** for mimic.tres per CLAUDE.md (file creation rules): `uid://` + 12 random lowercase alphanumeric chars

- **Chest opening flow — branching on mimic flag**:
  - **Current flow** (WorldScene line 1182–1206):
    1. Find nearby chest via `_find_nearby_chest(px, pz, INTERACT_RANGE)`
    2. If `not opened`, set `opened=true`, play "chest_open" SFX
    3. Call `SceneManager.save_manager.mark_chest_opened(cid)` — records in `opened_chests: Array[String]`
    4. Spawn card items via `_spawn_card_items(card_ids, chest_pos, chest_tier)` (line 1258–1271)
    5. Spawn coin piles via `_spawn_coin_piles(origin)` (line 1273–1279)
  - **Mimic branching**:
    1. After line 1183 check, add: `if chest.get("is_mimic", false):`
    2. Instead of spawning cards, **emit GameBus.enemy_engaged** with mimic enemy_data:
       ```gdscript
       var mimic_data := {
           "id": cid,  # Reuse chest id as enemy id
           "x": chest_pos.x,
           "z": chest_pos.z,
           "alive": true,
           "tracking": false,
           "enemy_type": "mimic",
           "enemy_deck": EnemyRegistry.get_deck("mimic"),
       }
       GameBus.enemy_engaged.emit(mimic_data)
       ```
    3. **Do NOT call `mark_chest_opened()` here** — defer until victory (see below)
  - **Non-mimic path**: Continue as normal (spawn cards + coins)

- **Mimic battle victory flow**:
  - **Hook location**: SceneManager._on_battle_won() (autoloads/SceneManager.gd line 253–290+)
  - **Current victory logic**: Drop cards + coins based on enemy_type difficulty tier (lines 256–280)
  - **Add mimic check** (after line 255, before enemy_type read):
    ```gdscript
    var enemy_id: String = str(save_manager.pending_battle_enemy_data.get("id", ""))
    var is_mimic: bool = str(save_manager.pending_battle_enemy_data.get("enemy_type", "")) == "mimic"
    if is_mimic:
        # Find original chest by id to get card_ids
        var map: WorldMap = SceneManager.get_world_scene().world_map
        var chest_dict: Dictionary = map.find_chest_by_id(enemy_id)
        if not chest_dict.is_empty():
            # Grant boosted loot: tier+1 for rarity, +50% coins
            const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
            var orig_cards: Array[String] = []
            orig_cards.assign(chest_dict.get("card_ids", []))
            var chest_pos := Vector3(chest_dict.get("x", 0.0), 0.0, chest_dict.get("z", 0.0))
            # Spawn cards at tier+1 (tier 2→3, tier 3→4)
            _spawn_card_items(orig_cards, chest_pos, 3)  # Hardcode tier 3 for now, or compute from mimic difficulty
            # Bonus coins: roll 1.5× normal
            var coin_mult: float = 1.5
            SceneManager.save_manager.add_coins(int(rng.randi_range(10, 30) * coin_mult))
            # Mark chest opened (now safe, mimic defeated)
            SceneManager.save_manager.mark_chest_opened(enemy_id)
            # Toast feedback
            SceneManager._toast.show_text("Mimic defeated! Chest unlocked.")
            return
    ```
  - **WorldMap.find_chest_by_id(id: String) → Dictionary**: Add helper method to WorldMap if not present (search chests array for matching id)

- **Mimic defeat (loss) flow**:
  - **Hook location**: SceneManager._on_battle_lost() (autoloads/SceneManager.gd after _on_battle_won)
  - **Decision**: Mimic chest remains **closed and still mimics on re-open** — replayable within the dungeon visit
  - **Implementation**: Don't call `mark_chest_opened()` on loss. Chest stays `"opened": false` in memory (but is_mimic persists).

- **Visual feedback**:
  - **Mimic sprite/entity**: At battle start, the enemy entity is rendered as a chest-with-teeth sprite (via EnemyRegistry.get_sprite("mimic")). If TextureGen handles this, generate at runtime with prominent teeth/cracks.
  - **Toast on mimic encounter**: When chest opens and reveals mimic (before battle), show via `AchievementToast.show_text("It's a mimic!")` (SceneManager._toast, line 67 in docs/agent/ui-and-scene-management.md) + play a sting audio cue
  - **Audio sting**: `AudioManager.play_sfx("mimic_reveal")` or reuse "enemy_alert" if available

- **Dungeon persistence**:
  - **Mimic flag is part of chest dict** in the saved .tres file. When dungeon is saved after generation, `chest["is_mimic"] = true/false` is serialized.
  - **On re-entry**, the .tres is reloaded with is_mimic flag intact. Mimics remain mimics across visits.
  - **Opened state**: Mimic chests opened in victory have `"opened": true` written to the .tres file, so they don't respawn.

- **Headless tests**:
  1. **Seeded determinism**: Generate dungeon twice with same seed → same chests are mimics (same list of ids with is_mimic=true)
  2. **Seeded variation**: Generate with different seed → different chest may or may not be mimic (15% chance per chest, varies per seed)
  3. **No mimic** (low-seed run): Generate dungeon with seed tuned to roll <15% on all chests → no is_mimic=true in result
  4. **Mimic battle trigger**: Open mimic chest → `GameBus.enemy_engaged` emitted with enemy_type="mimic"
  5. **Victory loot**: After mimic battle victory, chest is marked opened and cards are spawned at tier 3
  6. **Defeat re-playable**: After mimic battle loss, chest remains unopened (is_mimic flag still true, reopenable)
  7. **Toast message**: Verify `AchievementToast.show_text()` called with "It's a mimic!"
  8. **Mimic EnemyData**: EnemyRegistry.get_deck("mimic") returns non-empty array of valid card ids

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
