extends Control

const NUM_SLOTS: int = 3

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var vh: float = get_viewport().get_visible_rect().size.y
	var vp: Vector2 = get_viewport().get_visible_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(vh * 0.035))
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(vp.x * 0.7, vh * 0.85)
	vbox.position = Vector2((vp.x - vp.x * 0.7) * 0.5, (vh - vh * 0.85) * 0.5)
	add_child(vbox)

	var title := Label.new()
	title.text = "Select Save Slot"
	title.add_theme_font_size_override("font_size", int(vh * 0.055))
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for slot: int in range(1, NUM_SLOTS + 1):
		vbox.add_child(_make_slot_row(slot, vh, vp))

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(vh * 0.22, vh * 0.055)
	back_btn.add_theme_font_size_override("font_size", int(vh * 0.026))
	back_btn.pressed.connect(_on_back)
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_child(back_btn)
	vbox.add_child(back_row)

func _make_slot_row(slot: int, vh: float, vp: Vector2) -> Control:
	var has: bool = SaveManager.has_save_slot(slot)
	var meta: Dictionary = SaveManager.get_slot_metadata(slot) if has else {}

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.18, 0.95)
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_color = Color(0.35, 0.35, 0.55, 0.6)
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 1
	style.border_width_right  = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(vp.x * 0.65, vh * 0.12)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(vh * 0.015))
	panel.add_child(hbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(vh * 0.02))
	margin.add_theme_constant_override("margin_right",  int(vh * 0.02))
	margin.add_theme_constant_override("margin_top",    int(vh * 0.01))
	margin.add_theme_constant_override("margin_bottom", int(vh * 0.01))
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)

	var inner_hbox := HBoxContainer.new()
	inner_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	inner_hbox.add_theme_constant_override("separation", int(vh * 0.015))
	margin.add_child(inner_hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_hbox.add_child(info_vbox)

	var slot_lbl := Label.new()
	slot_lbl.text = "Slot %d" % slot
	slot_lbl.add_theme_font_size_override("font_size", int(vh * 0.028))
	slot_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	info_vbox.add_child(slot_lbl)

	var detail_lbl := Label.new()
	if has:
		var map_str: String = str(meta.get("current_map", "?"))
		var coins_val: int = int(meta.get("coins", 0))
		var saved_at: String = str(meta.get("last_saved", ""))
		detail_lbl.text = "Map: %s  |  Coins: %d\n%s" % [map_str, coins_val, saved_at]
	else:
		detail_lbl.text = "Empty"
	detail_lbl.add_theme_font_size_override("font_size", int(vh * 0.022))
	detail_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	info_vbox.add_child(detail_lbl)

	var btn_vbox := VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", int(vh * 0.008))
	inner_hbox.add_child(btn_vbox)

	if has:
		var load_btn := Button.new()
		load_btn.text = "Continue"
		load_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.048)
		load_btn.add_theme_font_size_override("font_size", int(vh * 0.022))
		load_btn.pressed.connect(func() -> void: _on_load_slot(slot))
		btn_vbox.add_child(load_btn)

		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.048)
		del_btn.add_theme_font_size_override("font_size", int(vh * 0.022))
		del_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		del_btn.pressed.connect(func() -> void: _confirm_delete(slot))
		btn_vbox.add_child(del_btn)
	else:
		var new_btn := Button.new()
		new_btn.text = "New Game"
		new_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.048)
		new_btn.add_theme_font_size_override("font_size", int(vh * 0.022))
		new_btn.pressed.connect(func() -> void: _on_new_game_slot(slot))
		btn_vbox.add_child(new_btn)

	return panel

func _on_load_slot(slot: int) -> void:
	SaveManager.set_active_slot(slot)
	SceneManager.continue_game()

func _on_new_game_slot(slot: int) -> void:
	SaveManager.set_active_slot(slot)
	get_tree().change_scene_to_file("res://scenes/ui/BiomeSelectionScene.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_packed(preload("res://scenes/ui/MenuScene.tscn"))

func _confirm_delete(slot: int) -> void:
	var vh: float = get_viewport().get_visible_rect().size.y
	var vp: Vector2 = get_viewport().get_visible_rect().size

	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var dlg_w: float = vp.x * 0.52
	var dlg_h: float = vh * 0.26
	var dialog := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.05, 0.05, 0.98)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	dialog.add_theme_stylebox_override("panel", style)
	dialog.custom_minimum_size = Vector2(dlg_w, dlg_h)
	dialog.position = Vector2((vp.x - dlg_w) * 0.5, (vp.y - dlg_h) * 0.5)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(vh * 0.02))
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Delete Slot %d?\nThis cannot be undone." % slot
	lbl.add_theme_font_size_override("font_size", int(vh * 0.028))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(vh * 0.02))
	vbox.add_child(row)

	var yes_btn := Button.new()
	yes_btn.text = "Delete"
	yes_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.055)
	yes_btn.add_theme_font_size_override("font_size", int(vh * 0.026))
	yes_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	yes_btn.pressed.connect(func() -> void:
		SaveManager.delete_save_slot(slot)
		layer.queue_free()
		_refresh()
	)
	row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(vh * 0.18, vh * 0.055)
	no_btn.add_theme_font_size_override("font_size", int(vh * 0.026))
	no_btn.pressed.connect(func() -> void: layer.queue_free())
	row.add_child(no_btn)

func _refresh() -> void:
	# Reload the scene to reflect slot changes
	get_tree().reload_current_scene()
