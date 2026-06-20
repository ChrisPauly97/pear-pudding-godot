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
- M key opens `MapViewOverlay` in named maps: full 100×100 tile grid as a color-coded image with entity dots; not available in infinite world mode
- All modal overlay scenes extend `BaseOverlay` (GID-073); shared builder helpers in `UiUtil`

---

## Overlay Framework (GID-073)

### BaseOverlay (`scenes/ui/BaseOverlay.gd`)

All modal overlay scenes extend `"res://scenes/ui/BaseOverlay.gd"` using a string-path extends (not class_name). The base class provides:

| Member | Description |
|---|---|
| `signal closed` | Emitted when the overlay should close |
| `_vh`, `_vw` | Viewport height/width, set in `_ready()` |
| `_build_backdrop(alpha, close_on_tap)` | Full-screen dark ColorRect; optional tap-to-close |
| `_build_centered_panel(w, h)` | Centered PanelContainer (no custom style applied) |
| `_build_margin_vbox(parent, margin_frac, sep_frac)` | MarginContainer + VBoxContainer inside parent |
| `_make_dark_glass_style()` static | StyleBoxFlat with dark-blue glass look (for SettingsScene, CardInspectOverlay) |
| `_close()` | Emits `closed`; scenes that also need `queue_free()` override this |
| `_input(event)` | Handles `ui_cancel` → `_close()` |

Overlays that additionally need `queue_free()` on close override `_close()`:
```gdscript
func _close() -> void:
    closed.emit()
    queue_free()
```

### UiUtil (`scenes/ui/UiUtil.gd`)

Static helper file (preload with `const _UiUtil = preload("res://scenes/ui/UiUtil.gd")`):

| Static method | Description |
|---|---|
| `rarity_color(rarity)` | Returns Color for common/rare/epic/legendary |
| `rarity_badge(rarity)` | Returns `[C]`/`[R]`/`[E]`/`[L]` badge string |
| `effect_summary(type, value, count, card_id)` | Human-readable weapon effect text |
| `make_title_label(text, vh)` | Gold-colored, center-aligned label at `vh*0.038` |
| `make_body_label(text, vh)` | Light gray label at `vh*0.022` |
| `make_separator()` | HSeparator |
| `make_close_button(vh, on_pressed)` | Standard Close button |

### Migrated Overlays

All 9 modal overlays extend BaseOverlay (as of GID-073): `InventoryScene`, `ShopScene`, `SkillTreeScene`, `CharacterScene`, `JournalScene`, `AchievementsScene`, `SettingsScene`, `TutorialPopup`, `CardInspectOverlay` (scenes/battle).

`BiomeSelectionScene` is a full-screen new-game scene (not a modal), so it does not extend BaseOverlay.

---

## How It Works

### SceneManager (`autoloads/SceneManager.gd`)

The central scene router. It is an autoload and the only node that calls `get_tree().change_scene_to_*()` or manually adds/removes scenes.

**State machine:**
```
MENU → WORLD (new game or continue)
WORLD → [GAMBIT PICKER] → BATTLE (enemy_engaged signal; picker skipped on resume or auto-skip)
BATTLE → WORLD (battle_won signal)
BATTLE → GAME_OVER (battle_lost signal)
GAME_OVER → MENU (return to menu button)
WORLD ← → WORLD (map transition via map_stack)
WORLD ← → INVENTORY (overlay, world stays in tree)
WORLD ← → SHOP (overlay, world stays in tree)
WORLD ← → JOURNAL (overlay, world stays in tree)
WORLD → SPIRE_FLOOR (SceneManager.enter_spire via entrance panel in WorldScene)
SPIRE_FLOOR → SPIRE_FLOOR (SceneManager.exit_map detects spire_ prefix → _advance_spire_floor)
```

**Gambit picker flow (GID-063):**

`SceneManager._on_enemy_engaged()` is split into two phases:
1. Guards + context stamping (as before).
2. If `save_manager.pending_battle_enemy_data` is non-empty (resume) OR `get_setting("auto_skip_gambits")` is `true` → call `_start_battle(enemy_data)` directly.
3. Otherwise → show `GambitPickerOverlay` in a `CanvasLayer` (layer 200). On `gambit_chosen(id)`, write `enemy_data["gambit_id"] = id` (if non-empty) and call `_start_battle(enemy_data)`.

