## Where the current main-story objective is, on whichever map the player is on.
## The steps themselves live in StoryQuests.STEPS; this resolves a step (or any
## quest target of the same {map, tx, tz, site} shape — see QuestLog) to a tile.
class_name ObjectiveTracker
extends RefCounted

const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _StoryQuests = preload("res://game_logic/quests/StoryQuests.gd")

## Where the current objective is in the stitched realm (GID-138): a stitched
## town's tile moved into the overworld ("main"), an open-world beat's fixed
## road site, else the objective as authored (an interior / other named map).
static func realm_objective(flags: Dictionary) -> Dictionary:
	return to_realm(current_objective(flags))

## `realm_objective` for any target dict of the same shape.
static func to_realm(obj: Dictionary) -> Dictionary:
	if obj.is_empty():
		return {}
	var out: Dictionary = obj.duplicate()
	var site: String = str(obj.get("site", ""))
	var map: String = str(obj.get("map", ""))
	if site != "":
		var t: Vector2i = _RealmLayout.STORY_SITES[site]
		out["map"] = "main"
		out["tx"] = t.x
		out["tz"] = t.y
	elif _RealmLayout.is_stitched(map):
		var w: Vector2i = _RealmLayout.to_world_tile(map, Vector2i(int(obj["tx"]), int(obj["tz"])))
		out["map"] = "main"
		out["tx"] = w.x
		out["tz"] = w.y
	return out

## The active objective, but only when it is a real place on `map_name` the
## player can be pointed at — {} when there is none or it belongs to another map.
## In the overworld an objective inside an interior points at that interior's
## door, and stitched-town / road-site objectives are in overworld tiles.
##
## Single source for every "where is the objective" caller (compass marker,
## in-world beacon), so they can never disagree about which map or tile it is on.
static func objective_for_map(flags: Dictionary, map_name: String) -> Dictionary:
	return place_on_map(current_objective(flags), map_name)

## `objective_for_map` for any target dict ({map, tx, tz[, site]}) — QuestLog
## resolves treasure and bounty targets through the same rules.
static func place_on_map(target: Dictionary, map_name: String) -> Dictionary:
	var obj: Dictionary = to_realm(target) if _RealmLayout.is_overworld(map_name) else target
	if obj.is_empty():
		return {}
	var obj_map: String = str(obj.get("map", ""))
	if _RealmLayout.is_overworld(obj_map) and _RealmLayout.is_overworld(map_name):
		obj_map = map_name  # "main" and "infinite" are the same overworld
	if obj_map != map_name and _RealmLayout.is_overworld(map_name):
		# The objective is inside an interior: point at the door that leads in.
		var door: Dictionary = _RealmLayout.door_into(obj_map)
		if door.is_empty():
			return {}
		var out: Dictionary = obj.duplicate()
		out["map"] = map_name
		out["tx"] = int(floor(float(door["x"]) / IsoConst.TILE_SIZE))
		out["tz"] = int(floor(float(door["z"]) / IsoConst.TILE_SIZE))
		return out
	if obj_map != map_name:
		return {}
	# Named maps use the (−1, −1) wildcard for "no fixed tile"; overworld tiles can be negative.
	if not _RealmLayout.is_overworld(map_name) and (int(obj.get("tx", -1)) < 0 or int(obj.get("tz", -1)) < 0):
		return {}
	return obj

## Centre of the objective's tile in world space, or null when there is nothing
## to point at (see `objective_for_map`). Entities are spawned on tile centres,
## so the beacon and the compass bearing both use the centre, not the corner.
static func objective_world_pos(flags: Dictionary, map_name: String) -> Variant:
	return target_world_pos(current_objective(flags), map_name)

## `objective_world_pos` for any target dict.
static func target_world_pos(target: Dictionary, map_name: String) -> Variant:
	var obj: Dictionary = place_on_map(target, map_name)
	if obj.is_empty():
		return null
	return Vector3(
		(float(int(obj["tx"])) + 0.5) * IsoConst.TILE_SIZE,
		0.0,
		(float(int(obj["tz"])) + 0.5) * IsoConst.TILE_SIZE)

## The current main-story step (see StoryQuests.STEPS), or {} past the last one.
static func current_objective(flags: Dictionary) -> Dictionary:
	return _StoryQuests.current_step(flags)
