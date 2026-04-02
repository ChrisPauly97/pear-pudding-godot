# TID-043: Fix VirtualJoystick Viewport-Relative Sizing

**Goal:** GID-016
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

VirtualJoystick uses four fixed-pixel radius constants and two fixed-pixel position offsets. On tablets and high-DPI phones these become too small; on low-res phones they may overlap the game view or each other.

## Research Notes

### File
`scenes/ui/VirtualJoystick.gd`

### Fixed values to replace
```gdscript
# Current (lines 3–6) — fixed pixels
const BASE_RADIUS: float = 130.0
const KNOB_RADIUS: float = 54.0
const JUMP_RADIUS: float = 80.0
const INTERACT_RADIUS: float = 65.0

# Current (lines 22–30) — fixed offsets
return get_viewport_rect().size - Vector2(180.0, 180.0)  # joy center
return Vector2(180.0, s.y - 180.0)                        # jump center
return Vector2(180.0, s.y - 365.0)                        # interact center
```

### Replacement strategy
Convert constants to computed values from `_ready()` using `get_viewport_rect().size.y` (call it `_vh`):

```gdscript
var _base_r: float
var _knob_r: float
var _jump_r: float
var _interact_r: float
var _edge_margin: float   # replaces the 180px offset

func _ready() -> void:
    var vh: float = get_viewport_rect().size.y
    _base_r       = vh * 0.085   # ~130px at 1520px vh (typical phone landscape)
    _knob_r       = vh * 0.035
    _jump_r       = vh * 0.052
    _interact_r   = vh * 0.043
    _edge_margin  = vh * 0.118   # ~180px at 1520px
    ...
```

Position functions become:
```gdscript
func _get_joy_center() -> Vector2:
    var s: Vector2 = get_viewport_rect().size
    return s - Vector2(_edge_margin, _edge_margin)

func _get_jump_center() -> Vector2:
    var s: Vector2 = get_viewport_rect().size
    return Vector2(_edge_margin, s.y - _edge_margin)

func _get_interact_center() -> Vector2:
    var s: Vector2 = get_viewport_rect().size
    return Vector2(_edge_margin, s.y - _edge_margin * 2.4)
```

### Deadzone
`DEADZONE: float = 0.25` — this is a ratio (0–1), not pixels. Keep as-is.

### Touch detection radii
`_handle_touch` uses `BASE_RADIUS * 1.5` and `JUMP_RADIUS * 1.5` — update to use `_base_r * 1.5` and `_jump_r * 1.5` etc.

### _draw()
All `draw_circle` and `draw_arc` calls use the constant names — update to use the instance vars.

### No logic changes
Only sizing/positioning changes. All touch handling, action injection, and knob clamping logic stays identical.
## Plan

Replace the four fixed-pixel `const` values and three fixed-pixel position offsets with instance vars computed from `get_viewport_rect().size.y` in `_ready()`. Update all call sites in `_draw()`, `_handle_touch()`, and `_update_knob()`. No logic changes.

## Changes Made

- `scenes/ui/VirtualJoystick.gd`: removed four fixed-pixel constants (`BASE_RADIUS`, `KNOB_RADIUS`, `JUMP_RADIUS`, `INTERACT_RADIUS`). Added five `var` fields (`_base_r`, `_knob_r`, ``_jump_r`, `_interact_r`, `_edge_margin`) computed from `vh * fraction` in `_ready()`. Updated `_get_joy_center()`, `_get_jump_center()`, `_get_interact_center()` to use `_edge_margin`. Updated all `draw_circle`, `draw_arc`, and `distance_to` call sites. `_update_knob()` clamp uses `_base_r`. Logic unchanged.

## Documentation Updates

None — sizing approach already covered by CLAUDE.md UI Sizing section.
