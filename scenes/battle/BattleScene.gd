extends Control

const GameState = preload("res://game_logic/battle/GameState.gd")
const BasicAI = preload("res://ai/BasicAI.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const HeroState = preload("res://game_logic/battle/HeroState.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")
const CardInspectOverlay = preload("res://scenes/battle/CardInspectOverlay.gd")
const SettingsScene = preload("res://scenes/ui/SettingsScene.gd")
const Keywords = preload("res://game_logic/battle/Keywords.gd")

var enemy_data: Dictionary = {}
var _state: GameState
var _ai: BasicAI
var _ai_thinking: bool = false
var _boss_phase2_triggered: bool = false
var _hero_power_btn: Button = null
var _hero_power_used: bool = false
var _boss_banner: Control = null
var _boss_banner_timer: float = 0.0
const _BOSS_BANNER_DURATION: float = 2.5

var _float_layer: CanvasLayer = null
var _is_shaking: bool = false

# Click-to-target for board-card attacks (select attacker, then click enemy)
var _dragged_card: Dictionary = {}  # {card: CardInstance}
var _vh: float = 0.0

# Drag-to-play: hand card being dragged onto the board
var _hand_drag_card: CardInstance = null
var _drag_visual: Control = null
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _cancel_btn: Button = null

# Card inspect overlay
var _inspect_overlay: Control = null

# Battle pause
var _paused: bool = false
var _pause_overlay: CanvasLayer = null

# Spell targeting (TID-058)
const _TARGETED_EFFECTS: Array[String] = ["deal_damage_single"]
var _targeting_spell: CardInstance = null
var _targeting_active: bool = false

# Inline ability text on card faces (TID-140). Mirrors CardInspectOverlay._SPELL_EFFECT_LABELS.
const _SPELL_EFFECT_LABELS: Dictionary = {
	"deal_damage_single":  "Deal [power] damage to a target",
	"deal_damage_all":     "Deal [power] damage to all enemy minions",
	"deal_damage_random":  "Deal [power] damage to a random enemy",
	"debuff_attack":       "Reduce all enemy minion attack by [power]",
	"destroy_low_hp":      "Destroy all enemy minions with [power] or less HP",
	"resurrect_last":      "Resurrect the last friendly minion that died",
	"heal_single":         "Restore [power] HP to a friendly minion",
	"heal_all":            "Restore [power] HP to all friendly minions",
	"shield_minion":       "Give [power] armor to a friendly minion",
	"buff_attack":         "Give a friendly minion +[power] attack",
	"lifesteal_hit":       "Deal [power] damage; restore that much HP to your hero",
	"mana_drain":          "Remove [power] mana from the enemy hero",
	"curse_minion":        "Reduce an enemy minion's attack and HP by [power]",
	"draw_card":           "Draw [power] card(s)",
}

# Enemy intent banner (TID-059)
var _intent_panel: Control = null

# First-battle tutorial overlay
var _tutorial_overlay: Node = null
var _tutorial_timer: float = 0.0
const TUTORIAL_DURATION: float = 8.0

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
	_float_layer = CanvasLayer.new()
	_float_layer.layer = 128
	add_child(_float_layer)
	_vh = get_viewport().get_visible_rect().size.y
	_apply_ui_sizes()
	var _saved_battle: Dictionary = SceneManager.save_manager.pending_battle_state
	if not _saved_battle.is_empty():
		_state = GameState.from_dict(_saved_battle)
		SceneManager.save_manager.clear_pending_battle_state()
	else:
		_state = GameState.new()

		# Player deck: resolve instance UIDs to template IDs for the battle engine.
		var player_deck: Array[String] = []
		if SceneManager.save_manager.player_deck.size() > 0:
			player_deck = SceneManager.save_manager.get_deck_template_ids()
		else:
			player_deck = ["ghost", "skeleton", "zombie", "ghoul",
						   "ghost", "skeleton", "zombie", "ghoul",
						   "ghost", "skeleton", "zombie", "ghoul"]
		_state.players[0].build_deck(player_deck)
		_apply_equipment_effects(_state.players[0])
		_apply_passive_skills(_state.players[0])
		_state.players[0].draw_opening_hand(4)
		for _i in _state.players[0].bonus_draw:
			_state.players[0].draw_card()
		_flush_auto_spells(0)

		# Enemy deck — scale card stats by enemy difficulty tier
		var _enemy_type: String = str(enemy_data.get("enemy_type", ""))
		var _enemy_tier: int = EnemyRegistry.get_difficulty_tier(_enemy_type) if _enemy_type != "" else 1
		if bool(enemy_data.get("is_boss", false)):
			_enemy_tier = 4
		if enemy_data.has("enemy_deck"):
			var enemy_deck: Array[String] = []
			enemy_deck.assign(enemy_data["enemy_deck"])
			_state.players[1].build_deck(enemy_deck, _enemy_tier)
			_state.players[1].draw_opening_hand(4)

		# Boss setup: override enemy hero HP and show name banner
		if bool(enemy_data.get("is_boss", false)):
			var bhp: int = int(enemy_data.get("boss_hp", 0))
			if bhp > 0:
				_state.players[1].hero.health = bhp
				_state.players[1].hero.max_health = bhp
			_show_boss_banner()

		_state.players[0].start_turn(1)

	_end_turn_btn.pressed.connect(_on_end_turn)
	_menu_btn.pressed.connect(func() -> void: SceneManager.go_to_menu())
	_enemy_hero_view.gui_input.connect(_on_enemy_hero_input)
	_add_pause_button()
	_add_hero_power_button()
	GameBus.turn_ended.connect(_on_turn_ended)

	_refresh_all()

	AudioManager.play_music("res://assets/audio/music/battle.ogg")

	if not SceneManager.save_manager.get_story_flag("tutorial_battle_tip"):
		_show_battle_tutorial()

func _apply_equipment_effects(player: PlayerState) -> void:
	var sm := SceneManager.save_manager
	var slot_ids: Array[String] = [
		sm.equipped_weapon,
		sm.equipped_armor,
		sm.equipped_ring,
		sm.equipped_trinket,
	]
	var injected_any: bool = false
	for item_id in slot_ids:
		if item_id == "":
			continue
		var weapon: WeaponData = WeaponRegistry.get_weapon(item_id)
		if weapon == null:
			continue
		match weapon.battle_effect_type:
			"deck_inject":
				for i in weapon.injected_card_count:
					var tmpl: Dictionary = CardRegistry.get_template(weapon.injected_card_id)
					if tmpl.is_empty():
						continue
					player.draw_deck.append(CardInstance.new(tmpl))
				injected_any = true
			"starting_mana":
				player.hero.mana = mini(player.hero.mana + weapon.battle_effect_value, player.hero.max_mana + weapon.battle_effect_value)
				player.hero.max_mana += weapon.battle_effect_value
			"starting_hp":
				player.hero.health += weapon.battle_effect_value
				player.hero.max_health += weapon.battle_effect_value
			"passive_atk":
				player.hero.attack += weapon.battle_effect_value
	if injected_any:
		player.draw_deck.shuffle()

func _apply_passive_skills(player: PlayerState) -> void:
	for skill_id: String in SceneManager.save_manager.unlocked_skills:
		var skill: SkillData = SkillRegistry.get_skill(skill_id)
		if skill == null or skill.skill_type != "passive":
			continue
		match skill.effect_type:
			"passive_hp":
				player.hero.health += skill.effect_value
				player.hero.max_health += skill.effect_value
			"passive_mana":
				player.hero.mana = mini(player.hero.mana + skill.effect_value,
										player.hero.max_mana + skill.effect_value)
				player.hero.max_mana += skill.effect_value
			"passive_atk":
				player.hero.attack += skill.effect_value
			"passive_draw":
				player.bonus_draw += skill.effect_value

func _apply_ui_sizes() -> void:
	var hero_h: float = _vh * 0.09
	var board_h: float = _vh * 0.18
	_enemy_hand_view.custom_minimum_size   = Vector2(0, board_h)
	_enemy_hero_view.custom_minimum_size   = Vector2(0, hero_h)
	_enemy_board_view.custom_minimum_size  = Vector2(0, board_h)
	_player_board_view.custom_minimum_size = Vector2(0, board_h)
	_player_hero_view.custom_minimum_size  = Vector2(0, hero_h)
	_player_hand_view.custom_minimum_size  = Vector2(0, board_h)
	# Side panel buttons — large, easy to tap on mobile
	_end_turn_btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.10)
	_end_turn_btn.add_theme_font_size_override("font_size", int(_vh * 0.035))
	_menu_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.07)
	_menu_btn.add_theme_font_size_override("font_size", int(_vh * 0.028))
	($SidePanel as VBoxContainer).add_theme_constant_override("separation", int(_vh * 0.025))

