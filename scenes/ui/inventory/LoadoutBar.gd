## Loadout tabs + Rename / Copy / Delete for the deck table (moved out of
## InventoryScene, GID-180). Deck edits auto-save, so switching needs no commit:
## the bar changes the active loadout and emits `switched`; the host reloads
## its working deck from `player_deck`.
extends VBoxContainer

signal switched
signal loadout_renamed

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _ref: float = 0.0
var _tab_row: HBoxContainer
var _rename_btn: Button
var _dup_btn: Button
var _del_btn: Button
var _sig: String = ""


func setup(ref: float) -> void:
	_ref = ref
	add_theme_constant_override("separation", int(ref * 0.005))
	_tab_row = _UiUtil.make_hbox(int(ref * 0.005), self)
	var actions := _UiUtil.make_hbox(int(ref * 0.006), self)
	_rename_btn = _UiUtil.make_button("Rename", Vector2(ref * 0.12, ref * 0.055), int(ref * 0.020), _on_rename,
			actions)
	_dup_btn = _UiUtil.make_button("Copy", Vector2(ref * 0.10, ref * 0.055), int(ref * 0.020), _on_dup, actions)
	_del_btn = _UiUtil.make_button("Delete", Vector2(ref * 0.12, ref * 0.055), int(ref * 0.020), _on_del, actions)
	_del_btn.modulate = Color(1.0, 0.4, 0.4)


## Rebuilds the tabs when they would look different. `working_size` is the
## active deck's size (its tab turns red outside the deck size limits).
func refresh(working_size: int) -> void:
	var sm := SceneManager.save_manager
	var names: Array[String] = sm.decks.get_loadout_names()
	var active_idx: int = sm.active_loadout
	var at_cap: bool = names.size() >= sm.MAX_LOADOUTS
	var valid: Array[bool] = []
	for i in range(names.size()):
		valid.append(working_size >= IsoConst.DECK_MIN and working_size <= IsoConst.DECK_MAX
				if i == active_idx else sm.decks.is_loadout_valid(i))
	# Only rebuilt when the tabs would look different (GID-164 / TID-684).
	var sig: String = "%s|%d|%s|%d" % [",".join(names), active_idx, str(valid), int(_ref)]
	if sig == _sig and _tab_row.get_child_count() > 0:
		return
	_sig = sig
	for child in _tab_row.get_children():
		child.queue_free()
	for i in range(names.size()):
		var tab_btn := _UiUtil.make_button(names[i], Vector2(_ref * 0.12, _ref * 0.055), int(_ref * 0.020))
		tab_btn.flat = true
		if i == active_idx:
			tab_btn.modulate = Color.WHITE if valid[i] else Color(1.0, 0.35, 0.35)
		else:
			tab_btn.modulate = Color(0.7, 0.7, 0.7) if valid[i] else Color(0.75, 0.28, 0.28)
		tab_btn.pressed.connect(_on_tab.bind(i))
		_tab_row.add_child(tab_btn)
	var new_btn := _UiUtil.make_button("+", Vector2(_ref * 0.055, _ref * 0.055), int(_ref * 0.025), _on_new,
			_tab_row)
	new_btn.disabled = at_cap
	_del_btn.disabled = names.size() <= 1
	_dup_btn.disabled = at_cap


func _on_tab(index: int) -> void:
	SceneManager.save_manager.decks.set_active_loadout(index)
	switched.emit()


func _on_new() -> void:
	var sm := SceneManager.save_manager
	var new_idx: int = sm.decks.add_loadout("Deck %d" % (sm.loadouts.size() + 1))
	if new_idx < 0:
		return
	sm.decks.set_active_loadout(new_idx)
	switched.emit()


func _on_dup() -> void:
	var sm := SceneManager.save_manager
	var new_idx: int = sm.decks.duplicate_loadout(sm.active_loadout)
	if new_idx < 0:
		return
	sm.decks.set_active_loadout(new_idx)
	switched.emit()


func _popup(width_frac: float) -> Array:
	var popup := PopupPanel.new()
	add_child(popup)
	var vb := _UiUtil.make_vbox(int(_ref * 0.012), popup)
	vb.custom_minimum_size = Vector2(_ref * width_frac, 0)
	return [popup, vb]


func _on_rename() -> void:
	var sm := SceneManager.save_manager
	if sm.active_loadout < 0 or sm.active_loadout >= sm.loadouts.size():
		return
	var pv: Array = _popup(0.5)
	var popup: PopupPanel = pv[0]
	var vb: VBoxContainer = pv[1]
	_UiUtil.make_label("Rename Loadout", int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vb)
	var edit := LineEdit.new()
	edit.text = str(sm.loadouts[sm.active_loadout].get("name", ""))
	edit.max_length = 20
	edit.add_theme_font_size_override("font_size", int(_ref * 0.024))
	edit.custom_minimum_size = Vector2(0, _ref * 0.065)
	vb.add_child(edit)
	var btn_row := _UiUtil.make_hbox(int(_ref * 0.012), vb)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_UiUtil.make_button("OK", Vector2(_ref * 0.12, _ref * 0.065), int(_ref * 0.022), func() -> void:
		var new_name: String = edit.text.strip_edges()
		if new_name.length() > 0:
			sm.decks.rename_loadout(sm.active_loadout, new_name)
			loadout_renamed.emit()
		popup.queue_free(), btn_row)
	_UiUtil.make_button("Cancel", Vector2(_ref * 0.12, _ref * 0.065), int(_ref * 0.022), popup.queue_free, btn_row)
	popup.popup_centered()
	# Shift to top half so the Android keyboard doesn't cover the input field.
	popup.position.y = int(get_viewport_rect().size.y * 0.08)
	edit.grab_focus()
	edit.select_all()


func _on_del() -> void:
	var sm := SceneManager.save_manager
	if sm.loadouts.size() <= 1:
		return
	var pv: Array = _popup(0.5)
	var popup: PopupPanel = pv[0]
	var vb: VBoxContainer = pv[1]
	var lbl := _UiUtil.make_label("Delete '%s'?\nThis cannot be undone."
			% str(sm.loadouts[sm.active_loadout].get("name", "this loadout")), int(_ref * 0.022), Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, vb)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn_row := _UiUtil.make_hbox(int(_ref * 0.012), vb)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes_btn := _UiUtil.make_button("Yes, Delete", Vector2(_ref * 0.16, _ref * 0.065), int(_ref * 0.022),
			func() -> void:
				popup.queue_free()
				sm.decks.delete_loadout(sm.active_loadout)
				switched.emit(), btn_row)
	yes_btn.modulate = Color(1.0, 0.4, 0.4)
	_UiUtil.make_button("Cancel", Vector2(_ref * 0.14, _ref * 0.065), int(_ref * 0.022), popup.queue_free, btn_row)
	popup.popup_centered()