`_start_battle(enemy_data)` contains the original `set_pending_battle` / `TransitionManager.transition` / world-detach logic. Keeping picker and battle start separate prevents the `CanvasLayer` from racing with the transition.

`GambitPickerOverlay` (`scenes/battle/GambitPickerOverlay.gd`) extends `BaseOverlay`. Signal: `gambit_chosen(gambit_id: String)` (empty = no gambit). Includes "Don't ask again" checkbox; checking it saves `set_setting("auto_skip_gambits", true)`. Escape key emits no-gambit on desktop.

**Spire routing:**

`enter_spire()` — called from the Spire entrance panel in madrian (door `target_map = "spire"`):
- If `save_manager.is_spire_active()` → resumes at `spire_floor_<floor>_<seed>` via `enter_map()`.
- Else → `start_spire_run(randi())`, pushes `spire_floor_1_<seed>` via `enter_map()`.

`exit_map()` — if `current_map.begins_with("spire_floor_")` and spire is active → calls `_advance_spire_floor()` (increments floor counter, loads next floor) instead of popping the map stack.

`_on_battle_won()` — Spire branch: saves `hero_hp`, sets cleared flag for the exit door, shows `SpireDraftScene` overlay, skips standard card/coin rewards.

`_on_battle_lost()` — Spire branch: calls `_restore_spire_entry_point()` then `save_manager.end_spire_run()`, emits `GameBus.spire_run_ended`, shows `RunSummaryScene` with `spire_stats` set. Does NOT route to `GameOverScene`.

`go_to_menu()` — Spire retreat branch: same flow as death when `is_spire_active()` and state is WORLD. Player retreats voluntarily, run ends, Spire summary shown.

`_restore_spire_entry_point()` — pops the pre-Spire map from `map_stack` and sets `save_manager.current_map` so that continue-after-run-end loads the entrance town (madrian), not a floor.

Madrian entrance door: `entity_id = "spire_entrance"`, tile (70, 36), `target_map = "spire"`. WorldScene intercepts this and calls `_show_spire_entrance_panel()` instead of `enter_map()`.

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

### TransitionManager (`autoloads/TransitionManager.gd`)

Global CanvasLayer (layer 100, `PROCESS_MODE_ALWAYS`) that provides fade-to-black transitions between scenes.

- Full-screen black `ColorRect` starts fully transparent with `MOUSE_FILTER_IGNORE`
- `transition(change_fn: Callable)` — fire-and-forget coroutine: fades to black (0.2s), calls `change_fn`, awaits one process frame, fades back in (0.2s)
- Both tweens use `TWEEN_PAUSE_PROCESS` so they work when `get_tree().paused = true`
- `_transitioning` guard prevents overlapping transitions; if one is already running, `change_fn` is called immediately without a new fade
- All `SceneManager` scene swaps are wrapped in `TransitionManager.transition(func() -> void: ...)` lambdas

### MenuScene (`scenes/ui/MenuScene.gd`)

- **New Game** and **Continue** buttons both → `SceneManager.go_to_slot_select()` (slot select screens handles the distinction)
- **Settings** button → opens `SettingsScene` overlay
- Animated title: scale 0.85→1.0 + alpha 0→1 on load (0.5s tween), then idle scale-breathe loop 1.0→1.02→1.0 (3s period)
- Version label bottom-left: reads `ProjectSettings.get_setting("application/config/version")`

### SlotSelectScene (`scenes/ui/SlotSelectScene.gd`)

- Shows 3 save slots with per-slot metadata (current map, coins, last_saved timestamp)
- Occupied slot: **Continue** (loads that slot) + **Delete** (requires confirm dialog)
- Empty slot: **New Game** (routes to `BiomeSelectionScene`)
- Back button returns to `MenuScene`
- Calls `SaveManager.set_active_slot(n)` before any navigation

### OverworldPauseOverlay (`scenes/ui/OverworldPauseOverlay.gd`)

