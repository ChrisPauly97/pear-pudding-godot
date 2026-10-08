## GID-172 / TID-696: swimming in deep water (Swimming, HeroAnim, PaperDoll swim frames, Player, Pathfinder cost).
extends "res://tests/framework/test_case.gd"

const Swimming = preload("res://game_logic/world/Swimming.gd")
const HeroAnim = preload("res://game_logic/character/HeroAnim.gd")
const PaperDoll = preload("res://game_logic/character/PaperDoll.gd")
const Pathfinder = preload("res://game_logic/Pathfinder.gd")
const Player = preload("res://scenes/world/entities/Player.gd")
const Rivers = preload("res://game_logic/world/Rivers.gd")


func test_swimmers_swim_or_tread_water() -> void:
	assert_eq(HeroAnim.pick(false, true, 0.0, 0.0, true, &"walk", true, true), &"swim")
	assert_eq(HeroAnim.pick(false, true, 0.0, 0.0, false, &"idle", true, true), &"tread")
	assert_eq(HeroAnim.pick(true, true, 0.0, 0.0, true, &"idle", true, true), &"swim", "swimming wins over the saddle")
	assert_eq(HeroAnim.pick(false, true, 0.0, 0.0, true, &"walk", true), &"walk", "on land: walk as before")
	assert_eq(HeroAnim.facing(&"swim", true), &"swim_back")
	assert_eq(HeroAnim.facing(&"tread", true), &"tread_back")
	assert_true(HeroAnim.is_swim(&"swim_back"))
	assert_false(HeroAnim.is_swim(&"walk"))


func test_paper_doll_draws_the_strokes() -> void:
	var sf: SpriteFrames = PaperDoll.build_frames({}, {})
	for anim: String in ["swim", "swim_back", "tread", "tread_back"]:
		assert_true(sf.has_animation(anim), "has %s" % anim)
	assert_eq(sf.get_frame_count("swim"), 4)
	assert_eq(sf.get_frame_count("tread"), 2)
	assert_true(sf.get_animation_loop("swim"))
	var a: Image = PaperDoll.render_frame({}, {}, "swim", 0)
	var b: Image = PaperDoll.render_frame({}, {}, "swim", 2)
	assert_ne(a.get_data(), b.get_data(), "the arms move between strokes")
	for f: int in Swimming.STROKE_FRAMES:
		assert_lt(f, sf.get_frame_count("swim"), "stroke frame %d exists" % f)


func test_player_swims_slowly_and_sinks() -> void:
	var p: Player = Player.new()
	var walk: float = p._get_move_speed()
	p.set_swimming(true)
	assert_true(p.swimming)
	assert_almost_eq(p._get_move_speed(), Player.SPEED * Swimming.SPEED_MULT, 0.0001, "swims at a fraction of walking")
	assert_lt(p._get_move_speed(), walk)
	p._sprite = AnimatedSprite3D.new()
	p._sprite_base_pos = Vector3(0.0, 0.7, 0.0)
	p._update_mount_visuals(false)
	assert_almost_eq(p._sprite.position.y, 0.7 - Swimming.SINK, 0.0001, "the sprite sinks to the chest")
	p.set_swimming(false)
	assert_almost_eq(p._sprite.position.y, 0.7, 0.0001, "back on its feet ashore")
	p._sprite.free()
	p.free()


