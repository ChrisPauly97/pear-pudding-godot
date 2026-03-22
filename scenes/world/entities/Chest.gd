extends Node3D

var chest_data: Dictionary = {}
var _opened: bool = false

# Shared across all chest instances — created once
static var _opened_mat: StandardMaterial3D
static var _wood_mat: StandardMaterial3D
static var _gold_mat: StandardMaterial3D
static var _body_mesh: BoxMesh
static var _lock_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _wood_mat != null:
		return
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_color = Color(0.55, 0.35, 0.10)
	_wood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gold_mat = StandardMaterial3D.new()
	_gold_mat.albedo_color = Color(0.90, 0.75, 0.10)
	_gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body_mesh = BoxMesh.new()
	_body_mesh.size = Vector3(0.6, 0.4, 0.45)
	_lock_mesh = BoxMesh.new()
	_lock_mesh.size = Vector3(0.1, 0.1, 0.06)

func _ready() -> void:
	_ensure_shared_resources()

	# Re-use the existing MeshInstance3D (so visibility range from ChunkRenderer sticks)
	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		body.mesh = _body_mesh
		body.material_override = _wood_mat
		body.position = Vector3(0.0, 0.2, 0.0)

	# Gold lock pip on the front face
	var lock := MeshInstance3D.new()
	lock.mesh = _lock_mesh
	lock.material_override = _gold_mat
	lock.position = Vector3(0.0, 0.2, 0.225)
	add_child(lock)

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
