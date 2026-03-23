extends Node3D

var npc_data: Dictionary = {}

static var _body_mat: StandardMaterial3D
static var _head_mat: StandardMaterial3D
static var _body_mesh: BoxMesh
static var _head_mesh: BoxMesh
static var _leg_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _body_mat != null:
		return
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.2, 0.45, 0.7)
	_body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_head_mat = StandardMaterial3D.new()
	_head_mat.albedo_color = Color(0.9, 0.75, 0.6)
	_head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body_mesh = BoxMesh.new()
	_body_mesh.size = Vector3(0.5, 0.55, 0.3)
	_head_mesh = BoxMesh.new()
	_head_mesh.size = Vector3(0.35, 0.35, 0.35)
	_leg_mesh = BoxMesh.new()
	_leg_mesh.size = Vector3(0.22, 0.5, 0.22)

func _ready() -> void:
	_ensure_shared_resources()

	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		body.mesh = _body_mesh
		body.material_override = _body_mat
		body.position = Vector3(0.0, 0.275, 0.0)

	var head := _make_mi(_head_mesh, _head_mat)
	head.position = Vector3(0.0, 0.75, 0.0)
	add_child(head)

	var left_leg := _make_mi(_leg_mesh, _body_mat)
	left_leg.position = Vector3(-0.15, -0.25, 0.0)
	add_child(left_leg)

	var right_leg := _make_mi(_leg_mesh, _body_mat)
	right_leg.position = Vector3(0.15, -0.25, 0.0)
	add_child(right_leg)

static func _make_mi(mesh: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi

func init_from_data(data: Dictionary) -> void:
	npc_data = data

func get_dialogue() -> String:
	return str(npc_data.get("dialogue", "..."))
