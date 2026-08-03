extends "res://scenes/world/entities/WorldEntityBase.gd"

const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const TextureGen = preload("res://game_logic/TextureGen.gd")
const _SpriteRegistry = preload("res://game_logic/SpriteRegistry.gd")
const _EnemyAlertState = preload("res://game_logic/world/EnemyAlertState.gd")

const _ALERT_REACTION_TIME: float = 0.4
const _GIVEUP_HOLD_TIME: float = 2.0

var enemy_data: Dictionary = {}
var _alive: bool = true
var _is_boss: bool = false
var _is_roaming_boss: bool = false
var _tracking: bool = false
## Awareness/pursuit state for tracking enemies (GID-113): the transition
## rules themselves live in the pure `EnemyAlertState` helper (unit-tested in
## isolation, TID-424); this node just holds the current value/timers and
## applies whatever the helper returns.
var _alert_state: int = _EnemyAlertState.State.IDLE
var _alert_timer: float = 0.0
var _giveup_timer: float = 0.0
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
	if _alert_state == _EnemyAlertState.State.IDLE:
		return
	var player: CharacterBody3D = _resolve_player()
	if not is_instance_valid(player):
		return
	var dist: float = _flat_distance_to(player)
	if _update_giveup(delta, dist):
		return
	if _alert_state == _EnemyAlertState.State.ALERTED:
		_tick_reaction(delta)
	elif _alert_state == _EnemyAlertState.State.CHASING:
		_chase_player(delta, player, dist)

func _resolve_player() -> CharacterBody3D:
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody3D
	return _player_ref

func _flat_distance_to(player: CharacterBody3D) -> float:
	var d: Vector3 = player.global_position - global_position
	d.y = 0.0
	return d.length()

func _tick_reaction(delta: float) -> void:
	var result: Dictionary = _EnemyAlertState.tick_reaction(
		_alert_state, _alert_timer, delta, _ALERT_REACTION_TIME)
	_alert_state = int(result["state"])
	_alert_timer = float(result["alert_timer"])

func _chase_player(delta: float, player: CharacterBody3D, dist: float) -> void:
	if dist < 0.05:
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var step: float = min(IsoConst.TRACKING_SPEED * delta, dist)
	position += to_player.normalized() * step

## Breaks pursuit (TID-423): once ALERTED or CHASING, a sustained distance
## beyond ENEMY_GIVEUP_RANGE (not a single-frame spike, to avoid flicker at
## the boundary) reverts to IDLE — stopping movement, clearing the alert
## timer, and re-arming TID-421's ambush bonus for the next approach.
## Returns true if the enemy just gave up this frame (caller should skip the
## rest of its state handling — there's nothing left to tick).
func _update_giveup(delta: float, dist: float) -> bool:
	var result: Dictionary = _EnemyAlertState.tick_giveup(
		_alert_state, _giveup_timer, delta, dist, IsoConst.ENEMY_GIVEUP_RANGE, _GIVEUP_HOLD_TIME)
	_alert_state = int(result["state"])
	_giveup_timer = float(result["giveup_timer"])
	if bool(result["gave_up"]):
		_alert_timer = 0.0
		_show_giveup()
		return true
	return false

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
	var ambush: Dictionary = _EnemyAlertState.classify_ambush(_alert_state)
	var player_ambush: bool = bool(ambush["player_ambush"])
	var enemy_ambush: bool = bool(ambush["enemy_ambush"])
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

## Give-up relief beat (TID-423): mirrors _show_alert() but a fading gray
## "?" instead of a popping-in red "!" — the enemy losing interest reads
## differently from it noticing you.
func _show_giveup() -> void:
	var lbl := Label3D.new()
	lbl.text = "?"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = Color(0.75, 0.75, 0.75, 1.0)
	lbl.font_size = 48
	lbl.pixel_size = 0.01
	lbl.position = Vector3(0.0, 1.9, 0.0)
	add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

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
	if not _alive or not _tracking or _alert_state != _EnemyAlertState.State.IDLE:
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
	var dist: float = _flat_distance_to(body as CharacterBody3D)
	var new_state: int = _EnemyAlertState.check_awareness(_alert_state, dist, IsoConst.ENEMY_AWARENESS_RANGE)
	if new_state == _alert_state:
		return
	_alert_state = new_state
	_alert_timer = 0.0
	# Fair-warning telegraph (TID-422): same "!" beat engage() uses, reused
	# here so the player has a visible/audible cue the moment they're
	# spotted, before the chase even starts. World-space billboard + SFX —
	# no keyboard/touch-only signal, satisfies Mobile/Desktop parity.
	_show_alert()
	AudioManager.play_sfx("enemy_alert")

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
