# Treasure Maps & Buried Caches

## Key Features

- Map fragments (counter, not inventory items) drop from infinite-world chests at 20% chance when no map is active
- Collecting 3 fragments auto-assembles a treasure map and reveals a seeded dig site
- Dig site placement is deterministic: `TreasureGen.get_dig_site(world_seed, treasures_completed)`
- `DigSpot` world entity spawns in the matching chunk; interacting awards coins + rare card and marks the map complete
- MapViewOverlay shows a gold × marker at the active dig site on named-map overlays
- JournalScene displays fragment count and active map status in a header row

---

## How It Works

### Save Fields (`autoloads/SaveManager.gd`)

| Field | Type | Description |
|---|---|---|
| `treasure_fragments` | `int` | 0–2 collected; resets to 0 on assembly |
| `active_treasure` | `Dictionary` | `{ "site_x": int, "site_z": int, "completed": bool }` or `{}` |
| `treasures_completed` | `int` | Counter of completed maps; used as salt for next site derivation |

**Version:** save version 19 (migration `_migrate_v18_to_v19`).

### Fragment Drop (`scenes/world/WorldScene.gd` `_handle_interact()`)

On chest open in the infinite world: if `active_treasure` is empty and `randf() < 0.20`, call `SaveManager.collect_treasure_fragment()` instead of spawning card/coin items. Fragment drops are suppressed while a map is active to avoid stacking.

`collect_treasure_fragment()` increments the counter and auto-calls `_assemble_treasure_map()` when fragments reach 3, resetting the counter, computing the dig site, and emitting `GameBus.treasure_map_assembled`.

### Dig Site Derivation (`game_logic/world/TreasureGen.gd`)

```gdscript
static func get_dig_site(world_seed: int, treasure_counter: int) -> Vector2i
```

- Hashes `world_seed ^ (treasure_counter * 2654435761)` for angle and radius
- Radius range: 100–200 tiles from world origin
- Nudges to the nearest walkable grass tile in a 5×5 neighborhood (expanding outward)

### DigSpot Entity (`scenes/world/entities/DigSpot.gd / .tscn`)

- Spawned by `ChunkRenderer._spawn_entities()` when the active (non-completed) dig site tile falls inside the chunk being built
- Visual: brown earth mound (0.5×0.5×0.5) + gold stake (0.06×0.8×0.06) above at y=0.9
- `dig()` method: rolls coins (50–200), picks random card at tier-3 rarity, awards via `SaveManager`, calls `SaveManager.complete_treasure()`, queues self for free
- WorldScene tracks the single active `DigSpot` node via `_digspot_node`; `register_digspot()` sets it; `_find_nearby_digspot()` checks proximity; `_handle_interact()` calls `dig()`

### Map Overlay Marker (`scenes/ui/MapViewOverlay.gd`)

`_draw_digsite(canvas)` is called from `_on_draw()`. Converts dig site tile coords to panel pixels via `_world_to_panel()` (same helper used for all entity dots). Draws an amber arc + X cross (8 px radius, 2 px stroke).

### Journal Display (`scenes/ui/JournalScene.gd`)

A gold `_treasure_label` is inserted above the two-panel scroll layout. `_refresh_treasure_panel()` reads `SaveManager.treasure_fragments` and `active_treasure` to display:
- "Map Fragments: N / 3" (no map)
- "Active dig site at (X, Z)" (map assembled, not yet dug)
- "Treasure Excavated!" (completed)

---

## Integrations with Other Features

- **Chest system** (`WorldScene._handle_interact()`): fragment drop is gated to infinite-world chests only (not dungeon chests)
- **ChunkRenderer** (`_spawn_entities()`): checks `SaveManager.active_treasure` each time a chunk is built; at most one DigSpot exists per save
- **AchievementToast** (via `SceneManager`): `fragment_collected` and `treasure_map_assembled` signals show toast messages
- **Journal** (`JournalScene`): treasure status displayed alongside lore scroll list

---

## Co-op note (GID-096)

Dig spots are tied to a player's **own** treasure-map fragment, so they are **per-player**
state, **not** shared-world state — they are deliberately excluded from the GID-096 co-op
world-object sync (which covers shared enemies and chests). Each player digs their own site.
See [multiplayer-coop.md](multiplayer-coop.md) → *Shared World-Object Sync*.

## Asset Requirements

- No new art assets required — DigSpot uses `StandardMaterial3D` with procedural meshes (brown earth + gold stake)
- All new `.gd` files preload their dependencies explicitly (no `class_name` reliance)
