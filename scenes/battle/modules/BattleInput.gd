## Card and hero input: hand / board / enemy taps and gestures, the spell cast confirm,
## and attacks.
##
## A child of BattleScene (`BattleScene.card_input`), created by `_ensure_battle_modules()`.
## Battle state stays on the scene. Reach it as `_battle.<name>`, and use
## `_battle.add_child` rather than a bare `add_child`.
extends Node

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")
const BattlefieldRules = preload("res://game_logic/battle/BattlefieldRules.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const SpellEffectResolver = preload("res://scenes/battle/SpellEffectResolver.gd")
const BattleNetProtocol = preload("res://game_logic/net/BattleNetProtocol.gd")

var _battle: _BattleScene


func _init(battle: _BattleScene) -> void:
	_battle = battle


func _bind_card_input(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	for conn in panel.gui_input.get_connections():
		panel.gui_input.disconnect(conn["callable"])
	if zone_id == "hand":
		_bind_hover_lift(panel)
	if zone_id == "hand" and _battle._state.current_player_idx == _battle._my_idx():
		# Tap/click handler fires on release; it only fires when no native drag was started.
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_hand_card_input(event, card))
		# Native drag forwarding: drag threshold handled by Godot (mouse + touch transparent).
		# LongPressDetector remains independent; it cancels itself if movement > SLOP_PX,
		# which happens before the drag threshold is reached, so inspect and drag don't conflict.
		panel.set_drag_forwarding(
			func(_pos: Vector2) -> Variant:
				if not _battle._can_local_act():
					return null
				if _battle._inspect_overlay != null and is_instance_valid(_battle._inspect_overlay):
					return null
				if not _battle._state.players[_battle._my_idx()].can_play(card):
					return null
				_battle._hand_drag_card = card
				var ghost: PanelContainer = _battle._make_card_ghost(card)
				ghost.scale = Vector2(1.05, 1.05)
				panel.set_drag_preview(ghost)
				panel.modulate.a = 0.45
				_battle._refresh_player_board()
				return {"card": card},
			func(_pos: Vector2, _data: Variant) -> bool: return false,
			func(_pos: Vector2, _data: Variant) -> void: pass
		)
	elif zone_id == "board" and _battle._state.current_player_idx == _battle._my_idx():
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_board_card_input(event, card))
		# Drag-to-attack: dragging a board card returns {"attacker": card} so it can
		# be dropped onto an enemy card panel or the enemy hero view.
		panel.set_drag_forwarding(
			func(_pos: Vector2) -> Variant:
				if not _battle._can_local_act(true) or not card.can_attack():
					return null
				return {"attacker": card},
			func(_pos: Vector2, _data: Variant) -> bool: return false,
			func(_pos: Vector2, _data: Variant) -> void: pass
		)
	elif zone_id == "enemy_board":
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_enemy_card_input(event, card))
		# Accept attack drags ({"attacker": card}) dropped onto enemy minions.
		panel.set_drag_forwarding(
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
				var valid: Array[CardInstance] = _battle._view.get_ward_valid_targets(
					_battle._state.players[_battle._opp_idx()].board.get_cards())
				return valid.has(card),
			func(_pos: Vector2, data: Variant) -> void:
				if not (data is Dictionary):
					return
				var drag_data: Dictionary = data as Dictionary
				if not drag_data.has("attacker"):
					return
				var attacker: CardInstance = drag_data["attacker"] as CardInstance
				if attacker != null:
					_attempt_attack(attacker, card)
		)
	# Right-click inspect — not on enemy hand (hidden information)
	if zone_id != "enemy_hand":
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
					_battle._show_card_inspect(card)
		)
		# Long-press inspect (mobile) — reuse existing detector to avoid node churn
		var lpd: LongPressDetector = panel.get_node_or_null("_lpd") as LongPressDetector
		if lpd == null:
			lpd = LongPressDetector.new()
			lpd.name = "_lpd"
			panel.add_child(lpd)
		else:
			for conn in lpd.long_pressed.get_connections():
				lpd.long_pressed.disconnect(conn["callable"])
		lpd.long_pressed.connect(func() -> void: _battle._show_card_inspect(card))

## Handles tap (press+release without drag). Fires only when native drag was NOT started,
## because Godot consumes the release event when a drag is in progress.
func _on_hand_card_input(event: InputEvent, card: CardInstance) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if not _battle._can_local_act():
				return
			_on_hand_card_tap(card)