# -------------------------------------------------------------------------
# First-battle tutorial overlay
# -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _tutorial_timer > 0.0:
		_tutorial_timer -= delta
		if _tutorial_timer <= 0.0:
			_dismiss_battle_tutorial()
	if _boss_banner_timer > 0.0:
		_boss_banner_timer -= delta
		if _boss_banner != null and is_instance_valid(_boss_banner):
			_boss_banner.modulate.a = clamp(_boss_banner_timer / 0.5, 0.0, 1.0)
		if _boss_banner_timer <= 0.0:
			if _boss_banner != null and is_instance_valid(_boss_banner):
				_boss_banner.queue_free()
			_boss_banner = null

func _show_battle_tutorial() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = int(_vh * 0.025)
	var panel_w: float = vp.x * 0.65
	var panel_h: float = _vh * 0.32

	var layer := CanvasLayer.new()
	layer.layer = 150
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(panel_w * 0.06))
	margin.add_theme_constant_override("margin_right",  int(panel_w * 0.06))
	margin.add_theme_constant_override("margin_top",    int(panel_h * 0.08))
	margin.add_theme_constant_override("margin_bottom", int(panel_h * 0.08))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.02))
	margin.add_child(vbox)

	var label := Label.new()
	label.text = "Drag a card from your hand to the board to play it.\nTap an enemy minion to attack with your minion."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(label)

	var btn := Button.new()
	btn.text = "Got it"
	btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.pressed.connect(_dismiss_battle_tutorial)
	vbox.add_child(btn)

	_tutorial_overlay = layer
	_tutorial_timer = TUTORIAL_DURATION

func _dismiss_battle_tutorial() -> void:
	if _tutorial_overlay != null and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null
	_tutorial_timer = 0.0
	SceneManager.save_manager.set_story_flag("tutorial_battle_tip")

# -------------------------------------------------------------------------
# Drag/Drop — scene-level input catches mouse move and release globally
# -------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
				return  # overlay handles its own Escape
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return

	if _hand_drag_card == null:
		return

	if event is InputEventMouseMotion:
		_drag_moved = true
		if _drag_visual:
			_drag_visual.position = get_viewport().get_mouse_position() - _drag_visual.size * 0.5
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if not _drag_moved:
				# Tap without drag — show inspect instead of play
				var card_to_inspect := _hand_drag_card
				_cancel_hand_drag()
				_show_card_inspect(card_to_inspect)
			else:
				_finish_hand_drag()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_hand_drag()
			get_viewport().set_input_as_handled()

func _finish_hand_drag() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var board_rect: Rect2 = _player_board_view.get_global_rect()
	if board_rect.has_point(mouse_pos):
		var played_card := _hand_drag_card
		# Targeted spells: don't play yet, enter target-selection mode
		if played_card.card_class == "spell" and _TARGETED_EFFECTS.has(played_card.spell_effect) and _state.players[0].can_play(played_card):
			_hand_drag_card = null
			if _drag_visual:
				_drag_visual.queue_free()
				_drag_visual = null
			_hide_cancel_btn()
			_enter_targeting_mode(played_card)
			return
		if _state.players[0].play_card(played_card):
			AudioManager.play_sfx("card_play")
			if played_card.card_class == "spell":
				var snap_fhd := _snapshot_hp_positions()
				_resolve_spell_effect(played_card, 0)
				_spawn_float_labels_from_snapshot(snap_fhd)
				_flash_from_snapshot(snap_fhd)
				_check_shake_from_snapshot(snap_fhd)
			_refresh_all()
			_check_game_over()
			_dismiss_battle_tutorial()
	_cancel_hand_drag()

func _cancel_hand_drag() -> void:
	_hide_cancel_btn()
	if _drag_visual:
		_drag_visual.queue_free()
		_drag_visual = null
	_hand_drag_card = null

func _start_hand_drag(card: CardInstance, from_pos: Vector2) -> void:
	_hand_drag_card = card
	_drag_start_pos = from_pos
	_drag_moved = false
	if not _state.players[0].can_play(card):
		# Still track for tap-to-inspect; don't show drag ghost for unplayable
		return
	_drag_visual = _make_card_ghost(card)
	_drag_visual.position = from_pos - _drag_visual.size * 0.5
	_drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_visual)
	move_child(_drag_visual, get_child_count() - 1)
	_show_cancel_btn("✕ Cancel", _cancel_hand_drag)

func _show_cancel_btn(label: String = "✕ Cancel", callback: Callable = Callable()) -> void:
	if _cancel_btn != null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var vw: float = vp.x
	_cancel_btn = Button.new()
	_cancel_btn.text = label
	_cancel_btn.custom_minimum_size = Vector2(vh * 0.14, vh * 0.06)
	_cancel_btn.add_theme_font_size_override("font_size", int(vh * 0.028))
	_cancel_btn.position = Vector2((vw - vh * 0.14) * 0.5, vh * 0.02)
	var cb: Callable = callback if callback.is_valid() else _cancel_hand_drag
	_cancel_btn.pressed.connect(cb)
	add_child(_cancel_btn)

func _hide_cancel_btn() -> void:
	if _cancel_btn != null:
		_cancel_btn.queue_free()
		_cancel_btn = null