func test_paths_swim_only_when_it_saves_a_long_walk() -> void:
	# A 9-wide strip of deep water (x 3..5, z −20..20); land everywhere else.
	var tiles := func(_x: int, _z: int) -> int: return IsoConst.TILE_GRASS
	var cost := func(x: int, z: int) -> float: return Swimming.PATH_COST if x >= 3 and x <= 5 and absi(z) <= 20 else 1.0
	var swim: Array[Vector2i] = Pathfinder.find_path(tiles, Vector2i(0, 0), Vector2i(8, 0), 64, cost)
	assert_false(swim.is_empty(), "deep water is no wall")
	for t: Vector2i in swim:
		assert_lt(absi(t.y), 3, "swims straight across rather than walking 40 tiles round (%s)" % str(t))
	var near: Array[Vector2i] = Pathfinder.find_path(tiles, Vector2i(0, 18), Vector2i(8, 18), 64, cost)
	var rounded: bool = false
	for t: Vector2i in near:
		rounded = rounded or t.y > 20
	assert_true(rounded, "walks round the end of the water: %s" % str(near))
	for k: int in range(near.size() - 1):
		for s: int in 11:
			var q: Vector2 = Vector2(near[k]).lerp(Vector2(near[k + 1]), float(s) / 10.0)
			var qt := Vector2i(roundi(q.x), roundi(q.y))
			assert_eq(cost.call(qt.x, qt.y), 1.0, "the smoothed walk never cuts across the water (%s)" % str(qt))
	var plain: Array[Vector2i] = Pathfinder.find_path(tiles, Vector2i(0, 0), Vector2i(8, 0), 64)
	assert_eq(plain, [Vector2i(0, 0), Vector2i(8, 0)] as Array[Vector2i], "no cost lookup: the old straight path")


func test_stamina_drains_in_water_and_refills_on_land() -> void:
	var s: float = Swimming.step(1.0, 1.0, true, 1.0, true, 0.0)
	assert_lt(s, 1.0, "swimming tires")
	assert_gt(Swimming.step(1.0, 1.0, true, 1.0, false, 0.0), s, "treading water tires less than swimming")
	assert_lt(Swimming.step(1.0, 1.0, true, 1.0, true, 1.5), s, "fighting a current tires more")
	assert_lt(Swimming.step(1.0, 1.0, true, 20.0, true, 0.0), s, "far out tires more")
	assert_eq(Swimming.step(0.5, 10.0, false, 0.0, false, 0.0), 1.0, "a rest ashore refills it")
	assert_eq(Swimming.step(0.01, 5.0, true, 1.0, true, 0.0), 0.0, "never below empty")
	var near_shore_secs: float = 1.0 / Swimming.drain_rate(1.0, true, 0.0)
	assert_between(near_shore_secs, 25.0, 45.0, "a full meter lasts half a minute near shore")


func test_rivers_are_crossable_but_the_open_sea_is_not() -> void:
	var tiles_per_sec: float = Player.SPEED * Swimming.SPEED_MULT / IsoConst.TILE_SIZE
	# Straight across the widest river (deep core both banks) and back costs well under a meter.
	var s: float = 1.0
	var width: float = 2.0 * Rivers.HW_MOUTH
	var t: float = 0.0
	while t < 2.0 * width / tiles_per_sec:
		s = Swimming.step(s, 0.1, true, Rivers.HW_MOUTH, true, 0.0)
		t += 0.1
	assert_gt(s, 0.4, "there and back across the widest river leaves stamina to spare (%.2f)" % s)
	# Straight out to sea: how far before the swimmer can't make it back?
	s = 1.0
	var out: float = 0.0
	while s > 0.0 and out < 200.0:
		s = Swimming.step(s, 0.1, true, out, true, 0.0)
		out += tiles_per_sec * 0.1
	assert_between(out, 20.0, 45.0, "swimming %.0f tiles straight out to sea is the limit" % out)


func test_current_and_depth_helpers() -> void:
	assert_eq(Swimming.against(Vector2(1.0, 0.0), Vector2(-1.5, 0.0)), 1.5, "straight upstream")
	assert_eq(Swimming.against(Vector2(1.0, 0.0), Vector2(1.5, 0.0)), 0.0, "with the current")
	assert_eq(Swimming.against(Vector2.ZERO, Vector2(1.5, 0.0)), 0.0, "drifting")
	var ts: float = IsoConst.TILE_SIZE
	assert_gt(Swimming.depth_at(100.0 * ts, 95.0 * ts), 20.0, "mid-bay is far from shore")
	var line: PackedVector2Array = Rivers.centreline(0)
	var p: Vector2 = line[line.size() - 20]
	assert_almost_eq(Swimming.depth_at(p.x * ts, p.y * ts), Rivers.depth(p.x, p.y), 0.01, "river depth from its bank")
	assert_almost_eq(Swimming.WASHED_UP_FRAC, 1.0 / 30.0, 0.0001, "washes up at 1 HP")
