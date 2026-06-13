extends Control

signal closed

var _vh: float = 0.0
var _vw: float = 0.0
var _selected_id: String = ""

var _scroll_list: VBoxContainer
var _title_label: Label
var _lore_label: RichTextLabel
var _replay_btn: Button
var _header_label: Label
var _treasure_label: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_build_ui()
	_populate_scroll_list()
	_refresh_treasure_panel()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var is_portrait: bool = _vw < _vh
	var panel_w: float = _vw * 0.95 if is_portrait else _vw * 0.86
	var panel_h: float = _vh * 0.92 if is_portrait else _vh * 0.86

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left",   int(_vw * 0.015))
	outer_margin.add_theme_constant_override("margin_right",  int(_vw * 0.015))
	outer_margin.add_theme_constant_override("margin_top",    int(_vh * 0.015))
	outer_margin.add_theme_constant_override("margin_bottom", int(_vh * 0.015))
	outer.add_child(outer_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_vh * 0.01))
	outer_margin.add_child(root_vbox)

	# ── Header row ────────────────────────────────────────────────────────────
	var header_row := HBoxContainer.new()
	root_vbox.add_child(header_row)

	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.add_theme_font_size_override("font_size", int(_vh * 0.035))
	header_row.add_child(_header_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(_vh * 0.055, _vh * 0.055)
	close_btn.add_theme_font_size_override("font_size", int(_vh * 0.028))
	close_btn.pressed.connect(_close)
	header_row.add_child(close_btn)

	# ── Treasure status row ───────────────────────────────────────────────────
	_treasure_label = Label.new()
	_treasure_label.add_theme_font_size_override("font_size", int(_vh * 0.025))
	_treasure_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	_treasure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_treasure_label)

	# ── Two-panel row ─────────────────────────────────────────────────────────
	var panels_box: BoxContainer
	if is_portrait:
		panels_box = VBoxContainer.new()
	else:
		panels_box = HBoxContainer.new()
	panels_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels_box.add_theme_constant_override("separation", int(_vw * 0.012))
	root_vbox.add_child(panels_box)

	# Left panel — scroll list
	var left_panel := PanelContainer.new()
	var left_w: float = _vw * 0.25 if not is_portrait else _vw * 0.85
	left_panel.custom_minimum_size = Vector2(left_w, 0.0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels_box.add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_scroll)

	_scroll_list = VBoxContainer.new()
	_scroll_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_list.add_theme_constant_override("separation", int(_vh * 0.008))
	left_scroll.add_child(_scroll_list)

	# Right panel — detail view
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels_box.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left",   int(_vw * 0.015))
	right_margin.add_theme_constant_override("margin_right",  int(_vw * 0.015))
	right_margin.add_theme_constant_override("margin_top",    int(_vh * 0.015))
	right_margin.add_theme_constant_override("margin_bottom", int(_vh * 0.015))
	right_panel.add_child(right_margin)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", int(_vh * 0.012))
	right_margin.add_child(detail_vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", int(_vh * 0.035))
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(_title_label)

	_lore_label = RichTextLabel.new()
	_lore_label.bbcode_enabled = true
	_lore_label.scroll_following = true
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lore_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lore_label.add_theme_font_size_override("normal_font_size", int(_vh * 0.022))
	detail_vbox.add_child(_lore_label)

	_replay_btn = Button.new()
	_replay_btn.text = "Replay Narration"
	_replay_btn.custom_minimum_size = Vector2(_vw * 0.18, _vh * 0.06)
	_replay_btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	_replay_btn.pressed.connect(_on_replay_pressed)
	_replay_btn.hide()
	detail_vbox.add_child(_replay_btn)

	_show_empty_state()

func _refresh_treasure_panel() -> void:
	if _treasure_label == null:
		return
	var sm := SaveManager
	var at: Dictionary = sm.active_treasure
	if not at.is_empty() and bool(at.get("completed", false)):
		_treasure_label.text = "Treasure: Excavated!"
	elif not at.is_empty():
		_treasure_label.text = "Treasure: Active dig site at (%d, %d)" % [int(at.get("site_x", 0)), int(at.get("site_z", 0))]
	elif sm.treasure_fragments > 0:
		_treasure_label.text = "Map Fragments: %d / 3" % sm.treasure_fragments
	else:
		_treasure_label.text = "Map Fragments: 0 / 3 — Collect 3 to form a treasure map."

func _show_empty_state() -> void:
	var found: int = SaveManager.collected_scrolls.size()
	_header_label.text = "Journal — %d / %d Scrolls" % [found, ScrollRegistry.SCROLL_COUNT]
	_title_label.text = "No scroll selected"
	_lore_label.text = ""
	_replay_btn.hide()

func _populate_scroll_list() -> void:
	for child in _scroll_list.get_children():
		child.queue_free()

	var all: Array[Dictionary] = ScrollRegistry.get_all_scrolls()
	var any_found: bool = false
	for scroll in all:
		var sid: String = scroll["id"]
		if not SaveManager.is_scroll_collected(sid):
			continue
		any_found = true
		var btn := Button.new()
		btn.text = scroll["title"]
		btn.custom_minimum_size = Vector2(_vw * 0.22, _vh * 0.06)
		btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_scroll_selected.bind(sid))
		_scroll_list.add_child(btn)

	if not any_found:
		var empty_lbl := Label.new()
		empty_lbl.text = "No lore scrolls found yet."
		empty_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_scroll_list.add_child(empty_lbl)

func _on_scroll_selected(scroll_id: String) -> void:
	_selected_id = scroll_id
	var scroll: Dictionary = ScrollRegistry.get_scroll(scroll_id)
	if scroll.is_empty():
		return
	var found: int = SaveManager.collected_scrolls.size()
	_header_label.text = "Journal — %d / %d Scrolls" % [found, ScrollRegistry.SCROLL_COUNT]
	_title_label.text = scroll.get("title", "")
	_lore_label.text = scroll.get("lore_text", "")
	_replay_btn.show()

func _on_replay_pressed() -> void:
	if _selected_id != "":
		AudioManager.play_narration(_selected_id)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	closed.emit()
	queue_free()
