extends "res://scenes/ui/BaseOverlay.gd"

const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const CompanionRegistry = preload("res://autoloads/CompanionRegistry.gd")
const CompanionData = preload("res://data/CompanionData.gd")
const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const _GearRolls = preload("res://game_logic/items/GearRolls.gd")
const _PaperDoll = preload("res://game_logic/character/PaperDoll.gd")
const _HeroAppearanceScene = preload("res://scenes/ui/HeroAppearanceScene.gd")
const _CharacterProfessions = preload("res://scenes/ui/CharacterProfessions.gd")
const _GearTooltip = preload("res://game_logic/items/GearTooltip.gd")
const _GearInspect = preload("res://scenes/ui/GearInspect.gd")

## Laid out two per row (TID-563: eight slots no longer fit one column).
const _SLOTS: Array[String] = [
	"weapon", "offhand", "helmet", "shoulders", "armor", "boots", "ring", "trinket",
]
const _SLOT_LABELS: Dictionary = {
	"weapon":  "Weapon",
	"offhand": "Off Hand",
	"armor":   "Armor",
	"shoulders": "Shoulders",
	"helmet":  "Helmet",
	"boots":   "Boots",
	"ring":    "Ring",
	"trinket": "Trinket",
}

const _COMPANION_LOCKED_TEXT: Dictionary = {
	"maiteln": "Travel with Maiteln in the story to unlock.",
}

const _COMPANION_FIRST_EQUIP_TOAST: Dictionary = {
	"maiteln": "Maiteln chuckles. 'Try to keep up, boy.'",
}

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
var _sheet_vbox: VBoxContainer = null   # GID-187 / TID-792: character-sheet stat totals

func _ready() -> void:
	super._ready()
	_build_ui()
	_refresh_slot_buttons()

