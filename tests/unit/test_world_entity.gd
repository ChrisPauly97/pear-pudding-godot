## Unit tests for WorldEntity.
##
## Tests cover construction, Euclidean distance calculation (including edge
## cases such as zero distance and negative coordinates), and the world-position
## conversion helper.
extends "res://tests/framework/test_case.gd"

const WorldEntity = preload("res://game_logic/world/WorldEntity.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _entity(id: String = "e", x: float = 0.0, z: float = 0.0) -> WorldEntity:
	return WorldEntity.new(id, x, z)


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func test_id_is_stored() -> void:
	assert_eq(_entity("enemy_1").id, "enemy_1")


func test_x_is_stored() -> void:
	assert_almost_eq(_entity("e", 3.5, 0.0).x, 3.5)


func test_z_is_stored() -> void:
	assert_almost_eq(_entity("e", 0.0, 7.25).z, 7.25)


# ---------------------------------------------------------------------------
# distance_to
# ---------------------------------------------------------------------------

func test_distance_to_same_position_is_zero() -> void:
	var e = _entity("e", 5.0, 5.0)
	assert_almost_eq(e.distance_to(5.0, 5.0), 0.0)


func test_distance_to_adjacent_along_x() -> void:
	var e = _entity("e", 0.0, 0.0)
	assert_almost_eq(e.distance_to(3.0, 0.0), 3.0)


func test_distance_to_adjacent_along_z() -> void:
	var e = _entity("e", 0.0, 0.0)
	assert_almost_eq(e.distance_to(0.0, 4.0), 4.0)


func test_distance_to_diagonal_is_correct() -> void:
	# 3-4-5 Pythagorean triple
	var e = _entity("e", 0.0, 0.0)
	assert_almost_eq(e.distance_to(3.0, 4.0), 5.0)


func test_distance_to_is_symmetric() -> void:
	var a = _entity("a", 1.0, 2.0)
	var b = _entity("b", 4.0, 6.0)
	assert_almost_eq(a.distance_to(b.x, b.z), b.distance_to(a.x, a.z))


func test_distance_to_negative_coordinates() -> void:
	var e = _entity("e", -3.0, 0.0)
	assert_almost_eq(e.distance_to(0.0, 0.0), 3.0)


func test_distance_to_both_negative() -> void:
	var e = _entity("e", -3.0, -4.0)
	assert_almost_eq(e.distance_to(0.0, 0.0), 5.0)


func test_distance_is_always_non_negative() -> void:
	var e = _entity("e", -10.0, -10.0)
	assert_gte(e.distance_to(5.0, 5.0), 0.0)


func test_distance_to_point_at_large_coordinates() -> void:
	var e = _entity("e", 0.0, 0.0)
	# 30-40-50 triple (scaled 3-4-5)
	assert_almost_eq(e.distance_to(30.0, 40.0), 50.0)


# ---------------------------------------------------------------------------
# to_world_pos
# ---------------------------------------------------------------------------

func test_to_world_pos_has_correct_x() -> void:
	var e = _entity("e", 6.0, 3.0)
	assert_almost_eq(e.to_world_pos().x, 6.0)


func test_to_world_pos_has_y_zero() -> void:
	var e = _entity("e", 5.0, 2.0)
	assert_almost_eq(e.to_world_pos().y, 0.0)


func test_to_world_pos_has_correct_z() -> void:
	var e = _entity("e", 1.0, 8.0)
	assert_almost_eq(e.to_world_pos().z, 8.0)


func test_to_world_pos_origin_entity() -> void:
	var pos = _entity("e", 0.0, 0.0).to_world_pos()
	assert_almost_eq(pos.x, 0.0)
	assert_almost_eq(pos.y, 0.0)
	assert_almost_eq(pos.z, 0.0)
