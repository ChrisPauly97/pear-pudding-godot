extends "res://tests/framework/test_case.gd"

## SpawnPoint (BID-055): the spawn rules lifted out of WorldScene._spawn_player.

const _SpawnPoint = preload("res://game_logic/world/SpawnPoint.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")


func _map_with_door() -> WorldMap:
	var wm := WorldMap.new("test_map", true)
	wm.player_spawn_x = 4
	wm.player_spawn_z = 6
	wm.doors.append({"id": "front", "x": 10.0, "z": 12.0})
	return wm


func test_map_spawn_uses_marker_centre() -> void:
	var ts: float = IsoConst.TILE_SIZE
	assert_eq(_SpawnPoint.map_spawn(_map_with_door()), Vector2(4.5 * ts, 6.5 * ts))


func test_map_spawn_without_marker_falls_back_three_tiles_in() -> void:
	var wm := WorldMap.new("test_map", true)
	wm.player_spawn_x = -1
	assert_eq(_SpawnPoint.map_spawn(wm), Vector2(3.0, 3.0) * IsoConst.TILE_SIZE)
	assert_eq(_SpawnPoint.map_spawn(null), Vector2(3.0, 3.0) * IsoConst.TILE_SIZE)


func test_named_map_door_wins_over_saved_position() -> void:
	var p: Vector2 = _SpawnPoint.resolve(false, "test_map", _map_with_door(), "front", "test_map", Vector2(1, 1))
	assert_eq(p, Vector2(10, 12))


func test_named_map_unknown_door_falls_back_to_spawn() -> void:
	var wm := _map_with_door()
	assert_eq(_SpawnPoint.resolve(false, "test_map", wm, "nope", "", Vector2.ZERO), _SpawnPoint.map_spawn(wm))


func test_named_map_restores_only_when_save_is_on_this_map() -> void:
	var wm := _map_with_door()
	assert_eq(_SpawnPoint.resolve(false, "test_map", wm, "", "test_map", Vector2(7, 8)), Vector2(7, 8))
	assert_eq(_SpawnPoint.resolve(false, "test_map", wm, "", "madrian", Vector2(7, 8)), _SpawnPoint.map_spawn(wm))
	assert_eq(_SpawnPoint.resolve(false, "test_map", wm, "", "test_map", Vector2.ZERO), _SpawnPoint.map_spawn(wm))


func test_overworld_interior_exit_token_wins() -> void:
	var token: String = _RealmLayout.pos_token(40.0, 50.0)
	assert_eq(_SpawnPoint.resolve(true, "main", null, token, "main", Vector2(7, 8)), Vector2(40, 50))


func test_overworld_continue_and_new_game() -> void:
	assert_eq(_SpawnPoint.resolve(true, "main", null, "", "main", Vector2(7, 8)), Vector2(7, 8))
	var madrian: Vector3 = _RealmLayout.spawn_pos("madrian")
	assert_eq(_SpawnPoint.resolve(true, "main", null, "", "", Vector2(7, 8)), Vector2(madrian.x, madrian.z))
