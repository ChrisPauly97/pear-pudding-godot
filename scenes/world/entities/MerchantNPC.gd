extends "res://scenes/world/entities/WorldEntityBase.gd"

var npc_data: Dictionary = {}
var _is_traveling: bool = false

static var _body_mat: StandardMaterial3D
static var _head_mat: StandardMaterial3D
static var _body_mesh: BoxMesh
static var _head_mesh: BoxMesh
static var _leg_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _body_mat != null:
		return
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.75, 0.62, 0.1)   # golden robe
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

	var body_mat: StandardMaterial3D
	if _is_traveling:
		body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.45, 0.15, 0.65)  # violet robe
		body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		body_mat = _body_mat

	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		body.mesh = _body_mesh
		body.material_override = body_mat
		body.position = Vector3(0.0, 0.45, 0.0)

	var head := _make_mi(_head_mesh, _head_mat)
	head.position = Vector3(0.0, 1.2, 0.0)
	add_child(head)

	var left_leg := _make_mi(_leg_mesh, body_mat)
	left_leg.position = Vector3(-0.23, -0.4, 0.0)
	add_child(left_leg)

	var right_leg := _make_mi(_leg_mesh, body_mat)
	right_leg.position = Vector3(0.23, -0.4, 0.0)
	add_child(right_leg)

	_add_name_label()

func init_from_data(data: Dictionary) -> void:
	npc_data = data
	_is_traveling = bool(data.get("is_traveling", false))

func _add_name_label() -> void:
	var lbl := Label3D.new()
	lbl.text = "Traveling Merchant" if _is_traveling else "Merchant"
	lbl.font_size = 32
	lbl.pixel_size = 0.025
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 2.0, 0.0)
	lbl.modulate = Color(0.85, 0.6, 1.0) if _is_traveling else Color(1.0, 0.85, 0.1)
	add_child(lbl)

func get_dialogue() -> String:
	if _is_traveling:
		return "Rare wares, straight from the ends of the world!"
	return "Welcome, traveller! Browse my wares."
