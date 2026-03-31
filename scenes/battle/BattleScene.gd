extends Control

const GameState = preload("res://game_logic/battle/GameState.gd")
const BasicAI = preload("res://ai/BasicAI.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")

var enemy_data: Dictionary = {}
var _state: GameState
var _ai: BasicAI
var _ai_thinking: bool = false

# Click-to-target for board-card attacks (select attacker, then click enemy)
var _dragged_card: Dictionary = {}  # {card: CardInstance}
var _vh: float = 0.0

# Drag-to-play: hand card being dragged onto the board
var _hand_drag_card: CardInstance = null
var _drag_visual: Control = null
var _drag_start_pos: Vector2 = Vector2.ZERO

@onready var _enemy_hand_view = $EnemyArea/EnemyHandView
@onready var _enemy_board_view = $EnemyArea/EnemyBoardView
@onready var _enemy_hero_view = $EnemyArea/EnemyHeroView
@onready var _player_board_view = $PlayerArea/PlayerBoardView
@onready var _player_hand_view = $PlayerArea/PlayerHandView
@onready var _player_hero_view = $PlayerArea/PlayerHeroView
@onready var _turn_label: Label = $SidePanel/TurnLabel
@onready var _mana_label: Label = $SidePanel/ManaLabel
@onready var _end_turn_btn: Button = $SidePanel/EndTurnButton
@onready var _menu_btn: Button = $SidePanel/MenuButton

func _ready() -> void:
	_vh = get_viewport().get_visible_rect().size.y
	_apply_ui_sizes()
	_state = GameState.new()

	# Player deck: use SaveManager collection if available, else default
	var player_deck: Array[String] = []
	if SceneManager.save_manager.player_deck.size() > 0:
		player_deck.assign(SceneManager.save_manager.player_deck)
	else:
		player_deck = ["ghost", "skeleton", "zombie", "ghoul",
					   "ghost", "skeleton", "zombie", "ghoul",
					   "ghost", "skeleton", "zombie", "ghoul"]
	_state.players[0].build_deck(player_deck)
	_state.players[0].draw_opening_hand(4)

	# Enemy deck
	if enemy_data.has("enemy_deck"):
		var enemy_deck: Array[String] = []
		enemy_deck.assign(enemy_data["enemy_deck"])
		_state.players[1].build_deck(enemy_deck)
		_state.players[1].draw_opening_hand(4)

	_end_turn_btn.pressed.connect(_on_end_turn)
	_menu_btn.pressed.connect(func() -> void: SceneManager.go_to_menu())
	_enemy_hero_view.gui_input.connect(_on_enemy_hero_input)
	_apply_menu_btn_size()
	GameBus.turn_ended.connect(_on_turn_ended)

	_state.players[0].start_turn(1)
	_refresh_all()

func _apply_menu_btn_size() -> void:
	_menu_btn.custom_minimum_size = Vector2(_vh * 0.12, _vh * 0.05)

func _apply_ui_sizes() -> void:
	var hero_h: float = _vh * 0.09
	var board_h: float = _vh * 0.18
	_enemy_hand_view.custom_minimum_size   = Vector2(0, board_h)
	_enemy_hero_view.custom_minimum_size   = Vector2(0, hero_h)
	_enemy_board_view.custom_minimum_size  = Vector2(0, board_h)
	_player_board_view.custom_minimum_size = Vector2(0, board_h)
	_player_hero_view.custom_minimum_size  = Vector2(0, hero_h)
	_player_hand_view.custom_minimum_size  = Vector2(0, board_h)

# -------------------------------------------------------------------------
# Drag/Drop — scene-level input catches mouse move and release globally
# -------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _hand_drag_card == null:
		return

	if event is InputEventMouseMotion:
		if _drag_visual:
			# Centre the ghost card on the cursor
			_drag_visual.position = get_viewport().get_mouse_position() - _drag_visual.size * 0.5
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_hand_drag()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_hand_drag()
			get_viewport().set_input_as_handled()

