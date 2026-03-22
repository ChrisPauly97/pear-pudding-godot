extends Control

const GameState = preload("res://game_logic/battle/GameState.gd")
const BasicAI = preload("res://ai/BasicAI.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
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
	if SaveManager.player_deck.size() > 0:
		player_deck.assign(SaveManager.player_deck)
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
	_refresh_hero(_enemy_hero_view, _state.players[1].hero)
	_refresh_hero(_player_hero_view, _state.players[0].hero)
	_update_status()

func _refresh_zone(zone_node: Node, cards: Array, zone_id: String) -> void:
	for child in zone_node.get_children():
		child.queue_free()
	for card in cards:
		var card_view := _make_card_view(card, zone_id)
		zone_node.add_child(card_view)

func _make_card_view(card: CardInstance, zone_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_vh * 0.09, _vh * 0.15)
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
	panel.add_child(vbox)

	# Style
	var style := StyleBoxFlat.new()
	var tmpl := CardRegistry.get_template(card.template_id)
	style.bg_color = tmpl.get("color", Color(0.3, 0.3, 0.3)) if not tmpl.is_empty() else Color(0.3, 0.3, 0.3)

	# Dim unplayable hand cards; highlight selected attacker
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

	# Interactions
	if zone_id == "hand" and _state.current_player_idx == 0:
		panel.gui_input.connect(func(event): _on_hand_card_input(event, card, panel))
	elif zone_id == "board" and _state.current_player_idx == 0:
		panel.gui_input.connect(func(event): _on_board_card_input(event, card))
	elif zone_id == "enemy_board":
		panel.gui_input.connect(func(event): _on_enemy_card_input(event, card))

	return panel

func _refresh_hero(hero_node: Node, hero: HeroState) -> void:
	var hp_lbl := hero_node.find_child("HPLabel", true, false)
	var mana_lbl := hero_node.find_child("ManaLabel", true, false)
	if hp_lbl:
		hp_lbl.text = "HP: %d/%d" % [hero.health, hero.max_health]
	if mana_lbl:
		mana_lbl.text = "Mana: %d/%d" % [hero.mana, hero.max_mana]

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
		var targets := _state.players[1].board.get_cards()
		if targets.is_empty():
			# No enemy minions — attack hero directly
			_state.players[1].hero.take_damage(my_card.attack)
			my_card.attack_count -= 1
			my_card.health -= _state.players[1].hero.attack
			_dragged_card.clear()
		else:
			# Select as attacker; player clicks an enemy card to resolve
			_dragged_card = {"card": my_card}
		_refresh_all()
		_check_game_over()

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
		await get_tree().create_timer(0.5).timeout
		_ai_thinking = false
		_state.end_turn()
		_refresh_all()
		_check_game_over()
		return
	actions[idx].call()
	_refresh_all()
	await get_tree().create_timer(0.6).timeout
	_execute_ai_actions(actions, idx + 1)

func _check_game_over() -> void:
	if _state.is_game_over():
		var w := _state.winner()
		if w == 0:
			GameBus.battle_won.emit({"enemy_data": enemy_data})
		else:
			GameBus.battle_lost.emit()
