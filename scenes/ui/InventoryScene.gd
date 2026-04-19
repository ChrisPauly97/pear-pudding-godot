extends Control

signal closed

const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const WeaponRegistry = preload("res://autoloads/WeaponRegistry.gd")
const WeaponData = preload("res://data/WeaponData.gd")

var _vh: float = 0.0
var _vw: float = 0.0
var _working_deck: Array[String] = []

var _collection_list: VBoxContainer
var _deck_list: VBoxContainer
var _deck_count_label: Label
var _coin_label: Label

# Weapon UI
var _weapon_list: VBoxContainer
var _equipped_col: VBoxContainer
var _selected_col: VBoxContainer
var _equip_btn: Button
var _selected_weapon_id: String = ""
var _cards_panel: Control
var _weapons_panel: Control
var _tab_cards_btn: Button
var _tab_weapons_btn: Button

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_vh = get_viewport().get_visible_rect().size.y
	_vw = get_viewport().get_visible_rect().size.x
	_working_deck.assign(SceneManager.save_manager.player_deck)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	# Dark backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Portrait: stack panels; landscape: side-by-side columns.
	var is_portrait: bool = _vw < _vh

	var outer := PanelContainer.new()
	var panel_w: float = _vw * 0.95 if is_portrait else _vw * 0.86
	var panel_h: float = _vh * 0.92 if is_portrait else _vh * 0.86
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

	# Wrapper VBox: tab bar on top, then the active content panel below
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", int(_vh * 0.008))
	outer_margin.add_child(wrapper)

	# ---- Tab bar -----------------------------------------------------------
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", int(_vw * 0.008))
	wrapper.add_child(tab_bar)

	_tab_cards_btn = Button.new()
	_tab_cards_btn.text = "Cards"
	_tab_cards_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.05)
	_tab_cards_btn.add_theme_font_size_override("font_size", int(_vh * 0.021))
	_tab_cards_btn.pressed.connect(_on_tab_cards)
	tab_bar.add_child(_tab_cards_btn)

	_tab_weapons_btn = Button.new()
	_tab_weapons_btn.text = "Weapons"
	_tab_weapons_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.05)
	_tab_weapons_btn.add_theme_font_size_override("font_size", int(_vh * 0.021))
	_tab_weapons_btn.pressed.connect(_on_tab_weapons)
	tab_bar.add_child(_tab_weapons_btn)

	# Scroll height floor in portrait mode
	var scroll_min_h: float = _vh * 0.25 if is_portrait else 0.0

	# ====================================================================
	# CARDS PANEL
	# ====================================================================
	var root_box: BoxContainer
	if is_portrait:
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", int(_vh * 0.008))
		root_box = vb
	else:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", int(_vw * 0.012))
		root_box = hb
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_panel = root_box
	wrapper.add_child(root_box)

	# ---- Collection panel ------------------------------------------------
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
	if is_portrait:
		left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(left_vbox)

	var col_title := Label.new()
	col_title.text = "Collection"
	col_title.add_theme_font_size_override("font_size", int(_vh * 0.026))
	col_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(col_title)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.modulate = Color(1.0, 0.85, 0.1)
	left_vbox.add_child(_coin_label)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if scroll_min_h > 0.0:
		left_scroll.custom_minimum_size = Vector2(0.0, scroll_min_h)
	left_vbox.add_child(left_scroll)

	_collection_list = VBoxContainer.new()
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("separation", int(_vh * 0.008))
	left_scroll.add_child(_collection_list)

	if not is_portrait:
		root_box.add_child(VSeparator.new())

	# ---- Deck panel ------------------------------------------------------
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	if is_portrait:
		right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(right_vbox)

	_deck_count_label = Label.new()
	_deck_count_label.add_theme_font_size_override("font_size", int(_vh * 0.026))
	_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(_deck_count_label)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if scroll_min_h > 0.0:
		right_scroll.custom_minimum_size = Vector2(0.0, scroll_min_h)
	right_vbox.add_child(right_scroll)

	_deck_list = VBoxContainer.new()
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_list.add_theme_constant_override("separation", int(_vh * 0.008))
	right_scroll.add_child(_deck_list)

	# ---- Buttons ---------------------------------------------------------
	if is_portrait:
		var btn_hbox := HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", int(_vw * 0.04))
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		root_box.add_child(btn_hbox)

		var save_btn := Button.new()
		save_btn.text = "Save Deck"
		save_btn.custom_minimum_size = Vector2(_vw * 0.35, _vh * 0.055)
		save_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
		save_btn.pressed.connect(_on_save)
		btn_hbox.add_child(save_btn)

		var close_btn := Button.new()
		close_btn.text = "Close"
		close_btn.custom_minimum_size = Vector2(_vw * 0.35, _vh * 0.055)
		close_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
		close_btn.pressed.connect(_on_close)
		btn_hbox.add_child(close_btn)
	else:
		var btn_vbox := VBoxContainer.new()
		btn_vbox.add_theme_constant_override("separation", int(_vh * 0.012))
		btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		root_box.add_child(btn_vbox)

		var save_btn := Button.new()
		save_btn.text = "Save Deck"
		save_btn.custom_minimum_size = Vector2(_vw * 0.1, _vh * 0.055)
		save_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
		save_btn.pressed.connect(_on_save)
		btn_vbox.add_child(save_btn)

		var close_btn := Button.new()
		close_btn.text = "Close  [I]" if not OS.has_feature("android") else "Close"
		close_btn.custom_minimum_size = Vector2(_vw * 0.1, _vh * 0.055)
		close_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
		close_btn.pressed.connect(_on_close)
		btn_vbox.add_child(close_btn)

	# ====================================================================
	# WEAPONS PANEL
	# ====================================================================
	var wp_box: BoxContainer
	if is_portrait:
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", int(_vh * 0.008))
		wp_box = vb
	else:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", int(_vw * 0.012))
		wp_box = hb
	wp_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wp_box.visible = false
	_weapons_panel = wp_box
	wrapper.add_child(wp_box)

	# ---- Weapon list column ----------------------------------------------
	var wlist_vbox := VBoxContainer.new()
	wlist_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wlist_vbox.size_flags_stretch_ratio = 1.0
	if is_portrait:
		wlist_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wp_box.add_child(wlist_vbox)

	var wlist_title := Label.new()
	wlist_title.text = "Owned Weapons"
	wlist_title.add_theme_font_size_override("font_size", int(_vh * 0.026))
	wlist_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wlist_vbox.add_child(wlist_title)

	var wlist_scroll := ScrollContainer.new()
	wlist_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if scroll_min_h > 0.0:
		wlist_scroll.custom_minimum_size = Vector2(0.0, scroll_min_h)
	wlist_vbox.add_child(wlist_scroll)

	_weapon_list = VBoxContainer.new()
	_weapon_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_list.add_theme_constant_override("separation", int(_vh * 0.008))
	wlist_scroll.add_child(_weapon_list)

	if not is_portrait:
		wp_box.add_child(VSeparator.new())

	# ---- Comparison column -----------------------------------------------
	var cmp_vbox := VBoxContainer.new()
	cmp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmp_vbox.size_flags_stretch_ratio = 1.5
	if is_portrait:
		cmp_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wp_box.add_child(cmp_vbox)

	var cmp_title := Label.new()
	cmp_title.text = "Compare"
	cmp_title.add_theme_font_size_override("font_size", int(_vh * 0.026))
	cmp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cmp_vbox.add_child(cmp_title)

	# Two side-by-side columns: Equipped | Selected
	var col_hbox := HBoxContainer.new()
	col_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_hbox.add_theme_constant_override("separation", int(_vw * 0.01))
	cmp_vbox.add_child(col_hbox)

	_equipped_col = VBoxContainer.new()
	_equipped_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipped_col.add_theme_constant_override("separation", int(_vh * 0.006))
	col_hbox.add_child(_equipped_col)

	col_hbox.add_child(VSeparator.new())

	_selected_col = VBoxContainer.new()
	_selected_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_col.add_theme_constant_override("separation", int(_vh * 0.006))
	col_hbox.add_child(_selected_col)

	# Equip + Close buttons row
	var wp_btn_row := HBoxContainer.new()
	wp_btn_row.add_theme_constant_override("separation", int(_vw * 0.02))
	wp_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cmp_vbox.add_child(wp_btn_row)

	_equip_btn = Button.new()
	_equip_btn.text = "Equip"
	_equip_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.055)
	_equip_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_equip_btn.disabled = true
	_equip_btn.pressed.connect(_on_equip_weapon)
	wp_btn_row.add_child(_equip_btn)

	var wp_close_btn := Button.new()
	wp_close_btn.text = "Close  [I]" if not OS.has_feature("android") else "Close"
	wp_close_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.055)
	wp_close_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
	wp_close_btn.pressed.connect(_on_close)
	wp_btn_row.add_child(wp_close_btn)

