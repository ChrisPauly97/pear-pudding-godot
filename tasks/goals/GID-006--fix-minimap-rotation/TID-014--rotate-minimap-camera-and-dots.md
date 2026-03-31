# TID-014: Rotate Minimap Camera and Dot Overlay to Match Isometric Azimuth

**Goal:** GID-006
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The minimap renders a top-down view and separately draws entity dots via a CanvasItem `_draw()` call. Both currently treat world +X as "minimap right" and world −Z as "minimap up." The isometric camera has a −45° azimuth, so the player's "screen right" is world NE `(+1, 0, −1)` and "screen up" is world NW `(−1, 0, −1)`. The minimap needs a +45° clockwise rotation (when viewed from above) applied to both the rendered texture and the dot overlay.

## Research Notes

**File:** `scenes/world/Minimap.gd`

**Camera fix (line 100):**
Change `_mini_cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)` to `Vector3(-90.0, 45.0, 0.0)`. A +45° Y rotation turns the camera's "up" from world −Z to world NW `(−1, 0, −1)`, matching the isometric screen's up direction.

**Dot overlay fix (`_draw_group`, lines 167–178):**
The current mapping is:
```gdscript
var dot := Vector2(_half + off.x * _scale, _half + off.z * _scale)
```
Replace with a +45° rotation (cos 45° = sin 45° = √2/2 ≈ 0.7071):
```gdscript
const ROT45: float = 0.7071067811865476
var rx: float = (off.x - off.z) * ROT45
var ry: float = (off.x + off.z) * ROT45
var dot := Vector2(_half + rx * _scale, _half + ry * _scale)
```
Verification:
- Move right in iso = world `(+d, 0, −d)` → rx = (d − (−d)) * 0.707 = +1.414d * 0.707 → dot moves right ✓
- Move up in iso = world `(−d, 0, −d)` → rx = 0 → dot moves straight up ✓

**Compass label fix (lines 132–141):**
Remove the `"N"` label entirely — after the 45° rotation the minimap top is isometric screen-up (world NW), not geographic north, so the label is misleading.

**No other files need changes.** WorldScene calls `Minimap.setup()` and `Minimap.update()` unchanged.

## Plan

1. Set minimap camera Y rotation to +45° so its "up" direction aligns with iso screen-up (world NW).
2. Apply the same +45° rotation matrix to all dot positions in `_draw_group`.
3. Remove the misleading "N" compass label.

## Changes Made

- `scenes/world/Minimap.gd` line ~100: `_mini_cam.rotation_degrees` changed from `Vector3(-90, 0, 0)` to `Vector3(-90, 45, 0)`.
- `scenes/world/Minimap.gd` `_draw_group`: replaced `off.x / off.z` direct mapping with `ROT45`-rotated `rx/ry` coordinates.
- `scenes/world/Minimap.gd` `setup()`: removed the `"N"` Label node (was lines 132–141).

## Documentation Updates

No agent docs required changes — the minimap is described under `docs/agent/ui-and-scene-management.md` but the change is mechanical (rotation fix), not architectural.
