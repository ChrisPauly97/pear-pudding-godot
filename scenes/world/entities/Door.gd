extends Node3D

var door_data: Dictionary = {}

static var _door_mat: StandardMaterial3D
static var _door_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _door_mat != null:
		return
	_door_mat = StandardMaterial3D.new()
	_door_mat.albedo_color = Color(0.45, 0.28, 0.10)
	_door_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_door_mesh = BoxMesh.new()
	_door_mesh.size = Vector3(1.8, 1.8, 0.1)

func _ready() -> void:
	_ensure_shared_resources()
	var mi: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mi:
		mi.mesh = _door_mesh
		mi.material_override = _door_mat
		mi.position = Vector3(0.0, 0.9, 0.0)

func init_from_data(data: Dictionary) -> void:
	door_data = data
	var target: String = str(data.get("target_map", ""))
	if target.is_empty():
		target = "[exit]"
	var lbl := Label3D.new()
	lbl.text = target
	lbl.font_size = 32
	lbl.pixel_size = 0.02
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.4, 0.0)
	lbl.modulate = Color(1.0, 0.85, 0.2)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	lbl.outline_size = 6
	add_child(lbl)
