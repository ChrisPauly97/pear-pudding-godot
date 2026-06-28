## Pure helpers for discrete co-op world-object state changes (GID-096).
##
## Callers: preload("res://game_logic/net/WorldObjectSync.gd")
## No scene dependencies — fully unit-testable. Covers the *discrete* (open/close,
## removed, defeated) events that ride the reliable RPCs, as opposed to the
## continuous position stream in EnemySync. JSON-primitive payloads only.
extends RefCounted

## Event kinds carried by recv_world_event / submit_world_event.
const EV_ENEMY_ENGAGED: String = "enemy_engaged"     # client → authority: I engaged enemy id
const EV_ENEMY_REMOVED: String = "enemy_removed"     # authority → peers: drop enemy id
const EV_ENEMY_DEFEATED: String = "enemy_defeated"   # → authority: persist enemy id as defeated
const EV_CHEST_OPENED: String = "chest_opened"       # opener/authority: chest id is now open


## Pack a discrete world event into [kind, id].
static func encode_event(kind: String, id: String) -> Array:
	return [kind, id]


## Unpack a discrete world event. Garbage/short → {kind:"", id:""} (ignored by callers).
static func decode_event(payload: Array) -> Dictionary:
	if payload.size() < 2:
		return {"kind": "", "id": ""}
	return {"kind": str(payload[0]), "id": str(payload[1])}


## Pack a late-join world snapshot: the set of already-removed enemy ids and
## already-opened object ids. Layout: [removed_enemy_ids, opened_object_ids].
static func encode_snapshot(removed_enemies: Array, opened_objects: Array) -> Array:
	return [_to_str_array(removed_enemies), _to_str_array(opened_objects)]


## Unpack a snapshot into {removed_enemies: Array[String], opened_objects: Array[String]}.
static func decode_snapshot(payload: Array) -> Dictionary:
	var removed: Array = payload[0] if payload.size() > 0 and payload[0] is Array else []
	var opened: Array = payload[1] if payload.size() > 1 and payload[1] is Array else []
	return {
		"removed_enemies": _to_str_array(removed),
		"opened_objects": _to_str_array(opened),
	}


static func _to_str_array(src: Array) -> Array:
	var out: Array = []
	for v in src:
		out.append(str(v))
	return out
