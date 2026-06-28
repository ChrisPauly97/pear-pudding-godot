## Pure helpers for avatar state sync over the network.
##
## Callers: preload("res://game_logic/net/AvatarSync.gd")
## No scene dependencies — fully unit-testable without a live connection.
extends RefCounted


## Pack local avatar state into a small array for RPC transmission.
## Payload layout: [x: float, z: float, flip_h: bool, moving: bool, map: String]
## y is intentionally omitted — receivers recompute it from terrain height. `map` is
## the sender's current map name so receivers can drop cross-map packets (TID-352);
## it is optional/defaulted so older 4-element payloads still decode.
static func encode(x: float, z: float, flip_h: bool, moving: bool, map: String = "") -> Array:
	return [x, z, flip_h, moving, map]


## Unpack a received payload back into named fields.
## Returns {x, z, flip_h, moving, map}. Explicit type vars guard against Variant
## inference; `map` defaults to "" for short/garbage/legacy 4-element payloads.
static func decode(payload: Array) -> Dictionary:
	var x: float = payload[0]
	var z: float = payload[1]
	var flip_h: bool = payload[2]
	var moving: bool = payload[3]
	var map: String = str(payload[4]) if payload.size() > 4 else ""
	return {"x": x, "z": z, "flip_h": flip_h, "moving": moving, "map": map}


## Smooth-step a remote avatar's current position toward the latest received target.
## rate: lerp speed (10–15 works well at 15 Hz updates without rubber-banding).
## The factor is clamped to [0, 1] so the result never overshoots the target.
static func interp(current: Vector3, target: Vector3, delta: float, rate: float) -> Vector3:
	var t: float = clamp(delta * rate, 0.0, 1.0)
	return current.lerp(target, t)


## Number of distinct ring slots a remote avatar's initial spawn can land on.
const SPAWN_RING_SLOTS: int = 12

## Deterministic XZ fan-out offset for a remote avatar's initial spawn, keyed by
## `peer_id`. With up to 4 players sharing one SPAWN marker the seeded positions
## would otherwise stack on the same tile until the first network packet arrives.
## The offset is a ring slot (`peer_id mod SPAWN_RING_SLOTS`) at a 2-tile radius,
## so it is stable across join order and frames and never lands on the centre.
## Returns (x_offset, z_offset) in world units.
static func spawn_offset(peer_id: int, tile_size: float) -> Vector2:
	var slot: int = abs(peer_id) % SPAWN_RING_SLOTS
	var angle: float = TAU * float(slot) / float(SPAWN_RING_SLOTS)
	var radius: float = 2.0 * tile_size
	return Vector2(cos(angle) * radius, sin(angle) * radius)
