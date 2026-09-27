## Derives the current Chapter 1 story objective from story flags.
## Returns {label: String, map: String, tx: int, tz: int} or {} if no active objective.
## Checks most-advanced flag first so the correct next step is always returned.
class_name ObjectiveTracker
extends RefCounted

const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")

## Where the current objective is in the stitched realm (GID-138): a stitched
## town's tile moved into the overworld ("main"), an open-world beat's fixed
## road site, else the objective as authored (an interior / other named map).
static func realm_objective(flags: Dictionary) -> Dictionary:
	var obj: Dictionary = current_objective(flags)
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
	var obj: Dictionary = realm_objective(flags) if _RealmLayout.is_overworld(map_name) \
			else current_objective(flags)
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
	var obj: Dictionary = objective_for_map(flags, map_name)
	if obj.is_empty():
		return null
	return Vector3(
		(float(int(obj["tx"])) + 0.5) * IsoConst.TILE_SIZE,
		0.0,
		(float(int(obj["tz"])) + 0.5) * IsoConst.TILE_SIZE)

static func current_objective(flags: Dictionary) -> Dictionary:
	if flags.get("chapter2_complete", false):
		return {}
	if flags.get("chapter2_warcamp_cleared", false):
		# Cliffhanger narration fires automatically on the boss win; no next objective yet.
		return {}
	if flags.get("chapter2_traitor_seal", false):
		return {"label": "Infiltrate the war-camp", "map": "marsax_hold", "tx": 20, "tz": 50}
	if flags.get("chapter2_siege_won", false):
		return {"label": "Search the hold for clues", "map": "marsax_hold", "tx": 52, "tz": 62}
	if flags.get("chapter2_ambush_survived", false):
		return {"label": "Defend Marsax Hold", "map": "marsax_hold", "tx": 50, "tz": 77}
	if flags.get("chapter2_found_letter", false):
		# The scout ambush waits on the road north from Larik.
		return {"label": "Continue west toward Marsax Hold", "map": "main", "tx": -1, "tz": -1,
			"site": "scout_ambush"}
	if flags.get("chapter2_reached_larik", false):
		return {"label": "Search Larik for answers", "map": "larik", "tx": 59, "tz": 58}
	if flags.get("chapter2_charged", false):
		return {"label": "Travel west to Larik", "map": "larik", "tx": 64, "tz": 50}
	if flags.get("chapter1_complete", false):
		return {"label": "Speak to King Eldar", "map": "blancogov_temple", "tx": 42, "tz": 15}
	if flags.get("chapter1_temple_council", false):
		return {"label": "Speak with the Queen and Scargroth, then the King",
			"map": "blancogov_temple", "tx": 42, "tz": 15}
	if flags.get("chapter1_reached_blancogov", false):
		return {"label": "Enter the Temple", "map": "blancogov_temple", "tx": 42, "tz": 15}
	if flags.get("chapter1_received_letter", false):
		return {"label": "Reach Blancogov", "map": "blancogov", "tx": 49, "tz": 9}
	if flags.get("chapter1_warned_farsyth", false):
		# Isfig waits on the road to Blancogov (RealmLayout.STORY_SITES).
		return {"label": "Encounter Isfig", "map": "main", "tx": -1, "tz": -1, "site": "isfig_road"}
	if flags.get("chapter1_learned_fire", false):
		return {"label": "Find Lord Farsyth", "map": "farsyth_mansion", "tx": 49, "tz": 20}
	if flags.get("chapter1_camp_night", false):
		# Fire-making lesson happens at the road camp.
		return {"label": "Learn to make fire", "map": "main", "tx": -1, "tz": -1, "site": "wilderness_camp"}
	if flags.get("chapter1_left_madrian", false):
		# Rabbit-hunt camp sits on the road south of Madrian.
		return {"label": "Make camp for the night", "map": "main", "tx": -1, "tz": -1,
			"site": "wilderness_camp"}
	if flags.get("story_intro_complete", false):
		return {"label": "Leave Madrian", "map": "main", "tx": -1, "tz": -1, "site": "madrian_south_road"}
	return {"label": "Speak to Maiteln", "map": "madrian", "tx": 45, "tz": 36}
