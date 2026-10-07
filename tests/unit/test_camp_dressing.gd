## GID-166 / TID-687: each starter camp is dressed to match its name, in a clearing.
extends "res://tests/framework/test_case.gd"

const CampDressing = preload("res://game_logic/world/CampDressing.gd")
const StarterZone = preload("res://game_logic/world/StarterZone.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")


func test_every_camp_is_dressed_with_known_sprites() -> void:
	for camp: Dictionary in StarterZone.CAMPS:
		var props: Array = CampDressing.props_for(str(camp["id"]))
		assert_gt(props.size(), 5, "%s has set dressing" % str(camp["id"]))
		for e: Array in props:
			assert_true(CampDressing.texture(str(e[0])) != null, "sprite for %s" % str(e[0]))
			assert_gt(float(e[2]), 0.0, "%s has a height" % str(e[0]))


func test_orchard_has_apple_trees() -> void:
	var trees: int = 0
	for e: Array in CampDressing.props_for("old_orchard"):
		if str(e[0]).begins_with("apple_tree"):
			trees += 1
	assert_gt(trees, 9, "the Old Orchard is rows of apple trees")


func test_props_stay_off_member_slots_and_inside_the_clearing() -> void:
	for camp: Dictionary in StarterZone.CAMPS:
		var slots: Dictionary = {}
		for i: int in range(int(camp["count"])):
			slots[StarterZone.slot_tile(camp, i)] = true
		var c: Vector2i = camp["tile"]
		for e: Array in CampDressing.props_for(str(camp["id"])):
			var p: Vector2 = e[1]
			var t := Vector2i(floori(p.x), floori(p.y))
			assert_false(slots.has(t), "%s %s not on a member slot" % [str(camp["id"]), str(e[0])])
			assert_true(Vector2(t - c).length() <= StarterZone.CAMP_CLEAR_RADIUS + 3.0,
				"%s %s within the clearing" % [str(camp["id"]), str(e[0])])
			if RealmLayout.town_at_tile(t.x, t.y) != "":
				var st: Vector2i = RealmLayout.stamp_tile(t.x, t.y, IsoConst.TILE_GRASS, 0)
				assert_ne(st.x, IsoConst.TILE_WALL, "%s %s not in a town wall" % [str(camp["id"]), str(e[0])])


func test_camp_ground_is_a_flat_unpaved_clearing() -> void:
	for camp: Dictionary in StarterZone.CAMPS:
		var c: Vector2i = camp["tile"]
		if RealmLayout.town_at_tile(c.x, c.y) != "":
			continue
		var d: float = RealmLayout.reserved_distance(c.x + 2, c.y + 2)
		assert_almost_eq(d, StarterZone.CAMP_SITE_PAD, 0.001, "%s is reserved ground" % str(camp["id"]))
		var st: Vector2i = RealmLayout.stamp_tile(c.x + 2, c.y + 2, IsoConst.TILE_HILL, 6)
		assert_eq(st, Vector2i(IsoConst.TILE_GRASS, 0), "%s clearing is flat grass, not a path" % str(camp["id"]))
		assert_true(RealmLayout.chunk_touches_realm(floori(float(c.x) / IsoConst.CHUNK_SIZE),
			floori(float(c.y) / IsoConst.CHUNK_SIZE)), "%s chunk is realm-aware" % str(camp["id"]))
