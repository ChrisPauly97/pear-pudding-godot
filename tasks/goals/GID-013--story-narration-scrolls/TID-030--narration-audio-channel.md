# TID-030: Narration audio channel (AudioManager extension + story-beat suppression)

**Goal:** GID-013
**Type:** agent
**Status:** pending
**Depends On:** TID-028

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Scroll narration is long-form audio (30–90 seconds) — it cannot share the 8-slot SFX pool which cuts off the oldest sound when all slots are busy. This task adds a dedicated narration `AudioStreamPlayer` to `AudioManager`, a `play_narration(scroll_id)` / `stop_narration()` API, and suppression logic so narration pauses when an NPC dialogue is in progress.

## Research Notes

**AudioManager.gd** (`autoloads/AudioManager.gd`):
- Currently: 8-slot pool of `AudioStreamPlayer` nodes created in `_ready()`
- `play_sfx(sfx_name)` — graceful no-op if file absent
- Add a 9th dedicated node `_narration_player: AudioStreamPlayer` (NOT part of the pool)
- Narration audio paths: `ScrollRegistry.get_scroll(id).audio_path` — pattern `"res://assets/audio/narration/<id>.ogg"`
- Graceful no-op if file absent (same `ResourceLoader.exists()` guard as `play_sfx`)
- Only one narration plays at a time — starting a new one stops the current

**New AudioManager API:**
```gdscript
var _narration_player: AudioStreamPlayer
var _narration_suppressed: bool = false

func _ready() -> void:
    # ... existing pool creation ...
    _narration_player = AudioStreamPlayer.new()
    _narration_player.volume_db = 0.0
    add_child(_narration_player)

func play_narration(scroll_id: String) -> void:
    if _narration_suppressed:
        return   # story beat is active; skip — player can replay from journal
    var scroll: Dictionary = ScrollRegistry.get_scroll(scroll_id)
    if scroll.is_empty():
        return
    var path: String = scroll.get("audio_path", "")
    if path.is_empty() or not ResourceLoader.exists(path):
        return  # graceful no-op
    var stream := load(path) as AudioStream
    if stream == null:
        return
    _narration_player.stop()
    _narration_player.stream = stream
    _narration_player.play()

func stop_narration() -> void:
    _narration_player.stop()

func is_narration_playing() -> bool:
    return _narration_player.playing

func set_narration_suppressed(suppressed: bool) -> void:
    _narration_suppressed = suppressed
    if suppressed:
        _narration_player.stop()
```

**Suppression: when does story-beat dialogue override narration?**

The NPC dialogue system works via `TownspersonNPC` → `WorldScene` shows a dialogue label for `DIALOGUE_DURATION` seconds. There is no persistent "dialogue active" flag in GameBus currently.

**Cleanest approach** — add a `GameBus` signal:
```gdscript
signal dialogue_state_changed(active: bool)
```
`WorldScene._show_dialogue()` emits `GameBus.dialogue_state_changed(true)` when it begins and `false` when it ends (timer expires). `AudioManager` connects to this in `_ready()`:
```gdscript
GameBus.dialogue_state_changed.connect(_on_dialogue_state_changed)

func _on_dialogue_state_changed(active: bool) -> void:
    set_narration_suppressed(active)
```

This is fully decoupled — WorldScene doesn't know AudioManager exists, and vice versa.

**Volume consideration:** Narration might need to be a touch quieter than SFX to sit in the background. Use `_narration_player.volume_db = -3.0` as a starting point.

**Adding `dialogue_state_changed` to GameBus.gd:**
- Add under `# World signals`:
  ```gdscript
  signal dialogue_state_changed(active: bool)
  ```
- `WorldScene._show_dialogue(text)` already sets `_dialogue_timer = DIALOGUE_DURATION`. Emit `true` there, and emit `false` in the timer-expiry branch of `_process()`.

**Reference — WorldScene dialogue pattern** (from TID-026 research notes):
```gdscript
# ~line 982
func _show_dialogue(text: String) -> void:
    _dialogue_label.text = text
    _dialogue_label.show()
    _dialogue_timer = DIALOGUE_DURATION

# in _process():
if _dialogue_timer > 0.0:
    _dialogue_timer -= delta
    if _dialogue_timer <= 0.0:
        _dialogue_label.hide()
        GameBus.dialogue_state_changed.emit(false)  # ADD THIS
```

And in `_show_dialogue`:
```gdscript
func _show_dialogue(text: String) -> void:
    _dialogue_label.text = text
    _dialogue_label.show()
    _dialogue_timer = DIALOGUE_DURATION
    GameBus.dialogue_state_changed.emit(true)       # ADD THIS
```

**Edge case:** if `_show_dialogue` is called while a dialogue is already showing (timer reset), we'd emit `true` again — that is fine, `set_narration_suppressed(true)` is idempotent.

**Audio file location:** Create directory `assets/audio/narration/` — no files needed at ship time (graceful no-op). Document the expected file format: `.ogg` (Godot prefers OGG for streaming long audio on Android).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
