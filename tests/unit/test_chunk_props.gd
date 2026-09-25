## Prop scatter (GID-134 / TID-522). Props are children of the chunk node, which
## sits at the chunk origin, so positions must be chunk-local: world positions
## drew every chunk but 0,0 a second origin away and nothing ever showed there.
extends "res://tests/framework/test_case.gd"

const _ChunkRenderer = preload("res://scenes/world/ChunkRenderer.gd")
const _ChunkData = preload("res://game_logic/world/ChunkData.gd")
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")


func _props_for(cx: int, cz: int) -> Dictionary:
	var cd := _ChunkData.new(cx, cz)
	cd.biome_id = 0
	var n: int = IsoConst.CHUNK_SIZE + 1
	var hfield := PackedFloat32Array()
	hfield.resize(n * n)
	var lookup := func(_tx: int, _tz: int) -> int: return IsoConst.TILE_GRASS
	return _ChunkRenderer._compute_prop_positions(cd, lookup, hfield, cd.origin_world(), n, 1234)


func test_positions_are_chunk_local_away_from_the_origin() -> void:
	var span: float = float(IsoConst.CHUNK_SIZE) * IsoConst.TILE_SIZE
	var total: int = 0
	for key: String in _props_for(5, -7).keys():
		for p: Vector3 in _props_for(5, -7)[key]:
			total += 1
			assert_true(p.x > -1.0 and p.x < span + 1.0 and p.z > -1.0 and p.z < span + 1.0,
				"%s at %s is chunk-local" % [key, p])
	assert_gt(total, 10, "a grass chunk gets a scatter of props")


func test_every_prop_type_has_a_size() -> void:
	for set_arr: Array in _BiomeDef.PROP_SETS:
		for key: String in set_arr:
			assert_true(_BiomeDef.PROP_SIZES.has(key), "%s has a billboard size" % key)
