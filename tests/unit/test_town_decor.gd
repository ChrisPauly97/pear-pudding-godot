## GID-167 / TID-688: town set pieces (Madrian's fountain) are kept clear by streets and entities.
extends "res://tests/framework/test_case.gd"

const TownDecor = preload("res://game_logic/world/TownDecor.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _WorldMap = preload("res://game_logic/world/WorldMap.gd")


func test_madrian_fountain_sits_in_the_square() -> void:
	var list: Array = TownDecor.pieces("madrian")
	assert_eq(list.size(), 1, "one fountain")
	var p: Dictionary = list[0]
	assert_eq(str(p["key"]), "fountain")


## GID-170: every stitched town has a centrepiece on its paved square, near the hub.
func test_every_town_square_has_a_set_piece() -> void:
	for town: String in RealmLayout.town_names():
		var list: Array = TownDecor.pieces(town)
		assert_eq(list.size(), 1, "%s has one square centrepiece" % town)
		var wm: _WorldMap = RealmLayout.town_map(town)
		for t: Variant in TownDecor.blocked_local(town):
			var lt: Vector2i = t
			assert_eq(wm.get_tile(lt.x, lt.y), IsoConst.TILE_PATH, "%s piece tile %s is paved square" % [town, str(lt)])
		var hub: Vector2i = RealmLayout.hub_of(town)
		var c: Vector2i = (list[0] as Dictionary)["tile"]
		assert_true(absi(hub.x - c.x) + absi(hub.y - c.y) <= 5, "%s piece sits by the hub" % town)


func test_streets_and_entities_avoid_set_pieces() -> void:
	for town: String in RealmLayout.town_names():
		var blocked: Dictionary = TownDecor.blocked_local(town)
		if blocked.is_empty():
			continue
		var tiles: Dictionary = RealmLayout.street_plan(town)["tiles"]
		for t: Variant in blocked:
			assert_false(tiles.has(t), "%s street avoids set piece tile %s" % [town, str(t)])
		var wm: _WorldMap = RealmLayout.town_map(town)
		assert_false(blocked.has(Vector2i(wm.player_spawn_x, wm.player_spawn_z)), "%s spawn not under a set piece" % town)
		for kind: String in ["npcs", "doors", "shrines", "chests", "scrolls"]:
			for e: Dictionary in RealmLayout.entities(kind):
				if not str(e.get("id", "")).begins_with(town + ":"):
					continue
				var local: Vector2i = IsoConst.entity_tile(e) - RealmLayout.offset_of(town)
				assert_false(blocked.has(local), "%s %s not under a set piece" % [kind, str(e.get("id", ""))])
