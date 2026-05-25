extends Control

signal closed

const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")

var _vh: float = 0.0
var _vw: float = 0.0

var _selected_slot: String = ""
var _slot_btns: Dictionary = {}   # slot -> Button
var _picker_title: Label
var _picker_list: VBoxContainer
var _unequip_btn: Button
var _picker_panel: Control

const _SLOTS: Array[String] = ["weapon", "armor", "ring", "trinket"]
const _SLOT_LABELS: Dictionary = {
	"weapon":  "Weapon",
	"armor":   "Armor",
	"ring":    "Ring",
	"trinket": "Trinket",
}

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_build_ui()
	_refresh_slot_buttons()

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

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.015))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.015))
	margin.add_theme_constant_override("margin_top",    int(_vh * 0.015))
	margin.add_theme_constant_override("margin_bottom", int(_vh * 0.015))
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_vh * 0.012))
	margin.add_child(root_vbox)

	# ---- Header bar ----------------------------------------------------------
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "Character"
	title_lbl.add_theme_font_size_override("font_size", int(_vh * 0.03))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close  [C]" if not OS.has_feature("android") else "Close"
	close_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.05)
	close_btn.add_theme_font_size_override("font_size", int(_vh * 0.021))
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# ---- Main content --------------------------------------------------------
	var content: BoxContainer
	if is_portrait:
		content = VBoxContainer.new()
		content.add_theme_constant_override("separation", int(_vh * 0.01))
	else:
		content = HBoxContainer.new()
		content.add_theme_constant_override("separation", int(_vw * 0.015))
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content)

	# ---- Left: avatar + slot buttons -----------------------------------------
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", int(_vh * 0.010))
	if is_portrait:
		left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		left_vbox.custom_minimum_size = Vector2(_vw * 0.30, 0)
	content.add_child(left_vbox)

	# Avatar placeholder
	var avatar_rect := ColorRect.new()
	avatar_rect.color = Color(0.25, 0.30, 0.40)
	var avatar_size: float = _vh * 0.22
	avatar_rect.custom_minimum_size = Vector2(avatar_size, avatar_size)
	avatar_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_vbox.add_child(avatar_rect)

	var avatar_lbl := Label.new()
	avatar_lbl.text = "Saimtar"
	avatar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_lbl.add_theme_font_size_override("font_size", int(_vh * 0.02))
	avatar_lbl.modulate = Color(0.8, 0.8, 0.8)
	left_vbox.add_child(avatar_lbl)

	var equip_hdr := Label.new()
	equip_hdr.text = "Equipment"
	equip_hdr.add_theme_font_size_override("font_size", int(_vh * 0.024))
	equip_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(equip_hdr)

	for slot in _SLOTS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, _vh * 0.058)
		btn.add_theme_font_size_override("font_size", int(_vh * 0.019))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_slot_pressed.bind(slot))
		left_vbox.add_child(btn)
		_slot_btns[slot] = btn

	if not is_portrait:
		content.add_child(VSeparator.new())

	# ---- Right: picker -------------------------------------------------------
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", int(_vh * 0.008))
	content.add_child(right_vbox)
	_picker_panel = right_vbox

	_picker_title = Label.new()
	_picker_title.text = "← Select a slot"
	_picker_title.add_theme_font_size_override("font_size", int(_vh * 0.024))
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_title.modulate = Color(0.7, 0.7, 0.7)
	right_vbox.add_child(_picker_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(scroll)

	_picker_list = VBoxContainer.new()
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_list.add_theme_constant_override("separation", int(_vh * 0.007))
	scroll.add_child(_picker_list)

	_unequip_btn = Button.new()
	_unequip_btn.text = "Unequip"
	_unequip_btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.052)
	_unequip_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
	_unequip_btn.disabled = true
	_unequip_btn.pressed.connect(_on_unequip)
	right_vbox.add_child(_unequip_btn)

# -------------------------------------------------------------------------
# Refresh
# -------------------------------------------------------------------------