func _finish_hand_drag() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var board_rect: Rect2 = _player_board_view.get_global_rect()
	if board_rect.has_point(mouse_pos):
		if _state.players[0].play_card(_hand_drag_card):
			_refresh_all()
			_check_game_over()
	_cancel_hand_drag()

func _cancel_hand_drag() -> void:
	if _drag_visual:
		_drag_visual.queue_free()
		_drag_visual = null
	_hand_drag_card = null

func _start_hand_drag(card: CardInstance, from_pos: Vector2) -> void:
	if not _state.players[0].can_play(card):
		return
	_hand_drag_card = card
	_drag_start_pos = from_pos
	_drag_visual = _make_card_ghost(card)
	_drag_visual.position = from_pos - _drag_visual.size * 0.5
	_drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_visual)
	# Ensure ghost renders on top
	move_child(_drag_visual, get_child_count() - 1)

func _make_card_ghost(card: CardInstance) -> PanelContainer:
	var panel := _make_card_view(card, "ghost")
	panel.modulate.a = 0.75
	# Fixed size already set inside _make_card_view
	return panel

# -------------------------------------------------------------------------
# UI Refresh
# -------------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_zone(_enemy_hand_view, _state.players[1].hand, "enemy_hand")
	_refresh_zone(_enemy_board_view, _state.players[1].board.get_cards(), "enemy_board")
	_refresh_zone(_player_board_view, _state.players[0].board.get_cards(), "board")
	_refresh_zone(_player_hand_view, _state.players[0].hand, "hand")
	_refresh_hero(_enemy_hero_view, _state.players[1].hero, true)
	_refresh_hero(_player_hero_view, _state.players[0].hero, false)
	_update_status()

func _refresh_zone(zone_node: Node, cards: Array[CardInstance], zone_id: String) -> void:
	var existing: Array[Node] = zone_node.get_children()
	var needed: int = cards.size()
	# Reuse existing panels where possible, update their content
	for i in range(needed):
		if i < existing.size():
			_update_card_view(existing[i] as PanelContainer, cards[i], zone_id)
		else:
			var card_view := _make_card_view(cards[i], zone_id)
			zone_node.add_child(card_view)
	# Remove excess panels
	for i in range(needed, existing.size()):
		existing[i].queue_free()

func _update_card_view(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	var vbox: VBoxContainer = panel.get_child(0) as VBoxContainer
	if not vbox or vbox.get_child_count() < 3:
		# Structure mismatch — rebuild from scratch
		for child in panel.get_children():
			child.queue_free()
		var new_vbox := _build_card_vbox(card)
		panel.add_child(new_vbox)
	else:
		var name_lbl: Label = vbox.get_child(0) as Label
		var stats_lbl: Label = vbox.get_child(1) as Label
		var desc_lbl: Label = vbox.get_child(2) as Label
		name_lbl.text = card.name
		stats_lbl.text = "%d/%d  (%d)" % [card.attack, card.health, card.cost]
		desc_lbl.text = card.description
	_apply_card_style(panel, card, zone_id)
	_bind_card_input(panel, card, zone_id)

func _build_card_vbox(card: CardInstance) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = card.name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.013))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats_lbl := Label.new()
	stats_lbl.text = "%d/%d  (%d)" % [card.attack, card.health, card.cost]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var desc_lbl := Label.new()
	desc_lbl.text = card.description
	desc_lbl.add_theme_font_size_override("font_size", int(_vh * 0.011))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)
	vbox.add_child(stats_lbl)
	vbox.add_child(desc_lbl)
	return vbox

