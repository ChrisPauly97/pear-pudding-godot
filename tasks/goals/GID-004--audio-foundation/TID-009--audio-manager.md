# TID-009: Create AudioManager Autoload with SFX Playback API

**Goal:** GID-004
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

There is no audio system. This task creates `AudioManager` — a thin autoload that owns a pool of `AudioStreamPlayer` nodes and exposes `play_sfx(name)`. Other tasks (TID-010, TID-011) hook into it. It must be robust against missing audio files so the game doesn't crash before real assets exist.

## Research Notes

**File to create:** `autoloads/AudioManager.gd`

**Architecture:**
```gdscript
extends Node

# Map from SFX name → file path (relative to res://)
const SFX_PATHS: Dictionary = {
    "card_play":    "res://assets/audio/sfx/card_play.wav",
    "attack":       "res://assets/audio/sfx/attack.wav",
    "battle_win":   "res://assets/audio/sfx/battle_win.wav",
    "battle_lose":  "res://assets/audio/sfx/battle_lose.wav",
    "enemy_engage": "res://assets/audio/sfx/enemy_engage.wav",
    "chest_open":   "res://assets/audio/sfx/chest_open.wav",
    "door_enter":   "res://assets/audio/sfx/door_enter.wav",
    "footstep":     "res://assets/audio/sfx/footstep.wav",
}

# Pool of players (avoids creating/freeing nodes every call)
var _players: Array[AudioStreamPlayer] = []
const _POOL_SIZE: int = 8

func _ready() -> void:
    for i in _POOL_SIZE:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)

func play_sfx(name: String) -> void:
    if not SFX_PATHS.has(name):
        return
    var path: String = SFX_PATHS[name]
    if not ResourceLoader.exists(path):
        return   # graceful no-op — file not yet added
    var stream := load(path) as AudioStream
    if stream == null:
        return
    # Find a free player
    for p in _players:
        if not p.playing:
            p.stream = stream
            p.play()
            return
    # All busy — use player 0 (oldest sound cut off)
    _players[0].stream = stream
    _players[0].play()
```

**Placeholder audio files:**
- Create `assets/audio/sfx/` directory.
- Rather than committing real audio, create a note file `assets/audio/sfx/README.md` documenting the expected files. The `ResourceLoader.exists()` check means missing files are a silent no-op.
- Alternatively, use Godot's built-in `AudioStreamGenerator` to produce a short beep programmatically as a placeholder — this makes SFX hookable and audible without any `.wav` files.

**Register in project.godot:**
- Add `AudioManager` to the `[autoload]` section:
  ```
  AudioManager="*res://autoloads/AudioManager.gd"
  ```
- Verify existing autoload entries format (read `project.godot` first).

**No `.uid` sidecar needed** — plain `.gd` scripts don't need UIDs. Any `.wav` files added later will need `.import` files (handled by Godot editor on first import).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
