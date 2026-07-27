extends "res://scenes/world/entities/WorldEntityBase.gd"
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

var npc_data: Dictionary = {}

static var _post_mat: StandardMaterial3D
static var _board_mat: StandardMaterial3D
static var _post_mesh: BoxMesh
static var _board_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _post_mat != null:
		return
	_post_mat = unshaded_material(Color(0.45, 0.30, 0.15))
	_board_mat = unshaded_material(Color(0.60, 0.40, 0.18))
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
	add_child(_SpriteRegistry.make_name_label("Bounty Board", Color(1.0, 0.90, 0.4), 1.9, 28, 0.022))

func get_dialogue() -> String:
	return "Contracts are posted daily. Check back each morning."