func _apply_card_style(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	var style := StyleBoxFlat.new()
	var tmpl := CardRegistry.get_template(card.template_id)
	style.bg_color = tmpl.get("color", Color(0.3, 0.3, 0.3)) if not tmpl.is_empty() else Color(0.3, 0.3, 0.3)
	if zone_id == "hand" and not _state.players[0].can_play(card):
		style.bg_color = style.bg_color.darkened(0.5)
	elif zone_id == "board" and not _dragged_card.is_empty() and _dragged_card.get("card") == card:
		style.border_color = Color.YELLOW
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

func _bind_card_input(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	# Disconnect old signals before connecting new ones
	for conn in panel.gui_input.get_connections():
		panel.gui_input.disconnect(conn["callable"])
	if zone_id == "hand" and _state.current_player_idx == 0:
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_hand_card_input(event, card, panel))
	elif zone_id == "board" and _state.current_player_idx == 0:
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_board_card_input(event, card))
	elif zone_id == "enemy_board":
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_enemy_card_input(event, card))

func _make_card_view(card: CardInstance, zone_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_vh * 0.09, _vh * 0.15)
	panel.add_child(_build_card_vbox(card))
	_apply_card_style(panel, card, zone_id)
	_bind_card_input(panel, card, zone_id)
	return panel

func _refresh_hero(hero_node: Node, hero: HeroState, is_enemy: bool) -> void:
	var vbox: VBoxContainer = hero_node.get_child(0) as VBoxContainer if hero_node.get_child_count() > 0 else null
	if not vbox:
		# First time — build the hero UI
		vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(_vh * 0.004))

		var name_lbl := Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.text = "ENEMY" if is_enemy else "YOU"
		name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.modulate = Color(1.0, 0.55, 0.55) if is_enemy else Color(0.55, 1.0, 0.75)

		var hp_lbl := Label.new()
		hp_lbl.name = "HPLabel"
		hp_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var bar := ProgressBar.new()
		bar.name = "HPBar"
		bar.custom_minimum_size = Vector2(0, int(_vh * 0.014))
		bar.show_percentage = false

		vbox.add_child(name_lbl)
		vbox.add_child(hp_lbl)
		vbox.add_child(bar)
		if not is_enemy:
			var mana_lbl := Label.new()
			mana_lbl.name = "ManaLabel"
			mana_lbl.add_theme_font_size_override("font_size", int(_vh * 0.013))
			mana_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(mana_lbl)
		hero_node.add_child(vbox)

	# Update values on existing nodes
	var hp_lbl: Label = vbox.get_node("HPLabel") as Label
	hp_lbl.text = "HP  %d / %d" % [hero.health, hero.max_health]
	var bar: ProgressBar = vbox.get_node("HPBar") as ProgressBar
	bar.max_value = hero.max_health
	bar.value = hero.health
	var mana_lbl: Label = vbox.get_node_or_null("ManaLabel") as Label
	if mana_lbl:
		mana_lbl.text = "Mana  %d / %d" % [hero.mana, hero.max_mana]

	# Styling
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	var is_targetable: bool = is_enemy and not _dragged_card.is_empty()
	if is_enemy:
		style.bg_color = Color(0.45, 0.1, 0.1) if not is_targetable else Color(0.55, 0.15, 0.1)
		if is_targetable:
			style.border_color = Color(1.0, 0.35, 0.2)
			style.border_width_top    = 3
			style.border_width_bottom = 3
			style.border_width_left   = 3
			style.border_width_right  = 3
	else:
		style.bg_color = Color(0.1, 0.2, 0.4)
	hero_node.add_theme_stylebox_override("panel", style)

func _update_status() -> void:
	var player := _state.players[0]
	_turn_label.text = "Turn %d" % _state.turn_number
	_mana_label.text = "Mana: %d/%d" % [player.hero.mana, player.hero.max_mana]
	_end_turn_btn.disabled = _state.current_player_idx != 0 or _ai_thinking

# -------------------------------------------------------------------------
# Input handlers
# -------------------------------------------------------------------------

