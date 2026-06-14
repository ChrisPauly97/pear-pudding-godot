extends Node3D

var waystone_data: Dictionary = {}

static var _dormant_mat: StandardMaterial3D
static var _active_mat: StandardMaterial3D
static var _pillar_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _dormant_mat != null:
		return
	_dormant_mat = StandardMaterial3D.new()
	_dormant_mat.albedo_color = Color(0.6, 0.6, 0.65)
	_dormant_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_active_mat = StandardMaterial3D.new()
	_active_mat.albedo_color = Color(1.0, 0.95, 0.3)
	_active_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_mesh = BoxMesh.new()
	_pillar_mesh.size = Vector3(1.0, 1.5, 1.0)

func _ready() -> void:
	_ensure_shared_resources()
	var mi: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mi:
		mi.mesh = _pillar_mesh
		mi.material_override = _dormant_mat
		mi.position = Vector3(0.0, 0.75, 0.0)

func init_from_data(data: Dictionary) -> void:
	waystone_data = data
	if data.get("active", false):
		_set_active_visual()

func mark_activated() -> void:
	if waystone_data.get("active", false):
		return
	waystone_data["active"] = true
	_set_active_visual()
	var wid: String = str(waystone_data.get("id", ""))
	SceneManager.save_manager.activate_waystone(wid)
	GameBus.waystone_activated.emit(wid)

func _set_active_visual() -> void:
	_ensure_shared_resources()
	var mi := find_child("MeshInstance3D", true, false)
	if mi is MeshInstance3D:
		(mi as MeshInstance3D).material_override = _active_mat
