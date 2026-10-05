extends RefCounted
## Tree placement for infinite-world chunks. Pure math (runs on the chunk
## worker thread): returns prop key -> Array[Vector3] of chunk-local positions,
## merged into ChunkRenderer's prop scatter so trees render as billboard props.
##
## Trees grow in groves: a low-frequency noise mask (the terrain noise sampled
## far away at a coarse scale) picks grove areas, where each tile grows a tree
## with BiomeDef.TREE_GROVE_CHANCE; elsewhere lone trees are rare. A tree needs
## its tile and all eight neighbours to be open ground (grass or hill), so ruins,
## roads and town edges stay clear, and it keeps its distance from entities,
## stitched towns and water.

const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const _ChunkData = preload("res://game_logic/world/ChunkData.gd")
const _InfiniteWorldGen = preload("res://game_logic/world/InfiniteWorldGen.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _WaterMath = preload("res://game_logic/world/WaterMath.gd")

## Grove mask sampling scale (on the shared terrain noise) and offset.
const GROVE_SCALE: float = 0.35
const GROVE_OFFSET := Vector2(9173.0, -4211.0)
## Noise above this is grove; the chance ramps up over GROVE_RAMP.
const GROVE_THRESH: float = 0.05
const GROVE_RAMP: float = 0.3
## World units a tree keeps from any chunk entity (chests, NPCs, enemies...).
const ENTITY_CLEARANCE: float = 3.0
## Tiles a tree keeps from stitched towns and roads.
const REALM_CLEARANCE: float = 3.0
const MAX_PER_CHUNK: int = 60


static func is_tree_key(key: String) -> bool:
	return key.begins_with("tree_")


## Grove chance at a world tile for a biome (0 when the biome has no trees).
static func chance_at(biome: int, wtx: int, wtz: int, world_seed: int) -> float:
	if biome < 0 or biome >= BiomeDef.TREE_SETS.size():
		return 0.0
	var noise: FastNoiseLite = _InfiniteWorldGen._get_noise(world_seed)
	var n: float = noise.get_noise_2d(float(wtx) * GROVE_SCALE + GROVE_OFFSET.x,
			float(wtz) * GROVE_SCALE + GROVE_OFFSET.y)
	var grove: float = clampf((n - GROVE_THRESH) / GROVE_RAMP, 0.0, 1.0)
	return lerpf(BiomeDef.TREE_LONE_CHANCE[biome], BiomeDef.TREE_GROVE_CHANCE[biome], grove)


static func compute(chunk_data: _ChunkData, grid_tile_lookup: Callable, hfield: PackedFloat32Array,
		chunk_origin: Vector3, nvx: int, world_seed: int,
		dry_points: _WaterMath.DryGrid = null) -> Dictionary:
	var result: Dictionary = {}
	var biome: int = chunk_data.biome_id
	if biome < 0 or biome >= BiomeDef.TREE_SETS.size():
		return result
	var keys: Array = BiomeDef.TREE_SETS[biome] as Array
	if keys.is_empty():
		return result
	var blockers: Array[Vector3] = _entity_points(chunk_data, chunk_origin)
	var near_realm: bool = _RealmLayout.chunk_touches_realm(chunk_data.cx, chunk_data.cz)
	var has_water: bool = _WaterMath.biome_has_water(biome)
	var placed: int = 0
	var h: int = (world_seed ^ (chunk_data.cx * 92821) ^ (chunk_data.cz * 68917)) & 0x7FFFFFFF
	for lz in range(IsoConst.CHUNK_SIZE):
		for lx in range(IsoConst.CHUNK_SIZE):
			var wtx: int = chunk_data.cx * IsoConst.CHUNK_SIZE + lx
			var wtz: int = chunk_data.cz * IsoConst.CHUNK_SIZE + lz
			h = (h * 1103515245 + lz * 19349663 + lx * 83492791 + 12345) & 0x7FFFFFFF
			var roll: float = float(h & 0xFFFF) / 65535.0
			if roll >= chance_at(biome, wtx, wtz, world_seed):
				continue
			if not _open_ground(grid_tile_lookup, wtx, wtz):
				continue
			if near_realm and _RealmLayout.reserved_distance(wtx, wtz) <= REALM_CLEARANCE:
				continue
			# Tile corner: the height field is exact there, so the trunk sits flush
			# on hills too (a small sink hides the facet gap).
			var lxz := Vector2(float(lx) * IsoConst.TILE_SIZE, float(lz) * IsoConst.TILE_SIZE)
			var local := Vector3(lxz.x, height_at_local(hfield, nvx, lxz.x, lxz.y) - 0.1, lxz.y)
			var wp := Vector2(chunk_origin.x + local.x, chunk_origin.z + local.z)
			if has_water and _WaterMath.wet_at(wp.x, wp.y, world_seed, dry_points):
				continue
			var blocked: bool = false
			for b: Vector3 in blockers:
				if Vector2(b.x, b.y).distance_squared_to(wp) < b.z * b.z:
					blocked = true
					break
			if blocked:
				continue
			var key: String = str(keys[(h >> 16) % keys.size()])
			if not result.has(key):
				result[key] = []
			(result[key] as Array).append(local)
			placed += 1
			if placed >= MAX_PER_CHUNK:
				return result
	return result


## Terrain height at a chunk-local xz, bilinear over the chunk height field
## (TERRAIN_VDENSITY vertices per tile, nvx per row) — the same surface the mesh
## draws, so props neither float nor sink.
static func height_at_local(hfield: PackedFloat32Array, nvx: int, x: float, z: float) -> float:
	if hfield.is_empty() or nvx <= 0:
		return 0.0
	var nvz: int = hfield.size() / nvx
	var step: float = IsoConst.TILE_SIZE / float(IsoConst.TERRAIN_VDENSITY)
	var fx: float = clampf(x / step, 0.0, float(nvx - 1))
	var fz: float = clampf(z / step, 0.0, float(nvz - 1))
	var ix: int = mini(int(fx), nvx - 2) if nvx > 1 else 0
	var iz: int = mini(int(fz), nvz - 2) if nvz > 1 else 0
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	var ix1: int = mini(ix + 1, nvx - 1)
	var iz1: int = mini(iz + 1, nvz - 1)
	var h00: float = hfield[iz * nvx + ix]
	var h10: float = hfield[iz * nvx + ix1]
	var h01: float = hfield[iz1 * nvx + ix]
	var h11: float = hfield[iz1 * nvx + ix1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## A tree tile and its eight neighbours are all grass or hill.
static func _open_ground(lookup: Callable, wtx: int, wtz: int) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var t: int = int(lookup.call(wtx + dx, wtz + dz))
			if t != IsoConst.TILE_GRASS and t != IsoConst.TILE_HILL:
				return false
	return true


## (world x, world z, clearance radius) of every entity the chunk spawns.
static func _entity_points(cd: _ChunkData, chunk_origin: Vector3) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for list: Array[Dictionary] in [cd.enemies, cd.chests, cd.doors, cd.npcs, cd.waystones,
			cd.burial_mounds, cd.mana_wells]:
		for e: Dictionary in list:
			if e.has("x") and e.has("z"):
				pts.append(Vector3(float(e["x"]), float(e["z"]), ENTITY_CLEARANCE))
	# Landmark tx/tz are chunk-local; keep the whole footprint clear.
	var lm_r: float = (float(_InfiniteWorldGen.LANDMARK_FP) + 1.5) * IsoConst.TILE_SIZE
	for lm: Dictionary in cd.landmarks:
		pts.append(Vector3(chunk_origin.x + IsoConst.tile_center(lm.get("tx", 0)),
				chunk_origin.z + IsoConst.tile_center(lm.get("tz", 0)), lm_r))
	return pts
