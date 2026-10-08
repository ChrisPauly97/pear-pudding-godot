## The mouth of a cave entrance (GID-173 / TID-700): a rough rock arch around a black opening,
## cut into the foot of a hill, with rubble spilling out. Built for a cave Door
## (`door_data.kind == "cave"`) in place of the wooden door sprite. Static builder; its local
## −Z runs into the hill (`facing`, tiles), so the opening faces back toward the approach tile.
extends RefCounted

const _WEB = preload("res://scenes/world/entities/WorldEntityBase.gd")
const _Coastline = preload("res://scenes/world/modules/Coastline.gd")

const ROCK := Color(0.42, 0.40, 0.37)
const ROCK_DARK := Color(0.31, 0.29, 0.27)
const ROCK_LIGHT := Color(0.52, 0.50, 0.46)
const VOID := Color(0.03, 0.03, 0.04)
## Arch size (world units): opening width / height, pillar thickness, how far the mouth sits
## from the door node (the approach tile's centre) toward the hill.
const OPEN_W: float = 1.9
const OPEN_H: float = 2.1
const PILLAR: float = 0.7
const SET_BACK: float = 1.1

static var _mat: StandardMaterial3D = null


## The mouth as a Node3D for a door at height `y_offset` above the ground, facing `facing` (into the hill).
static func make(facing: Vector2i, y_offset: float) -> Node3D:
	if _mat == null:
		_mat = _WEB.unshaded_material(Color.WHITE)
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var root := Node3D.new()
	root.name = "CaveMouth"
	root.rotation.y = atan2(-float(facing.x), -float(facing.y))
	root.position = Vector3(float(facing.x), 0.0, float(facing.y)) * SET_BACK + Vector3.DOWN * y_offset
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = OPEN_W * 0.5
	# The dark opening, a little inside the arch.
	_Coastline._box(st, Vector3(-hw, 0.0, -0.6), Vector3(hw, OPEN_H, -0.4), VOID)
	# Rough pillars: stacked, slightly offset blocks.
	for side: float in [-1.0, 1.0]:
		var x0: float = side * hw
		var x1: float = side * (hw + PILLAR)
		for i: int in 3:
			var y0: float = float(i) * OPEN_H / 3.0
			var jut: float = 0.08 * float((i + int(side > 0.0)) % 2)
			var col: Color = ROCK if i % 2 == 0 else ROCK_DARK
			_Coastline._box(st, Vector3(minf(x0, x1) - jut, y0, -0.5), Vector3(maxf(x0, x1) + jut,
					y0 + OPEN_H / 3.0, 0.2 + jut), col)
	# Lintel and a capstone.
	_Coastline._box(st, Vector3(-hw - PILLAR, OPEN_H, -0.55), Vector3(hw + PILLAR, OPEN_H + 0.55, 0.25), ROCK_LIGHT)
	_Coastline._box(st, Vector3(-hw * 0.6, OPEN_H + 0.55, -0.45), Vector3(hw * 0.6, OPEN_H + 0.9, 0.15), ROCK)
	# Rubble at the threshold.
	var rubble: Array[Vector3] = [Vector3(-1.1, 0.0, 0.5), Vector3(0.9, 0.0, 0.7), Vector3(1.4, 0.0, 0.2),
		Vector3(-1.6, 0.0, 0.9)]
	for k: int in rubble.size():
		var r: Vector3 = rubble[k]
		var sz: float = 0.22 + 0.08 * float(k % 3)
		_Coastline._box(st, r - Vector3(sz, 0.0, sz), r + Vector3(sz, sz * 1.3, sz), ROCK_DARK if k % 2 == 0 else ROCK)
	var mi := MeshInstance3D.new()
	mi.name = "Arch"
	mi.mesh = st.commit()
	mi.material_override = _mat
	root.add_child(mi)
	return root
