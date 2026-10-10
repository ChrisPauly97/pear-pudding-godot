## Potions: their HUD buttons (the hero power is gone — active skills are
## technique cards since GID-179), the two consumable quick slots
## (Q / E, shared cooldown — game_logic/battle/QuickSlots.gd, TID-542), and
## applying each effect.
##
## A child of BattleScene (`BattleScene.consumables`), created by `_ensure_battle_modules()`.
## Battle state stays on the scene. Reach it as `_battle.<name>`, and use
## `_battle.add_child` rather than a bare `add_child`.
extends Node

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const BattleNetProtocol = preload("res://game_logic/net/BattleNetProtocol.gd")
const _QuickSlots = preload("res://game_logic/battle/QuickSlots.gd")
const _LegendaryPotions = preload("res://game_logic/battle/LegendaryPotions.gd")
const _PotionEffects = preload("res://game_logic/battle/PotionEffects.gd")

var quick: _QuickSlots = _QuickSlots.new()
## Legendary potions refill per battle: this module is rebuilt with each BattleScene.
var legendary: _LegendaryPotions = _LegendaryPotions.new()
var quick_btns: Array[Button] = []
var _battle: _BattleScene


func _init(battle: _BattleScene) -> void:
	_battle = battle


func _add_potion_button() -> void:
	if _battle._state.puzzle_mode or _battle._state.scripted_battle:
		return
	for i: int in _QuickSlots.SLOTS:
		quick_btns.append(_UiUtil.make_button("", Vector2(_battle._vh * 0.18, _battle._vh * 0.05),
				int(_battle._font(0.017)), _on_quick_pressed.bind(i), _battle.get_node("SidePanel")))


## Relabels the quick-slot buttons: slotted potion, count, key, cooldown left.
## Hidden when a slot has nothing to drink; disabled off-turn or on cooldown.
func _refresh_potion_button() -> void:
	if quick_btns.is_empty():
		return
	var sm := SceneManager.save_manager
	var ids: Array[String] = _QuickSlots.resolve(sm.quick_slots, sm.potions)
	var rtm: bool = _is_realtime()
	var turn: int = _my_turn_number()
	var ready: bool = quick.is_ready(turn, rtm)
	var left: int = quick.remaining(turn, rtm)
	var my_turn: bool = _battle._state.current_player_idx == _battle._my_idx()
	for i: int in quick_btns.size():
		var btn: Button = quick_btns[i]
		var id: String = ids[i]
		btn.visible = id != ""
		if id == "":
			continue
		var info: Dictionary = GardenDefs.POTIONS[id]
		var key: String = "" if OS.has_feature("android") else "[%s] " % _QuickSlots.KEY_LABELS[i]
		var wait: String = "" if ready else "  (%d%s)" % [left, "s" if rtm else ""]
		var sip_ok: bool = legendary.can_sip(id)
		var count: String = ("∞" if sip_ok else "sipped") if GardenDefs.is_legendary(id) \
				else "×%d" % int(sm.potions.get(id, 0))
		btn.text = "%s%s %s%s" % [key, str(info.get("display_name", id)), count, wait]
		btn.tooltip_text = str(info.get("description", ""))
		btn.disabled = not ready or not my_turn or not sip_ok


func _on_quick_pressed(slot: int) -> void:
	var rtm: bool = _is_realtime()
	if not quick.is_ready(_my_turn_number(), rtm) or _battle._state.current_player_idx != _battle._my_idx():
		return
	var sm := SceneManager.save_manager
	var id: String = _QuickSlots.resolve(sm.quick_slots, sm.potions)[slot]
	if id != "":
		_apply_potion_effect(id)


## Q / E drink from the quick slots (the buttons are the touch path).
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var slot: int = _QuickSlots.KEYS.find(k.keycode)
	if slot >= 0 and slot < quick_btns.size():
		_on_quick_pressed(slot)
		get_viewport().set_input_as_handled()


## Real-time battles count the cooldown in seconds (BattleRealtime._process).
func tick_quick(delta: float) -> void:
	var before: int = quick.remaining(0, true)
	quick.tick(delta)
	if quick.remaining(0, true) != before:
		_refresh_potion_button()


func _is_realtime() -> bool:
	return _battle.realtime != null and _battle.realtime.is_active()


func _my_turn_number() -> int:
	var turns: Array[int] = _battle._state.player_turn_numbers
	var idx: int = _battle._my_idx()
	return turns[idx] if idx < turns.size() else 0


func _apply_potion_effect(potion_id: String) -> void:
	var sm := SceneManager.save_manager
	if GardenDefs.is_legendary(potion_id):
		if not legendary.can_sip(potion_id) or int(sm.potions.get(potion_id, 0)) <= 0:
			return
		legendary.mark_sipped(potion_id)
	elif not sm.garden.remove_potions(potion_id, 1):
		return
	var cd: float = _battle.realtime.rt.tune.get_f("potion_cooldown") if _is_realtime() else 0.0
	quick.start(_my_turn_number(), cd)
	if _battle._is_pvp_client():
		# Inventory consumed locally; the host applies the state effect to players[1].
		_battle._send_intent(BattleNetProtocol.encode_potion(potion_id))
		GameBus.potion_used.emit(potion_id)
		_refresh_potion_button()
		return
	var player: PlayerState = _battle._state.players[_battle._my_idx()]
	var snap_pot := _battle._fx.snapshot()
	match potion_id:
		"clarity_brew":
			player.draw_card()
			player.draw_card()
		_LegendaryPotions.PEAR_PUDDING:
			_LegendaryPotions.apply_pear_pudding(player.hero)
			_battle._fx.spawn_float_labels(snap_pot)
			_battle._fx.spawn_float_label(_battle._fx.pos_of_hero(false), "Pear Pudding!", Color(1.0, 0.85, 0.35))
		_:
			if _PotionEffects.apply_hero(potion_id, player.hero):
				_battle._fx.spawn_float_labels(snap_pot)
				var ft: Dictionary = _PotionEffects.FLOATS.get(potion_id, {})
				var col: Color = ft.get("color", Color.WHITE)
				_battle._fx.spawn_float_label(_battle._fx.pos_of_hero(false), str(ft.get("text", "")), col)
	GameBus.potion_used.emit(potion_id)
	_battle._refresh_all()
	_refresh_potion_button()
	if _battle._pvp:
		_battle._check_game_over()
