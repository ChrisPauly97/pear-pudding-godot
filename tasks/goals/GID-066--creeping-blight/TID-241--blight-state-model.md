# TID-241: Blight State Model — Seeded Hearts, Day-Tick Spread, Persistence

**Goal:** GID-066
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

This is the foundation task for the blight system. It defines the pure logic: where Blight Hearts spawn in the world (seeded/deterministic), how their corruption spreads over in-game days, how the state persists in saves, and how to query blight status for any chunk. All rendering and gameplay effects depend on this logic being reliable and testable.

## Research Notes

**Blight Heart placement:**
- Hearts are placed deterministically from world_seed, scattered across the infinite map to create multiple regions of corruption.
- Suggest one Blight Heart per ~12×12 super-region of chunks (768×768 tile area), seeded from (world_seed, super_region_x, super_region_z).
- Use a hash function to decide if a given super-region gets a heart: `hash((world_seed, sx, sz)) % 3 == 0` → ~33% of super-regions have hearts (tunable).
- Safe zone: skip hearts near the origin chunk (0, 0) — suggest radius 6 chunks from origin, matching the spawn/safe area in InfiniteWorldGen.gd.
- Heart position within a super-region: deterministically pick a random chunk within the super-region and place the heart at a fixed location (e.g., chunk center, tile (8, 8)).
- Each heart has a unique `heart_id: String` (e.g., "heart_sx_sz") for tracking which ones have been cleansed.

**Spread mechanics:**
- Each heart spreads corruption in a growing circle (Chebyshev or Euclidean distance) as in-game days elapse.
- Spread function: `blighted_radius(days_elapsed: int) -> float` = initial_radius + days_elapsed * spread_rate.
  - Suggest initial_radius = 2 chunks, spread_rate = 0.5 chunks per day (so on day 0, hearts blight a 2-chunk radius; day 1 is 2.5, day 2 is 3, etc.).
  - Cap the radius at some maximum (e.g., 10 chunks) so the blight doesn't cover the entire map eventually (or let it, if that's the design).
- For a given chunk (cx, cz), compute its distance to the nearest heart (Euclidean or Chebyshev distance in chunk space).
- A chunk is blighted if: `distance_to_nearest_heart < blighted_radius(days_elapsed)` AND that heart has NOT been cleansed.

**Persistence:**
- **Do NOT add a new day counter** — `SaveManager.days_elapsed: int` already exists (SaveManager.gd:45) alongside `time_of_day: float` (line 42). Use `days_elapsed` directly as the spread input.
- SaveManager new field:
  - `blight_cleansed_hearts: Array[String]` — stores IDs of hearts that have been cleansed (e.g., ["heart_0_0", "heart_3_4"]). Initialize to empty Array in migration defaults.
- When a Blight Heart is cleansed (TID-243), add its id to `blight_cleansed_hearts` and mark dirty.

**Blight status query function:**
- Create `game_logic/world/BlightField.gd` with static methods:
  - `static func is_blighted(cx: int, cz: int, world_seed: int, days_elapsed: int, cleansed_hearts: Array) -> bool` — returns true if the chunk is in a spread radius.
  - `static func blighted_radius(days_elapsed: int) -> float` — returns the current spread radius.
  - `static func blight_intensity(cx: int, cz: int, world_seed: int, days_elapsed: int, cleansed_hearts: Array) -> float` — returns a 0–1 value representing how "blighted" the chunk is (useful for shader tinting; full blight at distance 0, fading near the edge of the radius).
  - `static func get_nearest_heart(cx: int, cz: int, world_seed: int, cleansed_hearts: Array) -> Dictionary` — returns info about the closest heart (id, position, distance) or null if none exist.
- These functions are pure (no autoload calls, all state passed as arguments) so they're headless-testable.
- Use the same deterministic heart-placement logic as the game logic (hash-based, seeded).

**Day tick hook:**
- The in-game day/night cycle is already implemented: WorldScene advances `SaveManager.time_of_day` and increments `SaveManager.days_elapsed` on rollover.
- No new counter needed — when `days_elapsed` changes, blight queries automatically return updated results since `days_elapsed` is an input to the pure functions.
- On day tick, all active chunks should re-query their blight status (may change from unblighted → blighted or vice versa).
- ChunkRenderer will be notified to re-tint (see TID-242).

**Testing:**
- Headless unit tests:
  - Verify hearts spawn at expected density (~33% of super-regions).
  - Verify same world_seed always produces same heart locations.
  - Verify blight spreads correctly (radius grows, distance calc is correct).
  - Verify cleansed hearts stop spreading.
  - Verify safe zone has no hearts.
- No gameplay test needed here (that's TID-242 and TID-243).

**Integration notes:**
- BlightField is a pure logic module — don't add state or autoload calls.
- Callers (ChunkRenderer, TID-243's Blight Heart script) call the static methods with SaveManager data passed in.
- This keeps the logic decoupled and testable.

## Plan

1. Create `game_logic/world/BlightField.gd` — pure static module with heart placement hash, spread radius, intensity, and blight query functions.
2. Create `game_logic/world/BlightField.gd.uid` sidecar.
3. Add `blight_cleansed_hearts: Array[String]` to SaveManager (field, migration v37→v38, new_game, load, save, mark_heart_cleansed, is_heart_cleansed).
4. Add `blight_changed()` signal to GameBus.
5. Add headless unit tests in `tests/unit/test_blight_field.gd`.

## Changes Made

- **`game_logic/world/BlightField.gd`** (new): Pure static module. `SUPER_SIZE=12`, `HEART_DENSITY=3` (~33%), `INITIAL_RADIUS=2.0`, `SPREAD_RATE=0.5`, `MAX_RADIUS=10.0`, `SAFE_CHUNK_RADIUS=6`. Functions: `get_heart_for_super`, `get_heart_at_chunk`, `blighted_radius`, `is_blighted`, `blight_intensity`, `get_nearest_heart`.
- **`game_logic/world/BlightField.gd.uid`** (new): `uid://l6x3ppwccatj`
- **`autoloads/SaveManager.gd`**: Added `blight_cleansed_hearts: Array[String] = []`; bumped `CURRENT_SAVE_VERSION` 37→38; migration `_migrate_v37_to_v38`; `new_game`, `load_save`, `save` updated; `mark_heart_cleansed(heart_id)` and `is_heart_cleansed(heart_id)` methods added.
- **`autoloads/GameBus.gd`**: Added `signal blight_changed()`.
- **`tests/unit/test_blight_field.gd`** (new): 8 tests covering density, determinism, safe zone, spread, capping, cleansing, and `is_blighted` / intensity mirroring.
- **`tests/unit/test_blight_field.gd.uid`** (new): `uid://qtgdmxuyohdh`

## Documentation Updates

- Added `docs/agent/blight-system.md` covering architecture, BlightField API, shader uniform, entity, rewards, and integration points.
