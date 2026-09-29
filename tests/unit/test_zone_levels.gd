## Zone level ranges, con colours and level scaling (GID-136 / TID-536).
extends "res://tests/framework/test_case.gd"

const ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")


func _town_level(town: String) -> int:
	var t: Dictionary = RealmLayout.TOWNS[town]
	var crop: Rect2i = t["crop"]
	var off: Vector2i = t["offset"]
	var c: Vector2i = crop.position + crop.size / 2 + off
	return ZoneLevels.level_at_tile(c.x, c.y)


func test_madrian_is_level_one() -> void:
	assert_eq(ZoneLevels.level_at_tile(ZoneLevels.ORIGIN_TILE.x, ZoneLevels.ORIGIN_TILE.y), 1)
	assert_eq(_town_level("madrian"), 1)


func test_levels_rise_with_distance() -> void:
	var prev: int = 1
	for d: int in range(0, 600, 20):
		var lvl: int = ZoneLevels.level_at_tile(ZoneLevels.ORIGIN_TILE.x + d, ZoneLevels.ORIGIN_TILE.y)
		assert_gte(lvl, prev, "monotonic at %d tiles" % d)
		assert_lte(lvl, ZoneLevels.MAX_LEVEL)
		prev = lvl


func test_story_towns_follow_story_order() -> void:
	assert_lt(_town_level("madrian"), _town_level("maykalene"))
	assert_lt(_town_level("maykalene"), _town_level("marsax_hold"))
	assert_lte(_town_level("maykalene"), 12, "Maykalene stays early-game")


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
