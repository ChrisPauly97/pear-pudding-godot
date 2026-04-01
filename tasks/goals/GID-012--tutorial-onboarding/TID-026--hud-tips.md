# TID-026: Proximity-triggered HUD tips in WorldScene

**Goal:** GID-012
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

New players have no guidance on controls. This task adds a one-shot contextual tip label to the existing `WorldScene` HUD `CanvasLayer`. Tips use the same Tween-fade pattern already in place for `_dialogue_label`. Each tip fires once and is remembered via `SaveManager.story_flags` (reusing the existing `set_story_flag` / `get_story_flag` API — no new SaveManager fields needed).

Four trigger events:
1. First proximity to an NPC → `"Press E to talk"` / `"Tap to talk"` (flag: `tutorial_npc_tip`)
2. First proximity to a chest → `"Press E to open"` / `"Tap to open"` (flag: `tutorial_chest_tip`)
3. First proximity to an enemy → `"Walk into an enemy to start a battle"` (flag: `tutorial_enemy_tip`)
4. First world entry → `"Press I for your inventory"` / `"Tap the inventory button"` (flag: `tutorial_inventory_tip`)

## Research Notes

**Key files:**
- `scenes/world/WorldScene.gd` — target file
- `autoloads/SaveManager.gd` — `set_story_flag(key)` / `get_story_flag(key)` API; `story_flags: Dictionary`

**HUD structure (WorldScene.gd ~line 92):**
```gdscript
@onready var _hud: CanvasLayer = $HUD
@onready var _interact_label: Label = $HUD/InteractPrompt
@onready var _map_label: Label = $HUD/MapLabel
@onready var _coin_label: Label = $HUD/CoinLabel
var _dialogue_label: Label          # created dynamically in _ready()
var _dialogue_timer: float = 0.0
const DIALOGUE_DURATION: float = 4.0
```

**Dialogue label creation pattern (~line 240):**
```gdscript
_dialogue_label = Label.new()
_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
_dialogue_label.add_theme_font_size_override("font_size", font_size)
_dialogue_label.add_theme_color_override("font_color", Color.WHITE)
_dialogue_label.add_theme_color_override("font_shadow_color", Color.BLACK)
_dialogue_label.add_theme_constant_override("shadow_offset_x", 2)
_dialogue_label.add_theme_constant_override("shadow_offset_y", 2)
_dialogue_label.size = Vector2(vp.x * 0.6, vp.y * 0.15)
_dialogue_label.position = Vector2(vp.x * 0.2, vp.y * 0.78)
_dialogue_label.hide()
_hud.add_child(_dialogue_label)
GameBus.hud_message_requested.connect(_show_dialogue)
```

**_show_dialogue pattern (~line 982):**
```gdscript
func _show_dialogue(text: String) -> void:
    _dialogue_label.text = text
    _dialogue_label.show()
    _dialogue_timer = DIALOGUE_DURATION
```
And in `_process()`, `_dialogue_timer` counts down and hides the label when it reaches 0.

**Interaction proximity check (~line 906):**
```gdscript
func _check_interactions() -> void:
    var px: float = _player.position.x
    var pz: float = _player.position.z
    var enemy := _find_nearby_enemy(px, pz, IsoConst.INTERACT_RANGE)
    var chest := _find_nearby_chest(px, pz, IsoConst.INTERACT_RANGE)
    var door  := _find_nearby_door(px, pz, IsoConst.INTERACT_RANGE * 2.0)
    var npc   := _find_nearby_npc(px, pz, IsoConst.INTERACT_RANGE)
```
`_check_interactions()` is called every `INTERACT_INTERVAL` seconds from `_process()`.

**Android detection:** `OS.has_feature("android")` — already used for `_interact_label.text` at ~line 207.

**SaveManager flags:**
- `set_story_flag(key: String, value: bool = true)` — sets and marks dirty
- `get_story_flag(key: String) -> bool` — returns false if absent
- Tutorial flags to use: `tutorial_npc_tip`, `tutorial_chest_tip`, `tutorial_enemy_tip`, `tutorial_inventory_tip`

**Tip placement:** Position the tip label centrally near the top-third of screen (e.g. `y = vp.y * 0.25`) so it doesn't overlap the dialogue label at the bottom (`y = vp.y * 0.78`) or the interact prompt.

**Tween fade pattern:** Use `create_tween()` to alpha-fade in over 0.3s, hold, then fade out over 0.5s. Or reuse the timer pattern like `_dialogue_timer` since the label already does that.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