func _on_hand_card_tap(card: CardInstance) -> void:
	if not _battle._can_local_act() or _inspect_open():
		return
	var can_play: bool = _battle._state.players[_battle._my_idx()].can_play(card)
	if card.card_class != "spell" and can_play:
		_battle.targeting._enter_slot_select_mode(card)
		return
	if card.card_class == "spell" and can_play:
		# Tap-first casting (GID-119 / TID-450): mirror _board_drop's routing so
		# every spell class is playable without a drag. Unplayable cards and
		# no-valid-target situations keep falling through to inspect.
		if SpellEffectResolver.SLOT_TARGETED_EFFECTS.has(card.spell_effect):
			_battle.targeting._enter_slot_targeting_mode(card)
			return
		if SpellEffectResolver.ALLY_TARGETED_EFFECTS.has(card.spell_effect) and _battle._coop_pve:
			_battle.targeting._enter_ally_targeting_mode(card)
			return
		var is_enemy_targeted: bool = SpellEffectResolver.ENEMY_TARGETED_EFFECTS.has(card.spell_effect)
		var is_friendly_targeted: bool = SpellEffectResolver.FRIENDLY_TARGETED_EFFECTS.has(card.spell_effect)
		if is_enemy_targeted or is_friendly_targeted:
			if is_friendly_targeted and _battle._state.players[_battle._my_idx()].board.get_cards().is_empty():
				_battle._show_card_inspect(card)
				return
			if is_enemy_targeted and card.spell_effect != "deal_damage_single" \
					and _battle._state.players[_battle._opp_idx()].board.get_cards().is_empty():
				_battle._show_card_inspect(card)
				return
			_battle.targeting._enter_targeting_mode(card, is_friendly_targeted)
			return
		_show_cast_confirm(card)
		# gdlint:ignore = max-returns
		return
	_battle._show_card_inspect(card)

