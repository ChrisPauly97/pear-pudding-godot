## Unit tests for IsoConst coordinate utilities.
##
## IsoConst is an autoload (extends Node) so we preload and instantiate it
## directly rather than relying on the singleton.  The constants are verified
## independently of the Node lifecycle.
extends "res://tests/framework/test_case.gd"

const IsoConstScript = preload("res://autoloads/IsoConst.gd")

var _iso: Node

func before_all() -> void:
	_iso = IsoConstScript.new()


func after_all() -> void:
	_iso.free()


# ---------------------------------------------------------------------------
# Chunk and tile size constants
# ---------------------------------------------------------------------------

func test_chunk_size_is_16() -> void:
	assert_eq(IsoConstScript.CHUNK_SIZE, 16)


func test_tile_size_is_2() -> void:
	assert_almost_eq(IsoConstScript.TILE_SIZE, 2.0)


# ---------------------------------------------------------------------------
# Tile type constants
# ---------------------------------------------------------------------------

func test_tile_grass_is_zero() -> void:
	assert_eq(IsoConstScript.TILE_GRASS, 0)


func test_tile_wall_is_one() -> void:
	assert_eq(IsoConstScript.TILE_WALL, 1)


func test_tile_hill_is_two() -> void:
	assert_eq(IsoConstScript.TILE_HILL, 2)


func test_tile_type_constants_are_distinct() -> void:
	assert_ne(IsoConstScript.TILE_GRASS, IsoConstScript.TILE_WALL)
	assert_ne(IsoConstScript.TILE_GRASS, IsoConstScript.TILE_HILL)
	assert_ne(IsoConstScript.TILE_WALL, IsoConstScript.TILE_HILL)


# ---------------------------------------------------------------------------
# Entity range constants — sanity checks
# ---------------------------------------------------------------------------

func test_auto_battle_range_is_positive() -> void:
	assert_gt(IsoConstScript.AUTO_BATTLE_RANGE, 0.0)


func test_interact_range_is_positive() -> void:
	assert_gt(IsoConstScript.INTERACT_RANGE, 0.0)


func test_player_speed_is_positive() -> void:
	assert_gt(IsoConstScript.PLAYER_SPEED, 0.0)


func test_player_radius_is_positive() -> void:
	assert_gt(IsoConstScript.PLAYER_RADIUS, 0.0)


# ---------------------------------------------------------------------------
# tile_to_world
# ---------------------------------------------------------------------------

func test_tile_to_world_origin_maps_to_origin() -> void:
	var pos: Vector3 = _iso.tile_to_world(0, 0)
	assert_almost_eq(pos.x, 0.0)
	assert_almost_eq(pos.y, 0.0)
	assert_almost_eq(pos.z, 0.0)


func test_tile_to_world_x_scales_by_tile_size() -> void:
	var pos: Vector3 = _iso.tile_to_world(5, 0)
	assert_almost_eq(pos.x, 5.0 * IsoConstScript.TILE_SIZE)


func test_tile_to_world_z_scales_by_tile_size() -> void:
	var pos: Vector3 = _iso.tile_to_world(0, 3)
	assert_almost_eq(pos.z, 3.0 * IsoConstScript.TILE_SIZE)


func test_tile_to_world_y_is_always_zero() -> void:
	var pos: Vector3 = _iso.tile_to_world(10, 10)
	assert_almost_eq(pos.y, 0.0)


func test_tile_to_world_large_coordinates() -> void:
	var pos: Vector3 = _iso.tile_to_world(50, 75)
	assert_almost_eq(pos.x, 100.0)
	assert_almost_eq(pos.z, 150.0)


# ---------------------------------------------------------------------------
# world_to_tile
# ---------------------------------------------------------------------------

func test_world_to_tile_origin_maps_to_zero_zero() -> void:
	var tile: Vector2i = _iso.world_to_tile(0.0, 0.0)
	assert_eq(tile.x, 0)
	assert_eq(tile.y, 0)


func test_world_to_tile_exact_tile_boundary() -> void:
	var tile: Vector2i = _iso.world_to_tile(4.0, 6.0)
	assert_eq(tile.x, 2)
	assert_eq(tile.y, 3)


func test_world_to_tile_floors_fractional_coordinates() -> void:
	# 3.9 / 2.0 = 1.95 → floor → tile 1
	var tile: Vector2i = _iso.world_to_tile(3.9, 3.9)
	assert_eq(tile.x, 1)
	assert_eq(tile.y, 1)


func test_tile_to_world_and_world_to_tile_roundtrip() -> void:
	for tx in [0, 5, 10, 50, 99]:
		for tz in [0, 5, 10, 50, 99]:
			var world_pos: Vector3 = _iso.tile_to_world(tx, tz)
			var tile_back: Vector2i = _iso.world_to_tile(world_pos.x, world_pos.z)
			assert_eq(tile_back.x, tx, "roundtrip failed for tx=%d" % tx)
			assert_eq(tile_back.y, tz, "roundtrip failed for tz=%d" % tz)
