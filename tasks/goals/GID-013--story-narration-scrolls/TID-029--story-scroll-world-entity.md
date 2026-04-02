# TID-029: StoryScroll world entity + WorldMap SCROLL directive + named map placements

**Goal:** GID-013
**Type:** agent
**Status:** pending
**Depends On:** TID-028

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players need a physical world entity to find and collect. This task creates the `StoryScroll` scene (a glowing interactable in the world), adds `SCROLL x z scroll_id [FLAG:key]` parsing to `WorldMap`, and places the 7 named-map scrolls in the existing `.txt` map files.

## Research Notes

**WorldItem.gd** (`scenes/world/entities/WorldItem.gd`) — closest analogue:
- Extends `Node3D`; uses `Sprite3D` for visual, `Area3D` for detection
- Auto-collection for coins; E-key collection for cards
- `StoryScroll` should use E-key collection (similar to Chest) — scrolls are notable finds

**Chest.gd** (`scenes/world/entities/Chest.gd`) — interaction pattern to follow:
- `INTERACT_RANGE = IsoConst.INTERACT_RANGE` (1.5 world units)
- E-key triggered; checks if already opened via `SaveManager.is_chest_opened(id)`
- On interact: calls SaveManager, emits GameBus signal, plays SFX
- `StoryScroll` mirrors this but calls `SaveManager.is_scroll_collected(id)` and `mark_scroll_collected(id)`, emits `GameBus.story_scroll_collected(scroll_id)`

**WorldMap.gd** (`game_logic/world/WorldMap.gd`) — parser to extend:
- Read the file to find the directive parsing block (CHEST/NPC/DOOR/ENEMY)
- Add a new branch for `SCROLL`:
  ```gdscript
  elif directive == "SCROLL":
      var sx: int = int(parts[1])
      var sz: int = int(parts[2])
      var sid: String = parts[3] if parts.size() > 3 else ""
      var flag_key: String = ""
      for p in parts:
          if p.begins_with("FLAG:"):
              flag_key = p.substr(5)
      scrolls.append({ "id": "scroll_%s_%d_%d" % [sid, sx, sz], "scroll_id": sid, "x": sx, "z": sz, "flag_key": flag_key })
  ```
- Add `var scrolls: Array[Dictionary] = []` field alongside `chests`, `npcs`, `doors`
- `WorldScene` reads `world_map.scrolls` and spawns `StoryScroll` nodes (same loop pattern as chests)

**StoryScroll scene design:**
- Root: `Node3D` with script `StoryScroll.gd`
- Child: `Sprite3D` — use a parchment/book icon or a simple coloured quad; `billboard = BILLBOARD_ENABLED`; `pixel_size = 0.04`; positioned at `Vector3(0, 1.1, 0)` (matches sprite depth fix in CLAUDE.md)
- Child: `OmniLight3D` — soft gold glow (`color = Color(1.0, 0.85, 0.4)`, `light_energy = 0.6`, `omni_range = 2.0`) to make it findable
- Child: `Area3D` + `CollisionShape3D` (sphere, `radius = 1.2`) for proximity detection
- **On spawn**: if `SaveManager.is_scroll_collected(_scroll_id)` → `queue_free()` immediately (don't render already-collected scrolls)
- **In `_process()`**: check player proximity (same pattern as Chest — distance to `_player.position`); show/hide interact label via `GameBus.hud_message_requested` is NOT appropriate here (that's for dialogue) — instead set a `_near_player: bool` flag and let WorldScene's `_check_interactions()` handle the E-key prompt OR add a local label above the scroll

**Interaction pattern** — simplest consistent with Chest:
```gdscript
func setup(scroll_id: String, player_node: Node3D) -> void:
    _scroll_id = scroll_id
    _player = player_node
    if SaveManager.is_scroll_collected(_scroll_id):
        queue_free()

func _process(_delta: float) -> void:
    if _player == null:
        return
    var dist: float = position.distance_to(_player.position)
    _near_player = dist <= IsoConst.INTERACT_RANGE

func interact() -> void:
    if SaveManager.is_scroll_collected(_scroll_id):
        return
    SaveManager.mark_scroll_collected(_scroll_id)
    GameBus.story_scroll_collected.emit(_scroll_id)
    AudioManager.play_sfx("scroll_pickup")
    queue_free()
```

WorldScene calls `scroll.interact()` when E is pressed and `scroll._near_player` is true — same as it does for chests. WorldScene also adds this scroll to its `_scroll_nodes` array and checks proximity in `_check_interactions()`.

**Named map SCROLL placements** — add to map `.txt` files in `assets/maps/`:
- `madrian.txt`: `SCROLL <x> <z> scroll_larik_origins`
- `maykalene.txt`: `SCROLL <x> <z> scroll_martarquas_first_war`
- `farsyth_mansion.txt`: `SCROLL <x> <z> scroll_maiteln_order` and `SCROLL <x> <z> scroll_prophecy_text`
- `blancogov.txt`: `SCROLL <x> <z> scroll_farsyth_lineage` and `SCROLL <x> <z> scroll_blancogov_founding`
- `blancogov_temple.txt`: `SCROLL <x> <z> scroll_king_eldar_coronation`

Positions must be read from the actual map files during the Plan phase to find grass tiles that are accessible but slightly off the critical path (encourage exploration).

**SFX:** Add `"scroll_pickup": "res://assets/audio/sfx/scroll_pickup.wav"` to `AudioManager.SFX_PATHS`.

**UID sidecar:** Create `scenes/world/entities/StoryScroll.tscn.uid` — generate a 12-char random UID.

**WorldScene integration checklist:**
1. Preload `StoryScroll.tscn` as a constant
2. After loading map, iterate `world_map.scrolls` and spawn each
3. Pass `scroll.setup(entry.scroll_id, _player)` after adding to scene
4. Add to `_scroll_nodes: Array` field
5. In `_check_interactions()`, find nearest scroll within `INTERACT_RANGE`; show interact prompt; on E key call `scroll.interact()`
6. `_find_nearby_scroll()` helper following the pattern of `_find_nearby_chest()`

**GDScript Variant rule:** `var _scroll_nodes: Array[Node3D] = []` — typed array to avoid `:=` Variant error when indexing.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
