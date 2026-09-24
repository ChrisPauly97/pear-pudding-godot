## Hero power and potions: their HUD buttons, the potion picker, and applying each
## effect.
##
## A child of BattleScene (`BattleScene.consumables`), created by `_ensure_battle_modules()`.
## Battle state stays on the scene. Reach it as `_battle.<name>`, and use
## `_battle.add_child` rather than a bare `add_child`.
extends Node

const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")
const GardenDefs = preload("res://game_logic/GardenDefs.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const BattleNetProtocol = preload("res://game_logic/net/BattleNetProtocol.gd")

var _battle: _BattleScene


func _init(battle: _BattleScene) -> void:
	_battle = battle


func _add_hero_power_button() -> void:
	var active_skill: SkillData = _get_active_skill()
	if active_skill == null:
		return
	_battle._hero_power_btn = _UiUtil.make_button(active_skill.display_name, Vector2(_battle._vh * 0.18,
			_battle._vh * 0.05), int(_battle._font(0.02)),
			_use_hero_power)
	_battle.get_node("SidePanel").add_child(_battle._hero_power_btn)

func _add_potion_button() -> void:
	if _battle._state.puzzle_mode or _battle._state.scripted_battle:
		return
	var has_any: bool = false
	for potion_id: String in SceneManager.save_manager.potions:
		if int(SceneManager.save_manager.potions[potion_id]) > 0:
			has_any = true
			break
	if not has_any:
		return
	_battle._potion_btn = _UiUtil.make_button("Potion", Vector2(_battle._vh * 0.16, _battle._vh * 0.05),
			int(_battle._font(0.02)),
			_on_potion_button_pressed)
	_battle.get_node("SidePanel").add_child(_battle._potion_btn)

func _refresh_potion_button() -> void:
	if _battle._potion_btn == null:
		return
	var has_potions: bool = false
	for potion_id: String in SceneManager.save_manager.potions:
		if int(SceneManager.save_manager.potions[potion_id]) > 0:
			has_potions = true
			break
	var not_my_turn: bool = _battle._state.current_player_idx != _battle._my_idx()
	_battle._potion_btn.disabled = _battle._used_potion_this_battle or not has_potions or not_my_turn
	_battle._potion_btn.visible = has_potions

func _on_potion_button_pressed() -> void:
	if _battle._used_potion_this_battle or _battle._state.current_player_idx != _battle._my_idx():
		return
	_show_potion_picker()

func _show_potion_picker() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 160
	_battle.add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = minf(vp.x * 0.7, _battle._vh * 0.55)
	var panel := PanelContainer.new()
	var style := _UiUtil.make_style(Color(0.08, 0.08, 0.18, 0.97), 10)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, 0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, vp.y * 0.3)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := _UiUtil.make_margin(int(_battle._vh * 0.025), int(_battle._vh * 0.025), int(_battle._vh * 0.025),
			int(_battle._vh * 0.025), panel)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := _UiUtil.make_vbox(int(_battle._vh * 0.015), margin)

	var title_lbl := _UiUtil.make_label("Use a Potion", int(_battle._font(0.026)), Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER,
			vbox)

	var sm := SceneManager.save_manager
	for potion_id: String in GardenDefs.POTIONS:
		var count: int = int(sm.potions.get(potion_id, 0))
		if count <= 0:
			continue
		var potion_data: Dictionary = GardenDefs.POTIONS[potion_id]
		var display_name: String = str(potion_data.get("display_name", potion_id))
		var row := _UiUtil.make_hbox(int(_battle._vh * 0.012))
		var lbl := _UiUtil.make_label("%s  ×%d" % [display_name, count], int(_battle._font(0.022)), Color.WHITE,
				HORIZONTAL_ALIGNMENT_LEFT, row)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var use_btn := _UiUtil.make_button("Use", Vector2(_battle._vh * 0.1, _battle._vh * 0.055),
				int(_battle._font(0.022)))
		var pid: String = potion_id
		use_btn.pressed.connect(func() -> void:
			layer.queue_free()
			_apply_potion_effect(pid)
		)
		row.add_child(use_btn)
		vbox.add_child(row)

	var cancel_btn := _UiUtil.make_button("Cancel", Vector2(panel_w * 0.5, _battle._vh * 0.055),
			int(_battle._font(0.022)),
			layer.queue_free)
	var center := CenterContainer.new()
	center.add_child(cancel_btn)
	vbox.add_child(center)

