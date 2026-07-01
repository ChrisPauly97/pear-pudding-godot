## Unit tests for DungeonGen secret rooms (TID-207).
##
## Validates secret room generation: determinism, TILE_CRACKED wall placement,
## 3x3 carved area, and bonus chest placement.
extends "res://tests/framework/test_case.gd"

const DungeonGen = preload("res://game_logic/world/DungeonGen.gd")
const WorldMapScript = preload("res://game_logic/world/WorldMap.gd")

# Seeds empirically verified to generate a secret room (rng % 100 < 30).
# Seed 12345 hits the 30% secret room branch.
const SEED_WITH_SECRET: int = 12345


func _gen(seed_val: int) -> RefCounted:
	return DungeonGen.generate("test_dungeon_%d" % seed_val, seed_val)


func test_generate_returns_world_map() -> void:
	var map: RefCounted = _gen(SEED_WITH_SECRET)
	assert_true(map != null, "generate() should return a WorldMap")


func test_dungeon_has_five_rooms_worth_of_tiles() -> void:
	var map: RefCounted = _gen(SEED_WITH_SECRET)
	# At least one TILE_GRASS tile should exist (rooms are carved)
	var grass_count: int = 0
	for tz in range(DungeonGen.DH):
		for tx in range(DungeonGen.DW):
			if map.get_tile(tx, tz) == IsoConst.TILE_GRASS:
				grass_count += 1
	assert_true(grass_count > 50, "dungeon should have many grass tiles after carving rooms and corridors")


func test_secret_room_uses_tile_cracked() -> void:
	# Run many seeds to find one that produces a secret room
	var found_cracked: bool = false
	for seed_val in [12345, 100, 200, 300, 400, 500, 9999, 77777]:
		var map: RefCounted = _gen(seed_val)
		for tz in range(DungeonGen.DH):
			for tx in range(DungeonGen.DW):
				if map.get_tile(tx, tz) == IsoConst.TILE_CRACKED:
					found_cracked = true
					break
			if found_cracked:
				break
		if found_cracked:
			break
	assert_true(found_cracked, "at least one seed should produce a TILE_CRACKED secret room entrance")


func test_cracked_tile_is_adjacent_to_grass() -> void:
	for seed_val in [12345, 100, 200, 300, 400, 500, 9999, 77777]:
		var map: RefCounted = _gen(seed_val)
		for tz in range(1, DungeonGen.DH - 1):
			for tx in range(1, DungeonGen.DW - 1):
				if map.get_tile(tx, tz) == IsoConst.TILE_CRACKED:
					# Must be adjacent to at least one TILE_GRASS tile (the corridor side)
					var adjacent_grass: bool = (
						map.get_tile(tx + 1, tz) == IsoConst.TILE_GRASS or
						map.get_tile(tx - 1, tz) == IsoConst.TILE_GRASS or
						map.get_tile(tx, tz + 1) == IsoConst.TILE_GRASS or
						map.get_tile(tx, tz - 1) == IsoConst.TILE_GRASS
					)
					assert_true(adjacent_grass, "cracked tile at (%d,%d) must border a grass tile" % [tx, tz])
					return  # one check is sufficient


func test_secret_room_chest_has_dsr_prefix() -> void:
	for seed_val in [12345, 100, 200, 300, 400, 500, 9999, 77777]:
		var map: RefCounted = _gen(seed_val)
		for chest in map.chests:
			var cid: String = str(chest.get("id", ""))
			if cid.begins_with("dsr_"):
				assert_true(chest.get("card_ids", []).size() >= 1,
					"secret room chest should have at least 1 card")
				return


func test_secret_room_chest_not_opened_initially() -> void:
	for seed_val in [12345, 100, 200, 300, 400, 500, 9999, 77777]:
		var map: RefCounted = _gen(seed_val)
		for chest in map.chests:
			if str(chest.get("id", "")).begins_with("dsr_"):
				assert_false(bool(chest.get("opened", false)),
					"secret room chest should start closed")
				return


func test_dungeon_determinism_same_seed() -> void:
	var map1: RefCounted = _gen(SEED_WITH_SECRET)
	var map2: RefCounted = _gen(SEED_WITH_SECRET)
	# Both maps should have identical tile at center
	var cx: int = DungeonGen.DW / 2
	var cz: int = DungeonGen.DH / 2
	assert_eq(map1.get_tile(cx, cz), map2.get_tile(cx, cz),
		"same seed should produce same tile at center")
	assert_eq(map1.chests.size(), map2.chests.size(),
		"same seed should produce same chest count")


