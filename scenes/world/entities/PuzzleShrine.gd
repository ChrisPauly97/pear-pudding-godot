extends Node3D

var _puzzle_id: String = ""
var _player: Node3D = null

static var _shrine_mat: StandardMaterial3D
static var _shrine_mesh: PrismMesh

static func _ensure_shared_resources() -> void:
	if _shrine_mat != null:
		return
	_shrine_mat = StandardMaterial3D.new()
	_shrine_mat.albedo_color = Color(0.3, 0.6, 1.0)
	_shrine_mat.emission_enabled = true
	_shrine_mat.emission = Color(0.2, 0.4, 0.9)
	_shrine_mat.emission_energy_multiplier = 1.2
	_shrine_mesh = PrismMesh.new()
	_shrine_mesh.size = Vector3(0.45, 0.7, 0.45)

func _ready() -> void:
	_ensure_shared_resources()

	var body := MeshInstance3D.new()
	body.mesh = _shrine_mesh
	body.material_override = _shrine_mat
	body.position = Vector3(0.0, 0.35, 0.0)
	add_child(body)

	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.6, 1.0)
	glow.light_energy = 1.0
	glow.omni_range = 3.0
	glow.position = Vector3(0.0, 0.7, 0.0)
	add_child(glow)

func setup(puzzle_id: String, player_node: Node3D) -> void:
	_puzzle_id = puzzle_id
	_player = player_node
	if SaveManager.is_puzzle_solved(_puzzle_id):
		_dim_solved()

func _dim_solved() -> void:
	if _shrine_mat == null:
		return
	var mat := _shrine_mat.duplicate() as StandardMaterial3D
	mat.albedo_color = Color(0.4, 0.4, 0.5)
	mat.emission = Color(0.1, 0.1, 0.15)
	mat.emission_energy_multiplier = 0.3
	for child in get_children():
		if child is MeshInstance3D:
			child.material_override = mat
		elif child is OmniLight3D:
			child.light_energy = 0.2

func interact() -> void:
	if _puzzle_id.is_empty():
		return
	GameBus.puzzle_requested.emit(_puzzle_id)