func _refresh_slot_buttons() -> void:
	var sm := SceneManager.save_manager
	for slot in _SLOTS:
		var btn: Button = _slot_btns[slot]
		var equipped_id: String = sm.get_equipped_by_slot(slot)
		var label_name: String = _SLOT_LABELS.get(slot, slot.capitalize())
		if equipped_id == "":
			btn.text = "  %s:  (empty)" % label_name
			btn.modulate = Color(0.7, 0.7, 0.7)
		else:
			var w: WeaponData = WeaponRegistry.get_weapon(equipped_id)
			var display: String = w.display_name if w != null else equipped_id
			btn.text = "  %s:  %s" % [label_name, display]
			btn.modulate = Color(1.0, 1.0, 1.0)
		if slot == _selected_slot:
			btn.modulate = Color(1.0, 1.0, 0.5)

func _refresh_picker() -> void:
	for child in _picker_list.get_children():
		child.queue_free()

	if _selected_slot == "":
		return

	var sm := SceneManager.save_manager
	var owned: Array[String] = sm.get_owned_by_slot(_selected_slot)
	var equipped_id: String = sm.get_equipped_by_slot(_selected_slot)
	var label_name: String = _SLOT_LABELS.get(_selected_slot, _selected_slot.capitalize())

	_picker_title.text = "%s items" % label_name
	_picker_title.modulate = Color(1.0, 1.0, 1.0)
	_unequip_btn.disabled = equipped_id == ""

	if owned.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No %s items owned yet." % label_name.to_lower()
		none_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
		none_lbl.modulate = Color(0.6, 0.6, 0.6)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_picker_list.add_child(none_lbl)
		return

	for item_id in owned:
		var w: WeaponData = WeaponRegistry.get_weapon(item_id)
		if w == null:
			continue
		var row := _make_picker_row(item_id, w, item_id == equipped_id)
		_picker_list.add_child(row)

func _make_picker_row(item_id: String, w: WeaponData, is_equipped: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", int(_vh * 0.002))
	row.add_child(info_vbox)

	var name_row := HBoxContainer.new()
	info_vbox.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = w.display_name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.02))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	if is_equipped:
		var eq_lbl := Label.new()
		eq_lbl.text = "[E]"
		eq_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
		eq_lbl.modulate = Color(0.4, 1.0, 0.5)
		name_row.add_child(eq_lbl)

	var effect_lbl := Label.new()
	effect_lbl.text = _effect_summary(w)
	effect_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
	effect_lbl.modulate = Color(0.9, 1.0, 0.7)
	info_vbox.add_child(effect_lbl)

	var equip_btn := Button.new()
	equip_btn.text = "Equipped" if is_equipped else "Equip"
	equip_btn.disabled = is_equipped
	equip_btn.custom_minimum_size = Vector2(_vh * 0.12, _vh * 0.048)
	equip_btn.add_theme_font_size_override("font_size", int(_vh * 0.018))
	equip_btn.pressed.connect(_on_equip.bind(item_id))
	row.add_child(equip_btn)

	return row

func _effect_summary(w: WeaponData) -> String:
	match w.battle_effect_type:
		"deck_inject":    return "Inject %d× %s" % [w.injected_card_count, w.injected_card_id]
		"starting_mana":  return "+%d starting mana" % w.battle_effect_value
		"starting_hp":    return "+%d starting HP" % w.battle_effect_value
		"passive_atk":    return "+%d hero ATK" % w.battle_effect_value
	return w.battle_effect_type

# -------------------------------------------------------------------------
# Handlers
# -------------------------------------------------------------------------

func _on_slot_pressed(slot: String) -> void:
	_selected_slot = slot
	_refresh_slot_buttons()
	_refresh_picker()

func _on_equip(item_id: String) -> void:
	SceneManager.save_manager.equip_item(item_id, _selected_slot)
	_refresh_slot_buttons()
	_refresh_picker()

func _on_unequip() -> void:
	SceneManager.save_manager.equip_item("", _selected_slot)
	_refresh_slot_buttons()
	_refresh_picker()

func _on_close() -> void:
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("character") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close()
