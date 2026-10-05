## GID-164 / TID-675: the hill summed-area-table skip in
## compute_height_field_grid gives exactly the full per-vertex scan on real
## streamed chunks (hills, walls, towns).
extends "res://tests/framework/test_case.gd"

const _ChunkStreamingManager = preload("res://scenes/world/ChunkStreamingManager.gd")
const TerrainMath = preload("res://game_logic/TerrainMath.gd")

const SEED: int = 42


func test_sat_skip_matches_full_scan() -> void:
	var csm: _ChunkStreamingManager = _ChunkStreamingManager.new()
	csm.setup(SEED, true, null, null, null)
	var hilly: int = 0
	var keys: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 5)]
	for i in 24:
		keys.append(Vector2i(-12 + i * 7, 20 - i * 5))
	for key: Vector2i in keys:
		csm._ensure_tile_data_around(key)
		var snap: Array = csm.snapshot_tile_grid_for(key)
		var tg: PackedInt32Array = snap[0]
		var hg: PackedInt32Array = snap[1]
		var mx: int = int(snap[2])
		var mz: int = int(snap[3])
		var w: int = int(snap[4])
		var tl := func(x: int, z: int) -> int:
			var lx: int = x - mx
			var lz: int = z - mz
			if lx < 0 or lz < 0 or lx >= w or lz >= w:
				return IsoConst.TILE_WALL
			return tg[lz * w + lx]
		var hl := func(x: int, z: int) -> int:
			var lx: int = x - mx
			var lz: int = z - mz
			if lx < 0 or lz < 0 or lx >= w or lz >= w:
				return 1
			return hg[lz * w + lx]
		var ox: float = float(key.x) * 32.0
		var oz: float = float(key.y) * 32.0
		var full: PackedFloat32Array = TerrainMath.compute_height_field(
				tl, hl, ox, oz, 33, 33, 1.0, IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
		var fast: PackedFloat32Array = TerrainMath.compute_height_field_grid(
				tg, hg, mx, mz, w, ox, oz, 33, 33, 1.0, IsoConst.HILL_CURVE_R, IsoConst.HILL_PEAK_H)
		var any_hill: bool = false
		for i in full.size():
			if full[i] != fast[i]:
				_fail("chunk %s vertex %d: fast %f vs full %f" % [key, i, fast[i], full[i]])
				csm.free()
				return
			any_hill = any_hill or full[i] > 0.0
		if any_hill:
			hilly += 1
	assert_gt(hilly, 2, "some sampled chunks have hills (test not vacuous)")
	csm.free()
