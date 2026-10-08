## GID-173 / TID-701: cave interiors (CaveGen via DungeonGen for dungeon_cave_* maps).
extends "res://tests/framework/test_case.gd"

const CaveGen = preload("res://game_logic/world/CaveGen.gd")
const DungeonGen = preload("res://game_logic/world/DungeonGen.gd")
const WorldMap = preload("res://game_logic/world/WorldMap.gd")

const NAMES: Array[String] = ["dungeon_cave_101", "dungeon_cave_77231", "dungeon_cave_5150", "dungeon_cave_9"]


func _open(m: WorldMap) -> Dictionary:
	var open: Dictionary = {}
	for z: int in range(WorldMap.MAP_HEIGHT):
		for x: int in range(WorldMap.MAP_WIDTH):
			if m.get_tile(x, z) == IsoConst.TILE_GRASS:
				open[Vector2i(x, z)] = true
	return open


func _reach(open: Dictionary, from: Vector2i) -> Dictionary:
	return CaveGen._walk_distances(open, from)


func test_caves_are_one_connected_cavern() -> void:
	for n: String in NAMES:
		var m: WorldMap = DungeonGen.generate(n, int(n.to_int()))
		var open: Dictionary = _open(m)
		assert_gt(open.size(), CaveGen.MIN_OPEN - 60, "%s is roomy (%d open)" % [n, open.size()])
		var spawn := Vector2i(m.player_spawn_x, m.player_spawn_z)
		assert_true(open.has(spawn), "%s spawns on open floor" % n)
		var dist: Dictionary = _reach(open, spawn)
		assert_eq(dist.size(), open.size(), "%s: every open tile is reachable from the entrance" % n)
		for group: Array[Dictionary] in [m.enemies, m.chests, m.doors, m.npcs]:
			for e: Dictionary in group:
				var t: Vector2i = IsoConst.world_to_tile(float(e["x"]), float(e["z"]))
				assert_true(dist.has(t), "%s: %s stands on reachable floor" % [n, str(e["id"])])
		assert_eq(m.get_tile(0, 0), IsoConst.TILE_WALL, "solid rock outside the cave box")
		assert_eq(m.get_tile(WorldMap.MAP_WIDTH - 1, WorldMap.MAP_HEIGHT - 1), IsoConst.TILE_WALL)


func test_exit_at_the_far_end_and_dwellers_along_the_way() -> void:
	var m: WorldMap = DungeonGen.generate(NAMES[0], 101)
	var exits: Array[Dictionary] = m.doors.filter(func(d: Dictionary) -> bool: return str(d["id"]) == "exit")
	assert_eq(exits.size(), 1, "one way out")
	assert_eq(str(exits[0]["target_map"]), "", "the exit returns to the overworld")
	var open: Dictionary = _open(m)
	var dist: Dictionary = _reach(open, Vector2i(m.player_spawn_x, m.player_spawn_z))
	var ex: Vector2i = IsoConst.world_to_tile(float(exits[0]["x"]), float(exits[0]["z"]))
	var far: int = 0
	for v: Variant in dist.values():
		far = maxi(far, int(v))
	assert_gte(int(dist[ex]), far - 2, "the exit is the far end of the cave")
	assert_gte(m.enemies.size(), 3, "cave dwellers")
	for e: Dictionary in m.enemies:
		assert_true(CaveGen.CAVE_POOL.has(str(e["enemy_type"])), "a cave dweller, not a crypt ghoul pack only")
		assert_false((e["enemy_deck"] as Array).is_empty(), "with a deck")
	var crystal: int = 0
	for c: Dictionary in m.chests:
		if bool(c.get("crystal", false)):
			crystal += 1
			assert_true(str(c["id"]).begins_with("dtr_"), "crystal caches drop like treasure rooms")
	assert_gt(crystal, 0, "at least one crystal cache")


func test_deterministic_and_plain_dungeons_unchanged() -> void:
	var a: WorldMap = CaveGen.generate("dungeon_cave_4242", 4242)
	var b: WorldMap = CaveGen.generate("dungeon_cave_4242", 4242)
	assert_eq(a.tiles, b.tiles, "same seed, same cave")
	assert_eq(a.enemies.size(), b.enemies.size())
	var d: WorldMap = DungeonGen.generate("dungeon_4242", 4242)
	assert_eq(d.get_tile(1, 1), IsoConst.TILE_WALL, "a plain dungeon still uses rooms")
	assert_true(d.doors.any(func(x: Dictionary) -> bool: return str(x["id"]) == "exit"), "with its exit")
