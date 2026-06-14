## TrophyRegistry — static data and predicates for player-home trophy pedestals.
##
## Each trophy entry has:
##   display_name: String — shown when interacting with the pedestal
##   description:  String — shown below the name
##   predicate_key: String — identifies which static check function to call
##
## Predicates gracefully return false when the relevant save fields don't exist yet
## (e.g. GID-037 / GID-038 features not yet unlocked in a given save).

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

const _DATA: Array[Dictionary] = [
	{
		"id": "champion",
		"display_name": "Regional Champion",
		"description": "Defeat all duelist NPCs in the world.",
		"predicate_key": "champion",
	},
	{
		"id": "spire_7",
		"display_name": "Spire Climber",
		"description": "Reach floor 7 or higher in the Endless Spire.",
		"predicate_key": "spire_7",
	},
	{
		"id": "first_boss",
		"display_name": "Boss Slayer",
		"description": "Defeat your first boss.",
		"predicate_key": "first_boss",
	},
]

static func get_all() -> Array[Dictionary]:
	return _DATA

static func get_trophy(trophy_id: String) -> Dictionary:
	for entry: Dictionary in _DATA:
		if entry["id"] == trophy_id:
			return entry
	return {}

static func is_earned(trophy_id: String, save_mgr: Object) -> bool:
	match trophy_id:
		"champion":
			return _check_champion(save_mgr)
		"spire_7":
			return _check_spire_7(save_mgr)
		"first_boss":
			return _check_first_boss(save_mgr)
	return false

static func _check_champion(save_mgr: Object) -> bool:
	var duelists: Variant = save_mgr.get("defeated_duelists")
	if duelists == null:
		return false
	var arr: Array = duelists as Array
	return arr.size() > 0

static func _check_spire_7(save_mgr: Object) -> bool:
	var best: Variant = save_mgr.get("spire_best_floor")
	if best == null:
		return false
	return int(best) >= 7

static func _check_first_boss(save_mgr: Object) -> bool:
	var defeated: Variant = save_mgr.get("defeated_enemies")
	if defeated == null:
		return false
	var arr: Array = defeated as Array
	for raw_id in arr:
		var eid: String = str(raw_id)
		# Enemy IDs encode the type: "enemy_cx_cz_idx" for world enemies,
		# or "map_<mapname>_enemy_<id>" for named-map enemies.
		# We look up the enemy type via EnemyRegistry which knows is_boss.
		# Named-map enemies have their type in the id prefix; skip lookup for
		# world enemies since type info is not embedded in the defeat id.
		# Fallback: check for any enemy id that begins with a known boss type.
		if EnemyRegistry.is_boss(eid):
			return true
		# Also check if the battle enemy data stored a boss type for this id.
	return false