func _enter_targeting_mode(card: CardInstance) -> void:
	_targeting_spell = card
	_targeting_active = true
	_show_cancel_btn("✕ Cancel Spell", _cancel_targeting)
	_refresh_all()

func _cancel_targeting() -> void:
	_targeting_active = false
	_targeting_spell = null
	_hide_cancel_btn()
	_refresh_all()

# -------------------------------------------------------------------------
# Card inspect overlay (TID-086)
# -------------------------------------------------------------------------

func _show_card_inspect(card: CardInstance) -> void:
	if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
		return
	var overlay: CardInspectOverlay = CardInspectOverlay.new()
	add_child(overlay)
	move_child(overlay, get_child_count() - 1)
	overlay.show_card(card)
	overlay.closed.connect(func() -> void: _inspect_overlay = null)
	_inspect_overlay = overlay

# -------------------------------------------------------------------------
# Battle pause (TID-088)
# -------------------------------------------------------------------------

func _add_pause_button() -> void:
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(_vh * 0.055, _vh * 0.055)
	pause_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(_toggle_pause)
	$SidePanel.add_child(pause_btn)
	$SidePanel.move_child(pause_btn, 0)

func _toggle_pause() -> void:
	if _paused:
		_hide_pause_overlay()
	else:
		_show_pause_overlay()

func _add_hero_power_button() -> void:
	var active_skill: SkillData = _get_active_skill()
	if active_skill == null:
		return
	_hero_power_btn = Button.new()
	_hero_power_btn.text = active_skill.display_name
	_hero_power_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.05)
	_hero_power_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
	_hero_power_btn.pressed.connect(_use_hero_power)
	$SidePanel.add_child(_hero_power_btn)

func _get_active_skill() -> SkillData:
	var result: SkillData = null
	for skill_id: String in SceneManager.save_manager.unlocked_skills:
		var sk: SkillData = SkillRegistry.get_skill(skill_id)
		if sk != null and sk.skill_type == "active":
			result = sk
	return result

func _use_hero_power() -> void:
	if _hero_power_used:
		return
	var active_skill: SkillData = _get_active_skill()
	if active_skill == null:
		return
	_hero_power_used = true
	if _hero_power_btn != null:
		_hero_power_btn.disabled = true
	var player: PlayerState = _state.players[0]
	var enemy: PlayerState = _state.players[1]
	match active_skill.effect_type:
		"active_damage_all":
			for card: CardInstance in enemy.board.get_cards().duplicate():
				card.health -= active_skill.effect_value
				if card.health <= 0:
					enemy.board.remove_card(card)
		"active_heal":
			player.hero.health = mini(
				player.hero.health + active_skill.effect_value,
				player.hero.max_health)
		"active_draw":
			for _i in active_skill.effect_value:
				player.draw_card()
			_flush_auto_spells(0)
		"active_mana":
			player.hero.mana = mini(
				player.hero.mana + active_skill.effect_value,
				player.hero.max_mana)
	_refresh_all()

func _show_pause_overlay() -> void:
	if _paused:
		return
	_paused = true
	get_tree().paused = true

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_pause_overlay = layer

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var panel_w: float = vp.x * 0.55
	var panel_h: float = _vh * 0.52
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.97)
	style.corner_radius_top_left    = 12
	style.corner_radius_top_right   = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vh * 0.03))
	margin.add_theme_constant_override("margin_right",  int(_vh * 0.03))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.03))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.03))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.025))
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", int(_vh * 0.05))
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(_vh * 0.3, _vh * 0.07)
	resume_btn.add_theme_font_size_override("font_size", int(_vh * 0.03))
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(_hide_pause_overlay)
	vbox.add_child(resume_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(_vh * 0.3, _vh * 0.07)
	settings_btn.add_theme_font_size_override("font_size", int(_vh * 0.03))
	settings_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_btn.pressed.connect(_open_settings_from_pause)
	vbox.add_child(settings_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(_vh * 0.3, _vh * 0.07)
	menu_btn.add_theme_font_size_override("font_size", int(_vh * 0.03))
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.pressed.connect(_confirm_return_to_menu)
	vbox.add_child(menu_btn)

func _hide_pause_overlay() -> void:
	if not _paused:
		return
	_paused = false
	get_tree().paused = false
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
	_pause_overlay = null

func _open_settings_from_pause() -> void:
	var overlay: SettingsScene = SettingsScene.new()
	_pause_overlay.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.closed.connect(overlay.queue_free)

func _confirm_return_to_menu() -> void:
	# Simple inline confirm dialog
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var dialog := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.05, 0.05, 0.98)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	dialog.add_theme_stylebox_override("panel", style)
	var dlg_w: float = vp.x * 0.5
	var dlg_h: float = _vh * 0.28
	dialog.custom_minimum_size = Vector2(dlg_w, dlg_h)
	dialog.position = Vector2((vp.x - dlg_w) * 0.5, (vp.y - dlg_h) * 0.5)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vh * 0.025))
	margin.add_theme_constant_override("margin_right",  int(_vh * 0.025))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.025))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.025))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.022))
	margin.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Return to menu?\nYour battle will be saved."
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.026))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(_vh * 0.03))
	vbox.add_child(row)

	var yes_btn := Button.new()
	yes_btn.text = "Yes, leave"
	yes_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.065)
	yes_btn.add_theme_font_size_override("font_size", int(_vh * 0.026))
	yes_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	yes_btn.pressed.connect(func() -> void:
		SceneManager.save_manager.set_pending_battle_state(_state.to_dict())
		SceneManager.save_manager.save()
		get_tree().paused = false
		SceneManager.go_to_menu()
	)
	row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.065)
	no_btn.add_theme_font_size_override("font_size", int(_vh * 0.026))
	no_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	no_btn.pressed.connect(dialog.queue_free)
	row.add_child(no_btn)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _state != null:
			SceneManager.save_manager.set_pending_battle_state(_state.to_dict())
			SceneManager.save_manager.save()
		if not _paused:
			_show_pause_overlay()

func _on_target_chosen_card(target: CardInstance) -> void:
	var spell := _targeting_spell
	_targeting_active = false
	_targeting_spell = null
	_hide_cancel_btn()
	if _state.players[0].play_card(spell):
		AudioManager.play_sfx("card_play")
		var snap_otc := _snapshot_hp_positions()
		_resolve_spell_effect(spell, 0, {"type": "minion", "card": target})
		_spawn_float_labels_from_snapshot(snap_otc)
		_flash_from_snapshot(snap_otc)
		_check_shake_from_snapshot(snap_otc)
	_refresh_all()
	_check_game_over()
	_dismiss_battle_tutorial()

