# TID-170: Bestiary Data: Lore Fields on EnemyData + Encounter/Defeat Tracking

**Goal:** GID-045
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The data layer for the bestiary system. Extends `EnemyData` resource format with lore text; instruments SaveManager to track per-enemy encounter counts; wires GameBus signals to capture battle start/end events and increment counters.

## Research Notes

- **EnemyData resource script:** `data/EnemyData.gd` — currently exports `id`, `display_name`, `deck`, `drop_pool`, `coin_reward`, `is_boss`, `boss_hp`, `phase2_deck`, `difficulty_tier`. Add `lore_text: String` field (empty string default) via `@export var lore_text: String = ""`.
- **All bundled enemy .tres files:** Found in `data/enemies/` — currently 4 enemies: `undead_basic.tres`, `undead_horde.tres`, `ghoul_pack.tres`, `undead_elite.tres`. Each must receive a unique lore blurb (1–2 sentences describing the enemy's role/flavor); can be written directly into the `.tres` resource editing the `lore_text` field.
- **SaveManager new field:** `bestiary: Dictionary` (per-enemy-id tracking) with structure `enemy_id → {seen: int, defeated: int}`. Example: `{"undead_basic": {seen: 1, defeated: 2}, ...}`. Add to SaveManager instance vars after line 95 (after `redemption_points`).
- **SaveManager migration:** `CURRENT_SAVE_VERSION` is 14 (line 184). Add `_migrate_v14_to_v15()` function following the existing pattern (lines 188–249); backfill empty `bestiary` dict for old saves. Update `CURRENT_SAVE_VERSION = 15`. Call the migration function in the migration chain (check `_load_impl()` for how migrations are applied in sequence).
- **SaveManager load/save:** Persist `bestiary` in `_save_impl()` (line ~430 where JSON is built) and `_load_impl()` (line ~371 where fields are restored from JSON). Add lines: `bestiary = data.get("bestiary", {})` on load; `"bestiary": bestiary` in JSON dict on save.
- **GameBus signals:** Battle start and end already exist — `battle_won` is emitted at line 19 of `autoloads/GameBus.gd`; locate enemy_engaged signal (line 4). No new signals needed; reuse existing.
- **Battle start hook:** `SceneManager` connects to `GameBus.enemy_engaged` (search `SceneManager.gd` for the signal connection). On engage, extract `enemy_data.get("enemy_type", "")` and call `SaveManager.record_enemy_seen(type_id: String)` — this increments the `seen` count for that type. Hook location: add the call in the enemy_engaged handler or create a new private method `_on_enemy_engaged()` in SaveManager and connect it from SceneManager. Check where `_current_battle_enemy_id` is set (line ~263 in SceneManager._on_battle_won) — the enemy_type is available there.
- **Battle end hook (victory):** `SceneManager._on_battle_won()` already calls `mark_enemy_defeated()` (line 264). At the same location, also call `SaveManager.record_enemy_defeated(type_id: String)` to increment the `defeated` count. The enemy_type is extracted at line 258 and is available.
- **Method signatures in SaveManager:**
  ```gdscript
  func record_enemy_seen(type_id: String) -> void:
      if not bestiary.has(type_id):
          bestiary[type_id] = {"seen": 0, "defeated": 0}
      bestiary[type_id]["seen"] += 1
      mark_dirty()

  func record_enemy_defeated(type_id: String) -> void:
      if not bestiary.has(type_id):
          bestiary[type_id] = {"seen": 0, "defeated": 0}
      bestiary[type_id]["defeated"] += 1
      mark_dirty()

  func get_bestiary_entry(type_id: String) -> Dictionary:
      return bestiary.get(type_id, {"seen": 0, "defeated": 0})
  ```
- **EnemyRegistry integration:** The registry already exports all enemy types via `_ensure_loaded()` (line 16) which loads from `data/enemies/*.tres`. To enumerate all enemies for the bestiary UI, add a static method: `static func get_all_enemy_ids() -> Array[String]` — iterate `_enemies.keys()` and return sorted or in a stable order (e.g., by difficulty_tier then id).
- **UID/preload rules:** EnemyData .tres files already exist with .uid sidecars. No new resource creation; only editing existing .tres files to add lore_text. The .uid files already point to the resources, so no new sidecar generation is needed.
- **Tests:** Headless test `tests/test_bestiary_data.gd` covering:
  1. `SaveManager.record_enemy_seen()` increments seen count
  2. `SaveManager.record_enemy_defeated()` increments defeated count
  3. `SaveManager.get_bestiary_entry()` returns correct counts
  4. Save round-trip: write save, reload, verify bestiary dict persists
  5. Migration: load a v14 save (no bestiary field), verify it backfills with empty dict
  6. Every enemy in `EnemyRegistry.get_all_enemy_ids()` has non-empty `lore_text` after writing the .tres updates

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