func _on_hand_card_input(event: InputEvent, card: CardInstance, panel: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _state.current_player_idx != 0 or _ai_thinking:
				return
			_start_hand_drag(card, panel.get_global_rect().get_center())

func _on_board_card_input(event: InputEvent, my_card: CardInstance) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not my_card.can_attack():
			return
		# Always enter selection mode — player clicks a target (minion or hero)
		_dragged_card = {"card": my_card}
		_refresh_all()

func _on_enemy_card_input(event: InputEvent, target: CardInstance) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _dragged_card.is_empty():
			return
		var attacker: CardInstance = _dragged_card["card"]
		if not attacker.can_attack():
			_dragged_card.clear()
			return
		target.health -= attacker.attack
		attacker.health -= target.attack
		attacker.attack_count -= 1
		if not target.is_alive():
			_state.players[1].board.remove_card(target)
			_state.players[1].discard.append(target)
		if not attacker.is_alive():
			_state.players[0].board.remove_card(attacker)
			_state.players[0].discard.append(attacker)
		_dragged_card.clear()
		_refresh_all()
		_check_game_over()

func _on_enemy_hero_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _state.current_player_idx != 0 or _ai_thinking:
			return
		if _dragged_card.is_empty():
			return
		var attacker: CardInstance = _dragged_card["card"]
		if not attacker.can_attack():
			_dragged_card.clear()
			_refresh_all()
			return
		_state.players[1].hero.take_damage(attacker.attack)
		attacker.health -= _state.players[1].hero.attack
		attacker.attack_count -= 1
		if not attacker.is_alive():
			_state.players[0].board.remove_card(attacker)
			_state.players[0].discard.append(attacker)
		_dragged_card.clear()
		_refresh_all()
		_check_game_over()

# -------------------------------------------------------------------------
# Turn / AI
# -------------------------------------------------------------------------

func _on_end_turn() -> void:
	if _state.current_player_idx != 0 or _ai_thinking:
		return
	_cancel_hand_drag()
	_dragged_card.clear()
	_state.end_turn()

func _on_turn_ended(player_idx: int) -> void:
	_refresh_all()
	if player_idx == 1:
		_run_ai_turn()

func _run_ai_turn() -> void:
	_ai_thinking = true
	_end_turn_btn.disabled = true
	var actions := BasicAI.decide_turn(_state)
	_execute_ai_actions(actions, 0)

func _execute_ai_actions(actions: Array[Callable], idx: int) -> void:
	if idx >= actions.size():
		await get_tree().create_timer(0.5, true).timeout
		_ai_thinking = false
		_state.end_turn()
		_refresh_all()
		_check_game_over()
		return
	actions[idx].call()
	_refresh_all()
	await get_tree().create_timer(0.6, true).timeout
	_execute_ai_actions(actions, idx + 1)

func _check_game_over() -> void:
	if _state.is_game_over():
		var w := _state.winner()
		if w == 0:
			var enemy_type: String = str(enemy_data.get("enemy_type", "undead_basic"))
			var pool: Array[String] = EnemyRegistry.get_drop_pool(enemy_type)
			var reward_card_id: String = ""
			if pool.size() > 0:
				reward_card_id = pool[randi() % pool.size()]
			_show_victory_overlay(reward_card_id)
		else:
			GameBus.battle_lost.emit()

func _show_victory_overlay(reward_card_id: String) -> void:
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.03))

	var title_lbl := Label.new()
	title_lbl.text = "Victory!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title_lbl)

	var reward_lbl := Label.new()
	if reward_card_id != "":
		var tmpl: Dictionary = CardRegistry.get_template(reward_card_id)
		var card_name: String = str(tmpl.get("name", reward_card_id))
		reward_lbl.text = "You earned: " + card_name
	else:
		reward_lbl.text = "No card dropped."
	reward_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reward_lbl)

	var btn := Button.new()
	btn.text = "Collect" if reward_card_id != "" else "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	var final_reward := reward_card_id
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.battle_won.emit({"card_reward": final_reward})
	)
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)
