## RealmMapArt: painted realm-map terrain and town plans.
extends "res://tests/framework/test_case.gd"

const RealmMapArt = preload("res://game_logic/world/RealmMapArt.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")


func test_terrain_paints_roads_and_sea() -> void:
	InfiniteWorldGen.warm(42)
	var rect := Rect2i(-20, -20, 40, 40)
	var img: Image = RealmMapArt.terrain_image(rect, 42)
	assert_eq(img.get_size(), rect.size * RealmMapArt.TERRAIN_PX)
	# Every town's plan is drawn at its crop, TOWN_PX per tile.
	for town: String in RealmLayout.town_names():
		var ti: Image = RealmMapArt.town_image(town)
		assert_eq(ti.get_size(), RealmLayout.crop_of(town).size * RealmMapArt.TOWN_PX, town)


func test_town_plan_has_roofs() -> void:
	var town: String = RealmLayout.town_names()[0]
	var plan: Array = RealmLayout.building_plan(town)["buildings"]
	assert_true(plan.size() > 0)
	var b: Dictionary = plan[0]
	var r: Rect2i = b["rect"]
	var crop: Rect2i = RealmLayout.crop_of(town)
	var c: Vector2i = (r.get_center() - crop.position) * RealmMapArt.TOWN_PX
	var px: Color = RealmMapArt.town_image(town).get_pixelv(c)
	assert_false(px.is_equal_approx(RealmMapArt.COL_TOWN_GROUND), "building centre is roofed")