CanvasLayer (layer 200, `PROCESS_MODE_ALWAYS`) that pauses the game tree.

- Sets `get_tree().paused = true` in `_ready()`; restores on close
- Signals: `resumed`, `quit_to_menu`
- **Resume** button / `pause` action in `_input()`: unpauses and emits `resumed`
- **Settings** button: adds `SettingsScene` as a child overlay
- **Save & Quit**: calls `SaveManager.save()` then `SceneManager.go_to_menu_direct()`, emits `quit_to_menu`
- Triggered from `WorldScene._open_pause()` (HUD "II" button or `pause` input action)

### SettingsScene (`scenes/ui/SettingsScene.gd`)

Overlay (extends Control, emits `closed`) showing volume and accessibility controls. Entry points: MenuScene Settings button, OverworldPauseOverlay, and BattleScene pause menu.

**Audio section:**
- **Music Volume** HSlider (0–1, default 0.5) — calls `AudioManager.set_music_volume(v)` and `SaveManager.set_setting("music_volume", v)`
- **SFX Volume** HSlider (0–1, default 1.0) — calls `AudioManager.set_sfx_volume(v)` and `SaveManager.set_setting("sfx_volume", v)`

**Accessibility & Comfort section:**
- **Screen Shake** `CheckButton` — persists `"screen_shake"` (default `true`); `BattleScene._trigger_shake()` checks this before shaking
- **Text Scale** `OptionButton` (Small=0.85 / Normal=1.0 / Large=1.25) — persists `"text_scale"` (default `1.0`)
- **Haptics** `CheckButton` (shown only on `OS.has_feature("mobile")`) — persists `"haptics"` (default `true`); `BattleScene._haptic(ms)` checks before calling `Input.vibrate_handheld(ms)`

**Battle section (GID-069 TID-254):**
- **Battle Speed** toggle row (Normal / Fast) — persists `"battle_speed"` (`"normal"` / `"fast"`); `BattleScene._ready()` reads this and sets `_speed_scale = 0.45` for fast mode. Default `"normal"` requires no migration.

Values apply immediately on change and persist across sessions. Dismissed by Close button, tapping the backdrop, or Escape key.

### BiomeSelectionScene (`scenes/ui/BiomeSelectionScene.gd`)

- Displays one button per biome (Grasslands, Forest, Desert, Scorched, Mountains)
- On selection: calls `SceneManager.start_new_game_with_biome(biome_id)` then transitions to `WorldScene`
- Back button → `SlotSelectScene` (not MenuScene directly)
- UI scales buttons by viewport height

### GameOverScene (`scenes/ui/GameOverScene.gd`)

- Shown after `GameBus.battle_lost` for **spire** and **siege** losses only
- "Return to Menu" button frees the game-over scene and loads `MenuScene`
- Does **not** delete the save file; player can continue from the last save

### Defeat Overlay (GID-069 TID-250)

Regular (non-spire, non-siege) battle losses no longer route to `GameOverScene`. Instead:

1. `SceneManager._on_battle_lost()` copies the enemy data into `_defeat_pending_enemy_data`, calls `clear_pending_battle_state()`, frees `_battle_overlay`, and re-adds the world scene via `TransitionManager.transition()`.
2. `_show_defeat_overlay()` adds a `CanvasLayer` (layer 200) on top of the restored world with three buttons: **Retry Battle**, **Respawn**, **Return to Menu**.

**Button behaviours:**
- **Retry Battle** (`_on_defeat_retry()`): frees the overlay, calls `_start_battle(_defeat_pending_enemy_data)` — starts a fresh battle against the same enemy.
- **Respawn** (`_on_defeat_respawn()`): frees the overlay, calls `save_manager.clear_pending_battle()`, sets a 3 s `engage_cooldown` on the nearest EnemyNPC to prevent instant re-engagement.
- **Return to Menu** (`_on_defeat_menu()`): frees the overlay, calls `clear_pending_battle()`, then `go_to_menu()`.