func _on_target_chosen_hero() -> void:
	var spell := _targeting_spell
	_targeting_active = false
	_targeting_spell = null
	_hide_cancel_btn()
	if _state.players[0].play_card(spell):
		AudioManager.play_sfx("card_play")
		var snap_oth := _snapshot_hp_positions()
		_resolve_spell_effect(spell, 0, {"type": "hero"})
		_spawn_float_labels_from_snapshot(snap_oth)
		_flash_from_snapshot(snap_oth)
		_check_shake_from_snapshot(snap_oth)
	_refresh_all()
	_check_game_over()
	_dismiss_battle_tutorial()

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
	var name_lbl: Label = vbox.get_node_or_null("NameLabel") as Label if vbox else null
	var is_board_zone: bool = (zone_id == "board" or zone_id == "enemy_board")
	if not vbox or not name_lbl:
		for child in panel.get_children():
			child.queue_free()
		panel.add_child(_build_card_vbox(card, is_board_zone))
	else:
		name_lbl.text = card.name
		var stats_lbl: Label = vbox.get_node_or_null("StatsLabel") as Label
		if stats_lbl:
			if card.card_class == "spell":
				stats_lbl.text = "(%d)" % card.cost
			else:
				stats_lbl.text = "%d/%d  (%d)" % [card.attack, card.health, card.cost]
		var desc_lbl: Label = vbox.get_node_or_null("DescLabel") as Label
		if desc_lbl:
			var ability_text: String = _get_card_ability_text(card)
			if ability_text != "":
				desc_lbl.text = ability_text
				desc_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
			else:
				desc_lbl.text = card.description
				desc_lbl.remove_theme_color_override("font_color")
		var kw_row: HBoxContainer = vbox.get_node_or_null("KeywordRow") as HBoxContainer
		if kw_row:
			_update_keyword_badges(kw_row, card)
		if is_board_zone:
			var sr: HBoxContainer = vbox.get_node_or_null("StatusRow") as HBoxContainer
			if sr:
				_update_status_icons_card(sr, card)
			else:
				var new_sr := HBoxContainer.new()
				new_sr.name = "StatusRow"
				_update_status_icons_card(new_sr, card)
				vbox.add_child(new_sr)
	_apply_card_style(panel, card, zone_id)
	_bind_card_input(panel, card, zone_id)

func _get_card_ability_text(card: CardInstance) -> String:
	if card.card_class == "spell" and card.spell_effect != "":
		var tmpl: String = str(_SPELL_EFFECT_LABELS.get(card.spell_effect, card.spell_effect))
		return tmpl.replace("[power]", str(card.spell_power))
	return ""

func _build_card_vbox(card: CardInstance, with_status_row: bool = false) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = card.name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.013))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats_lbl := Label.new()
	stats_lbl.name = "StatsLabel"
	if card.card_class == "spell":
		stats_lbl.text = "(%d)" % card.cost
	else:
		stats_lbl.text = "%d/%d  (%d)" % [card.attack, card.health, card.cost]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	var ability_text: String = _get_card_ability_text(card)
	if ability_text != "":
		desc_lbl.text = ability_text
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	else:
		desc_lbl.text = card.description
	desc_lbl.add_theme_font_size_override("font_size", int(_vh * 0.011))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)
	vbox.add_child(stats_lbl)
	vbox.add_child(desc_lbl)
	var kw_row := HBoxContainer.new()
	kw_row.name = "KeywordRow"
	kw_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_update_keyword_badges(kw_row, card)
	vbox.add_child(kw_row)
	if with_status_row:
		var sr := HBoxContainer.new()
		sr.name = "StatusRow"
		_update_status_icons_card(sr, card)
		vbox.add_child(sr)
	return vbox

func _apply_card_style(panel: PanelContainer, card: CardInstance, zone_id: String) -> void:
	var style := StyleBoxFlat.new()
	var tmpl := CardRegistry.get_template(card.template_id)
	style.bg_color = tmpl.get("color", Color(0.3, 0.3, 0.3)) if not tmpl.is_empty() else Color(0.3, 0.3, 0.3)
	if zone_id == "hand" and not _state.players[0].can_play(card):
		style.bg_color = style.bg_color.darkened(0.5)
	elif zone_id == "enemy_board" and _targeting_active:
		style.border_color = Color.CYAN
		style.border_width_top = 4
		style.border_width_bottom = 4
		style.border_width_left = 4
		style.border_width_right = 4
	elif zone_id == "enemy_board" and not _dragged_card.is_empty():
		# Ward: dim minions that cannot be targeted while a Ward minion is alive
		var valid_targets := _get_ward_valid_targets(_state.players[1].board.get_cards())
		if not valid_targets.has(card):
			style.bg_color = style.bg_color.darkened(0.45)
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
	for conn in panel.gui_input.get_connections():
		panel.gui_input.disconnect(conn["callable"])
	if zone_id == "hand" and _state.current_player_idx == 0:
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_hand_card_input(event, card, panel))
	elif zone_id == "board" and _state.current_player_idx == 0:
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_board_card_input(event, card))
	elif zone_id == "enemy_board":
		panel.gui_input.connect(func(event: InputEvent) -> void: _on_enemy_card_input(event, card))
	# Right-click inspect works in all zones always
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_card_inspect(card)
	)

func _make_card_view(card: CardInstance, zone_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_vh * 0.09, _vh * 0.15)
	var is_board_zone: bool = (zone_id == "board" or zone_id == "enemy_board")
	panel.add_child(_build_card_vbox(card, is_board_zone))
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
		if is_enemy:
			if bool(enemy_data.get("is_boss", false)):
				name_lbl.text = EnemyRegistry.get_display_name(str(enemy_data.get("enemy_type", "")))
			else:
				name_lbl.text = "ENEMY"
		else:
			name_lbl.text = "YOU"
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
		var hero_sr := HBoxContainer.new()
		hero_sr.name = "StatusRow"
		vbox.add_child(hero_sr)
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
	var hero_status_row: HBoxContainer = vbox.get_node_or_null("StatusRow") as HBoxContainer
	if hero_status_row:
		_update_status_icons_hero(hero_status_row, hero)

	# Styling
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	var ward_blocks_hero: bool = false
	if is_enemy and not _dragged_card.is_empty():
		for ec: CardInstance in _state.players[1].board.get_cards():
			if ec.keywords.has(Keywords.WARD):
				ward_blocks_hero = true
				break
	var is_attack_targetable: bool = is_enemy and not _dragged_card.is_empty() and not ward_blocks_hero
	var is_spell_targetable: bool = is_enemy and _targeting_active
	if is_enemy:
		if is_spell_targetable:
			style.bg_color = Color(0.1, 0.35, 0.45)
			style.border_color = Color.CYAN
			style.border_width_top    = 4
			style.border_width_bottom = 4
			style.border_width_left   = 4
			style.border_width_right  = 4
		elif is_attack_targetable:
			style.bg_color = Color(0.55, 0.15, 0.1)
			style.border_color = Color(1.0, 0.35, 0.2)
			style.border_width_top    = 3
			style.border_width_bottom = 3
			style.border_width_left   = 3
			style.border_width_right  = 3
		else:
			style.bg_color = Color(0.45, 0.1, 0.1)
	else:
		style.bg_color = Color(0.1, 0.2, 0.4)
	hero_node.add_theme_stylebox_override("panel", style)

