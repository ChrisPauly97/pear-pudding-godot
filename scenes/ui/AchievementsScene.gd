extends Control

const AchievementRegistry = preload("res://game_logic/AchievementRegistry.gd")

signal closed

var _vh: float = 0.0
var _vw: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = minf(_vw * 0.92, _vh * 0.75)
	var panel_h: float = _vh * 0.88

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.015))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.015))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.015))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.015))
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_vh * 0.012))
	margin.add_child(root_vbox)

	# Title + close row
	var header_row := HBoxContainer.new()
	root_vbox.add_child(header_row)

	var title := Label.new()
	title.text = "Achievements"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", int(_vh * 0.038))
	header_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(_vh * 0.065, _vh * 0.065)
	close_btn.add_theme_font_size_override("font_size", int(_vh * 0.024))
	close_btn.pressed.connect(_on_close)
	header_row.add_child(close_btn)

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(_vh * 0.010))
	scroll.add_child(list)

	var unlocked: Array[String] = SceneManager.save_manager.unlocked_achievements
	var progress: Dictionary = SceneManager.save_manager.achievement_progress

	for a: Dictionary in AchievementRegistry.get_all():
		var aid: String = str(a["id"])
		var is_unlocked: bool = unlocked.has(aid)
		var row := _make_row(a, is_unlocked, int(progress.get(aid, 0)))
		list.add_child(row)

func _make_row(a: Dictionary, is_unlocked: bool, current: int) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left",   int(_vw * 0.01))
	inner.add_theme_constant_override("margin_right",  int(_vw * 0.01))
	inner.add_theme_constant_override("margin_top",    int(_vh * 0.008))
	inner.add_theme_constant_override("margin_bottom", int(_vh * 0.008))
	row.add_child(inner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(_vw * 0.010))
	inner.add_child(hbox)

	# Lock / check icon
	var icon := Label.new()
	icon.text = "[OK]" if is_unlocked else "[  ]"
	icon.add_theme_font_size_override("font_size", int(_vh * 0.022))
	icon.modulate = Color(0.3, 1.0, 0.3) if is_unlocked else Color(0.5, 0.5, 0.5)
	hbox.add_child(icon)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", int(_vh * 0.003))
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	name_lbl.text = str(a.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	if not is_unlocked:
		name_lbl.modulate = Color(0.55, 0.55, 0.55)
	text_vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(a.get("description", ""))
	desc_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	desc_lbl.modulate = Color(0.65, 0.65, 0.65)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_vbox.add_child(desc_lbl)

	# Progress
	var target: int = int(a.get("target_value", 1))
	if target > 1 and not is_unlocked:
		var prog_lbl := Label.new()
		prog_lbl.text = "%d / %d" % [mini(current, target), target]
		prog_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		prog_lbl.modulate = Color(0.7, 0.85, 1.0)
		text_vbox.add_child(prog_lbl)

	# Reward indicator
	var reward_id: String = str(a.get("reward_card_id", ""))
	if reward_id != "":
		var reward_lbl := Label.new()
		reward_lbl.text = "Reward: Legendary card"
		reward_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		reward_lbl.modulate = Color(1.0, 0.8, 0.2) if is_unlocked else Color(0.5, 0.4, 0.1)
		text_vbox.add_child(reward_lbl)

	return row

func _on_close() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
