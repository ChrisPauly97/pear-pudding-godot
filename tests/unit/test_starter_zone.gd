## GID-141 / TID-591: Madrian's outskirts starter zone — camps, graveyard, sealed crypt.
extends "res://tests/framework/test_case.gd"

const StarterZone = preload("res://game_logic/world/StarterZone.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const WorldMapScript = preload("res://game_logic/world/WorldMap.gd")
const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")


func _madrian_tile(world_tile: Vector2i) -> int:
	var wm := WorldMapScript.new("madrian")
	var off: Vector2i = RealmLayout.TOWNS["madrian"]["offset"]
	var local: Vector2i = world_tile - off
	return wm.get_tile(local.x, local.y)


func test_camps_ramp_one_level_at_a_time() -> void:
	var ids: Dictionary = {}
	var prev: int = 0
	for c: Dictionary in StarterZone.CAMPS:
		assert_false(ids.has(c["id"]), "camp id unique")
		ids[c["id"]] = true
		assert_eq(int(c["level"]), prev + 1, "%s is the next level" % str(c["id"]))
		prev = int(c["level"])
		assert_false(EnemyRegistry.get_deck(str(c["enemy_type"])).is_empty(), "%s enemy has a deck" % str(c["id"]))
		assert_gt(int(c["count"]), 2, "%s has enough members for a slay quest" % str(c["id"]))
	assert_eq(prev, 9, "the starter zone covers levels 1–9")


func test_camp_slots_inside_madrian_are_open_ground() -> void:
	var crop: Rect2i = RealmLayout.TOWNS["madrian"]["crop"]
	var off: Vector2i = RealmLayout.TOWNS["madrian"]["offset"]
	for c: Dictionary in StarterZone.CAMPS:
		for slot: int in range(int(c["count"])):
			var t: Vector2i = StarterZone.slot_tile(c, slot)
			if not crop.has_point(t - off):
				continue
			assert_ne(_madrian_tile(t), IsoConst.TILE_WALL, "%s slot %d not in a wall" % [str(c["id"]), slot])


func test_camp_members_are_never_saved_as_defeated() -> void:
	var sm: SaveManagerScript = SaveManagerScript.new()
	var id: String = StarterZone.member_id(StarterZone.CAMPS[0], 0)
	assert_true(StarterZone.is_camp_enemy(id))
	sm.mark_enemy_defeated(id)
	assert_false(sm.is_enemy_defeated(id))


func test_graveyard_mounds_and_gravedigger() -> void:
	for t: Vector2i in StarterZone.GRAVEYARD_MOUNDS:
		assert_ne(_madrian_tile(t), IsoConst.TILE_WALL, "mound %s on open ground" % str(t))
	var found: int = 0
	for cx: int in range(-3, 1):
		for cz: int in range(0, 3):
			found += StarterZone.mounds_in_chunk(cx, cz, IsoConst.CHUNK_SIZE, IsoConst.TILE_SIZE).size()
	assert_eq(found, StarterZone.GRAVEYARD_MOUNDS.size(), "every mound lands in exactly one chunk")
	var digger: Dictionary = {}
	for npc: Dictionary in RealmLayout.entities("npcs"):
		if str(npc["id"]) == "gravedigger_madrian":
			digger = npc
	assert_false(digger.is_empty(), "the Gravedigger stands in the realm")
	var tile := Vector2i(int(floor(float(digger["x"]) / IsoConst.TILE_SIZE)),
			int(floor(float(digger["z"]) / IsoConst.TILE_SIZE)))
	assert_lt((tile - StarterZone.GRAVEYARD_TILE).length(), 6.0, "…in the graveyard")


func test_sealed_crypt_needs_ghost_phase() -> void:
	var wm := WorldMapScript.new("madrian")
	var chest: Dictionary = {}
	for c: Dictionary in wm.chests:
		if str(c["id"]) == "sealed_crypt_chest":
			chest = c
	assert_false(chest.is_empty(), "crypt chest authored")
	assert_eq((chest["card_ids"] as Array).size(), 2, "PackedStringArray card ids load")
	# Fully walled: every tile on the ring around the 3×3 interior is a wall.
	for x: int in range(22, 27):
		assert_eq(wm.get_tile(x, 48), IsoConst.TILE_WALL)
		assert_eq(wm.get_tile(x, 52), IsoConst.TILE_WALL)
	for z: int in range(48, 53):
		assert_eq(wm.get_tile(22, z), IsoConst.TILE_WALL)
		assert_eq(wm.get_tile(26, z), IsoConst.TILE_WALL)


func test_named_npcs_stand_on_open_ground() -> void:
	# TID-594: the Combat Trainer and dummy used to stand on the south fence wall.
	var wm := WorldMapScript.new("madrian")
	for npc: Dictionary in wm.npcs:
		var tx: int = int(floor(float(npc["x"]) / IsoConst.TILE_SIZE))
		var tz: int = int(floor(float(npc["z"]) / IsoConst.TILE_SIZE))
		assert_ne(wm.get_tile(tx, tz), IsoConst.TILE_WALL, "%s is not standing in a wall" % str(npc["id"]))


func test_every_trainer_and_quest_giver_has_its_own_sprite() -> void:
	# GID-143 / TID-604.
	const SideQuests = preload("res://game_logic/quests/SideQuests.gd")
	const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
	var ids: Array[String] = []
	for q: Dictionary in SideQuests.all():
		if not ids.has(str(q["giver"])):
			ids.append(str(q["giver"]))
	for t: Variant in UnlockLadder.TRAINER_NPCS:
		var nid: String = str(UnlockLadder.TRAINER_NPCS[t])
		if t in ["merchant", "stable"]:
			continue  # service NPCs keep their own scenes / looks
		if not ids.has(nid):
			ids.append(nid)
	for nid: String in ids:
		assert_not_null(SpriteRegistry.named_npc_texture(nid), "%s has a generated sprite" % nid)


func test_graveyard_dressing() -> void:
	# GID-143 / TID-605: fence is decor now (no wall tiles), crypt keeps its walls.
	var wm := WorldMapScript.new("madrian")
	var r: Rect2i = StarterZone.GRAVEYARD_LOCAL_RECT
	for x: int in range(r.position.x, r.end.x):
		assert_ne(wm.get_tile(x, r.position.y), IsoConst.TILE_WALL, "graveyard edge is open at %d" % x)
	var keys: Dictionary = {}
	for e: Array in StarterZone.graveyard_props():
		keys[str(e[0])] = true
		if str(e[0]) == "iron_fence":
			assert_true(str(e[2]) in ["x", "z"], "fence segments run along the tile edges, not camera-facing")
		assert_not_null(SpriteRegistry.graveyard_prop(str(e[0])), str(e[0]))
	for k: String in ["iron_fence", "crypt_door", "headstone_0", "headstone_1", "headstone_2"]:
		assert_true(keys.has(k), "%s placed" % k)
