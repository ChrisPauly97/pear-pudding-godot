extends "res://scenes/ui/BaseOverlay.gd"

const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const CompanionRegistry = preload("res://autoloads/CompanionRegistry.gd")
const CompanionData = preload("res://data/CompanionData.gd")
const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var hub_mode: bool = false

var _selected_slot: String = ""
var _slot_btns: Dictionary = {}   # slot -> Button
var _companion_btn: Button = null
var _picker_title: Label
var _picker_list: VBoxContainer
var _unequip_btn: Button
var _picker_panel: Control

var _compare_popup: PopupPanel = null
var _hovered_compare_item: String = ""
var _hovered_compare_row: Control = null

const _SLOTS: Array[String] = ["weapon", "armor", "ring", "trinket"]
const _SLOT_LABELS: Dictionary = {
	"weapon":  "Weapon",
	"armor":   "Armor",
	"ring":    "Ring",
	"trinket": "Trinket",
}

func _ready() -> void:
	super._ready()
	_build_ui()
	_refresh_slot_buttons()

func _build_ui() -> void:
	var is_portrait: bool = _vw < _vh
	var root_vbox: VBoxContainer
	if hub_mode:
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		var m: int = int(_ref * 0.012)
		margin.add_theme_constant_override("margin_left", m)
		margin.add_theme_constant_override("margin_right", m)
		margin.add_theme_constant_override("margin_top", m)
		margin.add_theme_constant_override("margin_bottom", m)
		add_child(margin)
		root_vbox = VBoxContainer.new()
		root_vbox.add_theme_constant_override("separation", int(_ref * 0.012))
		margin.add_child(root_vbox)
	else:
		_build_backdrop(0.78)
		var panel_w: float = _vw * 0.95 if is_portrait else _vw * 0.86
		var panel_h: float = _vh * 0.92 if is_portrait else _vh * 0.86
		var outer := _build_centered_panel(panel_w, panel_h)
		root_vbox = _build_margin_vbox(outer, 0.015, 0.012)

	# ---- Header bar ----------------------------------------------------------
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title_lbl := _UiUtil.make_label("Character", int(_ref * 0.03), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, header)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not hub_mode:
		var close_btn := _UiUtil.make_button("Close  [C]" if not OS.has_feature("android") else "Close", Vector2(_ref * 0.14, _ref * 0.065), int(_ref * 0.022), _on_close, header)

	# ---- Main content --------------------------------------------------------
	var content: BoxContainer
	if is_portrait:
		content = VBoxContainer.new()
		content.add_theme_constant_override("separation", int(_ref * 0.01))
	else:
		content = HBoxContainer.new()
		content.add_theme_constant_override("separation", int(_vw * 0.015))
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content)

	# ---- Left: avatar + slot buttons -----------------------------------------
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", int(_ref * 0.010))
	if is_portrait:
		left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		left_vbox.custom_minimum_size = Vector2(_vw * 0.30, 0)
	content.add_child(left_vbox)

	# Avatar placeholder
	var avatar_rect := ColorRect.new()
	avatar_rect.color = Color(0.25, 0.30, 0.40)
	var avatar_size: float = _ref * 0.22
	avatar_rect.custom_minimum_size = Vector2(avatar_size, avatar_size)
	avatar_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_vbox.add_child(avatar_rect)

	var avatar_lbl := _UiUtil.make_label("Saimtar", int(_ref * 0.022), Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, left_vbox)

	var equip_hdr := _UiUtil.make_label("Equipment", int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, left_vbox)

	for slot in _SLOTS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, _ref * 0.065)
		btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_slot_pressed.bind(slot))
		left_vbox.add_child(btn)
		_slot_btns[slot] = btn

	var companion_hdr := _UiUtil.make_label("Companion", int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, left_vbox)

	_companion_btn = Button.new()
	_companion_btn.custom_minimum_size = Vector2(0, _ref * 0.065)
	_companion_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	_companion_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_companion_btn.pressed.connect(_on_slot_pressed.bind("companion"))
	left_vbox.add_child(_companion_btn)

	if not is_portrait:
		content.add_child(VSeparator.new())

	# ---- Right: picker -------------------------------------------------------
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", int(_ref * 0.008))
	content.add_child(right_vbox)
	_picker_panel = right_vbox

	_picker_title = _UiUtil.make_label("← Select a slot", int(_ref * 0.024), Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_CENTER, right_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	_picker_list = VBoxContainer.new()
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_list.add_theme_constant_override("separation", int(_ref * 0.007))
	scroll.add_child(_picker_list)

	_unequip_btn = _UiUtil.make_button("Unequip", Vector2(_ref * 0.16, _ref * 0.065), int(_ref * 0.022), _on_unequip, right_vbox)
	_unequip_btn.disabled = true

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
			if slot == "weapon":
				var inst: Dictionary = SceneManager.save_manager.get_owned_weapon_by_id(equipped_id)
				var lvl: int = int(inst.get("upgrade_level", 0))
				if lvl > 0:
					display += " +%d" % lvl
			btn.text = "  %s:  %s" % [label_name, display]
			btn.modulate = Color(1.0, 1.0, 1.0)
		if slot == _selected_slot:
			btn.modulate = Color(1.0, 1.0, 0.5)
	# Companion slot button
	if _companion_btn != null:
		var cid: String = sm.active_companion
		if cid == "":
			_companion_btn.text = "  Companion:  (none)"
			_companion_btn.modulate = Color(0.7, 0.7, 0.7)
		else:
			var c: CompanionData = CompanionRegistry.get_companion(cid)
			var display: String = c.display_name if c != null else cid
			_companion_btn.text = "  Companion:  %s" % display
			_companion_btn.modulate = Color(1.0, 1.0, 1.0)
		if _selected_slot == "companion":
			_companion_btn.modulate = Color(1.0, 1.0, 0.5)

func _refresh_picker() -> void:
	_hide_compare_tooltip()
	_hovered_compare_item = ""
	for child in _picker_list.get_children():
		child.queue_free()

	if _selected_slot == "":
		return

	if _selected_slot == "companion":
		_refresh_companion_picker()
		return

	var sm := SceneManager.save_manager
	var owned: Array[String] = sm.get_owned_by_slot(_selected_slot)
	var equipped_id: String = sm.get_equipped_by_slot(_selected_slot)
	var label_name: String = _SLOT_LABELS.get(_selected_slot, _selected_slot.capitalize())

	_picker_title.text = "%s items" % label_name
	_picker_title.modulate = Color(1.0, 1.0, 1.0)
	_unequip_btn.disabled = equipped_id == ""

	if owned.is_empty():
		var none_lbl := _UiUtil.make_label("No %s items owned yet." % label_name.to_lower(), int(_ref * 0.022), Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, _picker_list)
		return

	for item_id in owned:
		var w: WeaponData = WeaponRegistry.get_weapon(item_id)
		if w == null:
			continue
		var row := _make_picker_row(item_id, w, item_id == equipped_id)
		_picker_list.add_child(row)

func _refresh_companion_picker() -> void:
	_picker_title.text = "Companions"
	_picker_title.modulate = Color(1.0, 1.0, 1.0)
	var active_id: String = SceneManager.save_manager.active_companion
	_unequip_btn.disabled = active_id == ""
	var all_ids: Array[String] = CompanionRegistry.all_ids()
	if all_ids.is_empty():
		var none_lbl := _UiUtil.make_label("No companions available yet.", int(_ref * 0.022), Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, _picker_list)
		return
	for cid in all_ids:
		var c: CompanionData = CompanionRegistry.get_companion(cid)
		if c == null:
			continue
		var row := _make_companion_row(c, cid == active_id)
		_picker_list.add_child(row)

func _make_companion_row(c: CompanionData, is_active: bool) -> HBoxContainer:
	var unlocked: bool = CompanionRegistry.is_unlocked(c.companion_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", int(_ref * 0.002))
	row.add_child(info_vbox)

	var name_row := HBoxContainer.new()
	info_vbox.add_child(name_row)

	var name_lbl := _UiUtil.make_label(c.display_name, int(_ref * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not unlocked:
		name_lbl.modulate = Color(0.5, 0.5, 0.5)
	name_row.add_child(name_lbl)

	if is_active:
		var eq_lbl := _UiUtil.make_label("[A]", int(_ref * 0.022), Color(0.4, 1.0, 0.5), HORIZONTAL_ALIGNMENT_LEFT, name_row)

	var desc_lbl := Label.new()
	if unlocked:
		desc_lbl.text = c.description
		desc_lbl.modulate = Color(0.9, 1.0, 0.7)
	else:
		desc_lbl.text = _companion_locked_text(c)
		desc_lbl.modulate = Color(0.55, 0.55, 0.55)
	desc_lbl.add_theme_font_size_override("font_size", int(_ref * 0.019))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)

	var equip_btn := _UiUtil.make_button("Active" if is_active else "Equip", Vector2(_ref * 0.14, _ref * 0.065), int(_ref * 0.022), _on_equip_companion.bind(c.companion_id), row)
	equip_btn.disabled = is_active or not unlocked

	return row

const _COMPANION_LOCKED_TEXT: Dictionary = {
	"maiteln": "Travel with Maiteln in the story to unlock.",
}

func _companion_locked_text(c: CompanionData) -> String:
	if _COMPANION_LOCKED_TEXT.has(c.companion_id):
		return str(_COMPANION_LOCKED_TEXT[c.companion_id])
	return "Locked — complete story objectives to unlock."

func _make_picker_row(item_id: String, w: WeaponData, is_equipped: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", int(_ref * 0.002))
	row.add_child(info_vbox)

	var name_row := HBoxContainer.new()
	info_vbox.add_child(name_row)

	var name_lbl := Label.new()
	var disp_name: String = w.display_name
	if w.slot == "weapon":
		var win: Dictionary = SceneManager.save_manager.get_owned_weapon_by_id(item_id)
		var wlvl: int = int(win.get("upgrade_level", 0))
		if wlvl > 0:
			disp_name += " +%d" % wlvl
	name_lbl.text = disp_name
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	if is_equipped:
		var eq_lbl := _UiUtil.make_label("[E]", int(_ref * 0.022), Color(0.4, 1.0, 0.5), HORIZONTAL_ALIGNMENT_LEFT, name_row)

	var effect_lbl := Label.new()
	var sm := SceneManager.save_manager
	var upgrade_level: int = 0
	if w.slot == "weapon":
		var winst: Dictionary = sm.get_owned_weapon_by_id(item_id)
		upgrade_level = int(winst.get("upgrade_level", 0))
	effect_lbl.text = UpgradeDefs.get_display_string(w, upgrade_level)
	effect_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	effect_lbl.modulate = Color(0.9, 1.0, 0.7)
	info_vbox.add_child(effect_lbl)

	var equip_btn := _UiUtil.make_button("Equipped" if is_equipped else "Equip", Vector2(_ref * 0.14, _ref * 0.065), int(_ref * 0.022), _on_equip.bind(item_id), row)
	equip_btn.disabled = is_equipped

	# Compare against the currently equipped item in this slot: hold Shift while
	# hovering on desktop, or tap-and-hold on mobile (no Shift key there).
	if not is_equipped:
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.mouse_entered.connect(func() -> void:
			_hovered_compare_item = item_id
			_hovered_compare_row = row
			if Input.is_key_pressed(KEY_SHIFT):
				_show_compare_tooltip(item_id, w, row))
		row.mouse_exited.connect(func() -> void:
			if _hovered_compare_item == item_id:
				_hovered_compare_item = ""
				_hovered_compare_row = null
				_hide_compare_tooltip())

		var lpd := LongPressDetector.new()
		row.add_child(lpd)
		lpd.long_pressed.connect(func() -> void: _show_compare_tooltip(item_id, w, row))

	return row

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

func _on_equip_companion(companion_id: String) -> void:
	var first_equip_flag: String = "companion_%s_first_equip" % companion_id
	var is_first: bool = not SceneManager.save_manager.get_story_flag(first_equip_flag)
	SceneManager.save_manager.equip_companion(companion_id)
	if is_first:
		SceneManager.save_manager.set_story_flag(first_equip_flag)
		_show_companion_toast(companion_id)
	_refresh_slot_buttons()
	_refresh_picker()

const _COMPANION_FIRST_EQUIP_TOAST: Dictionary = {
	"maiteln": "Maiteln chuckles. 'Try to keep up, boy.'",
}

func _show_companion_toast(companion_id: String) -> void:
	var c: CompanionData = CompanionRegistry.get_companion(companion_id)
	if c == null:
		return
	var msg: String = str(_COMPANION_FIRST_EQUIP_TOAST.get(companion_id,
		"%s joins you as a companion." % c.display_name))
	SceneManager.show_toast(c.display_name, msg)

func _on_unequip() -> void:
	if _selected_slot == "companion":
		SceneManager.save_manager.unequip_companion()
	else:
		SceneManager.save_manager.equip_item("", _selected_slot)
	_refresh_slot_buttons()
	_refresh_picker()

func _on_close() -> void:
	closed.emit()

# -------------------------------------------------------------------------
# Compare tooltip (Shift+hover on desktop, tap-and-hold on mobile)
# -------------------------------------------------------------------------

func _hide_compare_tooltip() -> void:
	if _compare_popup != null and is_instance_valid(_compare_popup):
		_compare_popup.queue_free()
	_compare_popup = null

func _show_compare_tooltip(item_id: String, candidate: WeaponData, anchor: Control) -> void:
	_hide_compare_tooltip()

	var sm := SceneManager.save_manager
	var equipped_id: String = sm.get_equipped_by_slot(candidate.slot)
	var equipped: WeaponData = WeaponRegistry.get_weapon(equipped_id) if equipped_id != "" else null

	var candidate_lvl: int = 0
	var equipped_lvl: int = 0
	if candidate.slot == "weapon":
		candidate_lvl = int(sm.get_owned_weapon_by_id(item_id).get("upgrade_level", 0))
		if equipped_id != "":
			equipped_lvl = int(sm.get_owned_weapon_by_id(equipped_id).get("upgrade_level", 0))

	var popup := PopupPanel.new()
	add_child(popup)
	_compare_popup = popup

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(_ref * 0.008))
	vb.custom_minimum_size = Vector2(_ref * 0.34, 0)
	popup.add_child(vb)

	var title_lbl := _UiUtil.make_label("Compare — %s" % _SLOT_LABELS.get(candidate.slot, candidate.slot.capitalize()), int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vb)

	var equipped_lbl := Label.new()
	equipped_lbl.text = "Equipped: %s\n%s" % [
		(equipped.display_name if equipped != null else "(empty)"),
		(UpgradeDefs.get_display_string(equipped, equipped_lvl) if equipped != null else "—"),
	]
	equipped_lbl.add_theme_font_size_override("font_size", int(_ref * 0.020))
	equipped_lbl.modulate = Color(0.75, 0.75, 0.75)
	equipped_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(equipped_lbl)

	vb.add_child(HSeparator.new())

	var candidate_lbl := Label.new()
	candidate_lbl.text = "%s\n%s" % [
		candidate.display_name,
		UpgradeDefs.get_display_string(candidate, candidate_lvl),
	]
	candidate_lbl.add_theme_font_size_override("font_size", int(_ref * 0.020))
	candidate_lbl.modulate = Color(0.6, 1.0, 0.7)
	candidate_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(candidate_lbl)

	if equipped != null and equipped.battle_effect_type == candidate.battle_effect_type:
		var delta: int = candidate.battle_effect_value - equipped.battle_effect_value
		if delta != 0:
			var delta_lbl := _UiUtil.make_label("%+d vs equipped" % delta, int(_ref * 0.020), Color(0.4, 1.0, 0.5) if delta > 0 else Color(1.0, 0.45, 0.4), HORIZONTAL_ALIGNMENT_LEFT, vb)

	popup.popup(Rect2i(anchor.get_screen_transform().origin as Vector2i, Vector2i(int(_ref * 0.34), 0)))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		if _hovered_compare_item != "" and _hovered_compare_row != null:
			if event.pressed:
				var w: WeaponData = WeaponRegistry.get_weapon(_hovered_compare_item)
				if w != null:
					_show_compare_tooltip(_hovered_compare_item, w, _hovered_compare_row)
			else:
				_hide_compare_tooltip()
	if hub_mode:
		return
	if event.is_action_pressed("character"):
		get_viewport().set_input_as_handled()
		_on_close()
