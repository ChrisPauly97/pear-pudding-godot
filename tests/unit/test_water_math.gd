## Streams and ponds (GID-134 / TID-524): deterministic, bounded, and kept to
## the biomes that have water.
extends "res://tests/framework/test_case.gd"

const W = preload("res://game_logic/world/WaterMath.gd")


func test_intensity_is_bounded_and_deterministic() -> void:
	var wet: int = 0
	for i in 400:
		# Offset into the wilds: stitched towns and roads stay dry (GID-138).
		var x: float = float(i % 20) * 7.3 - 70.0 + 2000.0
		var z: float = float(i / 20) * 6.1 - 60.0
		var v: float = W.intensity(x, z, 42)
		assert_true(v >= 0.0 and v <= 1.0, "intensity %f in range" % v)
		assert_almost_eq(W.intensity(x, z, 42), v, 0.0, "same seed, same water")
		if W.is_wet(x, z, 42):
			wet += 1
	assert_gt(wet, 0, "some water in the wilds")
	assert_lt(wet, 200, "water is a feature, not the whole map")


func test_only_temperate_biomes_have_water() -> void:
	assert_true(W.biome_has_water(0))
	assert_true(W.biome_has_water(1))
	assert_false(W.biome_has_water(2), "no desert streams")
	assert_false(W.biome_has_water(3), "no scorched streams")


func test_water_keeps_clear_of_structures() -> void:
	var pts := PackedVector2Array([Vector2(10.0, 10.0)])
	assert_almost_eq(W.structure_fade(10.5, 10.0, pts), 0.0, 0.0001, "no water on a ruin")
	assert_almost_eq(W.structure_fade(30.0, 10.0, pts), 1.0, 0.0001, "full water well away")
	assert_almost_eq(W.structure_fade(0.0, 0.0, PackedVector2Array()), 1.0, 0.0001)
	assert_lte(W.DRY_RADIUS + W.DRY_FADE, 5.0,
		"fade reach must fit the chunk grid margin or water seams at chunk borders")


## TID-642: the current runs along the stream, zero off it, and has one
## orientation along the stream. It can only reverse near a saddle of the
## noise (two branches meeting, gradient → 0), so reversals must be rare.
func test_flow_runs_along_streams() -> void:
	var flowing: int = 0
	var reversed: int = 0
	for i in 2000:
		var x: float = float(i % 50) * 3.1 + 2000.0
		var z: float = float(i / 50) * 2.9
		var f: Vector2 = W.flow_at(x, z, 42)
		if not W.is_wet(x, z, 42):
			if W.intensity(x, z, 42) <= 0.0:
				assert_eq(f, Vector2.ZERO, "no current on dry ground")
			continue
		if f == Vector2.ZERO:
			continue  # pond
		flowing += 1
		var spd: float = f.length()
		assert_true(spd >= W.FLOW_MIN_SPEED - 0.001 and spd <= W.FLOW_MAX_SPEED + 0.001, "speed %f clamped" % spd)
		# One step along the current stays roughly parallel (continuous field).
		var next: Vector2 = W.flow_at(x + f.x / spd, z + f.y / spd, 42)
		if next != Vector2.ZERO and f.normalized().dot(next.normalized()) < 0.0:
			reversed += 1
	assert_gt(flowing, 0, "some streams flow")
	assert_lt(float(reversed), float(flowing) * 0.05, "current rarely reverses (%d / %d)" % [reversed, flowing])


## TID-643: reeds on the bank band, lily pads only on still deep water.
func test_edge_props_follow_the_water() -> void:
	assert_eq(W.edge_prop(0.2, Vector2(0.0, 1.0), 0.0), "reed", "reeds on a stream bank")
	assert_eq(W.edge_prop(0.2, Vector2.ZERO, 0.99), "", "the roll thins them out")
	assert_eq(W.edge_prop(0.8, Vector2.ZERO, 0.0), "lily_pad", "lily pads on a still pond")
	assert_eq(W.edge_prop(0.8, Vector2(1.0, 0.0), 0.0), "", "no lily pads in a current")
	assert_eq(W.edge_prop(0.45, Vector2.ZERO, 0.0), "", "open water between bank and pads")
	assert_eq(W.edge_prop(0.05, Vector2.ZERO, 0.0), "", "dry ground")


## GID-164 / TID-673: the bucketed DryGrid + realm-clear skip give exactly the
## old linear-scan result, near towns and roads and out in the wilds.
func test_chunk_context_matches_linear_scan() -> void:
	const RL = preload("res://game_logic/world/RealmLayout.gd")
	var chunks: Array[Vector2i] = [Vector2i(40, 40), Vector2i(-30, 12)]
	for town: String in RL.town_names():
		var r: Rect2i = RL.world_rect(town)
		chunks.append(Vector2i(floori(r.position.x / 16.0) - 1, floori(r.position.y / 16.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var checked: int = 0
	var clear_seen: bool = false
	for c: Vector2i in chunks:
		var o := Vector2(c) * 32.0
		var pts := PackedVector2Array()
		for i in 40:
			pts.append(o + Vector2(rng.randf_range(-6.0, 38.0), rng.randf_range(-6.0, 38.0)))
		var ctx: W.DryGrid = W.chunk_context(pts, c.x, c.y)
		clear_seen = clear_seen or ctx.realm_clear
		for seed_v: int in [42, 7]:
			for iz in 33:
				for ix in 33:
					var wx: float = o.x + float(ix)
					var wz: float = o.y + float(iz)
					var old: float = W.intensity(wx, wz, seed_v) * W.structure_fade(wx, wz, pts)
					var new_v: float = W.water_at(wx, wz, seed_v, ctx)
					if absf(old - new_v) > 0.000001:
						assert_almost_eq(new_v, old, 0.000001, "water differs at (%f, %f)" % [wx, wz])
						return
					assert_eq(W.wet_at(wx, wz, seed_v, ctx), old > W.WET_LEVEL)
					checked += 1
	assert_true(clear_seen, "a wild chunk proves realm-clear")
	assert_gt(checked, 10000)
