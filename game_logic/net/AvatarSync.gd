## Pure helpers for avatar state sync over the network.
##
## Callers: preload("res://game_logic/net/AvatarSync.gd")
## No scene dependencies — fully unit-testable without a live connection.
extends RefCounted


## Pack local avatar state into a small array for RPC transmission.
## Payload layout: [x: float, z: float, flip_h: bool, moving: bool]
## y is intentionally omitted — receivers recompute it from terrain height.
static func encode(x: float, z: float, flip_h: bool, moving: bool) -> Array:
	return [x, z, flip_h, moving]


## Unpack a received payload back into named fields.
## Returns {x, z, flip_h, moving}. Explicit type vars guard against Variant inference.
static func decode(payload: Array) -> Dictionary:
	var x: float = payload[0]
	var z: float = payload[1]
	var flip_h: bool = payload[2]
	var moving: bool = payload[3]
	return {"x": x, "z": z, "flip_h": flip_h, "moving": moving}


## Smooth-step a remote avatar's current position toward the latest received target.
## rate: lerp speed (10–15 works well at 15 Hz updates without rubber-banding).
## The factor is clamped to [0, 1] so the result never overshoots the target.
static func interp(current: Vector3, target: Vector3, delta: float, rate: float) -> Vector3:
	var t: float = clamp(delta * rate, 0.0, 1.0)
	return current.lerp(target, t)