func _build_ui() -> void:
	var is_portrait: bool = _vw < _vh
	var root_vbox: VBoxContainer
	if hub_mode:
		var m: int = int(_ref * 0.012)
		var margin := _UiUtil.make_margin(m, m, m, m, self)
		# _and_offsets_: the plain preset sets anchors but leaves the offsets, so the
		# margin stays at its minimum size instead of filling the hub content area.
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root_vbox = _UiUtil.make_vbox(int(_ref * 0.012), margin)
	else:
		_build_backdrop(0.78)
		var panel_w: float = _vw * 0.95 if is_portrait else _vw * 0.86
		var panel_h: float = _vh * 0.92 if is_portrait else _vh * 0.86
		var outer := _build_centered_panel(panel_w, panel_h)
		root_vbox = _build_margin_vbox(outer, 0.015, 0.012)

	# ---- Header bar ----------------------------------------------------------
	var header := _UiUtil.make_hbox(0, root_vbox)

	var title_lbl := _UiUtil.make_label("Character", int(_ref * 0.03), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, header)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not hub_mode:
		var close_btn := _UiUtil.make_button("Close  [C]" if not OS.has_feature("android") else "Close",
				Vector2(_ref * 0.14, _ref * 0.065), int(_ref * 0.022), _on_close, header)

	# ---- Main content --------------------------------------------------------
	var content: BoxContainer
	if is_portrait:
		content = _UiUtil.make_vbox(int(_ref * 0.01))
	else:
		content = _UiUtil.make_hbox(int(_vw * 0.015))
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content)

	# ---- Left: avatar + slot buttons -----------------------------------------
	var left_vbox := _UiUtil.make_vbox(int(_ref * 0.010))
	if is_portrait:
		left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		left_vbox.custom_minimum_size = Vector2(_vw * 0.30, 0)
	content.add_child(left_vbox)

	# The hero in their current gear and look (BID-076), with a Change Look button.
	var avatar_rect := TextureRect.new()
	avatar_rect.texture = _PaperDoll.idle_texture(_PaperDoll.gear_of(SceneManager.save_manager),
			_PaperDoll.appearance_of(SceneManager.save_manager))
	avatar_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var avatar_size: float = _ref * 0.22
	avatar_rect.custom_minimum_size = Vector2(avatar_size, avatar_size)
	avatar_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_vbox.add_child(avatar_rect)

	var avatar_lbl := _UiUtil.make_label("Saimtar", int(_ref * 0.022), Color(0.8, 0.8, 0.8),
			HORIZONTAL_ALIGNMENT_CENTER, left_vbox)
	_UiUtil.make_button("Change Look", Vector2(_ref * 0.18, _ref * 0.05), int(_ref * 0.02),
			func() -> void: _HeroAppearanceScene.open_editor(get_tree(), _rebuild_ui),
			left_vbox).size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var equip_hdr := _UiUtil.make_label("Equipment", int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER,
			left_vbox)

	var slot_grid := _UiUtil.make_grid(2, int(_ref * 0.010), int(_ref * 0.010), left_vbox)
	for slot in _SLOTS:
		var btn := _UiUtil.make_button("", Vector2(0, _ref * 0.065), int(_ref * 0.020),
				_on_slot_pressed.bind(slot), slot_grid)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_slot_btns[slot] = btn

	# GID-187 / TID-792: every stat across the equipped gear, at the player's level.
	_UiUtil.make_label("Gear stats", int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, left_vbox)
	_sheet_vbox = _UiUtil.make_vbox(int(_ref * 0.003), left_vbox)

	var companion_hdr := _UiUtil.make_label("Mentor", int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER,
			left_vbox)

	_companion_btn = _UiUtil.make_button("", Vector2(0, _ref * 0.065), int(_ref * 0.022),
			_on_slot_pressed.bind("companion"), left_vbox)
	_companion_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# GID-141: no companion slot until Maiteln has agreed to fight beside you.
	var has_companion: bool = SceneManager.save_manager.has_learned(_UnlockLadder.FEAT_COMPANION)
	companion_hdr.visible = has_companion
	_companion_btn.visible = has_companion

	# GID-182 / TID-766: profession levels, XP and known recipes.
	_CharacterProfessions.build(left_vbox, SceneManager.save_manager, _vh)

	if not is_portrait:
		content.add_child(VSeparator.new())

	# ---- Right: picker -------------------------------------------------------
	var right_vbox := _UiUtil.make_vbox(int(_ref * 0.008), content)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_panel = right_vbox

	_picker_title = _UiUtil.make_label("← Select a slot", int(_ref * 0.024), Color(0.7, 0.7, 0.7),
			HORIZONTAL_ALIGNMENT_CENTER, right_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	_picker_list = _UiUtil.make_vbox(int(_ref * 0.007), scroll)
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_unequip_btn = _UiUtil.make_button("Unequip", Vector2(_ref * 0.16, _ref * 0.065), int(_ref * 0.022), _on_unequip,
			right_vbox)
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
			# TID-538: the item's name reads in its rarity colour.
			btn.add_theme_color_override("font_color",
					_UiUtil.rarity_color(str(sm.gear.roll_of(equipped_id)["rarity"])))
		if equipped_id == "":
			btn.remove_theme_color_override("font_color")
		if slot == _selected_slot:
			btn.modulate = Color(1.0, 1.0, 0.5)
	# Companion slot button
	if _companion_btn != null:
		var cid: String = sm.active_companion
		if cid == "":
			_companion_btn.text = "  Mentor:  (none)"
			_companion_btn.modulate = Color(0.7, 0.7, 0.7)
		else:
			var c: CompanionData = CompanionRegistry.get_companion(cid)
			var display: String = c.display_name if c != null else cid
			_companion_btn.text = "  Mentor:  %s" % display
			_companion_btn.modulate = Color(1.0, 1.0, 1.0)
		if _selected_slot == "companion":
			_companion_btn.modulate = Color(1.0, 1.0, 0.5)
	_refresh_sheet()

## GID-187 / TID-792: the character sheet's stat totals across every equipped item.
func _refresh_sheet() -> void:
	if _sheet_vbox != null:
		_GearInspect.fill_sheet(_sheet_vbox, _ref, SceneManager.save_manager, _SLOTS)

## Blacksmith upgrade level of an owned item (weapons only; other slots never upgrade).
func _upgrade_level_of(item_id: String, slot: String) -> int:
	return _GearInspect.upgrade_level_of(SceneManager.save_manager, item_id, slot)

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
		var none_lbl := _UiUtil.make_label("No %s items owned yet." % label_name.to_lower(), int(_ref * 0.022),
				Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, _picker_list)
		return

	for item_id in owned:
		var w: WeaponData = WeaponRegistry.get_weapon(item_id)
		if w == null:
			continue
		var row := _make_picker_row(item_id, w, item_id == equipped_id)
		_picker_list.add_child(row)

func _refresh_companion_picker() -> void:
	_picker_title.text = "Mentors"
	_picker_title.modulate = Color(1.0, 1.0, 1.0)
	var active_id: String = SceneManager.save_manager.active_companion
	_unequip_btn.disabled = active_id == ""
	var all_ids: Array[String] = CompanionRegistry.all_ids()
	if all_ids.is_empty():
		var none_lbl := _UiUtil.make_label("No mentors available yet.", int(_ref * 0.022), Color(0.6, 0.6, 0.6),
				HORIZONTAL_ALIGNMENT_CENTER, _picker_list)
		return
	for cid in all_ids:
		var c: CompanionData = CompanionRegistry.get_companion(cid)
		if c == null:
			continue
		var row := _make_companion_row(c, cid == active_id)
		_picker_list.add_child(row)

func _make_companion_row(c: CompanionData, is_active: bool) -> HBoxContainer:
	var unlocked: bool = CompanionRegistry.is_unlocked(c.companion_id)
	var row := _UiUtil.make_hbox(int(_vw * 0.008))

	var info_vbox := _UiUtil.make_vbox(int(_ref * 0.002), row)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_row := _UiUtil.make_hbox(0, info_vbox)

	var name_lbl := _UiUtil.make_label(c.display_name, int(_ref * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not unlocked:
		name_lbl.modulate = Color(0.5, 0.5, 0.5)
	name_row.add_child(name_lbl)

	if is_active:
		var eq_lbl := _UiUtil.make_label("[A]", int(_ref * 0.022), Color(0.4, 1.0, 0.5), HORIZONTAL_ALIGNMENT_LEFT,
				name_row)

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

	var equip_btn := _UiUtil.make_button("Active" if is_active else "Equip", Vector2(_ref * 0.14, _ref * 0.065),
			int(_ref * 0.022), _on_equip_companion.bind(c.companion_id), row)
	equip_btn.disabled = is_active or not unlocked

	return row

func _companion_locked_text(c: CompanionData) -> String:
	if _COMPANION_LOCKED_TEXT.has(c.companion_id):
		return str(_COMPANION_LOCKED_TEXT[c.companion_id])
	return "Locked — complete story objectives to unlock."

func _make_picker_row(item_id: String, w: WeaponData, is_equipped: bool) -> HBoxContainer:
	var row := _UiUtil.make_hbox(int(_vw * 0.008))

	var info_vbox := _UiUtil.make_vbox(int(_ref * 0.002), row)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_row := _UiUtil.make_hbox(0, info_vbox)

	var name_lbl := Label.new()
	var disp_name: String = w.display_name
	if w.slot == "weapon":
		var win: Dictionary = SceneManager.save_manager.get_owned_weapon_by_id(item_id)
		var wlvl: int = int(win.get("upgrade_level", 0))
		if wlvl > 0:
			disp_name += " +%d" % wlvl
	var roll: Dictionary = SceneManager.save_manager.gear.roll_of(item_id)
	name_lbl.text = "%s  (%s)" % [disp_name, _GearRolls.label(roll)]
	name_lbl.add_theme_color_override("font_color", _UiUtil.rarity_color(str(roll["rarity"])))
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)
	var affix_text: String = _GearRolls.affix_label(roll)  # school affix (GID-181 / TID-754)
	if affix_text != "":
		_UiUtil.make_label(affix_text, int(_ref * 0.019), Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, info_vbox)

	if is_equipped:
		var eq_lbl := _UiUtil.make_label("[E]", int(_ref * 0.022), Color(0.4, 1.0, 0.5), HORIZONTAL_ALIGNMENT_LEFT,
				name_row)

	var sm := SceneManager.save_manager
	var upgrade_level: int = _upgrade_level_of(item_id, w.slot)
	var mult: float = sm.gear.mult(item_id)
	var effect_lbl := Label.new()
	effect_lbl.text = _GearTooltip.summary(w, upgrade_level, sm.level, mult)
	effect_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	effect_lbl.modulate = Color(0.9, 1.0, 0.7)
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(effect_lbl)
	# GID-187 / TID-792: the level requirement, flagged when the player is below it.
	if w.level_req > sm.level:
		_UiUtil.make_label("Requires level %d (you are level %d)" % [w.level_req, sm.level],
				int(_ref * 0.019), Color(1.0, 0.45, 0.4), HORIZONTAL_ALIGNMENT_LEFT, info_vbox)

	var equip_btn := _UiUtil.make_button("Equipped" if is_equipped else "Equip", Vector2(_ref * 0.14, _ref * 0.065),
			int(_ref * 0.022), _on_equip.bind(item_id), row)
	equip_btn.disabled = is_equipped

	# Inspect (details, and the comparison against the equipped item in this slot): hold Shift while
	# hovering on desktop, or tap-and-hold on mobile (no Shift key there).
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
	var sm := SceneManager.save_manager
	var w: WeaponData = WeaponRegistry.get_weapon(item_id)
	# GID-187 / TID-792: an item above the player's level is refused (touch and mouse alike).
	if w != null and w.level_req > sm.level:
		SceneManager.show_toast("Too advanced", "%s needs level %d (you are level %d)." % [
			w.display_name, w.level_req, sm.level])
		return
	sm.equip_item(item_id, _selected_slot)
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

func _show_companion_toast(companion_id: String) -> void:
	var c: CompanionData = CompanionRegistry.get_companion(companion_id)
	if c == null:
		return
	var msg: String = str(_COMPANION_FIRST_EQUIP_TOAST.get(companion_id,
		"%s joins you as your mentor." % c.display_name))
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

## GID-187 / TID-792: the item's details (name, band, level requirement, stat lines) and, for an item
## not yet worn, the comparison against the equipped item in its slot (green / red stat deltas).
func _show_compare_tooltip(item_id: String, candidate: WeaponData, anchor: Control) -> void:
	_hide_compare_tooltip()

	var sm := SceneManager.save_manager
	var player_lvl: int = sm.level
	var equipped_id: String = sm.get_equipped_by_slot(candidate.slot)
	var equipped: WeaponData = WeaponRegistry.get_weapon(equipped_id) if equipped_id != "" else null
	var is_worn: bool = equipped_id == item_id
	var candidate_lvl: int = _upgrade_level_of(item_id, candidate.slot)
	var equipped_lvl: int = _upgrade_level_of(equipped_id, candidate.slot)
	var cand_tip: Dictionary = _GearTooltip.build(candidate, candidate_lvl, player_lvl,
			str(sm.gear.roll_of(item_id)["rarity"]), sm.gear.mult(item_id))
	var eq_tip: Dictionary = {}
	var rows: Array[Dictionary] = []
	if equipped != null and not is_worn:
		eq_tip = _GearTooltip.build(equipped, equipped_lvl, player_lvl,
				str(sm.gear.roll_of(equipped_id)["rarity"]), sm.gear.mult(equipped_id))
		var deltas: Dictionary = _GearTooltip.compare(candidate, candidate_lvl, equipped, equipped_lvl, player_lvl)
		rows = _GearTooltip.delta_rows(deltas)
	var slot_name: String = _SLOT_LABELS.get(candidate.slot, candidate.slot.capitalize())
	var title: String = ("Details — %s" if is_worn else "Compare — %s") % slot_name
	var note: String = "Nothing equipped in this slot." if (equipped == null and not is_worn) else ""

	var popup := PopupPanel.new()
	add_child(popup)
	_compare_popup = popup
	var vb := _UiUtil.make_vbox(int(_ref * 0.008), popup)
	vb.custom_minimum_size = Vector2(_ref * 0.34, 0)
	_GearInspect.fill(vb, _ref, title, cand_tip, eq_tip, rows, note)
	popup.popup(Rect2i(anchor.get_screen_transform().origin as Vector2i, Vector2i(int(_ref * 0.34), 0)))

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_ev: InputEventKey = event
		if key_ev.keycode == KEY_SHIFT and _hovered_compare_item != "" and _hovered_compare_row != null:
			if key_ev.pressed:
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

