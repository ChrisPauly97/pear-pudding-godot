## RealmMapOverlay framing (GID-139).
extends "res://tests/framework/test_case.gd"

const RealmMapOverlay = preload("res://scenes/ui/RealmMapOverlay.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")


func test_bounds_cover_every_town_and_are_square() -> void:
	var b: Rect2 = RealmMapOverlay.realm_bounds()
	assert_almost_eq(b.size.x, b.size.y, 0.001, "square so tiles stay square")
	for town: String in RealmLayout.town_names():
		var wr: Rect2i = RealmLayout.world_rect(town)
		assert_true(b.encloses(Rect2(Vector2(wr.position), Vector2(wr.size))), "%s on the map" % town)


func test_bounds_grow_to_include_far_points() -> void:
	var far := Vector2(900.0, -700.0)
	assert_true(RealmMapOverlay.realm_bounds([far]).has_point(far), "a far-off player stays on the map")
