## v43 save migration: stitched story towns moved into the overworld (GID-138).
extends "res://tests/framework/test_case.gd"

const _SaveMigrations = preload("res://game_logic/save/SaveMigrations.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")


func _v42(extra: Dictionary) -> Dictionary:
	var d: Dictionary = {"version": 42, "map_stack": [], "door_stack": [], "waypoint": {}}
	d.merge(extra, true)
	return d


func test_save_in_town_moves_to_overworld_same_spot() -> void:
	var d: Dictionary = _v42({"current_map": "maykalene", "player_x": 100.0, "player_z": 40.0})
	_SaveMigrations.apply(d, 43)
	var shift: Vector2 = RealmLayout.world_shift("maykalene")
	assert_eq(str(d["current_map"]), "main")
	assert_almost_eq(float(d["player_x"]), 100.0 + shift.x, 0.001)
	assert_almost_eq(float(d["player_z"]), 40.0 + shift.y, 0.001)
	assert_eq((d["map_stack"] as Array).size(), 0, "overworld has no stack")


func test_interior_stack_returns_to_its_door() -> void:
	var d: Dictionary = _v42({"current_map": "blancogov_temple", "player_x": 5.0, "player_z": 5.0,
		"map_stack": ["madrian", "main", "blancogov"], "door_stack": ["", "", ""]})
	_SaveMigrations.apply(d, 43)
	assert_eq(str(d["current_map"]), "blancogov_temple", "interiors stay put")
	assert_eq(d["map_stack"], ["main"], "town + overworld entries collapse into one")
	var p: Variant = RealmLayout.parse_pos_token(str((d["door_stack"] as Array)[0]))
	var expect: Variant = RealmLayout.return_pos_for("blancogov_temple")
	assert_true(p is Vector3 and expect is Vector3, "return token is a position")
	assert_true((p as Vector3).distance_to(expect as Vector3) < 0.1, "back out at the temple door")


func test_waypoint_in_town_translates() -> void:
	var d: Dictionary = _v42({"current_map": "main", "player_x": 1.0, "player_z": 1.0,
		"waypoint": {"map": "larik", "tx": 50, "tz": 50}})
	_SaveMigrations.apply(d, 43)
	var t: Vector2i = RealmLayout.to_world_tile("larik", Vector2i(50, 50))
	assert_eq(d["waypoint"], {"map": "main", "tx": t.x, "tz": t.y})


func test_pos_token_round_trip() -> void:
	var tok: String = RealmLayout.pos_token(12.5, -3.25)
	var p: Variant = RealmLayout.parse_pos_token(tok)
	assert_true(p is Vector3)
	assert_almost_eq((p as Vector3).x, 12.5, 0.01)
	assert_almost_eq((p as Vector3).z, -3.25, 0.01)
	assert_null(RealmLayout.parse_pos_token("door_3"), "door ids are not tokens")
