## Unit tests for RealmLayout — stitched story towns in the overworld (GID-138).
extends "res://tests/framework/test_case.gd"

const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")

func test_towns_do_not_overlap() -> void:
	var names: Array[String] = RealmLayout.town_names()
	for i: int in range(names.size()):
		for j: int in range(i + 1, names.size()):
			var a: Rect2i = RealmLayout.world_rect(names[i])
			var b: Rect2i = RealmLayout.world_rect(names[j])
			assert_false(a.grow(int(RealmLayout.BLEND_MARGIN)).intersects(b),
				"%s and %s must not overlap (incl. blend margin)" % [names[i], names[j]])

func test_round_trip_tiles() -> void:
	for town: String in RealmLayout.town_names():
		var local := Vector2i(50, 50)
		var w: Vector2i = RealmLayout.to_world_tile(town, local)
		assert_eq(RealmLayout.to_local_tile(town, w), local, "%s round trip" % town)

func test_madrian_spawn_near_origin() -> void:
	var p: Vector3 = RealmLayout.spawn_pos("madrian")
	assert_true(absf(p.x) < 20.0 and absf(p.z) < 20.0, "Madrian spawn sits by the overworld origin")

func test_town_at_tile_finds_each_town() -> void:
	for town: String in RealmLayout.town_names():
		var r: Rect2i = RealmLayout.world_rect(town)
		var c: Vector2i = r.get_center()
		assert_eq(RealmLayout.town_at_tile(c.x, c.y), town, "centre of %s" % town)
	assert_eq(RealmLayout.town_at_tile(5000, 5000), "", "far away is no town")

func test_roads_start_and_end_at_towns() -> void:
	for road: Array in RealmLayout.ROADS:
		for p: Vector2 in [road[0], road[road.size() - 1]]:
			var d: float = RealmLayout.reserved_distance(int(p.x), int(p.y))
			assert_eq(d, 0.0, "road end %s is paved or in a town" % str(p))
			var near_town: bool = false
			for town: String in RealmLayout.town_names():
				if RealmLayout.world_rect(town).grow(2).has_point(Vector2i(int(p.x), int(p.y))):
					near_town = true
			assert_true(near_town, "road end %s touches a town" % str(p))

func test_stamp_tile_inside_town_uses_town_tile() -> void:
	var wm = RealmLayout.town_map("madrian")
	var local := Vector2i(9, 9)  # Master's house wall corner in madrian
	var w: Vector2i = RealmLayout.to_world_tile("madrian", local)
	var st: Vector2i = RealmLayout.stamp_tile(w.x, w.y, IsoConst.TILE_HILL, 5)
	assert_eq(st.x, wm.get_tile(local.x, local.y), "town tile wins over noise")

func test_stamp_tile_road_is_path_and_far_is_noise() -> void:
	var st: Vector2i = RealmLayout.stamp_tile(13, 40, IsoConst.TILE_HILL, 4)
	assert_eq(st, Vector2i(IsoConst.TILE_PATH, 0), "road tile is flat path")
	var far: Vector2i = RealmLayout.stamp_tile(400, -400, IsoConst.TILE_HILL, 4)
	assert_eq(far, Vector2i(IsoConst.TILE_HILL, 4), "outside the realm the noise is kept")

## GID-162: the per-chunk stamp context only drops towns / roads / spots that
## cannot reach the chunk, so it must stamp every tile exactly like the full one,
## and the full one must agree with town_at_tile + reserved_distance.
func test_chunk_stamp_context_matches_full_stamp() -> void:
	var cs: int = IsoConst.CHUNK_SIZE
	var bounds := Rect2i()
	for town: String in RealmLayout.town_names():
		bounds = RealmLayout.world_rect(town) if bounds.size == Vector2i.ZERO \
				else bounds.merge(RealmLayout.world_rect(town))
	var mismatches: int = 0
	var checked: int = 0
	for cz: int in range(floori(bounds.position.y / float(cs)) - 2, ceili(bounds.end.y / float(cs)) + 2):
		for cx: int in range(floori(bounds.position.x / float(cs)) - 2, ceili(bounds.end.x / float(cs)) + 2):
			if not RealmLayout.chunk_touches_realm(cx, cz):
				continue
			var ctx: Dictionary = RealmLayout.stamp_context(cx, cz, true)
			for i: int in cs * cs:
				var wtx: int = cx * cs + i % cs
				var wtz: int = cz * cs + i / cs
				var fast: Vector2i = RealmLayout.stamp_tile_in(ctx, wtx, wtz, IsoConst.TILE_HILL, 7)
				var full: Vector2i = RealmLayout.stamp_tile(wtx, wtz, IsoConst.TILE_HILL, 7)
				checked += 1
				if fast != full:
					mismatches += 1
				elif RealmLayout.town_at_tile(wtx, wtz) == "":
					var d: float = RealmLayout.reserved_distance(wtx, wtz)
					var want: Vector2i = Vector2i(IsoConst.TILE_PATH, 0) if d <= 0.0 \
							else (Vector2i(IsoConst.TILE_HILL, 7) if d >= RealmLayout.BLEND_MARGIN else full)
					if full != want:
						mismatches += 1
	assert_gt(checked, 10000, "covered the realm")
	assert_eq(mismatches, 0, "chunk-filtered stamp == full stamp == reserved_distance rule")

