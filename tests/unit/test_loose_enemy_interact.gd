## Enemies spawned outside the chunk pipeline (story rivals, siege raiders,
## spectres) must still be reachable by interact. `_find_nearby_enemy` used to
## scan only ChunkData.enemies, so Isfig on the road could not be engaged.
extends "res://tests/framework/test_case.gd"

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _ChunkStreamingManager = preload("res://scenes/world/ChunkStreamingManager.gd")


func _world() -> _WorldScene:
	var ws: _WorldScene = _WorldScene.new()
	ws._csm = _ChunkStreamingManager.new()
	return ws


func test_loose_enemy_is_found_in_range() -> void:
	var ws: _WorldScene = _world()
	var rival := Node3D.new()
	rival.position = Vector3(160.0, 0.0, 360.0)
	ws.register_loose_enemy("rival_enc2", rival)
	assert_eq(ws._find_nearby_enemy(161.0, 361.0, 3.0), rival, "rival on the road is interactable")
	assert_null(ws._find_nearby_enemy(200.0, 400.0, 3.0), "out of range → nothing")
	assert_true(ws._enemy_nodes.has("rival_enc2"), "still tracked with every other enemy")
	rival.free()
	assert_null(ws._find_nearby_enemy(161.0, 361.0, 3.0), "a freed rival is skipped, not crashed on")
	ws._csm.free()
	ws.free()
