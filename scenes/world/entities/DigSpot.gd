extends Node3D

const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

static var _dig_mat: StandardMaterial3D
static var _marker_mat: StandardMaterial3D
static var _body_mesh: BoxMesh
static var _stake_mesh: BoxMesh

static func _ensure_shared_resources() -> void:
	if _body_mesh != null:
		return
	_body_mesh = BoxMesh.new()
	_body_mesh.size = Vector3(0.5, 0.5, 0.5)
	_stake_mesh = BoxMesh.new()
	_stake_mesh.size = Vector3(0.06, 0.8, 0.06)
	_dig_mat = StandardMaterial3D.new()
	_dig_mat.albedo_color = Color(0.55, 0.35, 0.10)   # brown earth
	_dig_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.albedo_color = Color(0.90, 0.75, 0.10)  # gold marker
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

var _site_x: int = 0
var _site_z: int = 0

func _ready() -> void:
	_ensure_shared_resources()
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	body.material_override = _dig_mat
	body.position = Vector3(0.0, 0.25, 0.0)
	add_child(body)
	# Gold stake marker standing above the mound
	var stake := MeshInstance3D.new()
	stake.mesh = _stake_mesh
	stake.material_override = _marker_mat
	stake.position = Vector3(0.0, 0.9, 0.0)
	add_child(stake)

func init_from_data(data: Dictionary) -> void:
	_site_x = int(data.get("site_x", 0))
	_site_z = int(data.get("site_z", 0))

func dig() -> void:
	var sm := SceneManager.save_manager
	if sm.active_treasure.is_empty() or bool(sm.active_treasure.get("completed", false)):
		return
	var rng := RandomNumberGenerator.new()
	var coins: int = rng.randi_range(50, 200)
	sm.add_coins(coins)
	var all_ids: Array[String] = []
	all_ids.assign(CardRegistry.get_all_ids())
	var card_id: String = all_ids[rng.randi() % all_ids.size()]
	var rarity: String = CardDropUtil.roll_rarity(3)
	rarity = CardDropUtil.effective_rarity(card_id, rarity)
	var stats: Dictionary = CardDropUtil.roll_stats(card_id, rarity)
	sm.grant_card_reward(card_id, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
	sm.complete_treasure(coins, card_id)
	queue_free()
