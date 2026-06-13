# TID-161: WeatherManager Autoload + Save Fields + GameBus Signals

**Goal:** GID-042  
**Type:** agent  
**Status:** done  
**Depends On:** —

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

The scheduler that drives biome weather systems. A single autoload tracks per-weather cooldowns, fires events on randomized intervals, and persists state so weather cycles survive restarts. Weather only ticks in the infinite world (disabled for named maps/dungeons); TID-162 and TID-163 consume the current weather state and apply visuals/mechanics.

## Research Notes

- **New autoload:** `autoloads/WeatherManager.gd`, registered in `project.godot` after SaveManager (reads/writes save state). Core API:
  - `register_weather(weather_id: String, biome_id: int)` — static method called at engine startup to register which weather types can occur in each biome (e.g. `WeatherManager.register_weather("rain", BiomeDef.GRASSLANDS)`); weights all equally.
  - `current_weather: String` — read-only property; `""` means clear. Exposed for TID-162 (visuals) and TID-163 (battle modifier).
  - `current_duration: float` — remaining seconds until weather changes (read-only); used by HUD to show countdown.
  - `_process(delta)` — accumulate time only while the player is in the **infinite world**. Determine context: check `SaveManager.current_map == "main"` (the sole infinite-world map name per **docs/agent/world-generation.md** and **scenes/world/WorldScene.gd** line 144 `current_map = "main"`); do NOT process for named maps or dungeon maps.
  - When a weather's timer expires, roll the next interval from the biome's weighted table, call `_pick_weather(current_biome)`, emit `GameBus.weather_changed(weather_id, duration)`.
  - `_pick_weather(biome_id: int) -> String` — return a weather ID (or `""` for clear) weighted by the biome table. Use seeded RNG per biome to avoid repetition (do not regenerate the seed each frame; use a per-biome RNG instance with seed = `world_seed ^ biome_id`).
  - Per-biome weighted tables (hardcoded or light configuration; tables shown in TID-162 Research Notes — suggestion: GRASSLANDS/FOREST 60% clear, 30% rain, 10% heavy_rain; DESERT 70% clear, 25% sandstorm, 5% dust_devil; SCORCHED 50% clear, 35% ash_fall, 15% volcanic; MOUNTAINS 55% clear, 30% snow, 15% blizzard).
- **Save integration via SaveManager:** Add field `weather: Dictionary` with shape `{ "id": String, "duration": float, "biome_id": int }` to track the **most recent** weather state. Persist `id` (the weather_id) and `duration` (remaining time) on the dirty-flag cycle (every 2 seconds max). On save, snapshot current weather + remaining time; on load, restore and resume the timer at the saved remaining value. **Migration:** In `SaveManager._migrate()`, add `if not data.has("weather"): data["weather"] = { "id": "", "duration": 0.0, "biome_id": 0 }` — matching the pattern from **autoloads/SaveManager.gd** lines 114–121.
- **World context detection:** Iterate through the biome table periodically (every 5 seconds) to detect biome changes via `InfiniteWorldGen.biome_for_chunk(player_chunk_x, player_chunk_z, SaveManager.world_seed)` — mirroring how **scenes/world/WorldScene.gd** lines 62 and 300+ manage `_current_biome`. Store `_current_biome: int` in WeatherManager; on biome change, reset the weather timer so a new weather rolls immediately for the new biome.
- **Signals (update GameBus):** Add `weather_changed(weather_id: String, duration: float)` and optionally `weather_ended(weather_id: String)`. See **autoloads/GameBus.gd** structure (lines 1–44).
- **Interval rolling:** Min/max durations per weather type (not per biome). Suggestion: clear 120–300s, rain/rain_heavy 60–180s, sandstorm 90–240s, ash/volcanic 80–200s, snow/blizzard 100–220s. Store as a static dict keyed by weather_id.
- **Headless tests** (`tests/unit/test_weather_manager.gd`):
  - Test interval rolling: register a weather, advance time, verify `weather_changed` signal fires and state is updated.
  - Test biome switching: verify weather resets when biome changes mid-cycle.
  - Test save round-trip: serialize current weather + duration to SaveManager, load, verify state restored exactly.
  - Test infinite-world-only: set `SaveManager.current_map = "dungeon"`, advance time, verify no weather change fires.
- **docs/agent/signals-and-constants.md:** Add row to the Signal Reference Table: `weather_changed` emitted by WeatherManager, listened to by WorldScene/BattleScene, payload `weather_id: String, duration: float`.

## Plan

1. Add `weather_changed(weather_id, duration)` signal to `GameBus.gd`
2. Add `weather: Dictionary` field to `SaveManager.gd`, bump version to 19, add migration, update load/save
3. Create `autoloads/WeatherManager.gd` — `_process` ticks only when `SaveManager.current_map == "main"`; `on_world_entered()` restores from save; `set_biome()` resets timer; `_pick_weather()` uses per-biome RNG
4. Register WeatherManager in `project.godot` after SaveManager
5. Write `tests/unit/test_weather_manager.gd` — interval, biome switch, save round-trip, world-only tests
6. Add suite to `tests/runner.gd`
7. Update `docs/agent/signals-and-constants.md`

## Changes Made

- `autoloads/GameBus.gd`: Added `weather_changed(weather_id: String, duration: float)` signal
- `autoloads/SaveManager.gd`: Added `weather: Dictionary` field; bumped save version to 19; added `_migrate_v18_to_v19()` migration; updated `load_save()`, `save()`, and `new_game()` to handle the field
- `autoloads/WeatherManager.gd` (new): Per-biome weighted weather tables; `on_world_entered()` restores from save; `set_biome()` resets timer on biome change; `_process()` ticks only when `current_map == "main"`; `_pick_weather()` uses seeded per-biome RNG; `_change_weather()` emits `GameBus.weather_changed`; `_sync_to_save()` writes to `SaveManager.weather`
- `project.godot`: Registered `WeatherManager` autoload after `SaveManager`
- `tests/unit/test_weather_manager.gd` (new): Tests for `_pick_weather`, `_change_weather` signal, `set_biome`, save round-trip, and world-only gating
- `tests/runner.gd`: Added `test_weather_manager.gd` suite

## Documentation Updates

- `docs/agent/signals-and-constants.md`: Added `weather_changed` row to the Signal Reference Table
