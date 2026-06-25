extends "res://scenes/world/entities/WorldEntityBase.gd"

var npc_data: Dictionary = {}

static var _post_mat: StandardMaterial3D
static var _board_mat: StandardMaterial3D
static var _post_mesh: BoxMesh
static var _board_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _post_mat != null:
		return
	_post_mat = StandardMaterial3D.new()
	_post_mat.albedo_color = Color(0.45, 0.30, 0.15)
	_post_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_board_mat = StandardMaterial3D.new()
	_board_mat.albedo_color = Color(0.60, 0.40, 0.18)
	_board_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_post_mesh = BoxMesh.new()
	_post_mesh.size = Vector3(0.12, 1.4, 0.12)
	_board_mesh = BoxMesh.new()
	_board_mesh.size = Vector3(0.85, 0.55, 0.08)

func _ready() -> void:
	add_to_group("interactable")
	_ring = build_highlight_ring(self, 0.6)
	_ensure_shared_resources()

	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		body.mesh = _post_mesh
		body.material_override = _post_mat
		body.position = Vector3(0.0, 0.7, 0.0)

	var board := _make_mi(_board_mesh, _board_mat)
	board.position = Vector3(0.0, 1.3, 0.0)
	add_child(board)

	_add_label()

func init_from_data(data: Dictionary) -> void:
	npc_data = data

func _add_label() -> void:
	var lbl := Label3D.new()
	lbl.text = "Bounty Board"
	lbl.font_size = 28
	lbl.pixel_size = 0.022
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 1.9, 0.0)
	lbl.modulate = Color(1.0, 0.90, 0.4)
	add_child(lbl)

func get_dialogue() -> String:
	return "Contracts are posted daily. Check back each morning."
