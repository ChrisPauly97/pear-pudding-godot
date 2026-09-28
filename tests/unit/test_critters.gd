## Ambient critters (CritterDef / Critter): tables line up, day-only species
## hide at night, critters wander and flee the hero.
extends "res://tests/framework/test_case.gd"

const _CritterDef = preload("res://game_logic/world/CritterDef.gd")
const _Critter = preload("res://scenes/world/entities/Critter.gd")
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")


func test_every_biome_species_has_params_and_frames() -> void:
	assert_eq(_CritterDef.BIOME_CRITTERS.size(), _BiomeDef.PARAMS.size(), "one critter pool per biome")
	for pool: Array in _CritterDef.BIOME_CRITTERS:
		for k: Variant in pool:
			var key: String = str(k)
			assert_false(_CritterDef.params(key).is_empty(), "%s has movement params" % key)
			var frames: Array = _CritterDef.FRAMES.get(key, []) as Array
			assert_eq(frames.size(), 2, "%s has two frames" % key)
			for f: Variant in frames:
				assert_true(f is Texture2D, "%s frame is a texture" % key)


func test_day_only_species_hide_at_night() -> void:
	for roll in range(40):
		var key: String = _CritterDef.species_for(_BiomeDef.GRASSLANDS, false, roll)
		assert_false(bool(_CritterDef.params(key)["day_only"]), "%s out at night" % key)
	assert_eq(_CritterDef.species_for(99, true, 0), "", "unknown biome has no critters")


func test_flee_and_facing() -> void:
	var p := Vector3(5.0, 0.0, 5.0)
	var away: Vector3 = _CritterDef.flee_target(p, Vector3(4.0, 0.0, 5.0))
	assert_gt(away.x, p.x, "flees away from the threat")
	assert_true(_CritterDef.faces_left(Vector3(-1.0, 0.0, 1.0)), "screen-left move flips")
	assert_false(_CritterDef.faces_left(Vector3(1.0, 0.0, -1.0)), "screen-right move faces right")


func _make(key: String, threat: Vector3) -> _Critter:
	var c := _Critter.new()
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var open := func(_x: float, _z: float) -> bool: return true
	var hero := func() -> Vector3: return threat
	c.setup(key, Vector3.ZERO, 7, flat, open, hero)
	c._ready()
	return c


func test_critter_wanders_near_home() -> void:
	var c := _make("mouse", Vector3(1000.0, 0.0, 1000.0))
	var moved: bool = false
	for i in range(600):
		c._process(0.05)
		if c.position.length() > 0.1:
			moved = true
		assert_true(Vector2(c.position.x, c.position.z).length() <= 3.01, "stays within its radius")
	assert_true(moved, "the mouse wanders")
	c.free()


func test_critter_flees_the_hero() -> void:
	var c := _make("rat", Vector3(0.5, 0.0, 0.0))
	for i in range(40):
		c._process(0.05)
	assert_lt(c.position.x, -0.5, "rat ran away from the hero")
	c.free()


func test_flyers_hover() -> void:
	var c := _make("butterfly", Vector3(1000.0, 0.0, 1000.0))
	c._process(0.05)
	assert_gt(c.position.y, 0.5, "butterfly flies above the ground")
	c.free()