## Confirm step for untargeted spells played by tap — they resolve instantly, so
## a bare tap (easy to fat-finger on a fanned hand) must not cast unprompted.
func _show_cast_confirm(card: CardInstance) -> void:
	if _battle._cast_confirm_layer != null and is_instance_valid(_battle._cast_confirm_layer):
		return
	var layer := CanvasLayer.new()
	layer.layer = 150
	_battle.add_child(layer)
	_battle._cast_confirm_layer = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_hide_cast_confirm())
	layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var panel := PanelContainer.new()
	var style := _UiUtil.make_style(Color(0.10, 0.10, 0.20, 0.97), 10)
	panel.add_theme_stylebox_override("panel", style)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(minf(vp.x * 0.5, _battle._vh * 0.75), 0)
	center.add_child(panel)

	var margin := _UiUtil.make_margin(int(_battle._vh * 0.025), int(_battle._vh * 0.02), int(_battle._vh * 0.025),
			int(_battle._vh * 0.02), panel)

	var vbox := _UiUtil.make_vbox(int(_battle._vh * 0.015), margin)

	var name_lbl := _UiUtil.make_label(card.name, int(_battle._font(0.028)), Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var ability_lbl := _UiUtil.make_label(_battle._view.get_card_ability_text(card), int(_battle._font(0.022)),
			Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER)
	ability_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_lbl.add_theme_color_override("font_color", _battle._view.get_card_ability_color(card))
	vbox.add_child(ability_lbl)

	var cast_btn := _UiUtil.make_button("Cast (%d mana)" % _battle._state.players[_battle._my_idx()].effective_cost(card),
			Vector2(_battle._vh * 0.22, _battle._vh * 0.08), int(_battle._font(0.030)))
	cast_btn.pressed.connect(func() -> void:
		_hide_cast_confirm()
		_cast_confirmed_spell(card))
	vbox.add_child(cast_btn)

	var cancel_btn := _UiUtil.make_button("Cancel", Vector2(_battle._vh * 0.22, _battle._vh * 0.06),
			int(_battle._font(0.024)),
			_hide_cast_confirm, vbox)

func _hide_cast_confirm() -> void:
	if _battle._cast_confirm_layer != null and is_instance_valid(_battle._cast_confirm_layer):
		_battle._cast_confirm_layer.queue_free()
	_battle._cast_confirm_layer = null

## Shared untargeted-spell cast path — used by the drag drop (_board_drop) and
## the tap confirm. Handles the PvP-client intent relay.
func _cast_confirmed_spell(card: CardInstance) -> void:
	if not _battle._can_local_act() or not _battle._state.players[_battle._my_idx()].can_play(card):
		return
	if _battle._is_pvp_client():
		var hi: int = _battle._state.players[_battle._my_idx()].hand.find(card)
		if hi != -1:
			AudioManager.play_sfx("card_play")
			_battle._fx.haptic(20)
			_battle._send_intent(BattleNetProtocol.encode_play_spell(hi, {}))
			_battle.tutorials._dismiss_battle_tutorial()
		return
	# Real time: spells show a cast bar and resolve when it completes (TID-546).
	var finish := func() -> void:
		if _battle._do_play_card(card, _battle._my_idx()):
			AudioManager.play_sfx("card_play")
			_battle._fx.haptic(20)
			var snap: Array[Dictionary] = _battle._fx.snapshot()
			_battle._resolver.resolve_spell(card, _battle._my_idx())
			_battle._fx.trigger_fx(snap)
			_battle._refresh_all()
			_battle._check_game_over()
			_battle.tutorials._dismiss_battle_tutorial()
	if not _battle.realtime.run_cast(card, finish, null):
		finish.call()

func _on_board_card_input(event: InputEvent, my_card: CardInstance) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if not _battle._can_local_act(true) or _inspect_open():
			return
		if _battle._targeting_active and _battle._targeting_friendly:
			_battle.targeting._on_target_chosen_card(my_card)
			return
		# Tapping the selected attacker again cancels the selection.
		if _battle._dragged_card.get("card") == my_card:
			clear_attacker_selection()
			return
		if not my_card.can_attack():
			_battle._fx.flash_node(_battle._fx.get_card_panel(my_card, false), Color(0.6, 0.6, 0.6, 1.0))
			return
		# Always enter selection mode — player clicks a target (minion or hero)
		_battle._dragged_card = {"card": my_card}
		AudioManager.play_sfx("ui_click")
		_battle._refresh_all()

## Drops the pending attacker selection (tap again, Escape, or tap empty board).
func clear_attacker_selection() -> void:
	if _battle._dragged_card.is_empty():
		return
	_battle._dragged_card.clear()
	_battle._refresh_all()

func _inspect_open() -> bool:
	return _battle._inspect_overlay != null and is_instance_valid(_battle._inspect_overlay)

## Desktop hover preview: lifts and enlarges a hand card so a fanned hand is
## readable without opening the inspect overlay. Bound once per panel.
func _bind_hover_lift(panel: PanelContainer) -> void:
	if panel.has_meta("hover_bound"):
		return
	panel.set_meta("hover_bound", true)
	panel.mouse_entered.connect(func() -> void: _set_hover_lift(panel, true))
	panel.mouse_exited.connect(func() -> void: _set_hover_lift(panel, false))

func _set_hover_lift(panel: PanelContainer, on: bool) -> void:
	if not is_instance_valid(panel) or not panel.visible:
		return
	panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y)
	panel.z_index = 20 if on else 0
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "scale", Vector2(1.25, 1.25) if on else Vector2.ONE,
			0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_enemy_card_input(event: InputEvent, target: CardInstance) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		# Real-time mode: with no Ally selected, a tap sets the hero's auto-attack
		# focus (even on global cooldown); a selected Ally attacks instead.
		if _is_realtime_focus_tap():
			_battle.realtime.set_focus(target)
		elif _battle._can_local_act(true):
			_on_enemy_card_tap(target)

## Real time, nothing selected, not aiming a spell: an enemy tap sets focus.
func _is_realtime_focus_tap() -> bool:
	return (_battle.realtime.is_active() and not _battle._targeting_active
			and _battle._dragged_card.is_empty())

func _on_enemy_card_tap(target: CardInstance) -> void:
	if _battle._targeting_active and not _battle._targeting_friendly:
		_battle.targeting._on_target_chosen_card(target)
		return
	if _battle._dragged_card.is_empty():
		return
	var attacker: CardInstance = _battle._dragged_card["card"]
	if not attacker.can_attack():
		_battle._dragged_card.clear()
		return
	# Ward: if any enemy minion has Ward, only those are valid targets (on the
	# target's own board — a real-time fight can have two enemies).
	var opp_board: Array[CardInstance] = _battle._state.players[_defender_of(target)].board.get_cards()
	var valid_targets: Array[CardInstance] = _battle._view.get_ward_valid_targets(opp_board)
	if not valid_targets.has(target):
		return  # keep attacker selected; player must click a Ward minion
	_attempt_attack(attacker, target)

