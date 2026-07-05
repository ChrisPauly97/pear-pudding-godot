## Unit tests for NPC spawning in named maps.
##
## Validates that NPCs defined in map files (.txt) survive the full
## data chain: file parsing → WorldMap → ChunkData distribution → iteration.
extends "res://tests/framework/test_case.gd"

const WorldMapScript = preload("res://game_logic/world/WorldMap.gd")
const ChunkDataScript = preload("res://game_logic/world/ChunkData.gd")

# ---------------------------------------------------------------------------
# madrian map — 2 NPCs defined in file
# ---------------------------------------------------------------------------

func test_madrian_loads_twelve_npcs() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	assert_eq(wm.npcs.size(), 12, "madrian should define 12 NPCs (inc. bounty board + blacksmith)")


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
	var max_cx: int = (WorldMapScript.MAP_WIDTH + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
	var max_cz: int = (WorldMapScript.MAP_HEIGHT + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
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
			var max_cx: int = (WorldMapScript.MAP_WIDTH + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
			var max_cz: int = (WorldMapScript.MAP_HEIGHT + IsoConst.CHUNK_SIZE - 1) / IsoConst.CHUNK_SIZE
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


# ---------------------------------------------------------------------------
# Flag-gated dialogue content pass (GID-108 / TID-404)
# ---------------------------------------------------------------------------

func _npc_by_id(wm: RefCounted, id: String) -> Dictionary:
	for n in wm.npcs:
		if str(n.get("id", "")) == id:
			return n
	return {}


func test_madrian_maiteln_flag_gated_after_recruitment() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	var n: Dictionary = _npc_by_id(wm, "npc_1")
	assert_eq(str(n.get("flag_key", "")), "story_intro_complete")
	assert_eq(str(n.get("after_dialogue", "")),
		"The road waits, wee Saimtar. South, past the wilds — Maykalene first.")


func test_madrian_master_flag_gated_after_recruitment() -> void:
	var wm: RefCounted = WorldMapScript.new("madrian")
	var n: Dictionary = _npc_by_id(wm, "npc_2")
	assert_eq(str(n.get("flag_key", "")), "story_intro_complete")
	assert_eq(str(n.get("after_dialogue", "")),
		"Running off with that old trickster? Good riddance — but your bed will be gone when you crawl back.")


func test_maykalene_townsperson_innkeeper_guard_flag_gated_on_warned_farsyth() -> void:
	var wm: RefCounted = WorldMapScript.new("maykalene")
	for id in ["npc_1", "npc_2", "npc_3"]:
		var n: Dictionary = _npc_by_id(wm, id)
		assert_eq(str(n.get("flag_key", "")), "chapter1_warned_farsyth",
			"maykalene %s should gate on chapter1_warned_farsyth" % id)
		assert_true(str(n.get("after_dialogue", "")).length() > 0,
			"maykalene %s should have an after_dialogue line" % id)


func test_farsyth_mansion_lord_farsyth_after_dialogue_matches_story() -> void:
	var wm: RefCounted = WorldMapScript.new("farsyth_mansion")
	var n: Dictionary = _npc_by_id(wm, "npc_2")
	assert_eq(str(n.get("flag_key", "")), "chapter1_warned_farsyth")
	assert_eq(str(n.get("after_dialogue", "")),
		"Ride hard for Blancogov. Every hour you save may save a village.")


func test_blancogov_gate_guard_flag_gated_on_received_letter() -> void:
	var wm: RefCounted = WorldMapScript.new("blancogov")
	var n: Dictionary = _npc_by_id(wm, "npc_1")
	assert_eq(str(n.get("flag_key", "")), "chapter1_received_letter")
	assert_eq(str(n.get("dialogue", "")),
		"Halt! State your business. No entry without authorisation!")


func test_blancogov_city_dweller_flag_gated_on_temple_council() -> void:
	var wm: RefCounted = WorldMapScript.new("blancogov")
	var n: Dictionary = _npc_by_id(wm, "npc_2")
	assert_eq(str(n.get("flag_key", "")), "chapter1_temple_council")
	assert_eq(str(n.get("after_dialogue", "")),
		"The bells rang thrice — the alliance is called. First time in my lifetime.")


# ---------------------------------------------------------------------------
# Chapter 1 ending (GID-108 / TID-405)
# ---------------------------------------------------------------------------

func test_blancogov_temple_king_eldar_uses_custom_npc_type() -> void:
	# King Eldar's dialogue is entirely custom-driven (WorldScene
	# _handle_king_eldar_interaction) since his 4 narrative states don't fit
	# the 2-state MapNpc flag_key/after_dialogue schema — flag_key must be
	# empty so the generic auto-set-on-interact path never fires for him.
	var wm: RefCounted = WorldMapScript.new("blancogov_temple")
	var n: Dictionary = _npc_by_id(wm, "npc_1")
	assert_eq(str(n.get("npc_type", "")), "chapter1_king_eldar")
	assert_eq(str(n.get("flag_key", "")), "")


func test_blancogov_temple_queen_flag_gated_on_spoke_queen() -> void:
	var wm: RefCounted = WorldMapScript.new("blancogov_temple")
	var n: Dictionary = _npc_by_id(wm, "npc_2")
	assert_eq(str(n.get("flag_key", "")), "chapter1_spoke_queen")
	assert_eq(str(n.get("after_dialogue", "")),
		"Rest here whenever the road wears you thin, young Saimtar.")


func test_blancogov_temple_scargroth_flag_gated_on_spoke_scargroth() -> void:
	var wm: RefCounted = WorldMapScript.new("blancogov_temple")
	var n: Dictionary = _npc_by_id(wm, "npc_3")
	assert_eq(str(n.get("flag_key", "")), "chapter1_spoke_scargroth")
	assert_eq(str(n.get("after_dialogue", "")),
		"I've been reading the old registers. There is a name from Larik you should see.")
