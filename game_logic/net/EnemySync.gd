## Pure helpers for authority→client enemy position sync (GID-096).
##
## Callers: preload("res://game_logic/net/EnemySync.gd")
## No scene dependencies — fully unit-testable without a live connection. Mirrors
## AvatarSync. Co-op enemies are spawned deterministically from the shared map, so
## their positions are already identical on every peer; this stream exists for
## forward-compat with future *moving* enemies (named-map enemies are static today).
## Discrete lifecycle (engaged / defeated / chest opened) goes through WorldObjectSync.
extends RefCounted


## Pack one enemy's transform + liveness into a JSON-primitive payload.
## Layout: [id: String, x: float, z: float, alive: bool]. y is omitted — receivers
## recompute it from terrain height, exactly like AvatarSync.
static func encode_state(id: String, x: float, z: float, alive: bool) -> Array:
	return [id, x, z, alive]


## Unpack a single enemy-state payload. Fully defaulted against short/garbage input.
static func decode_state(payload: Array) -> Dictionary:
	if payload.size() < 4:
		return {"id": "", "x": 0.0, "z": 0.0, "alive": true}
	return {
		"id": str(payload[0]),
		"x": float(payload[1]),
		"z": float(payload[2]),
		"alive": bool(payload[3]),
	}


## Pack many enemy states into one packet: [[id,x,z,alive], ...]. The list is the
## payload (kept as a method so the call sites read symmetrically with decode_batch).
static func encode_batch(states: Array) -> Array:
	return states


## Unpack a batch packet into an Array of decoded dictionaries, skipping non-array
## entries so a malformed element can never crash the receiver.
static func decode_batch(payload: Array) -> Array:
	var out: Array = []
	for entry in payload:
		if entry is Array:
			out.append(decode_state(entry))
	return out


## Smooth-step a synced enemy toward its latest target (clamped, no overshoot).
## Same contract as AvatarSync.interp — shared so avatars and enemies move alike.
static func interp(current: Vector3, target: Vector3, delta: float, rate: float) -> Vector3:
	var t: float = clamp(delta * rate, 0.0, 1.0)
	return current.lerp(target, t)