func _update_status() -> void:
	var player := _state.players[0]
	_turn_label.text = "Turn %d" % _state.turn_number
	_mana_label.text = "Mana: %d/%d" % [player.hero.mana, player.hero.max_mana]
	_end_turn_btn.disabled = _state.current_player_idx != 0 or _ai_thinking

# -------------------------------------------------------------------------
# Ward targeting helper
# -------------------------------------------------------------------------

# Returns only Ward minions from cards if any exist, otherwise all cards.
func _get_ward_valid_targets(cards: Array[CardInstance]) -> Array[CardInstance]:
	var ward: Array[CardInstance] = []
	for c: CardInstance in cards:
		if c.keywords.has(Keywords.WARD):
			ward.append(c)
	return ward if not ward.is_empty() else cards

# Clears hbox and adds one colored Label per active keyword. Shroud hidden when consumed.
func _update_keyword_badges(hbox: HBoxContainer, card: CardInstance) -> void:
	for child in hbox.get_children():
		child.queue_free()
	var kw_keys: Array[String]  = [Keywords.WARD, Keywords.SURGE, Keywords.SHROUD]
	var kw_labels: Array[String] = ["Ward",        "Surge",        "Shroud"]
	var kw_colors: Array[Color]  = [
		Color(0.35, 0.5, 1.0),
		Color(1.0,  0.6, 0.15),
		Color(0.8,  0.8, 0.88),
	]
	var font_sz: int = int(_vh * 0.018)
	for i in range(kw_keys.size()):
		var kw: String = kw_keys[i]
		if not card.keywords.has(kw):
			continue
		if kw == Keywords.SHROUD and not card.shroud_active:
			continue
		var lbl := Label.new()
		lbl.text = kw_labels[i]
		lbl.add_theme_font_size_override("font_size", font_sz)
		lbl.add_theme_color_override("font_color", kw_colors[i])
		hbox.add_child(lbl)

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
		if _targeting_active:
			_on_target_chosen_card(target)
			return
		if _dragged_card.is_empty():
			return
		var attacker: CardInstance = _dragged_card["card"]
		if not attacker.can_attack():
			_dragged_card.clear()
			return
		# Ward: if any enemy minion has Ward, only those are valid targets
		var valid_targets := _get_ward_valid_targets(_state.players[1].board.get_cards())
		if not valid_targets.has(target):
			return  # keep attacker selected; player must click a Ward minion
		AudioManager.play_sfx("attack")
		var target_panel_ec := _get_card_panel(target, true)
		var attacker_panel_ec := _get_card_panel(attacker, false)
		var snap_ec := _snapshot_hp_positions()
		target.take_damage(attacker.attack)
		attacker.take_damage(target.attack)
		attacker.attack_count -= 1
		_flash_node(target_panel_ec, Color(1.0, 0.3, 0.3, 1.0))
		_flash_node(attacker_panel_ec, Color(1.0, 0.3, 0.3, 1.0))
		if not target.is_alive():
			_state.players[1].board.remove_card(target)
			_state.players[1].discard.append(target)
		if not attacker.is_alive():
			_state.players[0].board.remove_card(attacker)
			_state.players[0].discard.append(attacker)
		_spawn_float_labels_from_snapshot(snap_ec)
		_check_shake_from_snapshot(snap_ec)
		_dragged_card.clear()
		_refresh_all()
		_check_game_over()

func _on_enemy_hero_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _targeting_active:
			_on_target_chosen_hero()
			return
		if _state.current_player_idx != 0 or _ai_thinking:
			return
		if _dragged_card.is_empty():
			return
		var attacker: CardInstance = _dragged_card["card"]
		if not attacker.can_attack():
			_dragged_card.clear()
			_refresh_all()
			return
		# Ward: cannot attack hero while any Ward minion is alive on enemy board
		for ec: CardInstance in _state.players[1].board.get_cards():
			if ec.keywords.has(Keywords.WARD):
				return  # keep attacker selected; player must target the Ward minion
		AudioManager.play_sfx("attack")
		var attacker_panel_eh := _get_card_panel(attacker, false)
		var snap_eh := _snapshot_hp_positions()
		_state.players[1].hero.take_damage(attacker.attack)
		attacker.take_damage(_state.players[1].hero.attack)
		attacker.attack_count -= 1
		_flash_node(_enemy_hero_view, Color(1.0, 0.3, 0.3, 1.0))
		_flash_node(attacker_panel_eh, Color(1.0, 0.3, 0.3, 1.0))
		if not attacker.is_alive():
			_state.players[0].board.remove_card(attacker)
			_state.players[0].discard.append(attacker)
		_spawn_float_labels_from_snapshot(snap_eh)
		_check_shake_from_snapshot(snap_eh)
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
	var snap_sot := _snapshot_hp_positions()
	_process_start_of_turn_statuses(player_idx)
	_spawn_float_labels_from_snapshot(snap_sot)
	_flash_from_snapshot(snap_sot)
	_check_shake_from_snapshot(snap_sot)
	_refresh_all()
	if player_idx == 0:
		_check_game_over()
		if not _state.is_game_over():
			AudioManager.play_sfx("card_draw")
			var snap_as := _snapshot_hp_positions()
			_flush_auto_spells(0)
			_spawn_float_labels_from_snapshot(snap_as)
			_flash_from_snapshot(snap_as)
			_check_shake_from_snapshot(snap_as)
			_refresh_all()
			_check_game_over()
	elif player_idx == 1:
		_check_game_over()
		if not _state.is_game_over():
			_run_ai_turn()

func _run_ai_turn() -> void:
	_ai_thinking = true
	_end_turn_btn.disabled = true
	var actions := BasicAI.decide_turn(_state)
	_show_intent_banner(BasicAI.describe_turn(_state))
	await get_tree().create_timer(1.5, true).timeout
	_execute_ai_actions(actions, 0)

func _execute_ai_actions(actions: Array[Callable], idx: int) -> void:
	if idx >= actions.size():
		_hide_intent_banner()
		await get_tree().create_timer(0.5, true).timeout
		_ai_thinking = false
		_state.end_turn()
		_refresh_all()
		_check_game_over()
		return
	AudioManager.play_sfx("attack")
	var snap_ai := _snapshot_hp_positions()
	actions[idx].call()
	_spawn_float_labels_from_snapshot(snap_ai)
	_flash_from_snapshot(snap_ai)
	_check_shake_from_snapshot(snap_ai)
	_refresh_all()
	await get_tree().create_timer(0.6, true).timeout
	_execute_ai_actions(actions, idx + 1)

