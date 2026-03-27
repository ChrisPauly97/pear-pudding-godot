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
	_body_mesh.size = Vector3(0.8, 0.9, 0.5)
	_head_mesh = BoxMesh.new()
	_head_mesh.size = Vector3(0.55, 0.55, 0.55)
	_leg_mesh = BoxMesh.new()
	_leg_mesh.size = Vector3(0.35, 0.8, 0.35)

func _ready() -> void:
	_ensure_shared_resources()

	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		body.mesh = _body_mesh
		body.material_override = _body_mat
		body.position = Vector3(0.0, 0.45, 0.0)

	var head := _make_mi(_head_mesh, _head_mat)
	head.position = Vector3(0.0, 1.2, 0.0)
	add_child(head)

	var left_leg := _make_mi(_leg_mesh, _body_mat)
	left_leg.position = Vector3(-0.23, -0.4, 0.0)
	add_child(left_leg)

	var right_leg := _make_mi(_leg_mesh, _body_mat)
	right_leg.position = Vector3(0.23, -0.4, 0.0)
	add_child(right_leg)

	# npc_data is set by init_from_data() before add_child(), so it's ready here
	_add_name_label()

static func _make_mi(mesh: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi

func init_from_data(data: Dictionary) -> void:
	npc_data = data

func _add_name_label() -> void:
	var npc_name: String = _extract_name()
	var lbl := Label3D.new()
	lbl.text = npc_name
	lbl.font_size = 32
	lbl.pixel_size = 0.025
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 2.0, 0.0)
	lbl.modulate = Color.YELLOW
	add_child(lbl)

func _extract_name() -> String:
	var dlg: String = str(npc_data.get("dialogue", ""))
	var lower: String = dlg.to_lower()
	var name_idx: int = lower.find("my name is ")
	if name_idx >= 0:
		var after: String = dlg.substr(name_idx + 11)
		var end: int = after.find(".")
		if end < 0:
			end = after.find("!")
		if end < 0:
			end = after.find(",")
		if end > 0:
			return after.substr(0, end).strip_edges()
	return "NPC"

func get_dialogue() -> String:
	return str(npc_data.get("dialogue", "..."))
