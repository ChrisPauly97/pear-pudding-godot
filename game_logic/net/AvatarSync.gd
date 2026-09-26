## Pure helpers for avatar state sync over the network.
##
## Callers: preload("res://game_logic/net/AvatarSync.gd")
## No scene dependencies — fully unit-testable without a live connection.
extends RefCounted


## Number of distinct ring slots a remote avatar's initial spawn can land on.
const SPAWN_RING_SLOTS: int = 12
## Distance (world units) past which a remote avatar snaps instead of gliding:
## a rally, respawn or door warp would otherwise slide it across the map.
const SNAP_DISTANCE: float = 12.0
## Longest a stale target is projected forward along the peer's last velocity.
const MAX_EXTRAPOLATION: float = 0.2
## Cap on a packet-derived speed (world units/s), above any mount's run speed.
const MAX_SPEED: float = 20.0


## Pack local avatar state into a small array for RPC transmission.
## Payload layout: [x: float, z: float, flip_h: bool, moving: bool, map: String, downed: bool]
## y is intentionally omitted — receivers recompute it from terrain height. `map` is
## the sender's current map name so receivers can drop cross-map packets (TID-352);
## it is optional/defaulted so older 4-element payloads still decode. `downed`
## (GID-105 / TID-389) is the co-op shared-dungeon downed/rescue flag; it rides this
## already-continuous 15 Hz stream rather than a dedicated RPC, so both directions
## of the transition (downed / revived) propagate to every peer automatically.
static func encode(x: float, z: float, flip_h: bool, moving: bool, map: String = "", downed: bool = false) -> Array:
	return [x, z, flip_h, moving, map, downed]


## Compact wire form of encode(): 4-byte float x, 4-byte float z, one flag byte
## (bit0 flip_h, bit1 moving, bit2 downed), then the map name as UTF-8. About 16
## bytes against ~64 for the Variant Array. decode() reads both forms.
static func encode_packed(x: float, z: float, flip_h: bool, moving: bool, map: String = "",
		downed: bool = false) -> PackedByteArray:
	var name_bytes: PackedByteArray = map.to_utf8_buffer()
	var out := PackedByteArray()
	out.resize(9)
	out.encode_float(0, x)
	out.encode_float(4, z)
	out[8] = (1 if flip_h else 0) | (2 if moving else 0) | (4 if downed else 0)
	out.append_array(name_bytes)
	return out


## Unpack a received payload back into named fields.
## Returns {x, z, flip_h, moving, map, downed}. Every field is bounds-checked and
## defaulted: this decodes packets straight off the wire, so a truncated or
## malformed payload from any peer must not fault the handler. `map` and `downed`
## are also absent from legacy 4- and 5-element payloads. Matches the
## garbage-tolerant contract every other *Sync decoder in this directory follows.
static func decode(payload: Variant) -> Dictionary:
	if payload is PackedByteArray:
		return _decode_packed(payload as PackedByteArray)
	var arr: Array = payload as Array if payload is Array else []
	return {
		"x": float(arr[0]) if arr.size() > 0 else 0.0,
		"z": float(arr[1]) if arr.size() > 1 else 0.0,
		"flip_h": bool(arr[2]) if arr.size() > 2 else false,
		"moving": bool(arr[3]) if arr.size() > 3 else false,
		"map": str(arr[4]) if arr.size() > 4 else "",
		"downed": bool(arr[5]) if arr.size() > 5 else false,
	}


static func _decode_packed(b: PackedByteArray) -> Dictionary:
	if b.size() < 9:
		return {"x": 0.0, "z": 0.0, "flip_h": false, "moving": false, "map": "", "downed": false}
	var flags: int = b[8]
	return {
		"x": b.decode_float(0),
		"z": b.decode_float(4),
		"flip_h": (flags & 1) != 0,
		"moving": (flags & 2) != 0,
		"map": b.slice(9).get_string_from_utf8(),
		"downed": (flags & 4) != 0,
	}


## Smooth-step a remote avatar's current position toward the latest received target.
## rate: lerp speed (10–15 works well at 15 Hz updates without rubber-banding).
## The factor is clamped to [0, 1] so the result never overshoots the target.
static func interp(current: Vector3, target: Vector3, delta: float, rate: float) -> Vector3:
	var t: float = clamp(delta * rate, 0.0, 1.0)
	return current.lerp(target, t)



## Velocity implied by two consecutive packets `dt` seconds apart. Zero for a
## non-positive or implausibly long gap (a heartbeat after standing still).
static func packet_velocity(prev: Vector2, cur: Vector2, dt: float) -> Vector2:
	if dt <= 0.0 or dt > 0.5:
		return Vector2.ZERO
	return ((cur - prev) / dt).limit_length(MAX_SPEED)


## Dead-reckoned target: the last packet's position pushed along the peer's
## velocity for the time since it arrived (capped), so a 15 Hz stream reads as
## continuous motion instead of stepping toward each packet.
static func extrapolate(target: Vector2, velocity: Vector2, since_packet: float) -> Vector2:
	return target + velocity * clampf(since_packet, 0.0, MAX_EXTRAPOLATION)


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
