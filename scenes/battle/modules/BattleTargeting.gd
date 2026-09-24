## Placing and aiming: the board drop zone, spell / ally / slot targeting modes and
## their cancel button, and resolving the chosen target.
##
## A child of BattleScene (`BattleScene.targeting`), created by `_ensure_battle_modules()`.
## Battle state stays on the scene. Reach it as `_battle.<name>`, and use
## `_battle.add_child` rather than a bare `add_child`.
extends Node

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const BattleNetProtocol = preload("res://game_logic/net/BattleNetProtocol.gd")

var _battle: _BattleScene


func _init(battle: _BattleScene) -> void:
	_battle = battle


## Wire _player_board_view as the native drop target for hand-card drags.
## Called once from _ready() after the board node is ready.
func _setup_board_drop_zone() -> void:
	# MOUSE_FILTER_STOP is required so the HBoxContainer (which defaults to
	# MOUSE_FILTER_IGNORE) actually receives drop events from hand-card drags.
	_battle._player_board_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_battle._player_board_view.set_drag_forwarding(
		func(_pos: Vector2) -> Variant: return null,
		func(pos: Vector2, data: Variant) -> bool: return _board_can_drop(pos, data),
		func(pos: Vector2, data: Variant) -> void: _board_drop(pos, data)
	)
	# Wire the enemy hero as a drop target for attack drags ({"attacker": card}).
	_battle._enemy_hero_view.set_drag_forwarding(
		func(_pos: Vector2) -> Variant: return null,
		func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary):
				return false
			var drag_data: Dictionary = data as Dictionary
			if not drag_data.has("attacker"):
				return false
			var attacker: CardInstance = drag_data["attacker"] as CardInstance
			if attacker == null or not attacker.can_attack():
				return false
			for ec: CardInstance in _battle._state.players[_battle._opp_idx()].board.get_cards():
				if ec.keywords.has(Keywords.WARD):
					return false
			return true,
		func(_pos: Vector2, data: Variant) -> void:
			if not (data is Dictionary):
				return
			var drag_data: Dictionary = data as Dictionary
			if not drag_data.has("attacker"):
				return
			var attacker: CardInstance = drag_data["attacker"] as CardInstance
			if attacker != null:
				_battle.card_input._attempt_attack(attacker, null)
	)

