# TID-032: Infinite world scroll placement via InfiniteWorldGen

**Goal:** GID-013
**Type:** agent
**Status:** done
**Depends On:** TID-029

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

One scroll (`scroll_martarquas_survivors`) is placed in the infinite world rather than a named map, encouraging exploration. This task adds seed-deterministic scroll placement to the chunk rendering pipeline so the scroll appears at a consistent world position per save and does not re-appear after collection.

## Research Notes

**Infinite world architecture** (from `docs/agent/world-generation.md`):
- `InfiniteWorldGen.gd` generates tile data per chunk
- `ChunkRenderer.gd` (or `WorldScene`) spawns entities from chunk data
- Chunks are keyed by `(chunk_x, chunk_z)` — 16×16 tile blocks
- Entity spawning in a chunk runs once when the chunk is first loaded into view

**Scroll placement algorithm — seed-deterministic probability:**

Only one infinite-world scroll (`scroll_martarquas_survivors`) is needed for the launch set. Rather than a global density pass, use a fixed-seed RNG per chunk:

```gdscript
func _get_chunk_scroll(cx: int, cz: int, world_seed: int) -> String:
    # Deterministic hash — same seed always produces same result
    var h: int = (cx * 73856093) ^ (cz * 19349663) ^ world_seed
    h = h & 0x7FFFFFFF  # ensure positive
    if h % SCROLL_CHUNK_RARITY != 0:
        return ""
    # Pick which scroll to place (only unplaced infinite-world scrolls eligible)
    var eligible: Array[String] = ["scroll_martarquas_survivors"]
    return eligible[h % eligible.size()]

const SCROLL_CHUNK_RARITY: int = 200  # approx 1 in 200 chunks gets a scroll
```

This is ~1 scroll per 200 chunks = ~1 scroll per 51,200 tiles. Adjust `SCROLL_CHUNK_RARITY` up to tune rarity.

**Where to add this:**
Read `InfiniteWorldGen.gd` and `WorldScene.gd` during Plan phase to determine the exact hook point. Expected location: wherever the chunk's entities are spawned (same loop that spawns enemies from chunk data). The scroll node is instantiated exactly like a named-map scroll — call `scroll.setup(scroll_id, _player)`.

**Scroll tile position within chunk:**
Use the same hash to pick a tile offset:
```gdscript
var tx: int = cx * IsoConst.CHUNK_SIZE + ((h >> 8) % IsoConst.CHUNK_SIZE)
var tz: int = cz * IsoConst.CHUNK_SIZE + ((h >> 16) % IsoConst.CHUNK_SIZE)
```
Check that the tile is `TILE_GRASS` (not wall or hill) before spawning. If not, skip — the next eligible chunk will have one instead.

**Already-collected guard:**
```gdscript
if SaveManager.is_scroll_collected(scroll_id):
    return   # don't spawn — already found on a previous session
```
This uses the same pattern as chests (`SaveManager.is_chest_opened`) and enemies (`SaveManager.is_enemy_defeated`).

**Chunk despawn / re-enter:**
When a chunk is unloaded and re-loaded (player circles back), the same deterministic hash fires again. The `is_scroll_collected` guard prevents re-spawning if already collected. If the player hasn't collected it yet, it reappears — consistent with how enemies work.

**No new SaveManager field needed:** `collected_scrolls` from TID-028 already covers this.

**IsoConst reference:**
- `IsoConst.CHUNK_SIZE = 16`
- `IsoConst.TILE_GRASS = 0`

**GDScript Variant note:** hash computation uses `int` literals — always use explicit `var h: int = ...` not `:=` with bitwise operations, as the result may be `Variant`.

## Plan

1. `InfiniteWorldGen.gd`: add `static func get_chunk_scroll_id(cx, cz, world_seed) -> String` using `_chunk_seed` + `SCROLL_CHUNK_RARITY = 200`.
2. `ChunkRenderer.gd`: preload `_StoryScrollScene`; add scroll spawn block in `_spawn_entities()` using `InfiniteWorldGen.get_chunk_scroll_id`, tile GRASS check, `is_scroll_collected` guard, then setup/register.
3. `WorldScene.gd`: add `func get_player() -> Node3D` and `func register_scroll(node: Node3D)` so ChunkRenderer can pass the player reference and register the scroll node for proximity detection.

## Changes Made

- `game_logic/world/InfiniteWorldGen.gd`: Added `const SCROLL_CHUNK_RARITY: int = 200` and `static func get_chunk_scroll_id(cx, cz, world_seed) -> String` — returns `"scroll_martarquas_survivors"` for ~1/200 chunks, `""` otherwise. Reuses existing `_chunk_seed` hash.
- `scenes/world/ChunkRenderer.gd`: Added `const _StoryScrollScene` preload and `const InfiniteWorldGen` preload. In `_spawn_entities()`, after doors/NPCs: calls `get_chunk_scroll_id`, checks tile is `TILE_GRASS`, checks `is_scroll_collected` guard, instantiates and positions StoryScroll, calls `world_scene.register_scroll()` for proximity detection.
- `scenes/world/WorldScene.gd`: Added `func get_player() -> Node3D` and `func register_scroll(node: Node3D)` so ChunkRenderer can pass the player reference and register scroll nodes into `_scroll_nodes`.

## Documentation Updates

None required — docs update deferred to TID-033.
