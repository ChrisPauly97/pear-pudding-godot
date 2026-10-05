## GID-164 / TID-674: gameplay water probes reuse one cached DryGrid per chunk
## and still answer exactly what a fresh snapshot + scan gives.
extends "res://tests/framework/test_case.gd"

const _ChunkStreamingManager = preload("res://scenes/world/ChunkStreamingManager.gd")
const _ChunkRenderer = preload("res://scenes/world/ChunkRenderer.gd")
const _InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const _WaterMath = preload("res://game_logic/world/WaterMath.gd")

const SEED: int = 42


func _fresh(csm: _ChunkStreamingManager, wx: float, wz: float) -> float:
	var key := Vector2i(floori(wx / 32.0), floori(wz / 32.0))
	var cd = csm.get_chunk_data(key)
	var snap: Array = csm.snapshot_tile_grid_for(key)
	var pts: PackedVector2Array = _ChunkRenderer.water_dry_points(
			cd, snap[0], int(snap[2]), int(snap[3]), int(snap[4]))
	return _WaterMath.intensity(wx, wz, SEED) * _WaterMath.structure_fade(wx, wz, pts)


func test_cached_probe_matches_fresh_scan() -> void:
	var csm: _ChunkStreamingManager = _ChunkStreamingManager.new()
	csm.setup(SEED, true, null, null, null)
	var key := Vector2i(40, 40)
	for i in 64:
		key = Vector2i(40 + i % 8, 40 + i / 8)
		var cd = _InfiniteWorldGen.generate_chunk(key.x, key.y, SEED)
		csm._chunk_data_cache[key] = cd
		if _WaterMath.biome_has_water(int(cd.get("biome_id"))):
			break
	var wet: int = 0
	for i in 400:
		var wx: float = float(key.x) * 32.0 + float(i % 20) * 1.6
		var wz: float = float(key.y) * 32.0 + float(i / 20) * 1.6
		var got: float = _ChunkRenderer.water_at_world(csm, wx, wz, SEED)
		assert_almost_eq(got, _fresh(csm, wx, wz), 0.000001)
		if got > 0.0:
			wet += 1
	assert_gt(wet, 0, "the sampled chunk has some water (test is not vacuous)")
	assert_true(csm._dry_cache.has(key), "probe cached the chunk's clearance")
	var g: Object = csm._dry_cache[key]
	_ChunkRenderer.water_at_world(csm, 1290.0, 1290.0, SEED)
	assert_eq(csm._dry_cache[key], g, "second probe reuses it")
	csm.free()
