extends Control

signal closed

const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData = preload("res://data/SkillData.gd")

var _vh: float = 0.0
var _vw: float = 0.0
var _points_label: Label
var _skill_container: Control
var _active_tab: int = 0
var _tab_buttons: Array[Button] = []

const _ROWS: int = 3

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
	_active_tab = 0
	_tab_buttons.clear()
	for child in get_children():
		child.free()
	_build_ui()
	_refresh()

# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------

func _opposing_magic(mt: String) -> String:
	return "dark" if mt == "light" else "light"

func _branch_for_tab(tab: int) -> String:
	if tab == 2:
		return ""
	var mt: String = SceneManager.save_manager.magic_type
	var branches: Array = MAGIC_BRANCHES[mt]
	if tab < branches.size():
		return str(branches[tab])
	return ""

func _tab_label(tab: int) -> String:
	if tab == 2:
		return "Cross-Magic"
	return _branch_for_tab(tab).capitalize()

func _tab_color(tab: int) -> Color:
	if tab == 2:
		return Color(0.85, 0.85, 0.85)
	match _branch_for_tab(tab):
		"ember": return Color(1.0, 0.7, 0.4)
		"dawn":  return Color(1.0, 1.0, 0.55)
		"dusk":  return Color(0.7, 0.5, 1.0)
		"ash":   return Color(0.65, 0.65, 0.65)
	return Color.WHITE

func _cross_magic_ids() -> Array[String]:
	var opposing: String = _opposing_magic(SceneManager.save_manager.magic_type)
	var opp_branches: Array = MAGIC_BRANCHES[opposing]
	var result: Array[String] = []
	for b in opp_branches:
		for sid: String in SkillRegistry.get_by_branch(str(b)):
			var sk: SkillData = SkillRegistry.get_skill(sid)
			if sk != null and sk.alt_cost > 0:
				result.append(sid)
	return result

func _cross_currency() -> String:
	return "corruption" if SceneManager.save_manager.magic_type == "light" else "redemption"

# -------------------------------------------------------------------------
# Main skill tree UI
# -------------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = _vw * 0.96
	var panel_h: float = _vh * 0.92

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.03))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.03))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.015))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.015))
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_vh * 0.010))
	margin.add_child(root_vbox)

	# ── Header: title + stats on the left, big X close on the right ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(_vw * 0.02))
	root_vbox.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", int(_vh * 0.004))
	header.add_child(title_stack)

	var title_lbl := Label.new()
	title_lbl.text = "Skill Tree"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.032))
	title_stack.add_child(title_lbl)

	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", int(_vh * 0.018))
	_points_label.modulate = Color(1.0, 0.85, 0.2)
	title_stack.add_child(_points_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	var close_size: float = _vw * 0.13
	close_btn.custom_minimum_size = Vector2(close_size, close_size)
	close_btn.add_theme_font_size_override("font_size", int(close_size * 0.45))
	close_btn.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_btn)

	# ── Tab bar ──
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", int(_vw * 0.015))
	root_vbox.add_child(tab_bar)

	_tab_buttons.clear()
	var tab_w: float = (_vw * 0.90 - _vw * 0.015 * 2) / 3.0
	for i in 3:
		var tb := Button.new()
		tb.text = _tab_label(i)
		tb.custom_minimum_size = Vector2(tab_w, _vh * 0.055)
		tb.add_theme_font_size_override("font_size", int(_vh * 0.021))
		tb.modulate = _tab_color(i) if i == _active_tab else Color(0.5, 0.5, 0.5)
		tb.pressed.connect(_set_tab.bind(i))
		tab_bar.add_child(tb)
		_tab_buttons.append(tb)

	# ── Skill area ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_skill_container = Control.new()
	scroll.add_child(_skill_container)

func _set_tab(tab: int) -> void:
	_active_tab = tab
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = _tab_color(i) if i == _active_tab else Color(0.5, 0.5, 0.5)
	_refresh()

