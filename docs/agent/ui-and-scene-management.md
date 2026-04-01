# UI and Scene Management

## Key Features

- `SceneManager` autoload owns the scene stack and routes all transitions (menu ↔ world ↔ battle ↔ game-over)
- Battle is an overlay: the world scene is detached from the tree during a fight and restored on win
- Map stack navigation supports arbitrarily deep dungeon nesting
- Day/night cycle updates sun/moon energy and sky colour every 0.5 seconds
- HUD elements: interact prompt, map name label, coin counter, dialogue fade
- All controls sized relative to viewport height (not fixed pixels) for resolution independence
- In-game `MapEditorScene` for level design and debug
- Mobile: `VirtualJoystick` overlay added at runtime when touchscreen detected

---

## How It Works

### SceneManager (`autoloads/SceneManager.gd`)

The central scene router. It is an autoload and the only node that calls `get_tree().change_scene_to_*()` or manually adds/removes scenes.

**State machine:**
```
MENU → WORLD (new game or continue)
WORLD → BATTLE (enemy_engaged signal)
BATTLE → WORLD (battle_won signal)
BATTLE → GAME_OVER (battle_lost signal)
GAME_OVER → MENU (return to menu button)
WORLD ← → WORLD (map transition via map_stack)
WORLD ← → INVENTORY (overlay, world stays in tree)
WORLD ← → SHOP (overlay, world stays in tree)
```

**Battle overlay pattern:**
```gdscript
# On enemy_engaged:
_world_node = get_tree().current_scene   # keep reference
get_tree().root.remove_child(_world_node) # detach (not free)
var battle = BattleScene.instantiate()
get_tree().root.add_child(battle)

# On battle_won:
get_tree().root.remove_child(battle)
battle.queue_free()
get_tree().root.add_child(_world_node)   # restore world
```

This keeps all world state (chunk cache, player position, NPC nodes) alive during the battle without re-loading.

### Map Transitions

`SceneManager.enter_map(map_name, target_door_id)`:
1. Push `{ map: current_map, pos: player_pos, return_door: current_door_id }` to `SaveManager.map_stack`
2. Replace `WorldScene`'s `WorldMap` with the new map loaded from file
3. Teleport player to the door tile whose ID matches `target_door_id`

`SceneManager.exit_map_via_door(door_node)`:
1. Pop top entry from `SaveManager.map_stack`
2. Restore previous `WorldMap`
3. Teleport player to the saved return door tile

### MenuScene (`scenes/ui/MenuScene.gd`)

- **New Game** button → opens `BiomeSelectionScene` overlay
- **Continue** button (shown only if save exists) → calls `SaveManager.load()` then loads `WorldScene`
- Background: static or animated title art

### BiomeSelectionScene (`scenes/ui/BiomeSelectionScene.gd`)

- Displays one button per biome (Grasslands, Forest, Desert, Scorched, Mountains)
- On selection: calls `SaveManager.new_game(biome)` then transitions to `WorldScene`
- UI scales buttons by viewport height

### GameOverScene (`scenes/ui/GameOverScene.gd`)

- Shown after `GameBus.battle_lost`
- "Return to Menu" button frees the game-over scene and loads `MenuScene`
- Does **not** delete the save file; player can continue from the last save

### Day/Night Cycle

In `WorldScene._process()`:
```gdscript
_time_of_day = fmod(_time_of_day + delta / DAY_LENGTH, 1.0)  # DAY_LENGTH = 600 s
if _cycle_update_timer >= 0.5:
    _apply_lighting(_time_of_day)
    _cycle_update_timer = 0.0
```

`_apply_lighting()`:
- `sun_light.light_energy = max(0, sin(time_of_day * PI))`
- `moon_light.light_energy = max(0, -sin(time_of_day * PI))`
- `WorldEnvironment` sky colour lerped between day and night palettes

`time_of_day` is read from `SaveManager` on load and written back on map exit.

### HUD (`WorldScene.gd`)

