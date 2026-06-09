# TID-165: Seeded Dig-Site Placement + DigSpot World Entity with Interaction

**Goal:** GID-043
**Type:** agent
**Status:** pending
**Depends On:** TID-164

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Convert the assembled map's abstract coordinates into a concrete, deterministic dig site in the infinite world. The DigSpot entity spawns when the chunk loads and yields its treasure exactly once, then despawns.

## Research Notes

- **Deterministic site derivation:** Add a static helper to a new file `game_logic/world/TreasureGen.gd`:
  - `static func get_dig_site(world_seed: int, treasure_counter: int) -> Vector2i` — returns tile coords (tx, tz) in world tile space
  - Hash function: `var h: int = hash(world_seed ^ treasure_counter)` (or use the same `_chunk_seed()` pattern from `game_logic/world/InfiniteWorldGen.gd` line 60 with parameters adjusted)
  - Clamp result to a ring: distance from origin (0, 0) between 100 and 200 tiles (Manhattan or Euclidean; Manhattan simpler for seeding)
  - Convert hash to angle + radius: `var angle: float = float(h % 360)`, `var radius: int = 100 + (h % 100)`, then `var tx: int = int(radius * cos(angle))`, `var tz: int = int(radius * sin(angle))`
  - Nudge to nearest walkable tile: Use `InfiniteWorldGen.generate_chunk_data_only()` (see `game_logic/world/InfiniteWorldGen.gd` line 86) to fetch the chunk's tile grid. Scan a 5×5 neighborhood around the derived coords for the first TILE_GRASS tile. Return that tile's world coords.
  - On failure (no grass tile in neighborhood), try the next closest neighbor until one is found or return origin as fallback.
- **DigSpot entity scene:** Create `scenes/world/entities/DigSpot.gd` following the pattern of `scenes/world/entities/Chest.gd` (simple Node3D with mesh visuals):
  - Constructor/init: `func init_from_data(data: Dictionary) -> void` (matching Chest's pattern) with fields: `"id"` (string), `"x"`, `"z"` (world position), `"treasure_counter"` (for display or logging)
  - Sprite3D body: Use a simple shovel or treasure marker graphic (via existing art or TextureGen; ask design if unclear — for now, use a small box mesh with brown/gold coloring, 0.5 × 0.5 × 0.8 world units)
  - Sprite3D y-offset per CLAUDE.md: Position sprite at `y = 0.8 * 0.5 + 0.1 = 0.5` so the bottom edge clears the floor at y=0
  - Interact via `interact` action (pressing E on desktop, touching "Press E" prompt on mobile): Call a `_dig()` method
  - `_dig()` logic:
    - Roll treasure: coins = `rng.randi_range(50, 200)`, card = roll a rarity-weighted card drop using `CardDropUtil.roll_rarity(tier)` with tier=3 (for epic/legendary bias), then pick a random card from `CardRegistry.get_all_ids()` and apply `CardDropUtil.roll_stats(card_id, rarity)` (both in `game_logic/CardDropUtil.gd` lines 16–55)
    - Call `SaveManager.add_coins(coins)` and `SaveManager.add_card_instance(card_id, rarity, -1, -1, -1)`
    - Mark `SaveManager.active_treasure["completed"] = true`
    - Emit `GameBus.treasure_excavated()` signal (new signal, cite in GameBus)
    - Show toast: "Treasure excavated! +{coins} coins + [card name]"
    - Queue free the entity after toast
  - Sprite3D positioning: Place at the dig site tile center (world position from `InfiniteWorldGen` tile lookup)
- **Chunk spawning:** Modify `scenes/world/ChunkRenderer.gd` in the entity spawning loop (after line 268, after NPC spawning) to check if a dig site is active and matches the current chunk. If `SaveManager.active_treasure` is non-empty and not completed, and the chunk contains the dig-site coords, instantiate a DigSpot node. Cite the exact spawn path: the pattern for all entities is in `scenes/world/ChunkRenderer.gd` lines 233–268 (`for c_data in _chunk_data.chests:` etc.) — use the same `TerrainMath.spawn_entity()` pattern or direct instantiation like the NPC code (lines 258–268).
- **Entity spawn pattern:** Follow `scenes/world/entities/Chest.gd` instantiation — it's created as a child of the chunk and given `init_from_data()`. DigSpot follows the same pattern.
- **Headless tests:** Write tests for:
  - Deterministic derivation: `get_dig_site(seed, counter=0)` returns the same tile coords on repeat calls
  - Different counters produce different sites: `get_dig_site(seed, counter=0)` ≠ `get_dig_site(seed, counter=1)`
  - Walkable nudge: If the derived tile is a wall, the function returns a nearby grass tile instead
  - Treasure roll: Verify coins in range 50–200, card is rare/epic/legendary (mock CardRegistry)
  - Save persistence: After dig, `SaveManager.active_treasure["completed"]` is true and subsequent loads don't respawn the entity

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
