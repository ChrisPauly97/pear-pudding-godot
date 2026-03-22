extends Node3D

var enemy_data: Dictionary = {}
var _alive: bool = true
var _tracking: bool = true
const TRACKING_SPEED: float = 2.5
const AUTO_BATTLE_RANGE: float = 1.5
const AUTO_BATTLE_RANGE_SQ: float = AUTO_BATTLE_RANGE * AUTO_BATTLE_RANGE
var _engaged: bool = false
var _player_ref: WeakRef = WeakRef.new()

func _ready() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.70, 0.12, 0.12)
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.45, 0.05, 0.05)
	dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Re-use the existing MeshInstance3D (so visibility range from ChunkRenderer sticks)
	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.55, 0.3)
		body.mesh = bm
		body.material_override = body_mat
		body.position = Vector3(0.0, 0.275, 0.0)

	# Head
	var head := _make_box(Vector3(0.35, 0.35, 0.35), dark_mat)
	head.position = Vector3(0.0, 0.75, 0.0)
	add_child(head)

	# Legs
	var left_leg := _make_box(Vector3(0.22, 0.5, 0.22), dark_mat)
	left_leg.position = Vector3(-0.15, -0.25, 0.0)
	add_child(left_leg)

	var right_leg := _make_box(Vector3(0.22, 0.5, 0.22), dark_mat)
	right_leg.position = Vector3(0.15, -0.25, 0.0)
	add_child(right_leg)

func _make_box(size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	return mi

func set_player(player: Node3D) -> void:
	_player_ref = weakref(player)

func init_from_data(data: Dictionary) -> void:
	enemy_data = data
	_alive = data.get("alive", true)
	_tracking = data.get("tracking", true)

func _process(_delta: float) -> void:
	if not _alive or _engaged:
		return

	var player: Node3D = _player_ref.get_ref() as Node3D
	if player == null:
		return

	# Use squared distance to skip sqrt
	var dx: float = position.x - player.position.x
	var dz: float = position.z - player.position.z
	var dist_sq: float = dx * dx + dz * dz

	if dist_sq <= AUTO_BATTLE_RANGE_SQ:
		_engaged = true
		enemy_data["alive"] = false
		_alive = false
		var edata := enemy_data.duplicate()
		# Ensure deck is present — fall back to registry if data pre-dates this system
		if not edata.has("enemy_deck"):
			var etype: String = str(edata.get("enemy_type", "undead_basic"))
			edata["enemy_deck"] = EnemyRegistry.get_deck(etype)
		GameBus.enemy_engaged.emit(edata)
		queue_free()
		return

func mark_defeated() -> void:
	_alive = false
	queue_free()
