extends "res://scenes/world/entities/WorldEntityBase.gd"

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const TextureGen = preload("res://game_logic/TextureGen.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")

## Awareness/pursuit state for tracking enemies (GID-113). IDLE = hasn't
## noticed the player; ALERTED = noticed, brief reaction beat before giving
## chase (TID-422 hooks its "fair warning" indicator here); CHASING = actively
## closing the distance. TID-423 owns breaking pursuit back to IDLE.
enum AlertState { IDLE, ALERTED, CHASING }
const _ALERT_REACTION_TIME: float = 0.4

var enemy_data: Dictionary = {}
var _alive: bool = true
var _is_boss: bool = false
var _is_roaming_boss: bool = false
var _tracking: bool = false
var _alert_state: int = AlertState.IDLE
var _alert_timer: float = 0.0
var _player_ref: CharacterBody3D = null

func _ready() -> void:
	var etype: String = str(enemy_data.get("enemy_type", ""))
	var sprite: Sprite3D = _SpriteRegistry.make_billboard(_SpriteRegistry.enemy_texture(etype, _is_roaming_boss, _is_boss), TextureGen.enemy(_is_roaming_boss, _is_boss), _SpriteRegistry.enemy_world_height(etype, _is_roaming_boss, _is_boss))
	add_child(sprite)
	if _is_roaming_boss:
		scale = Vector3(1.5, 1.5, 1.5)
	elif _is_boss:
		scale = Vector3(1.3, 1.3, 1.3)
	if _tracking:
		_setup_proximity_area()
		_setup_awareness_area()

## Pursuit movement and awareness are single-player only for now — co-op
## enemies stay static (documented scoping decision, see
## docs/agent/enemies-and-npcs.md).
func _process(delta: float) -> void:
	if not _alive or not _tracking:
		return
	if NetworkManager.is_active():
		return
	if not SceneManager.can_proximity_engage():
		return
	if _alert_state == AlertState.ALERTED:
		_alert_timer += delta
		if _alert_timer >= _ALERT_REACTION_TIME:
			_alert_state = AlertState.CHASING
	elif _alert_state == AlertState.CHASING:
		_chase_player(delta)

func _chase_player(delta: float) -> void:
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not is_instance_valid(_player_ref):
		return
	var to_player: Vector3 = _player_ref.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist < 0.05:
		return
	var step: float = min(IsoConst.TRACKING_SPEED * delta, dist)
	position += to_player.normalized() * step

func init_from_data(data: Dictionary) -> void:
	enemy_data = data
	_alive = data.get("alive", true)
	_is_roaming_boss = bool(data.get("is_roaming_boss", false))
	_tracking = bool(data.get("tracking", false))
	var etype: String = str(data.get("enemy_type", ""))
	if etype != "":
		_is_boss = EnemyRegistry.get_is_boss(etype)
	_add_difficulty_pip(etype)

## Async: shows a brief "!" alert beat before the battle transition, instead
## of vanishing into the fight with no warning (TID-427). `_alive` flips to
## false first, same as before, so re-entry (another interact/proximity hit
## while the beat is playing) is still a safe no-op.
func engage() -> void:
	if not _alive:
		return
	# Ambush classification (GID-113): IDLE covers both wanderers (never
	# alerted at all) and tracking enemies caught before they noticed the
	# player; CHASING means the enemy caught the player mid-pursuit (TID-422).
	# ALERTED (mid-reaction) is neither — a neutral fight.
	var player_ambush: bool = _alert_state == AlertState.IDLE
	var enemy_ambush: bool = _alert_state == AlertState.CHASING
	_alive = false
	enemy_data["alive"] = false
	_show_alert()
	AudioManager.play_sfx("enemy_alert")
	await get_tree().create_timer(0.4, false).timeout
	var edata := enemy_data.duplicate()
	edata["player_ambush"] = player_ambush
	edata["enemy_ambush"] = enemy_ambush
	var etype: String = str(edata.get("enemy_type", "undead_basic"))
	if not edata.has("enemy_deck"):
		edata["enemy_deck"] = EnemyRegistry.get_deck(etype)
	edata["is_boss"] = EnemyRegistry.get_is_boss(etype)
	edata["boss_hp"] = EnemyRegistry.get_boss_hp(etype)
	edata["phase2_deck"] = EnemyRegistry.get_phase2_deck(etype)
	AudioManager.play_sfx("enemy_engage")
	GameBus.enemy_engaged.emit(edata)
	queue_free()

func _show_alert() -> void:
	var lbl := Label3D.new()
	lbl.text = "!"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = Color(1.0, 0.15, 0.15)
	lbl.font_size = 56
	lbl.pixel_size = 0.01
	lbl.position = Vector3(0.0, 1.9, 0.0)
	lbl.scale = Vector3.ZERO
	add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func mark_defeated() -> void:
	_alive = false
	queue_free()

func _setup_proximity_area() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = IsoConst.AUTO_BATTLE_RANGE
	shape.shape = sphere
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _on_body_entered(body: Node3D) -> void:
	if not _alive or not _tracking:
		return
	if not body is CharacterBody3D:
		return
	if not SceneManager.can_proximity_engage():
		return
	var eid: String = str(enemy_data.get("id", ""))
	if eid != "" and SceneManager.save_manager.is_enemy_defeated(eid):
		return
	engage()

func _setup_awareness_area() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = IsoConst.ENEMY_AWARENESS_RANGE
	shape.shape = sphere
	area.add_child(shape)
	area.body_entered.connect(_on_awareness_entered)
	add_child(area)

func _on_awareness_entered(body: Node3D) -> void:
	if not _alive or not _tracking or _alert_state != AlertState.IDLE:
		return
	if not body is CharacterBody3D:
		return
	if NetworkManager.is_active():
		return
	if not SceneManager.can_proximity_engage():
		return
	var eid: String = str(enemy_data.get("id", ""))
	if eid != "" and SceneManager.save_manager.is_enemy_defeated(eid):
		return
	_alert_state = AlertState.ALERTED
	_alert_timer = 0.0

func _add_difficulty_pip(enemy_type: String) -> void:
	if enemy_type == "":
		return
	var tier: int = EnemyRegistry.get_difficulty_tier(enemy_type)
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	var pip_char: String = "◆"
	if _is_boss or _is_roaming_boss:
		lbl.text = "★ BOSS"
		lbl.modulate = Color(1.0, 0.6, 0.0)
	else:
		lbl.text = pip_char.repeat(tier)
		match tier:
			1: lbl.modulate = Color(0.5, 1.0, 0.5)
			2: lbl.modulate = Color(1.0, 1.0, 0.4)
			3: lbl.modulate = Color(1.0, 0.5, 0.2)
			_: lbl.modulate = Color(1.0, 0.2, 0.2)
	lbl.font_size = 24
	lbl.pixel_size = 0.004
	lbl.position = Vector3(0.0, 1.4, 0.0)
	add_child(lbl)
