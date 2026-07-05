extends "res://scenes/world/entities/WorldEntityBase.gd"

var mailbox_data: Dictionary = {}

static var _post_mat: StandardMaterial3D
static var _box_mat: StandardMaterial3D
static var _flag_mat: StandardMaterial3D
static var _post_mesh: BoxMesh
static var _box_mesh: BoxMesh
static var _flag_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _post_mat != null:
		return
	_post_mat = StandardMaterial3D.new()
	_post_mat.albedo_color = Color(0.35, 0.24, 0.14)
	_post_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box_mat = StandardMaterial3D.new()
	_box_mat.albedo_color = Color(0.62, 0.12, 0.10)
	_box_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flag_mat = StandardMaterial3D.new()
	_flag_mat.albedo_color = Color(0.85, 0.72, 0.15)
	_flag_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_post_mesh = BoxMesh.new()
	_post_mesh.size = Vector3(0.10, 1.1, 0.10)
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3(0.5, 0.35, 0.32)
	_flag_mesh = BoxMesh.new()
	_flag_mesh.size = Vector3(0.06, 0.22, 0.03)

func _ready() -> void:
	add_to_group("interactable")
	_ring = build_highlight_ring(self, 0.55)
	_ensure_shared_resources()

	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		body.mesh = _post_mesh
		body.material_override = _post_mat
		body.position = Vector3(0.0, 0.55, 0.0)

	var box := _make_mi(_box_mesh, _box_mat)
	box.position = Vector3(0.0, 1.05, 0.0)
	add_child(box)

	var flag := _make_mi(_flag_mesh, _flag_mat)
	flag.position = Vector3(0.28, 1.15, 0.0)
	add_child(flag)

	_add_label()

func init_from_data(data: Dictionary) -> void:
	mailbox_data = data

func _add_label() -> void:
	var lbl := Label3D.new()
	lbl.text = "Mailbox"
	lbl.font_size = 28
	lbl.pixel_size = 0.022
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 1.6, 0.0)
	lbl.modulate = Color(1.0, 0.85, 0.6)
	add_child(lbl)

func get_dialogue() -> String:
	return "Overflow rewards land here when your bag is full."