**SceneManager fields:**
- `_defeat_overlay: Node` — reference to the overlay CanvasLayer (freed on any choice).
- `_defeat_pending_enemy_data: Dictionary` — enemy data saved at loss time; cleared after Retry or Menu.

**`_exit_world_cleanup()`** frees `_defeat_overlay` if it exists when the player exits the world (e.g. go_to_menu from inside the overlay).

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
- **Interact prompt** — on desktop: `_interact_label` Label (`"[E] Interact"`); on Android: `_interact_btn` Button (`"USE"`, `vh * 0.18 × vh * 0.08`) positioned center-bottom at `vh * 0.80`. Both are hidden until the player is within `INTERACT_RANGE` of a door, chest, NPC, or scroll. On Android the button calls `_handle_interact()` directly when tapped.
- **Map name label** — displayed for 3 seconds on map load, then fades. Font `vh * 0.032`.
- **Coin counter** — reads `SaveManager.coins` each frame. Font `vh * 0.03`.
- **Level label** — `"Lv.X"` bottom-left, font `vh * 0.028`.
- **XP bar** — `ProgressBar` beside level label, height `vh * 0.032`.
- **XP fraction label** — `"current / next XP"` beside bar, font `vh * 0.025`.
- **Dialogue label** — shown above NPC; fades out after 4 seconds. Font `vh * 0.03`.
- **Tutorial tip label** — yellow-tinted one-shot hints; auto-hides after 5 seconds (`TIP_DURATION`). Font `vh * 0.03`. Four triggers, each shown exactly once (flag stored in `SaveManager.story_flags`):
  - World entry → inventory button hint (`tutorial_inventory_tip`)
  - First NPC proximity → talk hint (`tutorial_npc_tip`)
  - First chest proximity → open hint (`tutorial_chest_tip`)
  - First enemy proximity → battle hint (`tutorial_enemy_tip`)
  - Android vs desktop control names chosen via `OS.has_feature("android")`
- **Minimap** — circular, diameter `vh * 0.20` (top-right corner). See Minimap section.
- **Compass ribbon** — `vh * 0.04` tall, `vw * 0.40` wide, centred at the top of the screen (`vh * 0.01` from top). See Compass Ribbon section below.

### Compass Ribbon (`scenes/ui/CompassRibbon.gd`)

A horizontal `Control` node parented to the HUD `CanvasLayer`. It shows cardinal-direction tick marks (W/S/E/N) and coloured dot markers registered by other systems.

**Bearing math:**
The isometric camera faces NE (azimuth −45°), so NE is permanently at the ribbon centre. The mapping from world bearing `θ` (radians, `atan2(dz, dx)`) to ribbon local X:
```
ribbon_x = ribbon_width/2 + (deg(θ) + 45) / 360 * ribbon_width
```
Clamped to `[0, ribbon_width]`. Cardinal positions (ribbon_width = W):
| Direction | Bearing | ribbon_x |
|-----------|---------|----------|
| West  | −π   | W × 0.125 |
| South | −π/2 | W × 0.375 |
| NE ↑  | −π/4 | W × 0.500 (centre) |
| East  | 0    | W × 0.625 |
| North | +π/2 | W × 0.875 |

Bearings > 135° (SW/behind the camera) clamp to the right edge.

**Marker API:**
```gdscript
compass.add_marker("waypoint", Color.YELLOW, func() -> Variant: return world_pos)
compass.remove_marker("waypoint")
compass.set_current_map("maykalene")  # call on every map transition
```
`get_pos` is a Callable returning `Vector3` (world pos) or `null` (hidden).

**Integration:**
`WorldScene` instantiates one `CompassRibbon` in `_ready()`, passes `_player`, and calls `set_current_map(map_name)`. Other systems call `add_marker` / `remove_marker` on the compass node.

**Static helpers (testable):**
- `CompassRibbon.bearing_to_ribbon_x(bearing_rad, ribbon_width) → float`
- `CompassRibbon.compute_bearing(fx, fz, tx, tz) → float`

### Compass Ribbon (`scenes/ui/CompassRibbon.gd`)

Horizontal 360° bearing ribbon rendered at the top-center of the HUD.  The isometric camera is fixed, so the ribbon itself never rotates — only marker dots slide left/right as the player moves relative to targets.