func _apply_potion_effect(potion_id: String) -> void:
	var sm := SceneManager.save_manager
	if not sm.garden.remove_potions(potion_id, 1):
		return
	_battle._used_potion_this_battle = true
	if _battle._is_pvp_client():
		# Inventory consumed locally; the host applies the state effect to players[1].
		_battle._send_intent(BattleNetProtocol.encode_potion(potion_id))
		GameBus.potion_used.emit(potion_id)
		_refresh_potion_button()
		return
	var player: PlayerState = _battle._state.players[_battle._my_idx()]
	var snap_pot := _battle._fx.snapshot()
	match potion_id:
		"healing_draught":
			player.hero.health = mini(player.hero.health + 8, player.hero.max_health)
			_battle._fx.spawn_float_labels(snap_pot)
			_battle._fx.spawn_float_label(_battle._fx.pos_of_hero(false), "+8 HP", Color(0.267, 1.0, 0.533))
		"clarity_brew":
			player.draw_card()
			player.draw_card()
		"ember_tonic":
			player.hero.mana = mini(player.hero.mana + 1, player.hero.max_mana)
			_battle._fx.spawn_float_label(_battle._fx.pos_of_hero(false), "+1 Mana", Color(0.4, 0.8, 1.0))
	GameBus.potion_used.emit(potion_id)
	_battle._refresh_all()
	_refresh_potion_button()
	if _battle._pvp:
		_battle._check_game_over()

func _get_active_skill() -> SkillData:
	var result: SkillData = null
	for skill_id: String in SceneManager.save_manager.unlocked_skills:
		var sk: SkillData = SkillRegistry.get_skill(skill_id)
		if sk != null and sk.skill_type == "active":
			result = sk
	return result

func _use_hero_power() -> void:
	if _battle._hero_power_used:
		return
	if _battle._pvp and not _battle._can_local_act():
		return
	var active_skill: SkillData = _get_active_skill()
	if active_skill == null:
		return
	_battle._hero_power_used = true
	if _battle._hero_power_btn != null:
		_battle._hero_power_btn.disabled = true
	if _battle._is_pvp_client():
		# Host doesn't know the client's skill — relay the effect itself.
		_battle._send_intent(BattleNetProtocol.encode_hero_power({}, active_skill.effect_type,
				active_skill.effect_value))
		return
	_apply_hero_power_effect(_battle._my_idx(), active_skill.effect_type, active_skill.effect_value)
	_battle._refresh_all()
	_battle._check_game_over()

## Host → client: broadcast the full canonical state with a fresh seq.
## Also fans to any registered spectators (TID-367).
func _apply_hero_power_effect(player_idx: int, effect_type: String, value: int) -> void:
	var player: PlayerState = _battle._state.players[player_idx]
	# Hero power only fires on the acting player's own turn (current_player_idx ==
	# player_idx, enforced by every caller), so opponent() resolves correctly for
	# 2-player PvP, co-op-PvE (boss), and team PvP (auto lowest-HP enemy-team member —
	# hero powers don't carry a manual target_pidx, consistent with other AOE effects).
	var enemy: PlayerState = _battle._state.opponent()
	match effect_type:
		"active_damage_all":
			for card: CardInstance in enemy.board.get_cards().duplicate():
				card.take_damage(value)
				if not card.is_alive():
					enemy.board.remove_card(card)
					enemy.discard.append(card)
		"active_heal":
			player.hero.health = mini(player.hero.health + value, player.hero.max_health)
		"active_draw":
			for _i in value:
				player.draw_card()
			_battle._resolver.flush_auto_spells(player_idx)
		"active_mana":
			player.hero.mana = mini(player.hero.mana + value, player.hero.max_mana)