## Called by Godot when the dragged card is released over _player_board_view.
func _board_drop(local_pos: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var drop_data: Dictionary = data as Dictionary
	if not drop_data.has("card"):
		return
	var played_card: CardInstance = drop_data["card"] as CardInstance
	if played_card == null:
		return
	_battle._hand_drag_card = null
	_battle._refresh_player_board()

	var global_pos: Vector2 = _battle._player_board_view.global_position + local_pos
	var is_enemy_targeted: bool = SpellEffectResolver.ENEMY_TARGETED_EFFECTS.has(played_card.spell_effect)
	var is_friendly_targeted: bool = SpellEffectResolver.FRIENDLY_TARGETED_EFFECTS.has(played_card.spell_effect)
	var is_slot_targeted: bool = SpellEffectResolver.SLOT_TARGETED_EFFECTS.has(played_card.spell_effect)
	var is_ally_targeted: bool = SpellEffectResolver.ALLY_TARGETED_EFFECTS.has(played_card.spell_effect)

	var affordable: bool = _battle._state.players[_battle._my_idx()].can_play(played_card)
	if played_card.card_class == "spell" and is_slot_targeted and affordable:
		_enter_slot_targeting_mode(played_card)
		return

	if (played_card.card_class == "spell" and is_ally_targeted and _battle._coop_pve
			and _battle._state.players[_battle._my_idx()].can_play(played_card)):
		_enter_ally_targeting_mode(played_card)
		return

	if (played_card.card_class == "spell" and (is_enemy_targeted or is_friendly_targeted)
			and _battle._state.players[_battle._my_idx()].can_play(played_card)):
		if is_friendly_targeted and _battle._state.players[_battle._my_idx()].board.get_cards().is_empty():
			return
		if (is_enemy_targeted and played_card.spell_effect != "deal_damage_single"
				and _battle._state.players[_battle._opp_idx()].board.get_cards().is_empty()):
			return
		_enter_targeting_mode(played_card, is_friendly_targeted)
		return

	if played_card.card_class != "spell":
		var target_slot_idx: int = _slot_idx_at_point(global_pos, _battle._player_board_view)
		if target_slot_idx == -1 or _battle._state.players[_battle._my_idx()].board.slots[target_slot_idx] != null:
			return
		if _battle._is_pvp_client():
			var hi: int = _battle._state.players[_battle._my_idx()].hand.find(played_card)
			if hi != -1 and _battle._state.players[_battle._my_idx()].can_play(played_card):
				AudioManager.play_sfx("card_play")
				_battle._fx.haptic(20)
				_battle._send_intent(BattleNetProtocol.encode_play_card_at_slot(hi, target_slot_idx))
				_battle.tutorials._dismiss_battle_tutorial()
			# gdlint:ignore = max-returns
			return
		var from_panel: Control = _battle._hand_panel_node(played_card)
		var from_rect: Rect2 = from_panel.get_global_rect() if from_panel != null else Rect2()
		var to_pos: Vector2 = _battle._slot_panel_center(_battle._player_board_view, target_slot_idx)
		if _do_play_card_at_slot(played_card, _battle._my_idx(), target_slot_idx):
			AudioManager.play_sfx("card_play")
			_battle._fx.haptic(20)
			_battle._hide_hand_panel(from_panel)
			if played_card.emergence_effect != "":
				var snap_em := _battle._fx.snapshot()
				_battle._resolver.resolve_emergence(played_card, _battle._my_idx())
				_battle._fx.trigger_fx(snap_em)
			else:
				_battle.modifiers._apply_weather_to_summoned(played_card, _battle._my_idx())
			await _battle._animate_card_travel(played_card, from_rect, to_pos)
			_battle._refresh_all()
			_battle._check_game_over()
			_battle.tutorials._dismiss_battle_tutorial()
	else:
		# Non-targeted spell: slot doesn't matter. Drag is a deliberate gesture,
		# so no confirm step here (the tap path confirms via _show_cast_confirm).
		_battle.card_input._cast_confirmed_spell(played_card)

## Returns true so Godot highlights the board zone when a hand-card drag is over it.
func _board_can_drop(_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var drop_data: Dictionary = data as Dictionary
	if not drop_data.has("card"):
		return false
	var card: CardInstance = drop_data["card"] as CardInstance
	return card != null and _battle._can_local_act() and _battle._state.players[_battle._my_idx()].can_play(card)

func _show_cancel_btn(label: String = "✕ Cancel", callback: Callable = Callable()) -> void:
	if _battle._cancel_btn != null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var vw: float = vp.x
	_battle._cancel_btn = Button.new()
	_battle._cancel_btn.text = label
	# Big thumb target — it is the only way out of targeting mode on touch.
	_battle._cancel_btn.custom_minimum_size = Vector2(vh * 0.20, vh * 0.07)
	_battle._cancel_btn.add_theme_font_size_override("font_size", _battle._font(0.030))
	_battle._cancel_btn.position = Vector2((vw - vh * 0.20) * 0.5, vh * 0.02)
	var cb: Callable = callback if callback.is_valid() else _hide_cancel_btn
	_battle._cancel_btn.pressed.connect(cb)
	_battle.add_child(_battle._cancel_btn)

func _hide_cancel_btn() -> void:
	if _battle._cancel_btn != null:
		_battle._cancel_btn.queue_free()
		_battle._cancel_btn = null

func _enter_targeting_mode(card: CardInstance, friendly: bool = false) -> void:
	_battle._targeting_spell = card
	_battle._targeting_active = true
	_battle._targeting_friendly = friendly
	_show_cancel_btn("✕ Cancel Spell", _cancel_targeting)
	_battle._refresh_all()

func _cancel_targeting() -> void:
	_battle._targeting_active = false
	_battle._targeting_friendly = false
	_battle._targeting_spell = null
	_hide_cancel_btn()
	_battle._refresh_all()

func _enter_ally_targeting_mode(card: CardInstance) -> void:
	_battle._ally_targeting_spell = card
	_battle._ally_targeting_active = true
	_show_cancel_btn("✕ Cancel Spell", _cancel_ally_targeting)
	_battle.arena._build_coop_arena_layout()

func _cancel_ally_targeting() -> void:
	_battle._ally_targeting_active = false
	_battle._ally_targeting_spell = null
	_hide_cancel_btn()

func _resolve_ally_spell(spell: CardInstance, target_pidx: int) -> void:
	_battle._ally_targeting_active = false
	_battle._ally_targeting_spell = null
	_hide_cancel_btn()
	var tgt: Dictionary = {"pidx": target_pidx}
	if _battle._is_pvp_client():
		var hi: int = _battle._state.players[_battle._my_idx()].hand.find(spell)
		if hi != -1 and _battle._state.players[_battle._my_idx()].can_play(spell):
			AudioManager.play_sfx("card_play")
			_battle._fx.haptic(20)
			_battle._send_intent(BattleNetProtocol.encode_play_spell(hi, tgt))
		return
	if _battle._do_play_card(spell, _battle._my_idx()):
		AudioManager.play_sfx("card_play")
		_battle._fx.haptic(20)
		var snap := _battle._fx.snapshot()
		_battle._resolver.resolve_spell(spell, _battle._my_idx(), tgt)
		_battle._fx.trigger_fx(snap)
	_battle._refresh_all()
	_battle._check_game_over()

func _slot_idx_at_point(point: Vector2, board_view: Node) -> int:
	for child in board_view.get_children():
		if child is Control:
			var ctrl := child as Control
			if ctrl.get_global_rect().has_point(point):
				var idx: int = int(ctrl.get_meta("slot_idx", -1))
				if idx >= 0:
					return idx
	return -1

func _do_play_card_at_slot(card: CardInstance, player_idx: int, slot_idx: int) -> bool:
	var apply_discount: bool = (
		(_battle._battle_weather == "snow" or _battle._battle_weather == "blizzard") and
		not _battle._snow_discount_used[player_idx]
	)
	var ok: bool
	if apply_discount:
		var saved_cost: int = card.cost
		card.cost = maxi(0, card.cost - 1)
		ok = _battle._state.players[player_idx].play_card_at_slot(card, slot_idx)
		card.cost = saved_cost
		if ok:
			_battle._snow_discount_used[player_idx] = true
	else:
		ok = _battle._state.players[player_idx].play_card_at_slot(card, slot_idx)
	if ok:
		GameBus.card_played.emit(card.template_id, "board", slot_idx)
	return ok

func _enter_slot_select_mode(card: CardInstance) -> void:
	_battle._slot_select_card = card
	_show_cancel_btn("✕ Cancel", _exit_slot_select_mode)
	_battle._refresh_player_board()

func _exit_slot_select_mode() -> void:
	_battle._slot_select_card = null
	_hide_cancel_btn()
	_battle._refresh_player_board()

func _enter_slot_targeting_mode(spell: CardInstance) -> void:
	_battle._slot_targeting_spell = spell
	_battle._targeting_active = true
	_show_cancel_btn("✕ Cancel Spell", _exit_slot_targeting_mode)
	_battle._refresh_player_board()

func _exit_slot_targeting_mode() -> void:
	_battle._slot_targeting_spell = null
	_battle._targeting_active = false
	_hide_cancel_btn()
	_battle._refresh_player_board()

func _resolve_slot_spell(spell: CardInstance, slot_idx: int) -> void:
	if not _battle._state.players[_battle._my_idx()].can_play(spell):
		return
	if _battle._is_pvp_client():
		var hi: int = _battle._state.players[_battle._my_idx()].hand.find(spell)
		if hi != -1:
			AudioManager.play_sfx("spell_resolve")
			_battle._fx.haptic(20)
			_battle._send_intent(BattleNetProtocol.encode_play_spell(hi, {"slot": slot_idx}))
		return
	_battle._do_play_card(spell, _battle._my_idx())
	AudioManager.play_sfx("spell_resolve")
	_battle._fx.haptic(20)
	match spell.spell_effect:
		"bless_slot":
			_battle._state.players[_battle._my_idx()].board.enhance_slot(slot_idx, "atk_bonus", spell.spell_power)
		"ward_slot":
			_battle._state.players[_battle._my_idx()].board.enhance_slot(slot_idx, "shroud", 1)
	_battle._refresh_all()
	_battle._check_game_over()

func _on_target_chosen_card(target: CardInstance) -> void:
	var spell := _battle._targeting_spell
	_battle._targeting_active = false
	_battle._targeting_friendly = false
	_battle._targeting_spell = null
	_hide_cancel_btn()
	if _battle._is_pvp_client():
		var hi: int = _battle._state.players[_battle._my_idx()].hand.find(spell)
		if hi != -1 and _battle._state.players[_battle._my_idx()].can_play(spell):
			AudioManager.play_sfx("card_play")
			_battle._fx.haptic(20)
			_battle._send_intent(BattleNetProtocol.encode_play_spell(hi,
					_battle.battle_net._pvp_target_dict_for_card(target)))
			_battle.tutorials._dismiss_battle_tutorial()
		return
	if _battle._do_play_card(spell, _battle._my_idx()):
		AudioManager.play_sfx("card_play")
		_battle._fx.haptic(20)
		var snap_otc := _battle._fx.snapshot()
		_battle._resolver.resolve_spell(spell, _battle._my_idx(), {"type": "minion", "card": target})
		_battle._fx.trigger_fx(snap_otc)
	_battle._refresh_all()
	_battle._check_game_over()
	_battle.tutorials._dismiss_battle_tutorial()

func _on_target_chosen_hero() -> void:
	var spell := _battle._targeting_spell
	_battle._targeting_active = false
	_battle._targeting_friendly = false
	_battle._targeting_spell = null
	_hide_cancel_btn()
	var hero_tgt: Dictionary = {"hero": true, "pidx": _battle._opp_idx()} if _battle._team_pvp else {"hero": true}
	if _battle._is_pvp_client():
		var hi: int = _battle._state.players[_battle._my_idx()].hand.find(spell)
		if hi != -1 and _battle._state.players[_battle._my_idx()].can_play(spell):
			AudioManager.play_sfx("card_play")
			_battle._fx.haptic(20)
			_battle._send_intent(BattleNetProtocol.encode_play_spell(hi, hero_tgt))
			_battle.tutorials._dismiss_battle_tutorial()
		return
	if _battle._do_play_card(spell, _battle._my_idx()):
		AudioManager.play_sfx("card_play")
		_battle._fx.haptic(20)
		var snap_oth := _battle._fx.snapshot()
		var resolver_hero_tgt: Dictionary = {"type": "hero",
				"pidx": _battle._opp_idx()} if _battle._team_pvp else {"type": "hero"}
		_battle._resolver.resolve_spell(spell, _battle._my_idx(), resolver_hero_tgt)
		_battle._fx.trigger_fx(snap_oth)
	_battle._refresh_all()
	_battle._check_game_over()
	_battle.tutorials._dismiss_battle_tutorial()
