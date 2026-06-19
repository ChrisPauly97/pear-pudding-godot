extends Control

signal closed

const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")
const UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")

var _vh: float = 0.0
var _vw: float = 0.0
var _ref: float = 0.0
var _coin_label: Label
var _essence_label: Label
var _weapon_list: VBoxContainer
var _weapon_scroll: ScrollContainer

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_ref = minf(_vh, _vw)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel_w: float = minf(_vw * 0.90, _vh * 0.70)
	var panel_h: float = _vh * 0.85
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	outer.size = Vector2(panel_w, panel_h)
	outer.position = Vector2((_vw - panel_w) * 0.5, (_vh - panel_h) * 0.5)
	add_child(outer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   int(_vw * 0.015))
	margin.add_theme_constant_override("margin_right",  int(_vw * 0.015))
	margin.add_theme_constant_override("margin_top",    int(_ref * 0.015))
	margin.add_theme_constant_override("margin_bottom", int(_ref * 0.015))
	outer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", int(_ref * 0.012))
	margin.add_child(root_vbox)

	# Header row
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "Blacksmith"
	title_lbl.add_theme_font_size_override("font_size", int(_ref * 0.032))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close  [C]" if not OS.has_feature("android") else "Close"
	close_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.065)
	close_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# Currency display
	var currency_row := HBoxContainer.new()
	currency_row.add_theme_constant_override("separation", int(_vw * 0.03))
	root_vbox.add_child(currency_row)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", int(_ref * 0.024))
	_coin_label.modulate = Color(1.0, 0.85, 0.1)
	currency_row.add_child(_coin_label)

	_essence_label = Label.new()
	_essence_label.add_theme_font_size_override("font_size", int(_ref * 0.024))
	_essence_label.modulate = Color(0.5, 0.9, 1.0)
	currency_row.add_child(_essence_label)

	# Scrollable weapon list
	_weapon_scroll = ScrollContainer.new()
	_weapon_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_weapon_scroll.custom_minimum_size = Vector2(0.0, _ref * 0.30)
	root_vbox.add_child(_weapon_scroll)

	_weapon_list = VBoxContainer.new()
	_weapon_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_list.add_theme_constant_override("separation", int(_ref * 0.010))
	_weapon_scroll.add_child(_weapon_list)

func _refresh() -> void:
	var saved_scroll: int = _weapon_scroll.scroll_vertical if _weapon_scroll else 0
	for child in _weapon_list.get_children():
		child.queue_free()

	var sm := SceneManager.save_manager
	_coin_label.text = "Coins: %d" % sm.coins
	_essence_label.text = "Essence: %d" % sm.essence

	var owned: Array[Dictionary] = sm.owned_weapons
	if owned.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "You own no weapons yet."
		none_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
		none_lbl.modulate = Color(0.6, 0.6, 0.6)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_weapon_list.add_child(none_lbl)
		if _weapon_scroll and saved_scroll > 0:
			_weapon_scroll.scroll_vertical = saved_scroll
		return

	for inst: Dictionary in owned:
		var wid: String = str(inst.get("weapon_id", ""))
		var level: int = int(inst.get("upgrade_level", 0))
		var weapon: WeaponData = WeaponRegistry.get_weapon(wid)
		if weapon == null:
			continue
		var row := _make_weapon_row(wid, weapon, level, sm)
		_weapon_list.add_child(row)

	if _weapon_scroll and saved_scroll > 0:
		_weapon_scroll.scroll_vertical = saved_scroll