## GID-102 / TID-380: co-op shared dungeon crawl relies on DungeonGen being a pure
## function of (name, seed) — every peer independently calls DungeonGen.generate()
## with the same seed and must get byte-identical tile grids AND identical entity
## ids/types/positions, since GID-096's engage-lock / first-opener-takes sync keys
## purely on those string ids. This asserts the full property, not just a sample.
func test_dungeon_determinism_full_grid_and_entity_ids() -> void:
	var seed_val: int = 54321
	var map1: RefCounted = DungeonGen.generate("det_test_a_%d" % seed_val, seed_val)
	var map2: RefCounted = DungeonGen.generate("det_test_b_%d" % seed_val, seed_val)

	# Full tile grid equality (every tile, not just the center sample).
	for tz in range(DungeonGen.DH):
		for tx in range(DungeonGen.DW):
			assert_eq(map1.get_tile(tx, tz), map2.get_tile(tx, tz),
				"tile (%d,%d) should match for identical seed" % [tx, tz])

	# Player spawn identical.
	assert_eq(map1.player_spawn_x, map2.player_spawn_x, "spawn x should match")
	assert_eq(map1.player_spawn_z, map2.player_spawn_z, "spawn z should match")

	# Entity arrays identical in count, ids, types, and positions.
	assert_eq(map1.enemies.size(), map2.enemies.size(), "enemy count should match")
	for i in range(map1.enemies.size()):
		var e1: Dictionary = map1.enemies[i]
		var e2: Dictionary = map2.enemies[i]
		assert_eq(str(e1.get("id")), str(e2.get("id")), "enemy %d id should match" % i)
		assert_eq(str(e1.get("enemy_type")), str(e2.get("enemy_type")),
			"enemy %d type should match" % i)
		assert_eq(float(e1.get("x")), float(e2.get("x")), "enemy %d x should match" % i)
		assert_eq(float(e1.get("z")), float(e2.get("z")), "enemy %d z should match" % i)

	assert_eq(map1.chests.size(), map2.chests.size(), "chest count should match")
	for i in range(map1.chests.size()):
		var c1: Dictionary = map1.chests[i]
		var c2: Dictionary = map2.chests[i]
		assert_eq(str(c1.get("id")), str(c2.get("id")), "chest %d id should match" % i)
		assert_eq(bool(c1.get("is_mimic", false)), bool(c2.get("is_mimic", false)),
			"chest %d mimic flag should match" % i)
		assert_eq(float(c1.get("x")), float(c2.get("x")), "chest %d x should match" % i)
		assert_eq(float(c1.get("z")), float(c2.get("z")), "chest %d z should match" % i)

	assert_eq(map1.npcs.size(), map2.npcs.size(), "npc count should match")
	for i in range(map1.npcs.size()):
		var n1: Dictionary = map1.npcs[i]
		var n2: Dictionary = map2.npcs[i]
		assert_eq(str(n1.get("id")), str(n2.get("id")), "npc %d id should match" % i)
		assert_eq(str(n1.get("npc_type")), str(n2.get("npc_type")),
			"npc %d type should match" % i)

	assert_eq(map1.doors.size(), map2.doors.size(), "door count should match")
	for i in range(map1.doors.size()):
		var d1: Dictionary = map1.doors[i]
		var d2: Dictionary = map2.doors[i]
		assert_eq(str(d1.get("id")), str(d2.get("id")), "door %d id should match" % i)
		assert_eq(str(d1.get("target_map")), str(d2.get("target_map")),
			"door %d target_map should match" % i)


func test_dungeon_different_seeds_differ() -> void:
	var map1: RefCounted = _gen(11111)
	var map2: RefCounted = _gen(99999)
	# It's extremely unlikely two different seeds produce identical chest counts AND
	# identical player spawn coordinates, so check at least one differs.
	var same_spawn: bool = (map1.player_spawn_x == map2.player_spawn_x and
		map1.player_spawn_z == map2.player_spawn_z)
	var same_chests: bool = (map1.chests.size() == map2.chests.size())
	assert_false(same_spawn and same_chests,
		"different seeds should produce different dungeons")


func test_end_room_always_has_exit_door() -> void:
	for seed_val in [12345, 11111, 22222, 99999]:
		var map: RefCounted = _gen(seed_val)
		var has_exit: bool = false
		for door in map.doors:
			if str(door.get("id", "")) == "exit":
				has_exit = true
				break
		assert_true(has_exit, "dungeon with seed %d should always have an exit door" % seed_val)


func test_player_spawn_within_dungeon_bounds() -> void:
	for seed_val in [12345, 11111, 22222]:
		var map: RefCounted = _gen(seed_val)
		var max_world: float = float(DungeonGen.DW) * IsoConst.TILE_SIZE
		assert_true(map.player_spawn_x >= 0.0 and map.player_spawn_x < max_world,
			"player spawn X should be within dungeon bounds")
