## Burial mound entity for GID-065 Skeleton Dig cantrip.
## Spawned in ~10% of chunks; interactive only when player has ≥4 Skeleton-family cards.
extends Node3D

const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const _WEB = preload("res://scenes/world/entities/WorldEntityBase.gd")

const CantripManager = preload("res://game_logic/world/CantripManager.gd")
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

static var _mound_mat: StandardMaterial3D
static var _mound_mesh: CylinderMesh

var _mound_id: String = ""
var _dug: bool = false

static func _ensure_shared_resources() -> void:
	if _mound_mesh != null:
		return
	_mound_mesh = CylinderMesh.new()
	_mound_mesh.top_radius = 0.7
	_mound_mesh.bottom_radius = 1.1
	_mound_mesh.height = 0.35
	_mound_mat = _WEB.unshaded_material(Color(0.38, 0.26, 0.11))

func _ready() -> void:
	var tex: Texture2D = _SpriteRegistry.burial_mound_texture()
	if tex != null:
		var sprite := Sprite3D.new()
		_SpriteRegistry.setup_sprite(sprite, tex)  # drawn at its height in px (tools/generate_sprites.py)
		_SpriteRegistry.apply_billboard_flags(sprite)
		add_child(sprite)
		return
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
	if not sm.has_learned(_UnlockLadder.FEAT_DIG):
		GameBus.hud_message_requested.emit(_UnlockLadder.locked_message(_UnlockLadder.FEAT_DIG))
		return
	var current_time: float = Time.get_unix_time_from_system()
	var why: String = CantripManager.use_blocker("skeleton_dig", sm.get_deck_template_ids(), sm.cantrip_cooldowns,
			current_time)
	if why != "":
		GameBus.hud_message_requested.emit(why)
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
			sm.grant_card_reward(card_id, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)),
					int(stats.get("cost", -1)))
	else:
		var essence_amount: int = rng.randi_range(1, 3)
		sm.essence += essence_amount
		sm.mark_dirty()

	_dug = true
	if not sm.dug_mounds.has(_mound_id):
		sm.dug_mounds.append(_mound_id)
		sm.quests.progress_event("use_skill", "skeleton_dig")
	sm.cantrip_cooldowns["skeleton_dig"] = current_time + CantripManager.get_cooldown("skeleton_dig")
	sm.mark_dirty()

	GameBus.hud_message_requested.emit("Dug up %d coins from the burial mound!" % coins)
	GameBus.cantrip_used.emit("skeleton_dig")

	visible = false