## `pidx`: which enemy hero was tapped (-1 = the main opponent; a real-time add
## binds its own index).
func _on_enemy_hero_input(event: InputEvent, pidx: int = -1) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _battle._targeting_active and not _battle._targeting_friendly:
			_battle.targeting._on_target_chosen_hero(pidx)
		elif _is_realtime_focus_tap():
			_battle.realtime.set_focus_enemy(pidx)  # hero auto-attack goes at this enemy
		elif _battle._can_local_act(true) and not _battle._dragged_card.is_empty():
			_on_enemy_hero_tap(pidx)

## Owner index of an enemy target card (the main opponent for a hero / unknown).
func _defender_of(target: CardInstance) -> int:
	if target != null:
		for i in range(_battle._state.players.size()):
			if i != _battle._my_idx() and _battle._state.players[i].board.get_cards().has(target):
				return i
	return _battle._opp_idx()

func _on_enemy_hero_tap(pidx: int = -1) -> void:
	var attacker: CardInstance = _battle._dragged_card["card"]
	if not attacker.can_attack():
		_battle._dragged_card.clear()
		_battle._refresh_all()
		return
	# Ward: cannot attack hero while any Ward minion is alive on that enemy's board
	var def_idx: int = pidx if pidx >= 0 else _battle._opp_idx()
	for ec: CardInstance in _battle._state.players[def_idx].board.get_cards():
		if ec.keywords.has(Keywords.WARD):
			return  # keep attacker selected; player must target the Ward minion
	_attempt_attack(attacker, null, def_idx)

func _on_empty_slot_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _battle._slot_targeting_spell != null:
				var spell := _battle._slot_targeting_spell
				_battle.targeting._exit_slot_targeting_mode()
				_battle.targeting._resolve_slot_spell(spell, slot_idx)
				return
			if _battle._slot_select_card != null:
				var card := _battle._slot_select_card
				_battle.targeting._exit_slot_select_mode()
				if _battle._is_pvp_client():
					var hi: int = _battle._state.players[_battle._my_idx()].hand.find(card)
					if hi != -1 and _battle._state.players[_battle._my_idx()].can_play(card):
						AudioManager.play_sfx("card_play")
						_battle._fx.haptic(20)
						_battle._send_intent(BattleNetProtocol.encode_play_card_at_slot(hi, slot_idx))
						_battle.tutorials._dismiss_battle_tutorial()
					return
				var from_panel: Control = _battle._hand_panel_node(card)
				var from_rect: Rect2 = from_panel.get_global_rect() if from_panel != null else Rect2()
				var to_pos: Vector2 = _battle._slot_panel_center(_battle._player_board_view, slot_idx)
				if _battle.targeting._do_play_card_at_slot(card, _battle._my_idx(), slot_idx):
					AudioManager.play_sfx("card_play")
					_battle._fx.haptic(20)
					_battle._hide_hand_panel(from_panel)
					if card.emergence_effect != "":
						var snap_se := _battle._fx.snapshot()
						_battle._resolver.resolve_emergence(card, _battle._my_idx())
						_battle._fx.trigger_fx(snap_se)
					else:
						_battle.modifiers._apply_weather_to_summoned(card, _battle._my_idx())
					_battle._action_busy = true
					await _battle._animate_card_travel(card, from_rect, to_pos)
					_battle._action_busy = false
					_battle._refresh_all()
					_battle._check_game_over()
					_battle.tutorials._dismiss_battle_tutorial()
				return
			if _battle._slot_targeting_spell == null and _battle._slot_select_card == null:
				clear_attacker_selection()

