## Burial mound entity for GID-065 Skeleton Dig cantrip.
## Spawned in ~10% of chunks; interactive only when player has ≥4 Skeleton-family cards.
extends Node3D

const CantripManager = preload("res://game_logic/world/CantripManager.gd")
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

static var _mound_mat: StandardMaterial3D
static var _mound_mesh: CylinderMesh

static func _ensure_shared_resources() -> void:
	if _mound_mesh != null:
		return
	_mound_mesh = CylinderMesh.new()
	_mound_mesh.top_radius = 0.7
	_mound_mesh.bottom_radius = 1.1
	_mound_mesh.height = 0.35
	_mound_mat = StandardMaterial3D.new()
	_mound_mat.albedo_color = Color(0.38, 0.26, 0.11)
	_mound_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

var _mound_id: String = ""
var _dug: bool = false

func _ready() -> void:
	_ensure_shared_resources()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _mound_mesh
	mesh_inst.material_override = _mound_mat
	mesh_inst.position = Vector3(0.0, 0.175, 0.0)
	add_child(mesh_inst)

func init_from_data(data: Dictionary) -> void:
	_mound_id = str(data.get("id", ""))
	_dug = SceneManager.save_manager.dug_mounds.has(_mound_id)
	if _dug:
		visible = false

func interact() -> void:
	if _dug:
		GameBus.hud_message_requested.emit("This mound has already been dug.")
		return
	var sm := SceneManager.save_manager
	var template_ids: Array[String] = sm.get_deck_template_ids()
	if not CantripManager.is_available("skeleton_dig", template_ids):
		GameBus.hud_message_requested.emit("Skeleton Dig requires 4+ Skeleton-family cards in your deck.")
		return
	var current_time: float = Time.get_unix_time_from_system()
	if CantripManager.is_on_cooldown("skeleton_dig", sm.cantrip_cooldowns, current_time):
		var remaining: int = CantripManager.cooldown_remaining("skeleton_dig", sm.cantrip_cooldowns, current_time)
		GameBus.hud_message_requested.emit("Skeleton Dig on cooldown (%ds)." % remaining)
		return

	# Seeded rewards — same mound always gives the same loot on first dig
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(_mound_id)) % 0x7FFFFFFF

	var coins: int = rng.randi_range(10, 30)
	sm.add_coins(coins)

	if rng.randf() < 0.6:
		var all_ids: Array[String] = CardRegistry.get_all_ids()
		if not all_ids.is_empty():
			var card_id: String = all_ids[rng.randi() % all_ids.size()]
			var rarity: String = CardDropUtil.roll_rarity(1)
			rarity = CardDropUtil.effective_rarity(card_id, rarity)
			var stats: Dictionary = CardDropUtil.roll_stats(card_id, rarity)
			sm.grant_card_reward(card_id, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
	else:
		var essence_amount: int = rng.randi_range(1, 3)
		sm.essence += essence_amount
		sm.mark_dirty()

	_dug = true
	if not sm.dug_mounds.has(_mound_id):
		sm.dug_mounds.append(_mound_id)
	sm.cantrip_cooldowns["skeleton_dig"] = current_time + CantripManager.get_cooldown("skeleton_dig")
	sm.mark_dirty()

	GameBus.hud_message_requested.emit("Dug up %d coins from the burial mound!" % coins)
	GameBus.cantrip_used.emit("skeleton_dig")

	visible = false