func _make_weapon_row(wid: String, weapon: WeaponData, level: int, sm: Node) -> VBoxContainer:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", int(_ref * 0.004))

	var sep := HSeparator.new()
	outer.add_child(sep)

	# Name + level
	var name_row := HBoxContainer.new()
	outer.add_child(name_row)

	var name_lbl := Label.new()
	var level_suffix: String = "" if level == 0 else " +%d" % level
	name_lbl.text = weapon.display_name + level_suffix
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.024))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	var equipped_id: String = sm.equipped_weapon
	if equipped_id == wid:
		var eq_lbl := Label.new()
		eq_lbl.text = "[E]"
		eq_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
		eq_lbl.modulate = Color(0.4, 1.0, 0.5)
		name_row.add_child(eq_lbl)

	# Current stats
	var cur_lbl := Label.new()
	cur_lbl.text = "  Current: %s" % UpgradeDefs.get_display_string(weapon, level)
	cur_lbl.add_theme_font_size_override("font_size", int(_ref * 0.020))
	cur_lbl.modulate = Color(0.9, 1.0, 0.7)
	outer.add_child(cur_lbl)

	# Next-level preview or max label
	if level < UpgradeDefs.MAX_LEVEL:
		var next_lbl := Label.new()
		next_lbl.text = "  Next (+%d): %s  |  Cost: %d coins, %d essence" % [
			level + 1,
			UpgradeDefs.get_display_string(weapon, level + 1),
			UpgradeDefs.cost_coins(level),
			UpgradeDefs.cost_essence(level),
		]
		next_lbl.add_theme_font_size_override("font_size", int(_ref * 0.019))
		next_lbl.modulate = Color(0.7, 0.85, 1.0)
		outer.add_child(next_lbl)
	else:
		var max_lbl := Label.new()
		max_lbl.text = "  MAX LEVEL"
		max_lbl.add_theme_font_size_override("font_size", int(_ref * 0.020))
		max_lbl.modulate = Color(1.0, 0.85, 0.1)
		outer.add_child(max_lbl)

	# Action buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", int(_vw * 0.010))
	outer.add_child(btn_row)

	# Upgrade button
	var upgrade_btn := Button.new()
	upgrade_btn.custom_minimum_size = Vector2(_ref * 0.18, _ref * 0.065)
	upgrade_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	var can_upgrade: bool = level < UpgradeDefs.MAX_LEVEL \
		and UpgradeDefs.can_afford_upgrade(level, sm.coins, sm.essence)
	if level >= UpgradeDefs.MAX_LEVEL:
		upgrade_btn.text = "Max"
		upgrade_btn.disabled = true
	elif not UpgradeDefs.can_afford_upgrade(level, sm.coins, sm.essence):
		upgrade_btn.text = "Upgrade"
		upgrade_btn.disabled = true
		upgrade_btn.modulate = Color(0.6, 0.6, 0.6)
	else:
		upgrade_btn.text = "Upgrade"
		upgrade_btn.disabled = false
	upgrade_btn.pressed.connect(_on_upgrade_weapon.bind(wid))
	btn_row.add_child(upgrade_btn)

	# Salvage button
	var is_equipped: bool = sm.equipped_weapon == wid or sm.equipped_armor == wid \
		or sm.equipped_ring == wid or sm.equipped_trinket == wid
	var salvage_btn := Button.new()
	salvage_btn.text = "Salvage (+%d coins, +%d essence)" % [
		UpgradeDefs.SALVAGE_COINS, UpgradeDefs.SALVAGE_ESSENCE]
	salvage_btn.custom_minimum_size = Vector2(_ref * 0.35, _ref * 0.065)
	salvage_btn.add_theme_font_size_override("font_size", int(_ref * 0.019))
	salvage_btn.disabled = is_equipped
	if is_equipped:
		salvage_btn.modulate = Color(0.5, 0.5, 0.5)
	salvage_btn.pressed.connect(_on_salvage_weapon.bind(wid))
	btn_row.add_child(salvage_btn)

	return outer

func _on_upgrade_weapon(weapon_id: String) -> void:
	var sm := SceneManager.save_manager
	var inst: Dictionary = sm.get_owned_weapon_by_id(weapon_id)
	var level: int = int(inst.get("upgrade_level", 0))
	var weapon: WeaponData = WeaponRegistry.get_weapon(weapon_id)
	var ok: bool = sm.upgrade_weapon(weapon_id)
	if ok:
		var new_level: int = level + 1
		var wname: String = weapon.display_name if weapon != null else weapon_id
		SceneManager.show_toast("Upgraded!", "%s → +%d" % [wname, new_level])
		_refresh()
	else:
		SceneManager.show_toast("Cannot Upgrade", "Insufficient funds or max level reached.")

func _on_salvage_weapon(weapon_id: String) -> void:
	var sm := SceneManager.save_manager
	var weapon: WeaponData = WeaponRegistry.get_weapon(weapon_id)
	var wname: String = weapon.display_name if weapon != null else weapon_id
	var result: Dictionary = sm.salvage_weapon(weapon_id)
	if not result.is_empty():
		SceneManager.show_toast("Salvaged!", "%s  +%d coins, +%d essence" % [
			wname, int(result.get("coins", 0)), int(result.get("essence", 0))])
		_refresh()
	else:
		SceneManager.show_toast("Cannot Salvage", "Equipped items cannot be salvaged.")

func _on_close() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
