# App Diagnostics Log Screen

## Key Features

- `AppLog` autoload provides `info()`, `warn()`, and `error()` methods that store timestamped entries in a 200-entry ring buffer and pass through to `print()` / `push_warning()` / `push_error()`.
- `AppLog._ready()` auto-connects to 17 `GameBus` signals so key game events (battles, story flags, achievements, map transitions, weather, etc.) are captured without modifying existing call sites.
- `DiagnosticsScene` overlay renders all buffered entries in a colour-coded scrollable viewer (green = INFO, yellow = WARN, red = ERROR) using BBCode in a `RichTextLabel`.
- A "Diagnostics" button appears in both `OverworldPauseOverlay` (accessible via the in-game pause menu) and `MenuScene` (accessible from the main menu), satisfying the mobile/desktop parity rule.
- Works on Android without file I/O — reads from the in-memory ring buffer.

## How It Works

### AppLog (`autoloads/AppLog.gd`)

- `const MAX_ENTRIES: int = 200` — oldest entry discarded when full.
- Each entry is a `Dictionary` with keys `ts` (float, seconds since app start), `level` (`"INFO"` / `"WARN"` / `"ERROR"`), and `msg` (String).
- `info(msg)` / `warn(msg)` / `error(msg)` push to the buffer and call the matching Godot print function.
- `get_entries() -> Array[Dictionary]` returns a copy of the buffer (newest at end).
- `clear()` empties the buffer.
- Registered in `project.godot` as `AppLog="*res://autoloads/AppLog.gd"` after `GameBus`.

### Auto-logged GameBus signals

| Signal | Log output |
|---|---|
| `enemy_engaged` | INFO "Battle started: {enemy_type}" |
| `battle_won` | INFO "Battle won" |
| `battle_lost` | INFO "Battle lost" |
| `hud_message_requested` | INFO "HUD: {msg}" |
| `achievement_unlocked` | INFO "Achievement: {id}" |
| `level_up` | INFO "Level up: {level}" |
| `story_flag_set` | INFO "Flag: {flag}" |
| `story_scroll_collected` | INFO "Scroll: {id}" |
| `entered_named_map` | INFO "Map: {name}" |
| `world_event_started` | INFO "Event started: {id}" |
| `world_event_ended` | INFO "Event ended: {id}" |
| `bounty_completed` | INFO "Bounty done: {id}" |
| `siege_victory` | INFO "Siege victory" |
| `siege_defeated` | WARN "Siege defeated: lost {n} coins" |
| `rival_encounter_won` | INFO "Rival win #{n}" |
| `weather_changed` | INFO "Weather: {id}" |

### DiagnosticsScene (`scenes/ui/DiagnosticsScene.gd`)

- Script-only, extends `res://scenes/ui/BaseOverlay.gd` (no `.tscn` needed).
- Instantiate with `DiagnosticsScene.new()`, add as child, call `set_anchors_preset(PRESET_FULL_RECT)`.
- Builds an 88%×82% viewport-relative panel with dark glass style using `_build_centered_panel` and `_make_dark_glass_style()`.
- `RichTextLabel` (BBCode enabled) inside a `ScrollContainer` (EXPAND_FILL). Each entry line format:
  ```
  [color=#888888][{ts:.1f}s][/color] [color={col}][{level}][/color] {msg}
  ```
- "Clear" button calls `AppLog.clear()` and re-populates the label.
- "Close" button calls `_close()` (inherited from BaseOverlay), which emits `closed`. Callers connect `closed` to `queue_free`.

### Entry points

- **OverworldPauseOverlay** (`scenes/ui/OverworldPauseOverlay.gd`): "Diagnostics" button between Settings and Save & Quit.
- **MenuScene** (`scenes/ui/MenuScene.gd`): "Diagnostics" button before Quit in the main menu.

Both use the same open pattern:
```gdscript
const DiagnosticsScene = preload("res://scenes/ui/DiagnosticsScene.gd")

func _on_diagnostics() -> void:
    var overlay: DiagnosticsScene = DiagnosticsScene.new()
    add_child(overlay)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.closed.connect(overlay.queue_free)
```

## Integrations with Other Features

- **GameBus** — `AppLog` connects to signals in `_ready()`. Adding a new signal to GameBus and wanting it logged only requires a new `connect` call in `AppLog._ready()`.
- **BaseOverlay** — `DiagnosticsScene` inherits the `_close()` / `closed` signal pattern used by all other overlays (Settings, Journal, etc.), so it fits seamlessly into the overlay stack.
- **OverworldPauseOverlay / MenuScene** — both scenes open the overlay as a child (not via SceneManager) so game state is unaffected.

## Asset Requirements

None. `AppLog.gd` is a plain script autoload. `DiagnosticsScene.gd` is a script-only overlay with no external assets.
