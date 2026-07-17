# Save System

## Key Features

- **3 save slots**: `user://save_slot_1.json`, `save_slot_2.json`, `save_slot_3.json`; active slot set via `SaveManager.set_active_slot(n)` before load/save
- Legacy migration: if `user://save.json` exists and no slot files exist, it is automatically copied to slot 1 on first launch after update
- Batched disk writes: changes are queued and flushed at most every 2 seconds (dirty flag pattern)
- Automatic field migration: old saves missing new fields are backfilled with defaults on load
- Tracks player deck, owned cards, position, map stack, defeated enemies, opened chests, coins, and world configuration
- `SaveManager` is a global autoload — all systems read/write through it without touching the file directly

---

## How It Works

### File Location and Format

```
user://save_slot_1.json   # slot 1 (default)
user://save_slot_2.json
user://save_slot_3.json
user://save.json           # legacy single-save (migrated to slot 1 on first run)
```

`user://` resolves to a platform-specific user data directory (e.g. `~/.local/share/pear-pudding/` on Linux, `AppData/Roaming/` on Windows).

**Slot API:**
- `SaveManager.set_active_slot(n)` — set which slot subsequent `save()` and `load_save()` calls target
- `SaveManager.has_save_slot(n) -> bool` — check if slot n has a save file
- `SaveManager.get_slot_metadata(n) -> Dictionary` — returns `{current_map, coins, last_saved}` without full load
- `SaveManager.delete_save_slot(n)` — removes the slot file and backups

The file is a flat JSON object:

```json
{
  "player_deck": ["ghost", "ghost", "skeleton", "zombie"],
  "owned_cards":  ["ghost", "ghost", "ghost", "skeleton", ...],
  "current_map":  "main",
  "player_x":     15.0,
  "player_z":     22.0,
  "map_stack":    [],
  "defeated_enemies": ["enemy_cx2_cz1_0", "enemy_cx2_cz1_1"],
  "opened_chests":    ["chest_cx3_cz0_0"],
  "coins":         0,
  "time_of_day":   0.42,
  "world_seed":    839274,
  "starting_biome": "grasslands"
}
```

### Dirty Flag and Batched Writes

Every mutating method (`add_card`, `update_position`, `mark_enemy_defeated`, etc.) sets `_dirty = true`. A 2-second `Timer` (`SAVE_INTERVAL`) calls `_flush_if_dirty()`, which clears the flag and dispatches the write — preventing per-frame I/O.

### Background (Async) Flush

The batched flush is **asynchronous** — a full save is a multi-hundred-KB pretty-printed JSON plus an HMAC-SHA256 signature, a payload-escaping outer stringify, a `.bak` copy, and an atomic tmp-rename. Doing that on the main thread caused visible gameplay hitches (worst around chest openings, where every loot pickup re-dirties the save). The split:

- `_flush_if_dirty()` (2 s timer) → `_save_async()`: deep-copies the state snapshot on the main thread (`_collect_save_data().duplicate(true)` — mutation-safe), then runs `_write_save_payload()` on a `WorkerThreadPool` task. `_async_save_task` holds the task id; only one background write runs at a time (if one is still in flight, the flag stays set and the next tick retries).
- `save()` (public, synchronous): used by explicit save points — scene transitions, battle end, pause menu. Waits for any in-flight background write (`_await_async_save()`), then writes inline. Never two writers on the same slot's tmp file.
- `_flush_now()` (shutdown path): `NOTIFICATION_WM_CLOSE_REQUEST` / `EXIT_TREE` / `APPLICATION_PAUSED` / `FOCUS_OUT` flush fully inline, because the process may die before a background task or deferred call ever runs.
- `_collect_save_data()` assembles the save Dictionary from live state (references, not copies) — main thread only.
- `_write_save_payload(data, slot)` is thread-safe: it touches only its arguments, pure path helpers, and the filesystem, and reports completion via `call_deferred`.
- `delete_save_slot()` also waits for an in-flight write so a background flush can't resurrect a just-deleted file.

### Field Descriptions

