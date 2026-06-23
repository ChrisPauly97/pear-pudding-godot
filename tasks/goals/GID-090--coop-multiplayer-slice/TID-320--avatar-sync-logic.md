# TID-320: Pure avatar-sync logic (serialize + interpolate)

**Goal:** GID-090
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The co-op slice broadcasts a tiny per-frame avatar state between peers and
interpolates remote avatars toward their latest received state. This task
isolates the only network-independent, testable logic — payload encode/decode and
the interpolation step — into a pure helper so it can be unit-tested without a
live connection. Keeping this separate from the RPC plumbing (TID-323) and the
RemotePlayer node (TID-322) follows the codebase's pattern of pure logic in
`game_logic/` (e.g. `game_logic/TerrainMath.gd`, `game_logic/Pathfinder.gd`) that
scene code delegates to.

## Research Notes

**Where pure logic lives:** `game_logic/` holds RefCounted/static-only helpers
with no scene dependencies (`TerrainMath.gd`, `Pathfinder.gd`,
`game_logic/battle/GameState.gd` with `to_dict()`/`from_dict()`). Create a new
`game_logic/net/` subfolder and add `AvatarSync.gd` there.

**Payload shape (decided in design):** `[x: float, z: float, facing_flip_h: bool,
is_moving: bool]`. `y` is intentionally absent — recomputed locally from
`get_terrain_height(x, z)` on the receiver. Keep the payload a small typed
`Array` (or 4 scalar RPC args); a compact `PackedByteArray` is unnecessary for the
slice but the encode/decode seam should make a later switch cheap.

**Interpolation:** remote avatars store a target position and lerp toward it each
frame. Provide a pure step function, e.g.
`AvatarSync.interp(current: Vector3, target: Vector3, delta: float, rate: float) -> Vector3`
using `current.lerp(target, clamp(delta * rate, 0.0, 1.0))`. A rate around
10–15 keeps motion smooth at 15 Hz updates without rubber-banding. Keep it a
`static func` so it is trivially testable.

**CLAUDE.md conventions:** use explicit type annotations everywhere (avoid
Variant-inference parse errors — `Array` indexing returns Variant, so annotate
`var x: float = payload[0]`). No `class_name` reliance — callers will `preload`
this script. Pure `.gd`, no `.uid` sidecar needed.

**Suggested API:**
```gdscript
static func encode(x: float, z: float, flip_h: bool, moving: bool) -> Array
static func decode(payload: Array) -> Dictionary   # {x, z, flip_h, moving}
static func interp(current: Vector3, target: Vector3, delta: float, rate: float) -> Vector3
```

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
