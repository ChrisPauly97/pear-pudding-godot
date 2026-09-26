## Replays other screens' attacks in networked battles (GID-135): the authority
## records attacks into each state mirror (`BattleNet.record_attack_fx`), and
## every receiving screen — opponent, co-op allies, spectators — lunges a ghost
## of the attacker's panel at its target before adopting the new state. The
## authority uses the same lunge for a remote player's attack on its own screen.
extends RefCounted

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const BattleFx = preload("res://scenes/battle/BattleFx.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")

const BattleNetProtocol = preload("res://game_logic/net/BattleNetProtocol.gd")

var _battle: _BattleScene
## Authority: attack fx queued for the next mirror.
var _pending: Array = []

func _init(battle: _BattleScene) -> void:
	_battle = battle

## Authority: records an attack so the next mirror carries it. Inert outside a
## networked battle. Call before the attack mutates the board (slots empty on death).
func record(attacker_pid: int, attacker: CardInstance, target_pid: int, target: CardInstance) -> void:
	if not (_battle._pvp or _battle._coop_pve or _battle._team_pvp) or not _battle._is_pvp_host():
		return
	var a_slot: int = _battle._state.players[attacker_pid].board.slots.find(attacker)
	if a_slot < 0:
		return
	var t_slot: int = BattleNetProtocol.TARGET_HERO
	if target != null:
		t_slot = _battle._state.players[target_pid].board.slots.find(target)
	_pending.append(BattleNetProtocol.encode_attack_fx(attacker_pid, a_slot, target_pid, t_slot))

## Drains the fx queued since the last mirror.
func take() -> Array:
	var fx: Array = _pending.duplicate()
	_pending.clear()
	return fx

func _visible() -> bool:
	return _battle._fx != null and _battle._local_player_idx >= 0

## Lunges each attack fx against the current (pre-mirror) board. Units not on
## this screen's two board rows (other co-op allies) have no panel and are skipped.
func replay(fx: Array[Dictionary]) -> void:
	if not _visible():
		return
	var players: Array = _battle._state.players
	for e: Dictionary in fx:
		var ap: int = int(e["ap"])
		var tp: int = int(e["tp"])
		if ap < 0 or ap >= players.size() or tp < 0 or tp >= players.size():
			continue
		var a_slots: Array = _battle._state.players[ap].board.slots
		var a_slot: int = int(e["as"])
		if a_slot < 0 or a_slot >= a_slots.size() or a_slots[a_slot] == null:
			continue
		var target: CardInstance = null
		var t_slots: Array = _battle._state.players[tp].board.slots
		var t_slot: int = int(e["ts"])
		if t_slot >= 0 and t_slot < t_slots.size():
			target = t_slots[t_slot] as CardInstance
		lunge(a_slots[a_slot] as CardInstance, ap, target, tp)

## One attack's lunge on this screen (no state change).
func lunge(attacker: CardInstance, attacker_pid: int, target: CardInstance, target_pid: int) -> void:
	if not _visible():
		return
	var me: int = _battle._my_idx()
	var panel: Control = _battle._fx.get_card_panel(attacker, attacker_pid != me)
	var to: Vector2 = _battle._fx.pos_of_hero(target_pid != me)
	var tpanel: Control = _battle._fx.get_card_panel(target, target_pid != me) if target != null else null
	if tpanel != null:
		to = tpanel.get_global_rect().get_center()
	AudioManager.play_sfx("attack")
	ghost_lunge(panel, to, _battle._speed_scale)

## Lunge a floating copy of `panel` at `target_pos` and back: the board
## underneath is re-rendered from the new state straight away, so the ghost
## (not the container-owned panel) carries the motion.
func ghost_lunge(panel: Control, target_pos: Vector2, speed_scale: float = 1.0) -> void:
	if panel == null or not is_instance_valid(panel) or not is_instance_valid(_battle._float_layer):
		return
	var ghost: Control = panel.duplicate() as Control
	if ghost == null:
		return
	var rect: Rect2 = panel.get_global_rect()
	ghost.position = rect.position
	ghost.size = panel.size
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle._float_layer.add_child(ghost)
	var out: Vector2 = rect.position + (target_pos - rect.get_center()) * 0.6
	var tw: Tween = ghost.create_tween()
	tw.tween_property(ghost, "position", out, BattleFx.scaled_duration(0.14, speed_scale)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "position", rect.position, BattleFx.scaled_duration(0.18, speed_scale)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(ghost.queue_free)
