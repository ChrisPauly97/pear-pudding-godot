## RealmMapArt: painted realm-map terrain and town plans.
extends "res://tests/framework/test_case.gd"

const RealmMapArt = preload("res://game_logic/world/RealmMapArt.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const RealmMapBaked = preload("res://game_logic/world/RealmMapBaked.gd")
const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")


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



static func _rgba(img: Image) -> Image:
	var out: Image = img.duplicate()
	out.clear_mipmaps()
	out.convert(Image.FORMAT_RGBA8)
	return out


## Stale bake guard: re-run tools/bake_realm_map.gd when any of these fail.
func test_baked_art_matches_painter() -> void:
	assert_eq(RealmMapBaked.RECT, RealmMapArt.terrain_rect(), "realm bounds moved: re-bake")
	for s: int in BiomeDef.START_SEEDS:
		assert_true(RealmMapBaked.terrain(s) != null, "seed %d baked" % s)
	var towns: Dictionary = RealmMapBaked.towns()
	for town: String in RealmLayout.town_names():
		var tex: Texture2D = towns.get(town) as Texture2D
		assert_true(tex != null, town)
		if tex != null:
			assert_eq(_rgba(tex.get_image()).get_data(), _rgba(RealmMapArt.town_image(town)).get_data(),
				"%s plan changed: re-bake" % town)
	# Terrain: repaint a patch around Madrian and compare (skip the first tile row /
	# column, whose hill shading reads outside the patch).
	InfiniteWorldGen.warm(42)
	var patch := Rect2i(RealmLayout.world_rect("madrian").position - Vector2i(8, 8), Vector2i(32, 32))
	var px: int = RealmMapArt.TERRAIN_PX
	var fresh: Image = _rgba(RealmMapArt.terrain_image(patch, 42))
	var baked: Image = _rgba(RealmMapBaked.terrain(42).get_image())
	var at: Vector2i = (patch.position - RealmMapBaked.RECT.position) * px
	var inner := Rect2i(Vector2i(px, px), patch.size * px - Vector2i(px, px))
	assert_eq(baked.get_region(Rect2i(at + inner.position, inner.size)).get_data(),
		fresh.get_region(inner).get_data(), "terrain changed: re-bake")