func _refresh() -> void:
	var sm := SceneManager.save_manager
	_points_label.text = "SP: %d  |  CP: %d  |  RP: %d" % [
		sm.skill_points, sm.corruption_points, sm.redemption_points]

	for child in _skill_container.get_children():
		child.queue_free()

	if _active_tab == 2:
		_refresh_cross_magic()
		return

	var ids: Array[String] = SkillRegistry.get_by_branch(_branch_for_tab(_active_tab))

	var skill_map: Dictionary = {}
	for sid: String in ids:
		var sk: SkillData = SkillRegistry.get_skill(sid)
		if sk != null:
			skill_map["%d,%d" % [sk.tree_row, sk.tree_col]] = sk

	var node_w: float = (_vw * 0.90 - _vw * 0.04) / 2.0
	var node_h: float = _vh * 0.19
	var col_gap: float = _vw * 0.04
	var row_gap: float = _vh * 0.06
	var connector_w: float = _vw * 0.012

	var col_x: Dictionary = {0: 0.0, 3: node_w + col_gap}

	# Connector bars (behind skill nodes)
	var branch_color: Color = _tab_color(_active_tab)
	for r in range(_ROWS - 1):
		for col in [0, 3]:
			var parent_key: String = "%d,%d" % [r, col]
			var child_key: String = "%d,%d" % [r + 1, col]
			if not (skill_map.has(parent_key) and skill_map.has(child_key)):
				continue
			var parent_sk: SkillData = skill_map[parent_key] as SkillData
			var child_sk: SkillData = skill_map[child_key] as SkillData
			if not (parent_sk.id in child_sk.prerequisites):
				continue
			var parent_unlocked: bool = sm.has_skill(parent_sk.id)
			var bar := ColorRect.new()
			var col_x_val: float = col_x[col]
			bar.color = branch_color if parent_unlocked else Color(branch_color.r, branch_color.g, branch_color.b, 0.25)
			bar.position = Vector2(col_x_val + (node_w - connector_w) * 0.5, float(r) * (node_h + row_gap) + node_h)
			bar.size = Vector2(connector_w, row_gap)
			_skill_container.add_child(bar)

	# Skill nodes (on top of connectors)
	for r in _ROWS:
		for col in [0, 3]:
			var key: String = "%d,%d" % [r, col]
			if not skill_map.has(key):
				continue
			var sk: SkillData = skill_map[key] as SkillData
			var node := _make_skill_node(sk, node_w, node_h, false)
			var col_x_val: float = col_x[col]
			node.position = Vector2(col_x_val, float(r) * (node_h + row_gap))
			_skill_container.add_child(node)

	var total_h: float = float(_ROWS) * node_h + float(_ROWS - 1) * row_gap
	_skill_container.custom_minimum_size = Vector2(node_w * 2.0 + col_gap, total_h)

func _refresh_cross_magic() -> void:
	var ids: Array[String] = _cross_magic_ids()
	var node_w: float = (_vw * 0.90 - _vw * 0.015 * 3) / 4.0
	var node_h: float = _vh * 0.19

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_vw * 0.04))
	grid.add_theme_constant_override("v_separation", int(_vh * 0.012))
	_skill_container.add_child(grid)
	_skill_container.custom_minimum_size = Vector2(0, 0)

	for sid: String in ids:
		var sk: SkillData = SkillRegistry.get_skill(sid)
		if sk != null:
			grid.add_child(_make_skill_node(sk, node_w, node_h, true))

func _make_skill_node(sk: SkillData, w: float, h: float, is_cross: bool = false) -> PanelContainer:
	var sm := SceneManager.save_manager
	var is_unlocked: bool = sm.has_skill(sk.id)
	var prereqs_met: bool = is_cross or _prerequisites_met(sk.id)

	var currency: String = _cross_currency()
	var cross_bal: int = sm.corruption_points if currency == "corruption" else sm.redemption_points
	var can_afford_cross: bool = cross_bal >= sk.alt_cost

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)

	if is_unlocked:
		panel.modulate = Color(0.5, 1.0, 0.55)
	elif is_cross and not can_afford_cross:
		panel.modulate = Color(0.55, 0.55, 0.55)
	elif not is_cross and not prereqs_met:
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
		unlock_btn.custom_minimum_size = Vector2(0, _vh * 0.045)
		unlock_btn.add_theme_font_size_override("font_size", int(_vh * 0.018))
		if is_cross:
			var abbr: String = "CP" if currency == "corruption" else "RP"
			unlock_btn.text = "Unlock (%d %s)" % [sk.alt_cost, abbr]
			unlock_btn.disabled = not can_afford_cross
			unlock_btn.pressed.connect(_on_cross_unlock_pressed.bind(sk.id, sk.alt_cost, currency))
		else:
			unlock_btn.text = "Unlock"
			unlock_btn.disabled = not prereqs_met or sm.skill_points <= 0
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

func _on_cross_unlock_pressed(skill_id: String, cost: int, currency: String) -> void:
	SceneManager.save_manager.unlock_cross_skill(skill_id, cost, currency)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_tree") or event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
