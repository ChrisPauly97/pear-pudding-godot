## Streams and ponds (GID-134 / TID-524): deterministic, bounded, and kept to
## the biomes that have water.
extends "res://tests/framework/test_case.gd"

const W = preload("res://game_logic/world/WaterMath.gd")


func test_intensity_is_bounded_and_deterministic() -> void:
	var wet: int = 0
	for i in 400:
		var x: float = float(i % 20) * 7.3 - 70.0
		var z: float = float(i / 20) * 6.1 - 60.0
		var v: float = W.intensity(x, z, 42)
		assert_true(v >= 0.0 and v <= 1.0, "intensity %f in range" % v)
		assert_almost_eq(W.intensity(x, z, 42), v, 0.0, "same seed, same water")
		if W.is_wet(x, z, 42):
			wet += 1
	assert_gt(wet, 0, "some water near the origin")
	assert_lt(wet, 200, "water is a feature, not the whole map")


func test_only_temperate_biomes_have_water() -> void:
	assert_true(W.biome_has_water(0))
	assert_true(W.biome_has_water(1))
	assert_false(W.biome_has_water(2), "no desert streams")
	assert_false(W.biome_has_water(3), "no scorched streams")
