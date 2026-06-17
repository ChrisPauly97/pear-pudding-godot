# Night Hunts (GID-055)

## Key Features

- Three spectral enemy variants — `spectre_wisp` (tier 1), `spectre_haunt` (tier 2), `spectre_dread` (tier 3) — spawn only at night in the infinite world.
- At dawn all surviving spectres fade out (1-second tween on modulate alpha) and despawn.
- Defeating a spectre boosts the card drop rarity tier by 1 (capped at tier 4 / Legendary).
- Spectres appear as pale blue dots on the minimap vs red for normal enemies.
- A soft ambient nightfall cue plays at the sunset→night transition.
- A one-time tutorial popup ("Night Hunts") explains the mechanic on the first spectre spawn per play session.

## How It Works

### Night Window

Defined in `WorldScene._is_night(time_of_day: float) -> bool`:

```gdscript
static func _is_night(time_of_day: float) -> bool:
    return sin((time_of_day - 0.25) * TAU) < 0.0
```

Night spans roughly `time_of_day < 0.25` (midnight→pre-dawn) and `time_of_day > 0.75` (sunset→midnight). This mirrors the existing sun-height formula in `_update_day_night()`.

### Spawning

`WorldScene._update_nocturnal_spawns(delta)` runs every frame in the infinite world during night.

- Timer-driven: randomised interval 30–60 seconds, reset after each spawn event.
- Global cap of 12 alive nocturnal enemies; if the cap is reached, the timer resets but no enemy is spawned.
- Spawn position: `_find_nocturnal_spawn_pos()` samples tiles 5–12 world units from the player in the 4 cardinal directions, picking the first walkable grass tile found.
- Spectre type is selected by the player's chunk Manhattan distance from the world origin:
  - ≤3 chunks → `spectre_wisp`
  - ≤7 chunks → `spectre_haunt`
  - >7 chunks → `spectre_dread`
- Each spawned node receives `set_meta("is_nocturnal", true)` so the Minimap and post-battle logic can identify it.
- Spectral enemies are tracked in `_nocturnal_enemies: Dictionary` (spawn_id → {node, chunk}) separate from `_enemy_nodes`. They do **not** enter `SaveManager.defeated_enemies`.

### Despawning

- **Dawn transition**: `_despawn_nocturnal_enemies(fade: true)` runs when `_is_night` flips from `true` to `false`. Applies a 1-second modulate-alpha tween on each node, then `queue_free()`.
- **Chunk eviction**: `_evict_nocturnal_enemies_in_chunk(chunk_key)` is called from `_update_chunks()` when a chunk is unloaded; spectres in that chunk are freed immediately (no fade).

### Enemy Data

Stored inline in `EnemyRegistry._ensure_loaded()`:

| ID | Display Name | Tier | Coins | night_drop_boost |
|----|--------------|------|-------|-----------------|
| `spectre_wisp` | Wisp | 1 | 8 | true |
| `spectre_haunt` | Phantom | 2 | 12 | true |
| `spectre_dread` | Wraith | 3 | 18 | true |

All three are `is_tracking: true` (engage the player on proximity). Decks use existing card pool cards (ghost, shadow_bolt, soul_rend, wither, surge_spirit, void_creeper, dusk_wraith, soul_harvest, dark_pact).

### Drop Boost

`EnemyRegistry.get_night_drop_boost(type_id) -> bool` returns `true` for spectres.

In `SceneManager._on_battle_won()`, the drop tier is computed as:

```gdscript
var drop_tier: int = EnemyRegistry.get_difficulty_tier(enemy_type)
if EnemyRegistry.get_night_drop_boost(enemy_type):
    drop_tier = mini(drop_tier + 1, 4)
```

This is applied before `CardDropUtil.roll_rarity(drop_tier)`, giving spectres a one-tier rarity advantage capped at tier 4 (Legendary).

### Defeated-Enemy Persistence

Spectral enemies are transient. Detected by `enemy_type.begins_with("spectre_")` in `_on_battle_won()`:

- `SaveManager.mark_enemy_defeated()` is **not** called (enemy respawns next night).
- `SaveManager.record_enemy_defeated()` (bestiary/world tracking) is **not** called.
- XP is awarded normally (wisp +25, haunt +40, dread +60).

### Minimap

`Minimap._draw_enemy_nodes(canvas, origin)` replaces the generic `_draw_group()` call for enemies. It checks `n.get_meta("is_nocturnal", false)` and draws:

- Spectres: `Color(0.55, 0.75, 1.00)` (pale blue)
- Normal enemies: `Color(0.95, 0.20, 0.20)` (red)

### Audio

`AudioManager.SFX_PATHS["nightfall_ambient"]` → `res://assets/audio/sfx/nightfall.wav`. Called once per night window entry via `AudioManager.play_sfx("nightfall_ambient")`. Gracefully no-ops if the file doesn't exist.

### Tutorial

`TutorialRegistry._DATA["night_hunts"]` entry exists. Emitted via `GameBus.tutorial_popup_requested.emit("night_hunts")` on the first nocturnal spawn per session. A session flag `_night_hunt_tutorial_shown_session` prevents repeats within the same play session; `SaveManager.get_story_flag("seen_tutorial_night_hunts")` prevents it from ever showing again across restarts.

## Integrations with Other Features

- **Day/night cycle** (`WorldScene._update_day_night()`): Night window detection and dawn-fade triggered here.
- **Minimap** (`Minimap.gd`): `_draw_enemy_nodes()` reads `is_nocturnal` meta for color selection.
- **EnemyRegistry**: Spectre data stored inline alongside regular enemies; `get_night_drop_boost()` static method added.
- **SceneManager**: Drop boost and persistence exclusion logic in `_on_battle_won()`.
- **TutorialRegistry**: `night_hunts` entry.
- **AudioManager**: `nightfall_ambient` SFX key.

## Asset Requirements

- `res://assets/audio/sfx/nightfall.wav` — soft ambient nightfall sting (~1–3 s). Optional: `AudioManager.play_sfx()` no-ops if missing.