## Resolves the effect of a spell card played by caster_pid against the opponent.
## explicit_target: optional dict with "type" ("minion"/"hero") and "card" (CardInstance) for targeted spells.
func _resolve_spell_effect(card: CardInstance, caster_pid: int, explicit_target: Dictionary = {}) -> void:
	AudioManager.play_sfx("spell_resolve")
	var opponent: PlayerState = _state.players[1 - caster_pid]
	match card.spell_effect:
		"deal_damage_single":
			var target_card: CardInstance = explicit_target.get("card", null) as CardInstance
			if target_card != null:
				target_card.take_damage(card.spell_power)
				if not target_card.is_alive():
					opponent.board.remove_card(target_card)
					opponent.discard.append(target_card)
			elif explicit_target.get("type", "") == "hero":
				opponent.hero.take_damage(card.spell_power)
			else:
				var targets := opponent.board.get_cards()
				if targets.is_empty():
					opponent.hero.take_damage(card.spell_power)
				else:
					targets[0].take_damage(card.spell_power)
					if not targets[0].is_alive():
						opponent.board.remove_card(targets[0])
						opponent.discard.append(targets[0])
		"deal_damage_all":
			for t in opponent.board.get_cards():
				t.take_damage(card.spell_power)
			for t in opponent.board.get_cards().duplicate():
				if not t.is_alive():
					opponent.board.remove_card(t)
					opponent.discard.append(t)
		"deal_damage_random":
			var targets := opponent.board.get_cards()
			if targets.is_empty():
				opponent.hero.take_damage(card.spell_power)
			else:
				var idx: int = randi() % targets.size()
				targets[idx].take_damage(card.spell_power)
				if not targets[idx].is_alive():
					opponent.board.remove_card(targets[idx])
					opponent.discard.append(targets[idx])
		"debuff_attack":
			for t in opponent.board.get_cards():
				t.attack = maxi(0, t.attack - card.spell_power)
		"destroy_low_hp":
			for t in opponent.board.get_cards().duplicate():
				if t.health <= card.spell_power:
					opponent.board.remove_card(t)
					opponent.discard.append(t)
		"resurrect_last":
			var caster: PlayerState = _state.players[caster_pid]
			for i in range(caster.discard.size() - 1, -1, -1):
				var t := caster.discard[i] as CardInstance
				if t.card_class == "minion" and not caster.board.is_full():
					t.health = t.max_health
					t.summoning_sick = true
					caster.board.add_card(t)
					caster.discard.remove_at(i)
					break
		"heal_single":
			var caster: PlayerState = _state.players[caster_pid]
			var friendlies := caster.board.get_cards()
			if not friendlies.is_empty():
				var t := friendlies[0]
				t.health = mini(t.max_health, t.health + card.spell_power)
		"heal_all":
			var caster: PlayerState = _state.players[caster_pid]
			for t in caster.board.get_cards():
				t.health = mini(t.max_health, t.health + card.spell_power)
		"shield_minion":
			var caster: PlayerState = _state.players[caster_pid]
			var friendlies := caster.board.get_cards()
			if not friendlies.is_empty():
				friendlies[0].armor += card.spell_power
		"buff_attack":
			var caster: PlayerState = _state.players[caster_pid]
			var friendlies := caster.board.get_cards()
			if not friendlies.is_empty():
				friendlies[0].attack += card.spell_power
		"lifesteal_hit":
			var caster: PlayerState = _state.players[caster_pid]
			var targets := opponent.board.get_cards()
			if not targets.is_empty():
				targets[0].take_damage(card.spell_power)
				caster.hero.health = mini(caster.hero.max_health, caster.hero.health + card.spell_power)
				if not targets[0].is_alive():
					opponent.board.remove_card(targets[0])
					opponent.discard.append(targets[0])
		"mana_drain":
			opponent.hero.mana = maxi(0, opponent.hero.mana - card.spell_power)
		"curse_minion":
			var targets := opponent.board.get_cards()
			if not targets.is_empty():
				var t := targets[0]
				t.attack = maxi(0, t.attack - card.spell_power)
				t.health -= card.spell_power
				if not t.is_alive():
					opponent.board.remove_card(t)
					opponent.discard.append(t)
		"draw_card":
			var caster: PlayerState = _state.players[caster_pid]
			for _i in range(card.spell_power):
				caster.draw_card()

## Drains pending_auto_spells for the given player and resolves each.
## Called after any draw event (opening hand, turn draw).
func _flush_auto_spells(player_idx: int) -> void:
	var player: PlayerState = _state.players[player_idx]
	while not player.pending_auto_spells.is_empty():
		var card: CardInstance = player.pending_auto_spells.pop_front() as CardInstance
		_resolve_spell_effect(card, player_idx)

func _show_boss_banner() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = int(_vh * 0.045)
	var enemy_type: String = str(enemy_data.get("enemy_type", ""))
	var lbl := Label.new()
	lbl.text = "* %s *" % EnemyRegistry.get_display_name(enemy_type)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(vp.x, font_size * 2)
	lbl.position = Vector2(0.0, _vh * 0.08)
	add_child(lbl)
	move_child(lbl, get_child_count() - 1)
	if _boss_banner != null and is_instance_valid(_boss_banner):
		_boss_banner.queue_free()
	_boss_banner = lbl
	_boss_banner_timer = _BOSS_BANNER_DURATION

func _check_boss_phase2() -> void:
	if _boss_phase2_triggered:
		return
	if not bool(enemy_data.get("is_boss", false)):
		return
	var p2_raw: Array = enemy_data.get("phase2_deck", [])
	if p2_raw.is_empty():
		return
	var enemy_hero := _state.players[1].hero
	if enemy_hero.health > enemy_hero.max_health / 2:
		return
	_boss_phase2_triggered = true
	var p2_deck: Array[String] = []
	p2_deck.assign(p2_raw)
	var p2_enemy_type: String = str(enemy_data.get("enemy_type", ""))
	var p2_tier: int = 4 if bool(enemy_data.get("is_boss", false)) else EnemyRegistry.get_difficulty_tier(p2_enemy_type)
	_state.players[1].build_deck(p2_deck, p2_tier)
	_state.players[1].draw_opening_hand(4)
	_refresh_all()
	# Show phase 2 announcement banner
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = int(_vh * 0.04)
	var lbl := Label.new()
	lbl.text = "- PHASE 2 -"
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(vp.x, font_size * 2)
	lbl.position = Vector2(0.0, _vh * 0.4)
	add_child(lbl)
	move_child(lbl, get_child_count() - 1)
	if _boss_banner != null and is_instance_valid(_boss_banner):
		_boss_banner.queue_free()
	_boss_banner = lbl
	_boss_banner_timer = _BOSS_BANNER_DURATION

func _check_game_over() -> void:
	_check_boss_phase2()
	if _state.is_game_over():
		var w := _state.winner()
		if w == 0:
			AudioManager.play_sfx("battle_win")
			var enemy_type: String = str(enemy_data.get("enemy_type", "undead_basic"))
			var pool: Array[String] = EnemyRegistry.get_drop_pool(enemy_type)
			if bool(enemy_data.get("is_boss", false)):
				var weapon_pool: Array[String] = []
				for pid in pool:
					if WeaponRegistry.has_weapon(pid):
						weapon_pool.append(pid)
				if weapon_pool.is_empty():
					var all_ids: Array[String] = WeaponRegistry.get_all_ids()
					var owned_w: Array[String] = SceneManager.save_manager.owned_weapons
					for wid in all_ids:
						if not owned_w.has(wid):
							weapon_pool.append(wid)
				var weapon_reward_id: String = ""
				if not weapon_pool.is_empty():
					weapon_reward_id = weapon_pool[randi() % weapon_pool.size()]
				_show_victory_overlay_boss(pool, weapon_reward_id)
			else:
				var reward_card_id: String = ""
				if pool.size() > 0:
					reward_card_id = pool[randi() % pool.size()]
				_show_victory_overlay(reward_card_id, "")
		else:
			AudioManager.play_sfx("battle_lose")
			GameBus.battle_lost.emit()

