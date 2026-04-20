extends Node3D

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")

var enemy_data: Dictionary = {}
var _alive: bool = true
var _is_boss: bool = false

# Shared across all enemy instances — created once
static var _body_mat: StandardMaterial3D
static var _dark_mat: StandardMaterial3D
static var _body_mesh: BoxMesh
static var _head_mesh: BoxMesh
static var _leg_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _body_mat != null:
		return
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.70, 0.12, 0.12)
	_body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dark_mat = StandardMaterial3D.new()
	_dark_mat.albedo_color = Color(0.45, 0.05, 0.05)
	_dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body_mesh = BoxMesh.new()
	_body_mesh.size = Vector3(0.5, 0.55, 0.3)
	_head_mesh = BoxMesh.new()
	_head_mesh.size = Vector3(0.35, 0.35, 0.35)
	_leg_mesh = BoxMesh.new()
	_leg_mesh.size = Vector3(0.22, 0.5, 0.22)

func _ready() -> void:
	_ensure_shared_resources()

	# Re-use the existing MeshInstance3D (so visibility range from ChunkRenderer sticks)
	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		body.mesh = _body_mesh
		body.material_override = _body_mat
		body.position = Vector3(0.0, 0.275, 0.0)

	# Head
	var head := _make_mi(_head_mesh, _dark_mat)
	head.position = Vector3(0.0, 0.75, 0.0)
	add_child(head)

	# Legs
	var left_leg := _make_mi(_leg_mesh, _dark_mat)
	left_leg.position = Vector3(-0.15, -0.25, 0.0)
	add_child(left_leg)

	var right_leg := _make_mi(_leg_mesh, _dark_mat)
	right_leg.position = Vector3(0.15, -0.25, 0.0)
	add_child(right_leg)

	if _is_boss:
		_apply_boss_visual()

static func _make_mi(mesh: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi

func init_from_data(data: Dictionary) -> void:
	enemy_data = data
	_alive = data.get("alive", true)
	var etype: String = str(data.get("enemy_type", ""))
	if etype != "":
		_is_boss = EnemyRegistry.get_is_boss(etype)

# Called by WorldScene when player interacts with this enemy.
func engage() -> void:
	if not _alive:
		return
	_alive = false
	enemy_data["alive"] = false
	var edata := enemy_data.duplicate()
	var etype: String = str(edata.get("enemy_type", "undead_basic"))
	if not edata.has("enemy_deck"):
		edata["enemy_deck"] = EnemyRegistry.get_deck(etype)
	edata["is_boss"] = EnemyRegistry.get_is_boss(etype)
	edata["boss_hp"] = EnemyRegistry.get_boss_hp(etype)
	edata["phase2_deck"] = EnemyRegistry.get_phase2_deck(etype)
	AudioManager.play_sfx("enemy_engage")
	GameBus.enemy_engaged.emit(edata)
	queue_free()

func mark_defeated() -> void:
	_alive = false
	queue_free()

func _apply_boss_visual() -> void:
	scale = Vector3(1.3, 1.3, 1.3)
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.85, 0.65, 0.05)
	gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dark_gold_mat := StandardMaterial3D.new()
	dark_gold_mat.albedo_color = Color(0.55, 0.40, 0.02)
	dark_gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for child in get_children():
		var mi := child as MeshInstance3D
		if mi:
			mi.material_override = gold_mat
	var body: MeshInstance3D = find_child("MeshInstance3D", true, false) as MeshInstance3D
	if body:
		body.material_override = dark_gold_mat
