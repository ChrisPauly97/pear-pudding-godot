extends RefCounted

const CHUNK_SIZE: int = 16

var cx: int = 0
var cz: int = 0
var tiles: PackedInt32Array    # contiguous memory, ~6x smaller than Array[int]
var heights: PackedInt32Array
var enemies: Array[Dictionary] = []
var chests: Array[Dictionary] = []
var doors: Array[Dictionary] = []
var npcs: Array[Dictionary] = []
var waystones: Array[Dictionary] = []
var burial_mounds: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
var is_generated: bool = false
var has_entities: bool = false
var biome_id: int = 0

func _init(p_cx: int = 0, p_cz: int = 0) -> void:
	cx = p_cx
	cz = p_cz
	tiles = PackedInt32Array()
	tiles.resize(CHUNK_SIZE * CHUNK_SIZE)
	tiles.fill(0)  # TILE_GRASS
	heights = PackedInt32Array()
	heights.resize(CHUNK_SIZE * CHUNK_SIZE)
	heights.fill(0)

func get_tile(lx: int, lz: int) -> int:
	if lx < 0 or lx >= CHUNK_SIZE or lz < 0 or lz >= CHUNK_SIZE:
		return IsoConst.TILE_GRASS
	return tiles[lz * CHUNK_SIZE + lx]

func set_tile(lx: int, lz: int, v: int) -> void:
	if lx < 0 or lx >= CHUNK_SIZE or lz < 0 or lz >= CHUNK_SIZE:
		return
	tiles[lz * CHUNK_SIZE + lx] = v

func get_height(lx: int, lz: int) -> int:
	if lx < 0 or lx >= CHUNK_SIZE or lz < 0 or lz >= CHUNK_SIZE:
		return 1
	return heights[lz * CHUNK_SIZE + lx]

func set_height(lx: int, lz: int, h: int) -> void:
	if lx < 0 or lx >= CHUNK_SIZE or lz < 0 or lz >= CHUNK_SIZE:
		return
	heights[lz * CHUNK_SIZE + lx] = h

func origin_world() -> Vector3:
	return Vector3(
		float(cx) * float(CHUNK_SIZE) * IsoConst.TILE_SIZE,
		0.0,
		float(cz) * float(CHUNK_SIZE) * IsoConst.TILE_SIZE
	)
