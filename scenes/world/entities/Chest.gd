extends Node3D

var chest_data: Dictionary = {}
var _opened: bool = false

# Shared material for opened chests — created once, reused by all instances.
static var _opened_mat: StandardMaterial3D

func _ready() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.55, 0.35, 0.10)
	wood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.90, 0.75, 0.10)
	gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Re-use the existing MeshInstance3D (so visibility range from ChunkRenderer sticks)
	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.4, 0.45)
		body.mesh = bm
		body.material_override = wood_mat
		body.position = Vector3(0.0, 0.2, 0.0)

	# Gold lock pip on the front face
	var lock := _make_box(Vector3(0.1, 0.1, 0.06), gold_mat)
	lock.position = Vector3(0.0, 0.2, 0.225)
	add_child(lock)

func _make_box(size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	return mi

func init_from_data(data: Dictionary) -> void:
	chest_data = data
	_opened = data.get("opened", false)
	if _opened:
		_show_opened()

func mark_opened() -> void:
	_opened = true
	chest_data["opened"] = true
	_show_opened()

func _show_opened() -> void:
	if not _opened_mat:
		_opened_mat = StandardMaterial3D.new()
		_opened_mat.albedo_color = Color(0.4, 0.3, 0.0)
	var mi := find_child("MeshInstance3D", true, false)
	if mi is MeshInstance3D:
		mi.material_override = _opened_mat
