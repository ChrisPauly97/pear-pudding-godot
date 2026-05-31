extends Control

signal closed

const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")

var _vh: float = 0.0
var _vw: float = 0.0
var _points_label: Label
var _grid: GridContainer

const _ROWS: int = 3
const _COLS: int = 5

const MAGIC_BRANCHES: Dictionary = {
	"light": ["ember", "dawn"],
	"dark":  ["dusk",  "ash"],
}

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	if SceneManager.save_manager.magic_type == "":
		_build_magic_choice()
	else:
		_build_ui()
		_refresh()

# -------------------------------------------------------------------------
# Magic type selection modal (shown once if magic_type is unset)
# -------------------------------------------------------------------------

func _build_magic_choice() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = _vw * 0.82
	var panel_h: float = _vh * 0.72

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.04))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.04))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.04))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.04))
	outer.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * 0.025))
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Choose Your Path"
	title.add_theme_font_size_override("font_size", int(_vh * 0.045))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "This choice is permanent. Your skill trees will be drawn from the magic type you select."
	sub.add_theme_font_size_override("font_size", int(_vh * 0.019))
	sub.modulate = Color(0.72, 0.72, 0.72)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(_vw * 0.05))
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	hbox.add_child(_make_choice_column(
		"Light", Color(1.0, 1.0, 0.55),
		"Ember & Dawn\nFire, healing, and clarity",
		"Choose Light", "light"))
	hbox.add_child(_make_choice_column(
		"Dark", Color(0.75, 0.5, 1.0),
		"Dusk & Ash\nShadow, drain, and disruption",
		"Choose Dark", "dark"))

func _make_choice_column(header: String, header_color: Color, desc: String,
		btn_label: String, choice: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(_vh * 0.014))

	var lbl := Label.new()
	lbl.text = header
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.034))
	lbl.modulate = header_color
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
	desc_lbl.modulate = Color(0.8, 0.8, 0.8)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(_vw * 0.28, 0)
	col.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = btn_label
	btn.custom_minimum_size = Vector2(_vw * 0.28, _vh * 0.07)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.024))
	btn.modulate = header_color
	btn.pressed.connect(_on_magic_chosen.bind(choice))
	col.add_child(btn)

	return col

func _on_magic_chosen(choice: String) -> void:
	SceneManager.save_manager.set_magic_type(choice)
	for child in get_children():
		child.queue_free()
	_build_ui()
	_refresh()

# -------------------------------------------------------------------------
# Helpers (used by both this task and TID-119 tab UI)
# -------------------------------------------------------------------------

func _opposing_magic(mt: String) -> String:
	return "dark" if mt == "light" else "light"

# -------------------------------------------------------------------------
# Main skill tree UI
# -------------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = _vw * 0.94
	var panel_h: float = _vh * 0.90

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
	root_vbox.add_theme_constant_override("separation", int(_vh * 0.015))
	margin.add_child(root_vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(_vw * 0.02))
	root_vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "Skill Tree"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.035))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", int(_vh * 0.025))
	_points_label.modulate = Color(1.0, 0.85, 0.2)
	header.add_child(_points_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(_vh * 0.12, _vh * 0.05)
	close_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	close_btn.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_btn)

	# Skill grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = _COLS
	_grid.add_theme_constant_override("h_separation", int(_vw * 0.01))
	_grid.add_theme_constant_override("v_separation", int(_vh * 0.015))
	scroll.add_child(_grid)

func _refresh() -> void:
	_points_label.text = "Skill Points: %d" % SceneManager.save_manager.skill_points

	for child in _grid.get_children():
		child.queue_free()

	# Build skill lookup by (row, col)
	var skill_map: Dictionary = {}  # "row,col" -> SkillData
	for sid: String in SkillRegistry.get_all_ids():
		var sk: SkillData = SkillRegistry.get_skill(sid)
		if sk != null:
			skill_map["%d,%d" % [sk.tree_row, sk.tree_col]] = sk

	var node_w: float = _vh * 0.18
	var node_h: float = _vh * 0.20

	for r in _ROWS:
		for c in _COLS:
			var key: String = "%d,%d" % [r, c]
			if skill_map.has(key):
				var sk: SkillData = skill_map[key] as SkillData
				_grid.add_child(_make_skill_node(sk, node_w, node_h))
			else:
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(node_w, node_h)
				_grid.add_child(spacer)

func _make_skill_node(sk: SkillData, w: float, h: float) -> PanelContainer:
	var sm := SceneManager.save_manager
	var is_unlocked: bool = sm.has_skill(sk.id)
	var prereqs_met: bool = _prerequisites_met(sk.id)
	var has_points: bool = sm.skill_points > 0

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)

	if is_unlocked:
		panel.modulate = Color(0.5, 1.0, 0.55)
	elif not prereqs_met:
		panel.modulate = Color(0.55, 0.55, 0.55)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left",   int(_vw * 0.008))
	inner.add_theme_constant_override("margin_right",  int(_vw * 0.008))
	inner.add_theme_constant_override("margin_top",    int(_vh * 0.008))
	inner.add_theme_constant_override("margin_bottom", int(_vh * 0.008))
	panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * 0.005))
	inner.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = sk.display_name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = sk.skill_type.capitalize()
	type_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
	type_lbl.modulate = Color(0.7, 0.85, 1.0) if sk.skill_type == "active" else Color(0.85, 1.0, 0.7)
	vbox.add_child(type_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = sk.description
	desc_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
	desc_lbl.modulate = Color(0.8, 0.8, 0.8)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	if is_unlocked:
		var check_lbl := Label.new()
		check_lbl.text = "Unlocked"
		check_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
		check_lbl.modulate = Color(0.3, 0.95, 0.4)
		vbox.add_child(check_lbl)
	else:
		var unlock_btn := Button.new()
		unlock_btn.text = "Unlock"
		unlock_btn.custom_minimum_size = Vector2(0, _vh * 0.045)
		unlock_btn.add_theme_font_size_override("font_size", int(_vh * 0.018))
		unlock_btn.disabled = not prereqs_met or not has_points
		unlock_btn.pressed.connect(_on_unlock_pressed.bind(sk.id))
		vbox.add_child(unlock_btn)

	return panel

func _prerequisites_met(skill_id: String) -> bool:
	var sk: SkillData = SkillRegistry.get_skill(skill_id)
	if sk == null:
		return false
	for prereq_id: String in sk.prerequisites:
		if not SceneManager.save_manager.has_skill(prereq_id):
			return false
	return true

func _on_unlock_pressed(skill_id: String) -> void:
	if SceneManager.save_manager.skill_points <= 0:
		return
	if not _prerequisites_met(skill_id):
		return
	SceneManager.save_manager.unlock_skill(skill_id)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_tree") or event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
