## Zone level ranges, con colours and level scaling (GID-136 / TID-536).
extends "res://tests/framework/test_case.gd"

const ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")


func _town_level(town: String) -> int:
	var t: Dictionary = RealmLayout.TOWNS[town]
	var r: Rect2i = RealmLayout.world_rect(town)
	var c: Vector2i = r.position + r.size / 2
	return ZoneLevels.level_at_tile(c.x, c.y)


func test_madrian_is_level_one() -> void:
	assert_eq(ZoneLevels.level_at_tile(ZoneLevels.ORIGIN_TILE.x, ZoneLevels.ORIGIN_TILE.y), 1)
	assert_eq(_town_level("madrian"), 1)


## GID-176 / TID-719: town anchors in ROUTE sit at the town centres.
func test_route_anchors_match_towns() -> void:
	var towns: Dictionary = {0: "madrian", 3: "maykalene", 5: "blancogov", 6: "larik", 8: "marsax_hold"}
	for i: int in towns:
		var r: Rect2i = RealmLayout.world_rect(str(towns[i]))
		var c: Vector2i = r.position + r.size / 2
		assert_eq(ZoneLevels.ROUTE[i][0], c, "%s anchor" % str(towns[i]))
	for site: String in ["madrian_south_road", "wilderness_camp", "isfig_road", "scout_ambush"]:
		var found: bool = false
		for r: Array in ZoneLevels.ROUTE:
			found = found or r[0] == RealmLayout.STORY_SITES[site]
		assert_true(found, "%s on the route" % site)


## Chapter 1 (Madrian → Blancogov) spans levels 1–10; Chapter 2 is higher.
func test_story_route_levels() -> void:
	var prev: int = 0
	for r: Array in ZoneLevels.ROUTE:
		var t: Vector2i = r[0]
		var lvl: int = ZoneLevels.level_at_tile(t.x, t.y)
		assert_gte(lvl, prev, "route levels never drop in story order (%s)" % str(t))
		prev = lvl
	for town: String in ["madrian", "maykalene", "blancogov"]:
		assert_lte(_town_level(town), 10, "%s is Chapter 1 (≤ 10)" % town)
	assert_eq(_town_level("blancogov"), 10, "Chapter 1 ends at level 10")
	assert_gt(_town_level("marsax_hold"), 10, "Chapter 2 is past 10")


func test_zone_ranges_hold_route_levels() -> void:
	for r: Array in ZoneLevels.ROUTE:
		var t: Vector2i = r[0]
		var zr: Vector2i = ZoneLevels.range_at_tile(t.x, t.y)
		var lvl: int = ZoneLevels.level_at_tile(t.x, t.y)
		assert_true(lvl >= zr.x and lvl <= zr.y, "%s level %d in %s" % [str(t), lvl, str(zr)])


func test_wild_land_rises_off_the_route() -> void:
	var prev: int = 1
	for d: int in range(0, 600, 20):
		var lvl: int = ZoneLevels.level_at_tile(ZoneLevels.ORIGIN_TILE.x + d, ZoneLevels.ORIGIN_TILE.y - d)
		assert_gte(lvl, prev, "monotonic going north-east, away from the route (%d)" % d)
		assert_lte(lvl, ZoneLevels.MAX_LEVEL)
		prev = lvl
	assert_gt(prev, 20, "far wild land is high level")


func test_no_cliffs_between_neighbours() -> void:
	for x: int in range(-200, 200, 7):
		for z: int in range(-100, 300, 7):
			var a: int = ZoneLevels.level_at_tile(x, z)
			var b: int = ZoneLevels.level_at_tile(x + 1, z)
			var c: int = ZoneLevels.level_at_tile(x, z + 1)
			assert_lte(absi(a - b) + absi(a - c), 2, "smooth at (%d, %d)" % [x, z])


func test_enemy_level_clamps_to_zone_and_type() -> void:
	# Madrian (zone 1–5): a level 1–2 type stays 1; a tier-4 type is pulled into the zone.
	var o: Vector2i = ZoneLevels.ORIGIN_TILE
	assert_eq(ZoneLevels.enemy_level_at(o.x, o.y, Vector2i(1, 2)), 1)
	assert_eq(ZoneLevels.enemy_level_at(o.x, o.y, Vector2i(20, 60)), 1, "no overlap: the zone wins")
	assert_eq(ZoneLevels.enemy_level_at(o.x, o.y, Vector2i(3, 5)), 3, "raised to the type floor")


func test_con_bands() -> void:
	assert_eq(ZoneLevels.con(1, 10), "grey")
	assert_eq(ZoneLevels.con(7, 10), "green")
	assert_eq(ZoneLevels.con(10, 10), "yellow")
	assert_eq(ZoneLevels.con(13, 10), "orange")
	assert_eq(ZoneLevels.con(16, 10), "red")


func test_grey_gives_no_xp_and_higher_gives_more() -> void:
	assert_eq(ZoneLevels.scaled_xp(20, 1, 10), 0)
	assert_eq(ZoneLevels.scaled_xp(20, 1, 1), 20, "level 1 even fight = base XP")
	assert_gt(ZoneLevels.scaled_xp(20, 5, 5), 20)
	assert_gt(ZoneLevels.scaled_xp(20, 7, 5), ZoneLevels.scaled_xp(20, 5, 5), "orange pays more")


func test_hp_and_tier_scaling() -> void:
	assert_eq(ZoneLevels.scaled_hero_hp(30, 1), 30)
	assert_gt(ZoneLevels.scaled_hero_hp(30, 10), 30)
	assert_eq(ZoneLevels.scaled_tier(1, 1), 1)
	assert_eq(ZoneLevels.scaled_tier(1, 11), 2)
	assert_eq(ZoneLevels.scaled_tier(3, 60), 4, "capped at 4")
