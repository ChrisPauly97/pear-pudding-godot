## GID-168 / TID-689: a named sign beside every building door in the stitched towns.
extends "res://tests/framework/test_case.gd"

const TownSigns = preload("res://game_logic/world/TownSigns.gd")
const TownDecor = preload("res://game_logic/world/TownDecor.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _WorldMap = preload("res://game_logic/world/WorldMap.gd")


func test_every_town_building_with_a_door_is_signed_by_name() -> void:
	for town: String in RealmLayout.town_names():
		var names: Array[String] = []
		for s: Dictionary in TownSigns.signs(town):
			names.append(str(s["name"]))
		var authored: Dictionary = TownSigns.NAMES.get(town, {})
		assert_false(authored.is_empty(), "%s has authored building names (GID-170)" % town)
		for door: Variant in authored:
			assert_true(names.has(str(authored[door])), "%s sign for %s" % [town, str(authored[door])])
		assert_false(names.has(TownSigns.DEFAULT_NAME), "no %s building falls back to the default name" % town)


func test_every_door_building_in_every_town_has_a_sign() -> void:
	for town: String in RealmLayout.town_names():
		var with_doors: int = 0
		for b: Dictionary in RealmLayout.building_plan(town)["buildings"]:
			if not (b["doors"] as Array).is_empty():
				with_doors += 1
		assert_eq(TownSigns.signs(town).size(), with_doors, "%s: one sign per building with a door" % town)


func test_signs_stand_on_clear_open_ground() -> void:
	for town: String in RealmLayout.town_names():
		var wm: _WorldMap = RealmLayout.town_map(town)
		var streets: Dictionary = RealmLayout.street_plan(town)["tiles"]
		var blocked: Dictionary = TownDecor.blocked_local(town)
		var seen: Dictionary = {}
		for s: Dictionary in TownSigns.signs(town):
			var t: Vector2i = s["tile"]
			assert_false(seen.has(t), "%s sign tiles unique" % town)
			seen[t] = true
			assert_false(streets.has(t), "%s sign %s off the street" % [town, str(s["name"])])
			assert_false(blocked.has(t), "%s sign not on a set piece" % town)
			assert_ne(wm.get_tile(t.x, t.y), IsoConst.TILE_WALL, "%s sign not in a wall" % town)
			for npc: Dictionary in wm.npcs:
				assert_ne(IsoConst.entity_tile(npc), t, "%s sign not on %s" % [town, str(npc.get("id", ""))])


func test_outward_points_away_from_the_building() -> void:
	var r := Rect2i(10, 10, 5, 4)
	assert_eq(TownSigns.outward(r, Vector2i(12, 10)), Vector2i(0, -1))
	assert_eq(TownSigns.outward(r, Vector2i(12, 13)), Vector2i(0, 1))
	assert_eq(TownSigns.outward(r, Vector2i(10, 11)), Vector2i(-1, 0))
	assert_eq(TownSigns.outward(r, Vector2i(14, 11)), Vector2i(1, 0))
