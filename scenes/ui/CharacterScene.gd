extends "res://scenes/ui/BaseOverlay.gd"

const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const CompanionRegistry = preload("res://autoloads/CompanionRegistry.gd")
const CompanionData = preload("res://data/CompanionData.gd")
const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")

var hub_mode: bool = false

var _selected_slot: String = ""
var _slot_btns: Dictionary = {}   # slot -> Button
var _companion_btn: Button = null
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

	var title_lbl := Label.new()
	title_lbl.text = "Character"
	title_lbl.add_theme_font_size_override("font_size", int(_ref * 0.03))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	if not hub_mode:
		var close_btn := Button.new()
		close_btn.text = "Close  [C]" if not OS.has_feature("android") else "Close"
		close_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.065)
		close_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
		close_btn.pressed.connect(_on_close)
		header.add_child(close_btn)

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

	var avatar_lbl := Label.new()
	avatar_lbl.text = "Saimtar"
	avatar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	avatar_lbl.modulate = Color(0.8, 0.8, 0.8)
	left_vbox.add_child(avatar_lbl)

	var equip_hdr := Label.new()
	equip_hdr.text = "Equipment"
	equip_hdr.add_theme_font_size_override("font_size", int(_ref * 0.024))
	equip_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(equip_hdr)

	for slot in _SLOTS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, _ref * 0.065)
		btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_slot_pressed.bind(slot))
		left_vbox.add_child(btn)
		_slot_btns[slot] = btn

	var companion_hdr := Label.new()
	companion_hdr.text = "Companion"
	companion_hdr.add_theme_font_size_override("font_size", int(_ref * 0.024))
	companion_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(companion_hdr)

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

	_picker_title = Label.new()
	_picker_title.text = "← Select a slot"
	_picker_title.add_theme_font_size_override("font_size", int(_ref * 0.024))
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_title.modulate = Color(0.7, 0.7, 0.7)
	right_vbox.add_child(_picker_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(scroll)

	_picker_list = VBoxContainer.new()
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_list.add_theme_constant_override("separation", int(_ref * 0.007))
	scroll.add_child(_picker_list)

	_unequip_btn = Button.new()
	_unequip_btn.text = "Unequip"
	_unequip_btn.custom_minimum_size = Vector2(_ref * 0.16, _ref * 0.065)
	_unequip_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
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
		var none_lbl := Label.new()
		none_lbl.text = "No %s items owned yet." % label_name.to_lower()
		none_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
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

func _refresh_companion_picker() -> void:
	_picker_title.text = "Companions"
	_picker_title.modulate = Color(1.0, 1.0, 1.0)
	var active_id: String = SceneManager.save_manager.active_companion
	_unequip_btn.disabled = active_id == ""
	var all_ids: Array[String] = CompanionRegistry.all_ids()
	if all_ids.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No companions available yet."
		none_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
		none_lbl.modulate = Color(0.6, 0.6, 0.6)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_picker_list.add_child(none_lbl)
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

	var name_lbl := Label.new()
	name_lbl.text = c.display_name
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not unlocked:
		name_lbl.modulate = Color(0.5, 0.5, 0.5)
	name_row.add_child(name_lbl)

	if is_active:
		var eq_lbl := Label.new()
		eq_lbl.text = "[A]"
		eq_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
		eq_lbl.modulate = Color(0.4, 1.0, 0.5)
		name_row.add_child(eq_lbl)

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

	var equip_btn := Button.new()
	equip_btn.text = "Active" if is_active else "Equip"
	equip_btn.disabled = is_active or not unlocked
	equip_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.065)
	equip_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	equip_btn.pressed.connect(_on_equip_companion.bind(c.companion_id))
	row.add_child(equip_btn)

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
		var eq_lbl := Label.new()
		eq_lbl.text = "[E]"
		eq_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
		eq_lbl.modulate = Color(0.4, 1.0, 0.5)
		name_row.add_child(eq_lbl)

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

	var equip_btn := Button.new()
	equip_btn.text = "Equipped" if is_equipped else "Equip"
	equip_btn.disabled = is_equipped
	equip_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.065)
	equip_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	equip_btn.pressed.connect(_on_equip.bind(item_id))
	row.add_child(equip_btn)

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

func _input(event: InputEvent) -> void:
	if hub_mode:
		return
	if event.is_action_pressed("character"):
		get_viewport().set_input_as_handled()
		_on_close()
