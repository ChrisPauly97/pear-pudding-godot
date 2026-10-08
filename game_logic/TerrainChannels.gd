## Per-vertex terrain channels that ride in the mesh's CUSTOM0 (moved out of TerrainMath, GID-174):
## the stream current (xy, TID-642) and, in bog biomes, the bog intensity (z, GID-174). Skirt
## vertices past `total_verts` get still, dry values.
extends RefCounted


## {"data": PackedFloat32Array, "fmt": surface format flags} for CUSTOM0, or {} when there is no flow field.
static func custom0(flow_field: PackedVector2Array, bog_field: PackedFloat32Array, total_verts: int,
		vert_count: int) -> Dictionary:
	if flow_field.size() != total_verts:
		return {}
	var with_bog: bool = bog_field.size() == total_verts
	var n: int = 3 if with_bog else 2
	var data := PackedFloat32Array()
	data.resize(vert_count * n)
	for i: int in range(total_verts):
		data[i * n] = flow_field[i].x
		data[i * n + 1] = flow_field[i].y
		if with_bog:
			data[i * n + 2] = bog_field[i]
	var kind: int = Mesh.ARRAY_CUSTOM_RGB_FLOAT if with_bog else Mesh.ARRAY_CUSTOM_RG_FLOAT
	return {"data": data, "fmt": kind << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT}
