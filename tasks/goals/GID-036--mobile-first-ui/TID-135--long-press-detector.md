# TID-135: Tap-and-Hold Long Press Detector Component

**Goal:** GID-036
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No long-press mechanic exists anywhere in the game. This task creates a small reusable helper node (`LongPressDetector`) that any Control can add as a child to gain 500 ms hold detection, working identically on both touch (Android) and mouse (desktop). Subsequent tasks (TID-136, TID-137) depend on this component.

## Research Notes

### Placement

Create `scenes/ui/LongPressDetector.gd`. It is a pure GDScript node with no `.tscn` (instantiated in code by callers).

### Design

```gdscript
class_name LongPressDetector
extends Node

signal long_pressed

const THRESHOLD_MS: float = 0.5   # seconds

var _holding: bool = false
var _elapsed: float = 0.0
var _touch_index: int = -1

func _input(event: InputEvent) -> void:
    # Touch down / mouse down → start timer
    # Touch up / mouse up / move-beyond-slop → cancel
    pass

func _process(delta: float) -> void:
    if _holding:
        _elapsed += delta
        if _elapsed >= THRESHOLD_MS:
            _holding = false
            long_pressed.emit()
```

### Input handling details

- **Touch:** watch for `InputEventScreenTouch` (pressed=true starts, pressed=false cancels) and `InputEventScreenDrag` (if drag distance exceeds slop ~12px, cancel).
- **Mouse:** watch for `InputEventMouseButton` BUTTON_LEFT (pressed starts, released cancels) and `InputEventMouseMotion` with slop ~12px.
- The node does NOT consume the event — it only observes it. The parent Control handles normal taps independently.
- `_input` is used (not `_unhandled_input`) so the detector fires even when a parent already consumed the event for a tap.

### Slop constant

```gdscript
const SLOP_PX: float = 12.0
var _start_pos: Vector2 = Vector2.ZERO
```

If `event.position.distance_to(_start_pos) > SLOP_PX`, cancel. This prevents accidental triggers on slow drag gestures.

### Usage by callers (TID-136)

```gdscript
# In card node _ready():
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
var _lpd := LongPressDetector.new()
add_child(_lpd)
_lpd.long_pressed.connect(_on_long_press)
```

### No .uid file needed

Plain `.gd` scripts do not need `.uid` sidecars (confirmed in CLAUDE.md).

## Plan

Create `scenes/ui/LongPressDetector.gd` — a single Node script with no .tscn. Emits `long_pressed` after 500 ms of stationary hold. Handles both touch (`InputEventScreenTouch`, `InputEventScreenDrag`) and mouse (`InputEventMouseButton`, `InputEventMouseMotion`). Does not consume events.

## Changes Made

- Created `scenes/ui/LongPressDetector.gd`: reusable Node component; 500 ms threshold; 12 px slop cancel; handles touch + mouse; emits `long_pressed` signal; does not consume events.

## Documentation Updates

No agent doc changes needed — component is self-contained and documented in code. TID-136 will reference it.