# -------------------------------------------------------------------------
# Refresh — rebuilds both panels from current working state
# -------------------------------------------------------------------------

func _refresh() -> void:
	_refresh_cards()
	_refresh_weapons()

func _refresh_cards() -> void:
	for child in _collection_list.get_children():
		child.queue_free()
	for child in _deck_list.get_children():
		child.queue_free()

	_coin_label.text = "Coins: %d" % SceneManager.save_manager.coins

	var owned: Dictionary = SceneManager.save_manager.get_owned_counts()

	var deck_counts: Dictionary = {}
	for cid in _working_deck:
		var id: String = str(cid)
		deck_counts[id] = int(deck_counts.get(id, 0)) + 1

	for id in CardRegistry.get_all_ids():
		var owned_n: int = int(owned.get(id, 0))
		if owned_n == 0:
			continue
		var tmpl: Dictionary = CardRegistry.get_template(id)
		if tmpl.is_empty():
			continue
		var deck_n: int = int(deck_counts.get(id, 0))
		var avail: int = owned_n - deck_n
		var row := _make_collection_row(id, tmpl, owned_n, deck_n, avail)
		_collection_list.add_child(row)

	for i in _working_deck.size():
		var id: String = _working_deck[i]
		var tmpl: Dictionary = CardRegistry.get_template(id)
		var row := _make_deck_row(id, tmpl, i)
		_deck_list.add_child(row)

	var deck_sz: int = _working_deck.size()
	_deck_count_label.text = "Deck  (%d / %d)" % [deck_sz, IsoConst.DECK_MAX]
	if deck_sz < IsoConst.DECK_MIN or deck_sz > IsoConst.DECK_MAX:
		_deck_count_label.modulate = Color.RED
	else:
		_deck_count_label.modulate = Color.WHITE