## Routes a chosen attack: client sends an intent; host/single-player resolves
## locally via _execute_attack (which broadcasts through _check_game_over).
## `defender`: whose hero / board is hit (-1 = the target's owner, else the main opponent).
func _attempt_attack(attacker: CardInstance, target: CardInstance, defender: int = -1) -> void:
	# One attack per tap: while a lunge resolves, further taps/drops are ignored.
	if not _battle._can_local_act(true) or not attacker.can_attack():
		return
	if _battle._is_pvp_client():
		var a_slot: int = _battle._state.players[_battle._my_idx()].board.slots.find(attacker)
		var t_slot: int = BattleNetProtocol.TARGET_HERO
		if target != null:
			t_slot = _battle._state.players[_battle._opp_idx()].board.slots.find(target)
		_battle._dragged_card.clear()
		if a_slot != -1 and (target == null or t_slot != -1):
			var target_pidx: int = _battle._opp_idx() if _battle._team_pvp else -1
			_battle._send_intent(BattleNetProtocol.encode_attack(a_slot, t_slot, target_pidx))
		_battle._refresh_all()
		return
	await _execute_attack(attacker, target, defender)

## Resolves a player minion attack against target (CardInstance) or the enemy hero (null).
## Handles damage, counterattack, death removal, FX, and the card_attacked signal.
## Async: lunges the attacker into the target before mutating state, with a
## brief hit-stop on big/lethal hits, then animates any resulting death(s)
## before the board rebuilds (TID-426). All durations respect `_speed_scale`.
func _execute_attack(attacker: CardInstance, target: CardInstance, defender: int = -1) -> void:
	var def_idx: int = defender if defender >= 0 else _defender_of(target)
	# Multiplayer host: the next mirror carries this attack so other screens replay it.
	if _battle.battle_net != null:
		_battle.battle_net.record_attack_fx(_battle._my_idx(), attacker, def_idx, target)
	_battle._action_busy = true
	# Drop the selection highlight immediately so the board reads as resolving.
	_battle._dragged_card.clear()
	_battle._refresh_all()
	AudioManager.play_sfx("attack")
	var attacker_panel := _battle._fx.get_card_panel(attacker, false)
	var snap := _battle._fx.snapshot()
	var attacker_dmg: int = BattlefieldRules.modify_damage(attacker.attack, _battle._state.battlefield_biome)
	var target_panel_pre: Control = _battle._fx.get_card_panel(target, true) if target != null else null
	var target_pos: Vector2 = (target_panel_pre.get_global_rect().get_center() if target_panel_pre != null
			else _battle.realtime.hero_screen_pos(def_idx))
	var is_big_hit: bool = attacker_dmg >= 5 or (target != null and attacker_dmg >= target.health)
	await _battle._fx.animate_attack(attacker_panel, target_pos, _battle._speed_scale, 0.06 if is_big_hit else 0.0)
	if target != null:
		var target_dmg: int = BattlefieldRules.modify_damage(target.attack, _battle._state.battlefield_biome)
		target.take_damage(attacker_dmg)
		attacker.take_damage(target_dmg)
		attacker.attack_count -= 1
		var target_panel := _battle._fx.get_card_panel(target, true)
		_battle._fx.flash_node(target_panel, Color(1.0, 0.3, 0.3, 1.0))
		_battle._fx.flash_node(attacker_panel, Color(1.0, 0.3, 0.3, 1.0))
		if not target.is_alive():
			attacker.battle_kills += 1
			_battle._state.players[def_idx].board.remove_card(target)
			_battle._state.players[def_idx].discard.append(target)
		GameBus.card_attacked.emit(attacker.template_id, target.template_id)
	else:
		if _battle._capture_tracker != null:
			_battle._capture_tracker.note_minion_attacked_hero(0)
		_battle.realtime.on_ally_hit_enemy_hero(def_idx)  # real time: interrupts that enemy's cast
		var hero := _battle._state.players[def_idx].hero
		hero.take_damage(attacker_dmg)
		attacker.take_damage(BattlefieldRules.modify_damage(hero.attack, _battle._state.battlefield_biome))
		attacker.attack_count -= 1
		_battle._fx.flash_node(_battle.realtime.hero_view_for(def_idx), Color(1.0, 0.3, 0.3, 1.0))
		_battle._fx.flash_node(attacker_panel, Color(1.0, 0.3, 0.3, 1.0))
		GameBus.card_attacked.emit(attacker.template_id, "hero")
	if not attacker.is_alive():
		_battle._state.players[_battle._my_idx()].board.remove_card(attacker)
		_battle._state.players[_battle._my_idx()].discard.append(attacker)
	await _battle._animate_deaths_from_snapshot(snap)
	_battle._fx.spawn_float_labels(snap)
	_battle._fx.check_shake(snap)
	_battle._action_busy = false
	_battle._refresh_all()
	_battle._check_game_over()
