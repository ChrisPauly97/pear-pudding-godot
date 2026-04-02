# TID-040: M-Key Full-Map View Overlay for Named Maps

**Goal:** GID-015
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players in named maps (towns, mansions, temples) have no way to see the full layout of the area they're in. This task adds a full-map overlay toggled by the M key, showing the entire 100×100 tile grid with color-coded tiles and entity markers.

## Research Notes

### Existing patterns to follow

- **Overlay pattern:** `InventoryScene` and `ShopScene` are instantiated and added as a child of the current WorldScene node when opened, then `queue_free()`d when closed. The same pattern applies here — no `SceneManager` state change needed (map view is non-blocking, gameplay can pause implicitly since the player won't be issuing movement while looking at the map).
- **Minimap reference:** `scenes/world/Minimap.gd` draws entity dots via a `_DotLayer` inner class using `_draw()`. The map view can use the same dot-drawing approach for entity markers.
- **WorldScene.gd:** Already handles key input in `_unhandled_input`. The M key check goes there. The overlay is only created when `_is_infinite == false` (named map mode).

### Architecture

**New file: `scenes/ui/MapViewOverlay.tscn` + `scenes/ui/MapViewOverlay.gd`**

The overlay is a full-screen `CanvasLayer` containing:
1. A semi-transparent dark background `ColorRect` (full viewport)
2. A centered panel `ColorRect` (dark, ~80% of viewport min dimension, square)
3. A `TextureRect` showing the tile grid as a generated `ImageTexture`
4. A `_DotLayer` (Control) drawn on top for player + entity dots
5. A close button (or just keyboard-only close)
6. A title label showing the map name

**Tile grid rendering:**
```gdscript
func _build_map_texture(world_map) -> ImageTexture:
    var img := Image.create(100, 100, false, Image.FORMAT_RGB8)
    for z in range(100):
        for x in range(100):
            var tile: int = world_map.get_tile(x, z)
            var col: Color = _tile_color(tile)
            img.set_pixel(x, z, col)
    return ImageTexture.create_from_image(img)
```

Tile color palette:
- `TILE_GRASS` (0) → `Color(0.28, 0.55, 0.22)` (green)
- `TILE_WALL` (1) → `Color(0.30, 0.25, 0.20)` (dark brown)
- `TILE_HILL` (2) → `Color(0.55, 0.42, 0.22)` (tan/brown)
- `TILE_PATH` (3) → `Color(0.62, 0.52, 0.35)` (sandy path)
- default → `Color(0.1, 0.1, 0.1)` (near-black for unknowns)

**Entity dot rendering (on `_DotLayer._draw()`):**
Convert tile coordinates → pixel coordinates on the overlay panel. Each entity is a small colored circle (radius ~3px at 100px scale, scaled with panel size):
- Player: white, radius 5
- NPCs: green
- Enemies: red
- Chests: gold
- Doors: blue
- Merchant: cyan

**Setup method signature:**
```gdscript
func setup(world_map, player_pos: Vector2, entities: Dictionary) -> void
```
Where `entities` is a dict with keys `"enemies"`, `"chests"`, `"doors"`, `"npcs"` → each a `Dictionary` of `id -> Node3D` (same dicts WorldScene already maintains as `_enemy_nodes`, `_chest_nodes`, `_door_nodes`, `_npc_nodes`). Player position is passed as tile coords (divide world pos by TILE_SIZE).

**Sizing (per CLAUDE.md UI rules):**
```gdscript
var vh: float = get_viewport().get_visible_rect().size.y
var panel_size: float = vh * 0.80
# TextureRect stretches to fill panel
```

### WorldScene changes

In `WorldScene.gd`:
1. Add `const MapViewOverlay = preload("res://scenes/ui/MapViewOverlay.gd")`  
   (or `.tscn` if a scene is needed for the CanvasLayer root)
2. Add `var _map_overlay: Node = null`
3. In `_unhandled_input(event)`, add:
```gdscript
if event.is_action_pressed("ui_map") and not _is_infinite:
    if _map_overlay != null:
        _map_overlay.queue_free()
        _map_overlay = null
    else:
        _map_overlay = _MapViewOverlay.new()  # or instantiate .tscn
        add_child(_map_overlay)
        _map_overlay.setup(world_map, _player.position, {
            "enemies": _enemy_nodes, "chests": _chest_nodes,
            "doors": _door_nodes, "npcs": _npc_nodes
        })
```
4. The overlay emits a `closed` signal when Escape is pressed (or M pressed again); WorldScene connects it to free the overlay.

### Input map
Add action `"ui_map"` bound to `KEY_M` in `project.godot` (InputMap section). Check existing input actions first to avoid duplicate names.

### Relevant files
- `scenes/world/WorldScene.gd` — input handling + overlay lifecycle
- `scenes/world/WorldScene.tscn` — no changes needed (overlay added at runtime)
- `scenes/world/Minimap.gd` — reference for dot-drawing pattern
- `game_logic/world/WorldMap.gd` — `get_tile(x, z)` used to build the image
- `autoloads/IsoConst.gd` — `TILE_GRASS`, `TILE_WALL`, `TILE_HILL`, `TILE_PATH`, `TILE_SIZE`
- `project.godot` — add `ui_map` InputMap action

### No .uid sidecar needed
`MapViewOverlay.gd` is a plain `.gd` script, not a shader/resource. If a `.tscn` is created, scenes manage their own UIDs internally — no sidecar required.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