func _refresh_weapons() -> void:
	for child in _weapon_list.get_children():
		child.queue_free()

	var owned_w: Array[String] = SceneManager.save_manager.owned_weapons
	var equipped_id: String = SceneManager.save_manager.equipped_weapon

	if owned_w.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No weapons found yet."
		empty_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		_weapon_list.add_child(empty_lbl)
	else:
		for wid in owned_w:
			var weapon: WeaponData = WeaponRegistry.get_weapon(wid)
			if weapon == null:
				continue
			var row := _make_weapon_row(wid, weapon, wid == equipped_id, wid == _selected_weapon_id)
			_weapon_list.add_child(row)

	_refresh_comparison()

func _refresh_comparison() -> void:
	for child in _equipped_col.get_children():
		child.queue_free()
	for child in _selected_col.get_children():
		child.queue_free()

	var equipped_id: String = SceneManager.save_manager.equipped_weapon

	_fill_weapon_column(_equipped_col, "Equipped", equipped_id)
	_fill_weapon_column(_selected_col, "Selected", _selected_weapon_id)

	_equip_btn.disabled = _selected_weapon_id.is_empty() or _selected_weapon_id == equipped_id

func _fill_weapon_column(col: VBoxContainer, header: String, weapon_id: String) -> void:
	var header_lbl := Label.new()
	header_lbl.text = header
	header_lbl.add_theme_font_size_override("font_size", int(_vh * 0.02))
	header_lbl.modulate = Color(0.75, 0.85, 1.0)
	col.add_child(header_lbl)

	if weapon_id.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "(none)"
		none_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
		none_lbl.modulate = Color(0.5, 0.5, 0.5)
		col.add_child(none_lbl)
		return

	var weapon: WeaponData = WeaponRegistry.get_weapon(weapon_id)
	if weapon == null:
		var err_lbl := Label.new()
		err_lbl.text = "(unknown)"
		err_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
		col.add_child(err_lbl)
		return

	var name_lbl := Label.new()
	name_lbl.text = weapon.display_name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	col.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = weapon.description
	desc_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.modulate = Color(0.85, 0.85, 0.85)
	col.add_child(desc_lbl)

	var effect_lbl := Label.new()
	effect_lbl.text = _weapon_effect_summary(weapon)
	effect_lbl.add_theme_font_size_override("font_size", int(_vh * 0.017))
	effect_lbl.modulate = Color(0.9, 1.0, 0.7)
	col.add_child(effect_lbl)

func _weapon_effect_summary(weapon: WeaponData) -> String:
	match weapon.battle_effect_type:
		"deck_inject":
			return "Inject %d× %s" % [weapon.injected_card_count, weapon.injected_card_id]
		"starting_mana":
			return "+%d starting mana" % weapon.battle_effect_value
		"starting_hp":
			return "+%d starting HP" % weapon.battle_effect_value
		"passive_atk":
			return "+%d hero ATK" % weapon.battle_effect_value
	return weapon.battle_effect_type

# -------------------------------------------------------------------------
# Row builders
# -------------------------------------------------------------------------