func _show_victory_overlay(reward_card_id: String, weapon_reward_id: String = "") -> void:
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

	if weapon_reward_id != "":
		var weapon: WeaponData = WeaponRegistry.get_weapon(weapon_reward_id)
		var weapon_lbl := Label.new()
		var wname: String = weapon.display_name if weapon != null else weapon_reward_id
		weapon_lbl.text = "Weapon found: " + wname
		weapon_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
		weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_lbl.modulate = Color(0.8, 1.0, 0.5)
		vbox.add_child(weapon_lbl)

	var btn := Button.new()
	btn.text = "Collect" if (reward_card_id != "" or weapon_reward_id != "") else "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	var final_card: String = reward_card_id
	var final_weapon: String = weapon_reward_id
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.battle_won.emit({"card_reward": final_card, "weapon_reward": final_weapon})
	)
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)

func _show_victory_overlay_boss(reward_cards: Array[String], weapon_reward_id: String = "") -> void:
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(_vh * 0.025))

	var title_lbl := Label.new()
	title_lbl.text = "Boss Defeated!"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.06))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.75, 0.0)
	vbox.add_child(title_lbl)

	var rewards_lbl := Label.new()
	if reward_cards.is_empty():
		rewards_lbl.text = "No cards dropped."
	else:
		var names: PackedStringArray = PackedStringArray()
		for cid in reward_cards:
			var tmpl: Dictionary = CardRegistry.get_template(cid)
			names.append(str(tmpl.get("name", cid)))
		rewards_lbl.text = "Rewards: " + ", ".join(names)
	rewards_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	rewards_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(rewards_lbl)

	if weapon_reward_id != "":
		var weapon: WeaponData = WeaponRegistry.get_weapon(weapon_reward_id)
		var weapon_lbl := Label.new()
		var wname: String = weapon.display_name if weapon != null else weapon_reward_id
		weapon_lbl.text = "Weapon found: " + wname
		weapon_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
		weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_lbl.modulate = Color(0.8, 1.0, 0.5)
		vbox.add_child(weapon_lbl)

	var btn := Button.new()
	btn.text = "Collect" if (not reward_cards.is_empty() or weapon_reward_id != "") else "Continue"
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.06)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	var final_rewards: Array[String] = []
	final_rewards.assign(reward_cards)
	var final_weapon: String = weapon_reward_id
	btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameBus.battle_won.emit({"card_rewards": final_rewards, "weapon_reward": final_weapon})
	)
	vbox.add_child(btn)

	overlay.add_child(vbox)
	add_child(overlay)

# -------------------------------------------------------------------------
# Enemy intent banner (TID-059)
# -------------------------------------------------------------------------

func _show_intent_banner(text: String) -> void:
	_hide_intent_banner()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.88)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	add_child(panel)
	panel.reset_size()
	var sz: Vector2 = panel.get_minimum_size()
	panel.position = Vector2((vp.x - sz.x) * 0.5, vp.y * 0.35)
	move_child(panel, get_child_count() - 1)
	_intent_panel = panel

func _hide_intent_banner() -> void:
	if _intent_panel != null and is_instance_valid(_intent_panel):
		_intent_panel.queue_free()
	_intent_panel = null

# -------------------------------------------------------------------------
# Status effect turn processing (TID-061)
# -------------------------------------------------------------------------

func _process_start_of_turn_statuses(player_idx: int) -> void:
	var player: PlayerState = _state.players[player_idx]
	for card in player.board.get_cards():
		_tick_statuses_on_card(card)
	_tick_statuses_on_hero(player.hero, player_idx)

func _tick_statuses_on_card(card: CardInstance) -> void:
	if card.has_status("poison"):
		var dmg: int = card.get_status_value("poison")
		card.take_damage(dmg)
		var nv: int = dmg - 1
		if nv <= 0:
			card.clear_status("poison")
		else:
			card.apply_status("poison", nv)
		GameBus.status_ticked.emit(card.instance_id, "poison", maxi(nv, 0))
	if card.has_status("freeze"):
		var dur: int = card.get_status_value("freeze") - 1
		if dur <= 0:
			card.clear_status("freeze")
		else:
			card.apply_status("freeze", dur)
		GameBus.status_ticked.emit(card.instance_id, "freeze", maxi(dur, 0))
	# Stun on minions is decremented via out_of_play in CardInstance.start_turn()

func _tick_statuses_on_hero(hero: HeroState, player_idx: int) -> void:
	var hid: String = "hero_%d" % player_idx
	if hero.has_status("poison"):
		var dmg: int = hero.get_status_value("poison")
		hero.take_damage(dmg)
		var nv: int = dmg - 1
		if nv <= 0:
			hero.clear_status("poison")
		else:
			hero.apply_status("poison", nv)
		GameBus.status_ticked.emit(hid, "poison", maxi(nv, 0))
	if hero.has_status("freeze"):
		var dur: int = hero.get_status_value("freeze") - 1
		if dur <= 0:
			hero.clear_status("freeze")
		else:
			hero.apply_status("freeze", dur)
		GameBus.status_ticked.emit(hid, "freeze", maxi(dur, 0))
	if hero.has_status("stun"):
		var dur: int = hero.get_status_value("stun") - 1
		if dur <= 0:
			hero.clear_status("stun")
		else:
			hero.apply_status("stun", dur)
		GameBus.status_ticked.emit(hid, "stun", maxi(dur, 0))

# -------------------------------------------------------------------------
# Status effect UI icons (TID-062)
# -------------------------------------------------------------------------

func _update_status_icons_card(hbox: HBoxContainer, card: CardInstance) -> void:
	for child in hbox.get_children():
		child.queue_free()
	var effects: Array[String] = ["poison", "armor", "freeze", "stun"]
	var colors: Array[Color] = [Color.GREEN, Color.CORNFLOWER_BLUE, Color.CYAN, Color.YELLOW]
	var abbrevs: Array[String] = ["P", "A", "F", "S"]
	var icon_sz: float = _vh * 0.022
	for i in range(effects.size()):
		if not card.has_status(effects[i]):
			continue
		var lbl := Label.new()
		lbl.text = "%s%d" % [abbrevs[i], card.get_status_value(effects[i])]
		lbl.add_theme_color_override("font_color", colors[i])
		lbl.add_theme_font_size_override("font_size", int(icon_sz))
		hbox.add_child(lbl)