| Field | Type | Description |
|---|---|---|
| `player_deck` | `Array[String]` | Card IDs in the active battle deck |
| `owned_cards` | `Array[String]` | All card IDs collected (one entry per copy) |
| `current_map` | `String` | Name of the currently loaded map |
| `player_x`, `player_z` | `float` | Last recorded player tile position |
| `map_stack` | `Array[Dictionary]` | Nested map navigation history (see Named Maps doc) |
| `defeated_enemies` | `Array[String]` | Unique IDs of enemies already beaten (prevents re-grinding) |
| `opened_chests` | `Array[String]` | Unique IDs of opened chests |
| `coins` | `int` | Currency balance (plumbed, not yet used in gameplay) |
| `time_of_day` | `float` | 0–1 cycle position; restored into WorldScene on load |
| `world_seed` | `int` | Fixes infinite world layout for this save |
| `starting_biome` | `String` | Biome override for the player's safe starting zone |
| `equipped_weapon` | `String` | ID of the currently equipped weapon (`""` = none); added v5 |
| `collected_scrolls` | `Array[String]` | IDs of lore scrolls already collected; added v6 |
| `xp` | `int` | Total XP earned; added v12 |
| `level` | `int` | Current level (derived from XP); added v12 |
| `skill_points` | `int` | Unspent skill points from level-ups; added v12 |
| `unlocked_skills` | `Array[String]` | Skill IDs that have been purchased; added v12 |
| `magic_type` | `String` | Player's home magic type: `"light"`, `"dark"`, or `""` (not yet chosen); added v13 |
| `corruption_points` | `int` | Currency earned via dark dialogue choices, spent on cross-magic light skills; added v13 |
| `redemption_points` | `int` | Currency earned via light dialogue choices, spent on cross-magic dark skills; added v13 |
| `pending_battle_state` | `Dictionary` | Serialized `GameState` snapshot of an in-progress battle; `{}` when not in a battle. Set by `set_pending_battle_state()`, cleared by `clear_pending_battle_state()` on win/loss; added v14 |
| `spire_run` | `Dictionary` | Active Endless Spire run record. Keys: `active` (bool), `floor` (int, 1-based), `draft_deck` (Array of card ID strings), `hero_hp` (int), `seed` (int), `enemies_defeated` (int), `cards_drafted` (int). Default `{"active": false}` means no run in progress; added v16 |

### Migration History

| Version | Added fields |
|---|---|
| v1 | `owned_cards` |
| v2 | `world_seed`, `starting_biome` |
| v3 | `story_flags` |
| v4 | `days_elapsed`, `last_respawn_day` |
| v5 | `equipped_weapon` |
| v6 | `collected_scrolls` |
| v7 | `owned_weapons` (Array[String] initially) |
| v8 | `settings`, `achievement_progress`, `unlocked_achievements`, `visited_biomes` |
| v9 | `visited_dungeon_rooms` |
| v10 | `owned_cards` converted to `Array[Dictionary]` instances; `essence` added |
| v11 | `equipped_armor`, `equipped_ring`, `equipped_trinket`, `owned_armor`, `owned_rings`, `owned_trinkets` |
| v12 | `xp`, `level`, `skill_points`, `unlocked_skills` |
| v13 | `magic_type`, `corruption_points`, `redemption_points` |
| v14 | `pending_battle_state` |
| v15 | `defeated_duelists` |
| v16 | `spire_run` |
| v30 | `owned_weapons` converted from `Array[String]` to `Array[Dictionary]` `{weapon_id, upgrade_level}` (GID-052) |

### Migration

On `load()`, after parsing the JSON, `SaveManager._migrate(data)` checks for missing keys and inserts defaults:

```gdscript
func _migrate(data: Dictionary) -> void:
    if not data.has("coins"):
        data["coins"] = 0
    if not data.has("time_of_day"):
        data["time_of_day"] = 0.0
    if not data.has("starting_biome"):
        data["starting_biome"] = "grasslands"
    # …add new fields here for future versions
```

This means any old save file continues to work after a game update.

### New Game

`SaveManager.new_game(head_start: bool = false)` resets all fields to a true level-1
baseline: `xp = 0`, `level = 1`, `skill_points = 0`, `coins = 50`, starter deck of 12
commons (3× ghost/skeleton/zombie/ghoul) plus 2 extra owned cards. `world_seed` and
`starting_biome` are set by `SceneManager.start_new_game_with_biome` *before* calling
`new_game()`, so they are deliberately not reset inside it. The file is written
immediately (not deferred) so the new state is committed before `WorldScene` loads.

**Head Start (TID-443 / BID-049):** passing `head_start = true` seeds a boosted start —
`xp = 11250`, `level = 15`, `skill_points = 14`, `coins = 5000` (values kept consistent
with the `xp_for_level` curve: `_compute_level(11250) == 15`). Opt-in via the
"Head Start (debug)" `CheckButton` on `BiomeSelectionScene`, threaded through
`SceneManager.start_new_game_with_biome(biome_id, head_start)`. These were previously the
*unconditional* new-game values (debug state leaked via PR #290); the toggle preserves
them as a user-requested option.

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **SceneManager** | Owner | Holds a reference to `SaveManager`; calls `save_position()` on map exit |
| **BattleScene** | Reader | Reads `player_deck` at battle start to populate the player's draw pile |
| **InventoryScene** | Read + Write | Reads/writes `owned_cards` and `player_deck` as the player edits their deck |
| **WorldScene** | Reader + Writer | Reads `time_of_day`, `current_map`, `player_x/z` on load; writes position on unload |
| **InfiniteWorldGen** | Reader | Reads `world_seed` and `starting_biome` to seed the deterministic chunk generator |
| **Chest / EnemyNPC** | Writers | Call `mark_chest_opened(id)` / `mark_enemy_defeated(id)` to prevent respawn |
| **StoryScroll** | Writer | Calls `mark_scroll_collected(id)` / `is_scroll_collected(id)` |
| **MenuScene** | Trigger | "Continue" button calls `SaveManager.load()`; "New Game" calls `SaveManager.new_game()` |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| `SaveManager.gd` | `autoloads/SaveManager.gd` | Autoload singleton; registered in `project.godot` |
| Save file | `user://save.json` | Created/overwritten at runtime; not shipped with the game |

No textures, shaders, or scene files are required by the save system itself.