func _make_weapon_row(wid: String, weapon: WeaponData, is_equipped: bool, is_selected: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var name_lbl := Label.new()
	name_lbl.text = weapon.display_name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_selected:
		name_lbl.modulate = Color(1.0, 1.0, 0.5)
	row.add_child(name_lbl)

	if is_equipped:
		var eq_lbl := Label.new()
		eq_lbl.text = "[E]"
		eq_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
		eq_lbl.modulate = Color(0.4, 1.0, 0.5)
		row.add_child(eq_lbl)

	var sel_btn := Button.new()
	sel_btn.text = "Select"
	sel_btn.custom_minimum_size = Vector2(_vh * 0.1, _vh * 0.04)
	sel_btn.add_theme_font_size_override("font_size", int(_vh * 0.017))
	sel_btn.pressed.connect(_on_weapon_selected.bind(wid))
	row.add_child(sel_btn)

	return row

func _make_collection_row(id: String, tmpl: Dictionary, owned_n: int, deck_n: int, avail: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var swatch := ColorRect.new()
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_vh * 0.03, _vh * 0.03)
	row.add_child(swatch)

	var name_lbl := Label.new()
	var name_str: String = tmpl.get("name", id)
	name_lbl.text = "%s  ×%d" % [name_str, owned_n]
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var cost: int = tmpl.get("cost", 0)
	var atk: int  = tmpl.get("attack", 0)
	var hp: int   = tmpl.get("health", 0)
	var stats_lbl := Label.new()
	stats_lbl.text = "cost %d  %d/%d" % [cost, atk, hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
	row.add_child(stats_lbl)

	if deck_n > 0:
		var in_deck_lbl := Label.new()
		in_deck_lbl.text = "(in deck: %d)" % deck_n
		in_deck_lbl.add_theme_font_size_override("font_size", int(_vh * 0.015))
		in_deck_lbl.modulate = Color(0.8, 0.85, 1.0)
		row.add_child(in_deck_lbl)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.custom_minimum_size = Vector2(_vh * 0.042, _vh * 0.042)
	add_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	add_btn.disabled = (avail <= 0 or _working_deck.size() >= IsoConst.DECK_MAX)
	add_btn.pressed.connect(_on_add.bind(id))
	row.add_child(add_btn)

	return row

func _make_deck_row(id: String, tmpl: Dictionary, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var swatch := ColorRect.new()
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_vh * 0.03, _vh * 0.03)
	row.add_child(swatch)

	var name_lbl := Label.new()
	var name_str: String = tmpl.get("name", id)
	name_lbl.text = name_str
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var cost: int = tmpl.get("cost", 0)
	var atk: int  = tmpl.get("attack", 0)
	var hp: int   = tmpl.get("health", 0)
	var stats_lbl := Label.new()
	stats_lbl.text = "cost %d  %d/%d" % [cost, atk, hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
	row.add_child(stats_lbl)

	var rm_btn := Button.new()
	rm_btn.text = "−"
	rm_btn.custom_minimum_size = Vector2(_vh * 0.042, _vh * 0.042)
	rm_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	if _working_deck.size() <= IsoConst.DECK_MIN:
		if OS.has_feature("android"):
			rm_btn.modulate = Color(1, 1, 1, 0.4)
			rm_btn.pressed.connect(func() -> void:
				GameBus.hud_message_requested.emit("Minimum deck size reached"))
		else:
			rm_btn.disabled = true
			rm_btn.tooltip_text = "Minimum deck size reached"
			rm_btn.pressed.connect(_on_remove.bind(index))
	else:
		rm_btn.pressed.connect(_on_remove.bind(index))
	row.add_child(rm_btn)

	return row

# -------------------------------------------------------------------------
# Actions
# -------------------------------------------------------------------------

func _on_tab_cards() -> void:
	_cards_panel.visible = true
	_weapons_panel.visible = false

func _on_tab_weapons() -> void:
	_cards_panel.visible = false
	_weapons_panel.visible = true
	_refresh_weapons()

func _on_weapon_selected(wid: String) -> void:
	_selected_weapon_id = wid
	_refresh_weapons()

func _on_equip_weapon() -> void:
	if _selected_weapon_id.is_empty():
		return
	SceneManager.save_manager.equip_weapon(_selected_weapon_id)
	_refresh_weapons()

func _on_add(id: String) -> void:
	if _working_deck.size() >= IsoConst.DECK_MAX:
		return
	var owned: Dictionary = SceneManager.save_manager.get_owned_counts()
	var deck_counts: Dictionary = {}
	for cid in _working_deck:
		var s: String = str(cid)
		deck_counts[s] = int(deck_counts.get(s, 0)) + 1
	var owned_n: int = int(owned.get(id, 0))
	var deck_n: int  = int(deck_counts.get(id, 0))
	if deck_n >= owned_n:
		return
	_working_deck.append(id)
	_refresh_cards()

func _on_remove(index: int) -> void:
	if index < 0 or index >= _working_deck.size():
		return
	_working_deck.remove_at(index)
	_refresh_cards()

func _on_save() -> void:
	SceneManager.save_manager.set_active_deck(_working_deck)
	closed.emit()

func _on_close() -> void:
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close()