func _update_status_icons_hero(hbox: HBoxContainer, hero: HeroState) -> void:
	for child in hbox.get_children():
		child.queue_free()
	var effects: Array[String] = ["poison", "armor", "freeze", "stun"]
	var colors: Array[Color] = [Color.GREEN, Color.CORNFLOWER_BLUE, Color.CYAN, Color.YELLOW]
	var abbrevs: Array[String] = ["P", "A", "F", "S"]
	var icon_sz: float = _vh * 0.022
	for i in range(effects.size()):
		if not hero.has_status(effects[i]):
			continue
		var lbl := Label.new()
		lbl.text = "%s%d" % [abbrevs[i], hero.get_status_value(effects[i])]
		lbl.add_theme_color_override("font_color", colors[i])
		lbl.add_theme_font_size_override("font_size", int(icon_sz))
		hbox.add_child(lbl)

# -------------------------------------------------------------------------
# Floating damage / heal numbers (TID-077)
# -------------------------------------------------------------------------

func _pos_of_hero(is_enemy: bool) -> Vector2:
	var hv: Control = _enemy_hero_view if is_enemy else _player_hero_view
	return hv.get_global_rect().get_center()

func _snapshot_hp_positions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(2):
		var hero := _state.players[i].hero
		result.append({"id": "hero_%d" % i, "hp": hero.health, "pos": _pos_of_hero(i == 1)})
		var cards: Array[CardInstance] = _state.players[i].board.get_cards()
		var zv: Node = _enemy_board_view if i == 1 else _player_board_view
		for j in range(cards.size()):
			var panel: Control = zv.get_child(j) as Control if j < zv.get_child_count() else null
			var fallback: Vector2 = get_viewport().get_visible_rect().size * 0.5
			var pos: Vector2 = panel.get_global_rect().get_center() if panel != null else fallback
			result.append({"id": cards[j].instance_id, "hp": cards[j].health, "pos": pos})
	return result

func _spawn_float_labels_from_snapshot(snap: Array[Dictionary]) -> void:
	var cur_hp: Dictionary = {}
	for i in range(2):
		cur_hp["hero_%d" % i] = _state.players[i].hero.health
		for c: CardInstance in _state.players[i].board.get_cards():
			cur_hp[c.instance_id] = c.health
	for entry: Dictionary in snap:
		var eid: String = str(entry["id"])
		var hp_before: int = int(entry["hp"])
		var pos: Vector2 = entry["pos"] as Vector2
		var hp_after: int = 0
		if cur_hp.has(eid):
			hp_after = int(cur_hp[eid])
		var diff: int = hp_after - hp_before
		if diff < 0:
			_spawn_float_label(pos, str(diff), Color(1.0, 0.267, 0.267))
		elif diff > 0:
			_spawn_float_label(pos, "+%d" % diff, Color(0.267, 1.0, 0.533))

func _spawn_float_label(pos: Vector2, text: String, color: Color) -> void:
	if _float_layer == null or not is_instance_valid(_float_layer):
		return
	var font_sz: int = int(_vh * 0.035) if _vh > 0.0 else 18
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = pos - Vector2(15.0, 10.0)
	_float_layer.add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 70.0, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(lbl.queue_free)

# -------------------------------------------------------------------------
# Hit flash (TID-078)
# -------------------------------------------------------------------------

func _get_card_panel(card: CardInstance, is_enemy: bool) -> Control:
	var player: PlayerState = _state.players[1] if is_enemy else _state.players[0]
	var zv: Node = _enemy_board_view if is_enemy else _player_board_view
	var cards: Array[CardInstance] = player.board.get_cards()
	for j in range(cards.size()):
		if cards[j] == card:
			if j < zv.get_child_count():
				return zv.get_child(j) as Control
			break
	return null

func _flash_node(node: Control, flash_color: Color) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "modulate", flash_color, 0.0)
	tw.tween_property(node, "modulate", Color.WHITE, 0.25)

func _flash_from_snapshot(snap: Array[Dictionary]) -> void:
	var cur_hp: Dictionary = {}
	for i in range(2):
		cur_hp["hero_%d" % i] = _state.players[i].hero.health
		for c: CardInstance in _state.players[i].board.get_cards():
			cur_hp[c.instance_id] = c.health
	for entry: Dictionary in snap:
		var eid: String = str(entry["id"])
		var hp_before: int = int(entry["hp"])
		if not cur_hp.has(eid):
			continue
		var hp_after: int = int(cur_hp[eid])
		if hp_after == hp_before:
			continue
		var flash_color: Color = Color(1.0, 0.3, 0.3, 1.0) if hp_after < hp_before else Color(0.3, 1.0, 0.5, 1.0)
		if eid.begins_with("hero_"):
			var hv: Control = _enemy_hero_view if eid == "hero_1" else _player_hero_view
			_flash_node(hv, flash_color)
		else:
			var found_panel: bool = false
			for pi in range(2):
				if found_panel:
					break
				var cards: Array[CardInstance] = _state.players[pi].board.get_cards()
				var zv: Node = _enemy_board_view if pi == 1 else _player_board_view
				for j in range(cards.size()):
					if cards[j].instance_id == eid:
						var panel: Control = zv.get_child(j) as Control if j < zv.get_child_count() else null
						if panel != null:
							_flash_node(panel, flash_color)
						found_panel = true
						break

# -------------------------------------------------------------------------
# Screen shake (TID-079)
# -------------------------------------------------------------------------

func _trigger_shake(magnitude: float, duration: float) -> void:
	if _is_shaking:
		return
	_is_shaking = true
	var origin: Vector2 = position
	var tw: Tween = create_tween()
	var steps: int = maxi(2, int(duration / 0.05))
	for _i in range(steps):
		var ox: float = randf_range(-magnitude, magnitude)
		var oy: float = randf_range(-magnitude, magnitude)
		tw.tween_property(self, "position", origin + Vector2(ox, oy), 0.05)
	tw.tween_property(self, "position", origin, 0.05)
	tw.tween_callback(func() -> void: _is_shaking = false)

func _check_shake_from_snapshot(snap: Array[Dictionary]) -> void:
	var cur_hp: Dictionary = {}
	for i in range(2):
		cur_hp["hero_%d" % i] = _state.players[i].hero.health
		for c: CardInstance in _state.players[i].board.get_cards():
			cur_hp[c.instance_id] = c.health
	var hero_died: bool = false
	var max_dmg: int = 0
	for entry: Dictionary in snap:
		var eid: String = str(entry["id"])
		var hp_before: int = int(entry["hp"])
		var hp_after: int = 0
		if cur_hp.has(eid):
			hp_after = int(cur_hp[eid])
		var dmg: int = hp_before - hp_after
		if dmg > max_dmg:
			max_dmg = dmg
		if eid.begins_with("hero_") and hp_before > 0 and hp_after == 0:
			hero_died = true
	if hero_died:
		_trigger_shake(10.0, 0.35)
	elif max_dmg >= 5:
		_trigger_shake(5.0, 0.2)
