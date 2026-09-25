## PlaceNames (GID-134 / TID-517): players never see raw map ids.
extends "res://tests/framework/test_case.gd"

const PN = preload("res://game_logic/PlaceNames.gd")


func test_known_maps_have_titles() -> void:
	assert_eq(PN.title("marsax_hold"), "Marsax Hold")
	assert_eq(PN.title("spire"), "The Endless Spire")
	assert_eq(PN.title(""), "")


func test_dungeons_get_a_stable_readable_name() -> void:
	var t: String = PN.title("dungeon_48213")
	assert_true(t.begins_with("The "), "dungeon name reads as a place: %s" % t)
	assert_false(t.contains("_") or t.contains("48213"), "no raw id in %s" % t)
	assert_eq(PN.title("dungeon_48213"), t, "same dungeon, same name")


func test_unknown_ids_are_humanised() -> void:
	assert_eq(PN.title("old_watch_tower"), "Old Watch Tower")
	assert_eq(PN.title("spire_floor_3"), "Spire — Floor 3")


func test_biome_titles() -> void:
	assert_eq(PN.biome_title(0), "Grasslands")
	assert_eq(PN.biome_title(-1), "The Wilds")
