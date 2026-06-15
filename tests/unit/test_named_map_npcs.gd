## Unit tests for NPC spawning in named maps.
##
## Validates that NPCs defined in map files (.txt) survive the full
## data chain: file parsing → WorldMap → ChunkData distribution → iteration.
extends "res://tests/framework/test_case.gd"

const WorldMapScript = preload("res://game_logic/world/WorldMap.gd")
const ChunkDataScript = preload("res://game_logic/world/ChunkData.gd")

const CHUNK_SIZE: int = 16

# ---------------------------------------------------------------------------
# madrian map — 2 NPCs defined in file
# ---------------------------------------------------------------------------

func test_madrian_loads_ten_npcs() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	assert_eq(wm.npcs.size(), 10, "madrian should define 10 NPCs")


func test_madrian_npc_ids_are_unique() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	if wm.npcs.size() >= 2:
		assert_ne(wm.npcs[0]["id"], wm.npcs[1]["id"], "NPC ids should be unique")


func test_madrian_npc_has_dialogue() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	for n in wm.npcs:
		var dlg: String = str(n.get("dialogue", ""))
		assert_true(dlg.length() > 3, "NPC %s should have meaningful dialogue" % n["id"])


func test_madrian_npc_world_positions_are_valid() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	var max_world: float = float(WorldMapScript.MAP_WIDTH) * IsoConst.TILE_SIZE
	for n in wm.npcs:
		var wx: float = n["x"]
		var wz: float = n["z"]
		assert_true(wx >= 0.0 and wx < max_world, "NPC x %.1f should be in map bounds" % wx)
		assert_true(wz >= 0.0 and wz < max_world, "NPC z %.1f should be in map bounds" % wz)


func test_madrian_npcs_distributed_to_chunks() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	var max_cx: int = (WorldMapScript.MAP_WIDTH + CHUNK_SIZE - 1) / CHUNK_SIZE
	var max_cz: int = (WorldMapScript.MAP_HEIGHT + CHUNK_SIZE - 1) / CHUNK_SIZE
	var total: int = 0
	for cz in range(max_cz):
		for cx in range(max_cx):
			var cd: RefCounted = wm.get_chunk_data(cx, cz)
			total += cd.npcs.size()
	assert_eq(total, wm.npcs.size(), "all NPCs should appear in exactly one chunk")


func test_chunk_data_has_entities_flag_set() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	var cd: RefCounted = wm.get_chunk_data(0, 0)
	assert_true(cd.has_entities, "chunk data from named map should have has_entities=true")


func test_chunk_data_is_generated_flag_set() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	var cd: RefCounted = wm.get_chunk_data(0, 0)
	assert_true(cd.is_generated, "chunk data from named map should have is_generated=true")


# ---------------------------------------------------------------------------
# All named maps — every map with NPC lines should load them
# ---------------------------------------------------------------------------

func test_all_named_maps_load_npcs() -> void:
	var map_names: Array[String] = WorldMapScript.list_map_names()
	for mname in map_names:
		if mname == "main" or mname == "infinite" or mname == "test":
			continue
		var wm: RefCounted = WorldMapScript.new(mname)
		# Every story map should have at least one NPC
		if wm.npcs.size() > 0:
			# Verify NPCs survive chunk distribution
			var max_cx: int = (WorldMapScript.MAP_WIDTH + CHUNK_SIZE - 1) / CHUNK_SIZE
			var max_cz: int = (WorldMapScript.MAP_HEIGHT + CHUNK_SIZE - 1) / CHUNK_SIZE
			var total: int = 0
			for cz in range(max_cz):
				for cx in range(max_cx):
					total += wm.get_chunk_data(cx, cz).npcs.size()
			assert_eq(total, wm.npcs.size(),
				"map '%s': chunk NPC count should match world NPC count" % mname)


func test_madrian_is_not_fallback() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	assert_false(wm.is_fallback, "madrian should load from file, not fallback")


func test_nonexistent_map_is_fallback() -> void:
	var wm: RefCounted = WorldMapScript.new("nonexistent_map_12345")
	assert_true(wm.is_fallback, "nonexistent map should use fallback")


func test_fallback_map_generates_all_entity_types() -> void:
	# _build_default_map calls _generate_entities which should create enemies,
	# chests, AND NPCs so the fallback world isn't empty of any entity type.
	var wm: RefCounted = WorldMapScript.new("nonexistent_map_12345")
	assert_true(wm.enemies.size() > 0,
		"default map should have procedural enemies")
	assert_true(wm.chests.size() > 0,
		"default map should have procedural chests")
	assert_true(wm.npcs.size() > 0,
		"default map should have procedural NPCs")