**Bearing convention**

`atan2(target.z - player.z, target.x - player.x)` gives the world bearing (`0` = East/+X, `−π/2` = North/−Z).  The ribbon maps this linearly so that N/E/S/W land at equal intervals (each `ribbon_width/4` apart):

| Direction | World | ribbon_x offset from center |
|---|---|---|
| W | −X | −3 × width/8 |
| N | −Z | −1 × width/8 |
| **NE** (iso screen-right) | +X, −Z | **0 (center)** |
| E | +X | +1 × width/8 |
| S | +Z | +3 × width/8 |
| SW | −X, +Z | ±width/2 (edges, wrapping) |

Static formula: `bearing_to_ribbon_x(bearing_rad, ribbon_center, ribbon_width)`.

**Sizing** — set by `WorldScene._ready()` before calling `setup()`:
- Width = `vw × 0.40`, height = `vh × 0.04`
- Position: X = `(vw − width) / 2`, Y = `vh × 0.01` (top-center, clears the Menu button)

**Marker API**

```gdscript
compass.add_marker("waypoint", Color.YELLOW, func() -> Vector3: return waypoint_pos)
compass.add_marker("enemy",    Color.RED,    func() -> Vector3: return enemy.position, "maykalene")
compass.remove_marker("waypoint")
compass.set_current_map("madrian")  # call on every map transition
```

- `get_pos: Callable` is called every frame and must return a `Vector3` (or `null` to hide).
- If `map` is non-empty and doesn't match `_current_map`, the marker clamps to the ribbon edge (left or right, based on direction) to indicate an off-screen target.

**Integration** — `WorldScene._ready()` instantiates the ribbon after `_spawn_player()`, stores it in `_compass`, and calls `compass.set_current_map(map_name)`.  Future tasks (TID-183 waypoint, TID-184 story objective) call `add_marker()` to register their markers.

### TutorialPopup (`scenes/ui/TutorialPopup.gd`)

Reusable modal overlay for in-game tutorial guides. Any system can trigger one by emitting `GameBus.tutorial_popup_requested(popup_id)`.

**Flow:**
1. Emitter calls `GameBus.tutorial_popup_requested.emit("skill_tree")` (or any registered ID).
2. `SceneManager._on_tutorial_popup_requested()` checks `SaveManager.get_story_flag("seen_tutorial_" + popup_id)` — skips if already seen.
3. Looks up content in `TutorialRegistry.get_entry(popup_id)` — skips if ID unknown.
4. Sets the seen flag immediately, instantiates `TutorialPopup`, calls `popup.setup(title, body)`, adds to `get_tree().root`.
5. On `closed` signal: popup is freed.

**Layout:** full-screen dark backdrop (alpha 0.65) → centered `PanelContainer` (70% vw × 50% vh) → `VBoxContainer` with title label (3.5% vh), separator, autowrap body label, "Got it" button (5.5% vh tall).

**Dismiss:** "Got it" button press OR `ui_cancel` / `ui_accept` key.

**Adding a new popup:** add one entry to `game_logic/TutorialRegistry.gd`'s `_DATA` dict — no UI code changes needed.

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
| **SettingsScene** | Overlay | Opened from MenuScene or battle pause menu; emits `closed` signal; persists volume prefs |
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
| SettingsScene | `scenes/ui/SettingsScene.gd` | Volume sliders overlay (GID-026) |
| ShopScene | `scenes/ui/ShopScene.tscn` | Merchant shop overlay |
| VirtualJoystick scene | `scenes/ui/VirtualJoystick.tscn` | Mobile overlay |
| TutorialPopup | `scenes/ui/TutorialPopup.gd` | Pure-code modal overlay; no .tscn needed |
| TutorialRegistry | `game_logic/TutorialRegistry.gd` | Static data store for popup content |
| `SceneManager.gd` | `autoloads/SceneManager.gd` | Autoload singleton |
| UI theme / font | `assets/` | Optional custom theme `.tres`; falls back to Godot default |
| Title art | `assets/textures/` | Background for MenuScene (optional) |
