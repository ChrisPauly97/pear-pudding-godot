## Water-edge dressing for one chunk (moved out of ChunkRenderer, GID-174): reeds along stream,
## river and bog banks, lily pads on still ponds, rocks in fast river water. Pure: runs on the
## chunk worker with the rest of the chunk build.
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")  # usable before autoloads register (-s runs)
const _ChunkData = preload("res://game_logic/world/ChunkData.gd")
const _WaterMath = preload("res://game_logic/world/WaterMath.gd")
const _TreeScatter = preload("res://game_logic/world/TreeScatter.gd")


## Reeds along stream banks, lily pads on still ponds (TID-643), rocks in fast river water (GID-172) and reeds
## round bog pools (GID-174): up to four candidate spots per grass tile, each kept by WaterMath.edge_prop / bog_prop.
static func compute(
		chunk_data: _ChunkData,
		grid_tile_lookup: Callable,
		hfield: PackedFloat32Array,
		chunk_origin: Vector3,
		nvx: int,
		world_seed: int,
		dry_points: _WaterMath.DryGrid) -> Dictionary:
	const MAX_PER_TYPE: int = 40
	var result: Dictionary = {"reed": [], "lily_pad": [], "river_rock": []}
	var cx: int = chunk_data.cx
	var cz: int = chunk_data.cz
	var hash_s: int = (world_seed ^ (cx * 15731) ^ (cz * 789221) ^ 0x5bd1e995) & 0x7FFFFFFF
	var ts: float = IsoConst.TILE_SIZE
	for lz in range(IsoConst.CHUNK_SIZE):
		for lx in range(IsoConst.CHUNK_SIZE):
			var tile: int = grid_tile_lookup.call(cx * IsoConst.CHUNK_SIZE + lx, cz * IsoConst.CHUNK_SIZE + lz)
			if tile != IsoConst.TILE_GRASS:
				continue
			for k in 4:
				hash_s = (hash_s * 1103515245 + 12345 + k * 977) & 0x7FFFFFFF
				var lpx: float = (float(lx) + 0.15 + 0.7 * float(hash_s & 0xFF) / 255.0) * ts
				var lpz: float = (float(lz) + 0.15 + 0.7 * float((hash_s >> 8) & 0xFF) / 255.0) * ts
				var wx: float = chunk_origin.x + lpx
				var wz: float = chunk_origin.z + lpz
				var w: float = _WaterMath.water_at(wx, wz, world_seed, dry_points)
				var roll: float = float((hash_s >> 16) & 0x7FFF) / 32767.0
				var key: String = ""
				if w > _WaterMath.REED_MIN:
					key = _WaterMath.edge_prop(w, _WaterMath.flow_at(wx, wz, world_seed), roll)
					if not _WaterMath.edge_prop_ok(key, wx, wz):
						key = ""
				elif _WaterMath.biome_has_bog(chunk_data.biome_id):
					key = _WaterMath.bog_prop(_WaterMath.bog_at(wx, wz, world_seed), roll)  # GID-174
				if key == "":
					continue
				var arr: Array = result[key] as Array
				if arr.size() >= MAX_PER_TYPE:
					continue
				var y: float = _TreeScatter.height_at_local(hfield, nvx, lpx, lpz)
				if key == "lily_pad" or key == "river_rock":
					y -= _WaterMath.LILY_SINK
				arr.append(Vector3(lpx, y, lpz))
	return result