func test_entities_keep_ids_and_drop_overworld_doors() -> void:
	var npcs: Array[Dictionary] = RealmLayout.entities("npcs")
	var ids: Array[String] = []
	for n: Dictionary in npcs:
		ids.append(str(n.get("id", "")))
	assert_true(ids.has("madrian:npc_1"), "madrian npc_1 (Maiteln) is stitched, town-prefixed")
	assert_true(ids.has("duelist_1"), "unique ids are kept as-is")
	var seen: Dictionary = {}
	for id: String in ids:
		assert_false(seen.has(id), "npc id %s is unique across towns" % id)
		seen[id] = true
	for d: Dictionary in RealmLayout.entities("doors"):
		assert_false(RealmLayout.OVERWORLD_TARGETS.has(str(d.get("target_map", ""))),
			"door %s to the overworld is dropped" % str(d.get("id", "")))
	var targets: Array[String] = []
	for d: Dictionary in RealmLayout.entities("doors"):
		targets.append(str(d.get("target_map", "")))
	assert_true(targets.has("blancogov_temple"), "temple door kept")
	assert_true(targets.has("player_home"), "home door kept")
	assert_eq(targets.count("blancogov_temple"), 1, "one way into the temple (Madrian shortcut dropped)")
	assert_eq(targets.count("farsyth_mansion"), 1, "one way into the mansion")

func test_maiteln_world_position() -> void:
	for n: Dictionary in RealmLayout.entities("npcs"):
		if str(n.get("id", "")) == "madrian:npc_1":
			var expect: Vector2i = RealmLayout.to_world_tile("madrian", Vector2i(32, 29))
			assert_eq(int(float(n["x"]) / IsoConst.TILE_SIZE), expect.x, "x shifted")
			assert_eq(int(float(n["z"]) / IsoConst.TILE_SIZE), expect.y, "z shifted")
			return
	assert_true(false, "Maiteln not found")

func test_story_sites_on_roads() -> void:
	for site: Variant in RealmLayout.STORY_SITES.keys():
		var t: Vector2i = RealmLayout.STORY_SITES[site]
		assert_true(RealmLayout.road_distance(float(t.x), float(t.y)) <= 6.0, "%s is by a road" % str(site))
		assert_eq(RealmLayout.town_at_tile(t.x, t.y), "", "%s is between towns" % str(site))

# ── Chunk generation (TID-568) ───────────────────────────────────────────────


func _chunk_of_tile(t: Vector2i) -> Vector2i:
	return Vector2i(int(floor(float(t.x) / IsoConst.CHUNK_SIZE)), int(floor(float(t.y) / IsoConst.CHUNK_SIZE)))

func test_generated_chunk_carries_town_tiles_and_maiteln() -> void:
	var wt: Vector2i = RealmLayout.to_world_tile("madrian", Vector2i(32, 29))
	var ck: Vector2i = _chunk_of_tile(wt)
	var chunk = InfiniteWorldGen.generate_chunk(ck.x, ck.y, 1234)
	var found: bool = false
	for n: Dictionary in chunk.npcs:
		if str(n.get("id", "")) == "madrian:npc_1":
			found = true
	assert_true(found, "Maiteln spawns in the overworld chunk over Madrian")
	var wm = RealmLayout.town_map("madrian")
	var wall := Vector2i(21, 9)  # madrian inn wall
	var ww: Vector2i = RealmLayout.to_world_tile("madrian", wall)
	var wk: Vector2i = _chunk_of_tile(ww)
	var c2 = InfiniteWorldGen.generate_chunk(wk.x, wk.y, 1234)
	assert_eq(c2.get_tile(ww.x - wk.x * IsoConst.CHUNK_SIZE, ww.y - wk.y * IsoConst.CHUNK_SIZE),
		wm.get_tile(wall.x, wall.y), "town wall stamped into chunk")

func test_road_chunk_has_path_and_no_random_enemy_on_road() -> void:
	var ck: Vector2i = _chunk_of_tile(Vector2i(13, 40))
	var chunk = InfiniteWorldGen.generate_chunk(ck.x, ck.y, 99)
	assert_eq(chunk.get_tile(13 - ck.x * IsoConst.CHUNK_SIZE, 40 - ck.y * IsoConst.CHUNK_SIZE),
		IsoConst.TILE_PATH, "road tile is path")
	for e: Dictionary in chunk.enemies:
		var tx: int = int(floor(float(e["x"]) / IsoConst.TILE_SIZE))
		var tz: int = int(floor(float(e["z"]) / IsoConst.TILE_SIZE))
		assert_true(RealmLayout.reserved_distance(tx, tz) > 0.0 or e.has("town"), "no random enemy on the road")