Labels and panels parented to a `CanvasLayer` (always on top):
- **Interact prompt** (`"Press E"`) — visible when player is within `INTERACT_RANGE` of a door, chest, or NPC; hidden otherwise
- **Map name label** — displayed for 3 seconds on map load, then fades
- **Coin counter** — reads `SaveManager.coins` each frame (updated on coin pickup)
- **Dialogue label** — shown above NPC; fades out after 4 seconds via `Tween`
- **Tutorial tip label** — yellow-tinted one-shot hints; auto-hides after 5 seconds (`TIP_DURATION`). Four triggers, each shown exactly once (flag stored in `SaveManager.story_flags`):
  - World entry → inventory button hint (`tutorial_inventory_tip`)
  - First NPC proximity → talk hint (`tutorial_npc_tip`)
  - First chest proximity → open hint (`tutorial_chest_tip`)
  - First enemy proximity → battle hint (`tutorial_enemy_tip`)
  - Android vs desktop control names chosen via `OS.has_feature("android")`

### BattleScene — First-Battle Tutorial Overlay

On the player's first battle (flag `tutorial_battle_tip` not set), a semi-transparent `ColorRect` overlay is shown centred on screen:
- Text: `"Drag a card from your hand to the board to play it.\nTap an enemy minion to attack with your minion."`
- `"Got it"` button dismisses immediately
- Auto-dismisses after 8 seconds (`TUTORIAL_DURATION`) via `_process()`
- Also dismissed on first successful card play in `_finish_hand_drag()`
- On dismiss: `SaveManager.set_story_flag("tutorial_battle_tip")` — never shown again

### MapEditorScene (`scenes/ui/MapEditorScene.gd`)

In-game debug tool (not accessible from the main menu in release builds):
- Loads a `WorldMap` and renders it in the same isometric view
- Tile-paint tools: toggle GRASS / WALL / HILL per click
- Entity placement: select type from toolbar, click to place
- Save button writes to `user://maps/<name>.txt`
- Load button opens a file picker for `user://maps/`

### Viewport-Relative UI Sizing

All controls size themselves in `_ready()` (and re-apply in `_notification(NOTIFICATION_RESIZED)`):

```gdscript
var vh: float = get_viewport().get_visible_rect().size.y
button.custom_minimum_size = Vector2(vh * 0.15, vh * 0.055)
label.add_theme_font_size_override("font_size", int(vh * 0.022))
```

Recommended fractions: buttons 12–18% width, 5–6% height; font 2–2.5% height.

---

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **GameBus** | Signal source | `enemy_engaged`, `battle_won`, `battle_lost`, `map_transition_requested`, `inventory_requested` all route through SceneManager |
| **SaveManager** | State source | `map_stack`, `current_map`, `time_of_day`, `coins` read/written by SceneManager and WorldScene |
| **BattleScene** | Overlay | Instantiated on `enemy_engaged`; removed on `battle_won` / `battle_lost` |
| **InventoryScene** | Overlay | Instantiated on `inventory_requested`; removed on close |
| **ShopScene** | Overlay | Instantiated on `shop_requested` (player interacts with MerchantNPC); lists all cards for 15 coins; removed on close |
| **WorldMap / InfiniteWorldGen** | Data source | SceneManager chooses which path to use based on map name (`"infinite"` key) |
| **Player** | Position sync | SceneManager teleports player on map transitions and door traversal |
| **VirtualJoystick** | Mobile input | Added to HUD CanvasLayer when `DisplayServer.is_touchscreen_available()` |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| MenuScene | `scenes/ui/MenuScene.tscn` | Title screen |
| BiomeSelectionScene | `scenes/ui/BiomeSelectionScene.tscn` | New-game biome picker |
| GameOverScene | `scenes/ui/GameOverScene.tscn` | Death screen |
| MapEditorScene | `scenes/ui/MapEditorScene.tscn` | Debug/editor tool |
| ShopScene | `scenes/ui/ShopScene.tscn` | Merchant shop overlay |
| VirtualJoystick scene | `scenes/ui/VirtualJoystick.tscn` | Mobile overlay |
| `SceneManager.gd` | `autoloads/SceneManager.gd` | Autoload singleton |
| UI theme / font | `assets/` | Optional custom theme `.tres`; falls back to Godot default |
| Title art | `assets/textures/` | Background for MenuScene (optional) |
