extends Control

signal closed

const CardRegistry     = preload("res://autoloads/CardRegistry.gd")
const CraftingRegistry = preload("res://autoloads/CraftingRegistry.gd")
const _CardDropUtil    = preload("res://game_logic/CardDropUtil.gd")

var _vh: float = 0.0
var _vw: float = 0.0
var _working_deck: Array[String] = []

var _collection_list: VBoxContainer
var _deck_list: VBoxContainer
var _deck_count_label: Label
var _coin_label: Label
var _essence_label: Label

var _cards_panel: Control
var _tab_cards_btn: Button
var _tab_craft_btn: Button
var _craft_panel: Control
var _craft_list: VBoxContainer
var _craft_essence_label: Label

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

	_tab_craft_btn = Button.new()
	_tab_craft_btn.text = "Craft"
	_tab_craft_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.05)
	_tab_craft_btn.add_theme_font_size_override("font_size", int(_vh * 0.021))
	_tab_craft_btn.pressed.connect(_on_tab_craft)
	tab_bar.add_child(_tab_craft_btn)

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

	_essence_label = Label.new()
	_essence_label.add_theme_font_size_override("font_size", int(_vh * 0.020))
	_essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_essence_label.modulate = Color(0.5, 0.85, 1.0)
	left_vbox.add_child(_essence_label)

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
	# CRAFT PANEL
	# ====================================================================
	var craft_box := VBoxContainer.new()
	craft_box.add_theme_constant_override("separation", int(_vh * 0.008))
	craft_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	craft_box.visible = false
	_craft_panel = craft_box
	wrapper.add_child(craft_box)

	_craft_essence_label = Label.new()
	_craft_essence_label.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_craft_essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_craft_essence_label.modulate = Color(0.5, 0.85, 1.0)
	craft_box.add_child(_craft_essence_label)

	var craft_scroll := ScrollContainer.new()
	craft_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	craft_box.add_child(craft_scroll)

	_craft_list = VBoxContainer.new()
	_craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_list.add_theme_constant_override("separation", int(_vh * 0.006))
	craft_scroll.add_child(_craft_list)

	var craft_close_btn := Button.new()
	craft_close_btn.text = "Close  [I]" if not OS.has_feature("android") else "Close"
	craft_close_btn.custom_minimum_size = Vector2(_vw * 0.1, _vh * 0.055)
	craft_close_btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
	craft_close_btn.pressed.connect(_on_close)
	craft_box.add_child(craft_close_btn)

# -------------------------------------------------------------------------
# Refresh — rebuilds both panels from current working state
# -------------------------------------------------------------------------

func _refresh() -> void:
	_refresh_cards()
	if _craft_panel.visible:
		_refresh_craft()

func _refresh_cards() -> void:
	for child in _collection_list.get_children():
		child.queue_free()
	for child in _deck_list.get_children():
		child.queue_free()

	_coin_label.text = "Coins: %d" % SceneManager.save_manager.coins
	_essence_label.text = "Essence: %d" % SceneManager.save_manager.essence

	var all_instances: Array[Dictionary] = SceneManager.save_manager.get_owned_instances()

	# Available = owned instances not currently in the working deck
	var available: Array[Dictionary] = []
	for inst in all_instances:
		if not _working_deck.has(str(inst.get("uid", ""))):
			available.append(inst)

	# Sort: template_id alphabetically, then rarity tier descending (legendary first)
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: String = str(a.get("template_id", ""))
		var tb: String = str(b.get("template_id", ""))
		if ta != tb:
			return ta < tb
		var ra: int = IsoConst.RARITY_ORDER.find(str(a.get("rarity", "common")))
		var rb: int = IsoConst.RARITY_ORDER.find(str(b.get("rarity", "common")))
		return ra > rb
	)

	for inst in available:
		var row := _make_collection_row(inst)
		_collection_list.add_child(row)

	for i in _working_deck.size():
		var uid: String = _working_deck[i]
		var inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(uid)
		var row := _make_deck_row(uid, inst, i)
		_deck_list.add_child(row)

	var deck_sz: int = _working_deck.size()
	_deck_count_label.text = "Deck  (%d / %d)" % [deck_sz, IsoConst.DECK_MAX]
	if deck_sz < IsoConst.DECK_MIN or deck_sz > IsoConst.DECK_MAX:
		_deck_count_label.modulate = Color.RED
	else:
		_deck_count_label.modulate = Color.WHITE

# -------------------------------------------------------------------------
# Row builders
# -------------------------------------------------------------------------

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.80, 0.80, 0.80)
		"rare":      return Color(0.20, 0.50, 1.00)
		"epic":      return Color(0.70, 0.20, 1.00)
		"legendary": return Color(1.00, 0.75, 0.00)
	return Color(0.80, 0.80, 0.80)

func _rarity_badge(rarity: String) -> String:
	match rarity:
		"common":    return "[C]"
		"rare":      return "[R]"
		"epic":      return "[E]"
		"legendary": return "[L]"
	return "[?]"

func _stat_range_text(rolled: int, base: int, rarity: String) -> String:
	var disp: int = rolled if rolled >= 0 else base
	if base <= 0:
		return str(max(disp, 0))
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	var mult: float = float(cfg.get("multiplier", 1.0))
	var var_: float = float(cfg.get("variance", 0.10))
	var min_val: int = roundi(float(base) * mult * (1.0 - var_))
	var max_val: int = roundi(float(base) * mult * (1.0 + var_))
	if min_val == max_val:
		return str(disp)
	return "%d (%d–%d)" % [disp, min_val, max_val]

func _make_collection_row(inst: Dictionary) -> VBoxContainer:
	var uid: String     = str(inst.get("uid", ""))
	var tid: String     = str(inst.get("template_id", uid))
	var rarity: String  = str(inst.get("rarity", "common"))
	var tmpl: Dictionary = CardRegistry.get_template(tid)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	var card_name: String = tmpl.get("name", tid)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * 0.003))

	# Top row: colour swatch + name + rarity badge + add button
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", int(_vw * 0.008))
	vbox.add_child(top_row)

	var swatch := ColorRect.new()
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_vh * 0.03, _vh * 0.03)
	top_row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_vh * 0.017))
	badge_lbl.modulate = _rarity_color(rarity)
	top_row.add_child(badge_lbl)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.custom_minimum_size = Vector2(_vh * 0.042, _vh * 0.042)
	add_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	add_btn.disabled = _working_deck.size() >= IsoConst.DECK_MAX
	add_btn.pressed.connect(_on_add.bind(uid))
	top_row.add_child(add_btn)

	# Stats row: rolled values with (min–max) range annotation
	var rolled_atk: int  = int(inst.get("attack", -1))
	var rolled_hp: int   = int(inst.get("health", -1))
	var rolled_cost: int = int(inst.get("cost", -1))
	var base_atk: int    = int(tmpl.get("attack", 0))
	var base_hp: int     = int(tmpl.get("health", 0))
	var base_cost: int   = int(tmpl.get("cost", 0))
	var disp_cost: int   = rolled_cost if rolled_cost >= 0 else base_cost

	var stats_lbl := Label.new()
	stats_lbl.text = "Cost %d  ATK %s  HP %s" % [
		disp_cost,
		_stat_range_text(rolled_atk, base_atk, rarity),
		_stat_range_text(rolled_hp,  base_hp,  rarity),
	]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.015))
	stats_lbl.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(stats_lbl)

	# Sell / Scrap action row (hidden for unique cards)
	var is_unique: bool = bool(tmpl.get("is_unique", false))
	if not is_unique:
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
		var sell_gold: int       = int(cfg.get("sell_gold", 0))
		var scrap_ess: int       = int(cfg.get("scrap_essence", 0))
		var needs_confirm: bool  = rarity == "epic" or rarity == "legendary"

		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", int(_vw * 0.006))
		vbox.add_child(action_row)

		var confirm_row := HBoxContainer.new()
		confirm_row.add_theme_constant_override("separation", int(_vw * 0.006))
		confirm_row.visible = false
		vbox.add_child(confirm_row)

		var sell_btn := Button.new()
		sell_btn.text = "Sell +%dg" % sell_gold
		sell_btn.custom_minimum_size = Vector2(_vh * 0.11, _vh * 0.038)
		sell_btn.add_theme_font_size_override("font_size", int(_vh * 0.015))
		sell_btn.modulate = Color(1.0, 0.9, 0.3)
		if needs_confirm:
			sell_btn.pressed.connect(func() -> void:
				_show_confirm(action_row, confirm_row, "Sell", func() -> void: _do_sell(uid)))
		else:
			sell_btn.pressed.connect(_do_sell.bind(uid))
		action_row.add_child(sell_btn)

		var scrap_btn := Button.new()
		scrap_btn.text = "Scrap +%de" % scrap_ess
		scrap_btn.custom_minimum_size = Vector2(_vh * 0.11, _vh * 0.038)
		scrap_btn.add_theme_font_size_override("font_size", int(_vh * 0.015))
		scrap_btn.modulate = Color(0.5, 0.85, 1.0)
		if needs_confirm:
			scrap_btn.pressed.connect(func() -> void:
				_show_confirm(action_row, confirm_row, "Scrap", func() -> void: _do_scrap(uid)))
		else:
			scrap_btn.pressed.connect(_do_scrap.bind(uid))
		action_row.add_child(scrap_btn)

		# Combine button: visible when 3+ non-deck copies of same template+rarity exist
		# and the rarity is not legendary (no tier above it) and card is not unique
		if rarity != "legendary":
			var next_rarity_idx: int = IsoConst.RARITY_ORDER.find(rarity) + 1
			var next_rarity_str: String = IsoConst.RARITY_ORDER[next_rarity_idx] if next_rarity_idx < IsoConst.RARITY_ORDER.size() else ""
			if next_rarity_str != "":
				var can_combine: bool = _count_available(tid, rarity) >= 3
				var combine_btn := Button.new()
				combine_btn.text = "Combine 3× → %s" % _rarity_badge(next_rarity_str)
				combine_btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.038)
				combine_btn.add_theme_font_size_override("font_size", int(_vh * 0.015))
				combine_btn.modulate = _rarity_color(next_rarity_str)
				combine_btn.disabled = not can_combine
				combine_btn.pressed.connect(func() -> void:
					SceneManager.save_manager.combine_cards(tid, rarity)
					_refresh_cards())
				action_row.add_child(combine_btn)

	return vbox

func _make_deck_row(uid: String, inst: Dictionary, index: int) -> VBoxContainer:
	var tid: String    = str(inst.get("template_id", uid)) if not inst.is_empty() else uid
	var rarity: String = str(inst.get("rarity", "common")) if not inst.is_empty() else "common"
	var tmpl: Dictionary = CardRegistry.get_template(tid)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	var card_name: String = tmpl.get("name", tid)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_vh * 0.003))

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", int(_vw * 0.008))
	vbox.add_child(top_row)

	var swatch := ColorRect.new()
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_vh * 0.03, _vh * 0.03)
	top_row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_vh * 0.017))
	badge_lbl.modulate = _rarity_color(rarity)
	top_row.add_child(badge_lbl)

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
	top_row.add_child(rm_btn)

	# Stats row
	var rolled_atk: int  = int(inst.get("attack", -1))  if not inst.is_empty() else -1
	var rolled_hp: int   = int(inst.get("health", -1))  if not inst.is_empty() else -1
	var rolled_cost: int = int(inst.get("cost", -1))    if not inst.is_empty() else -1
	var base_atk: int    = int(tmpl.get("attack", 0))
	var base_hp: int     = int(tmpl.get("health", 0))
	var base_cost: int   = int(tmpl.get("cost", 0))
	var disp_cost: int   = rolled_cost if rolled_cost >= 0 else base_cost

	var stats_lbl := Label.new()
	stats_lbl.text = "Cost %d  ATK %s  HP %s" % [
		disp_cost,
		_stat_range_text(rolled_atk, base_atk, rarity),
		_stat_range_text(rolled_hp,  base_hp,  rarity),
	]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.015))
	stats_lbl.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(stats_lbl)

	return vbox

# -------------------------------------------------------------------------
# Actions
# -------------------------------------------------------------------------

func _make_craft_row(recipe: Object, player_essence: int) -> HBoxContainer:
	var tid: String    = str(recipe.template_id)
	var rarity: String = str(recipe.rarity)
	var cost: int      = int(recipe.essence_cost)
	var tmpl: Dictionary = CardRegistry.get_template(tid)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	var card_name: String = tmpl.get("name", tid)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var swatch := ColorRect.new()
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_vh * 0.028, _vh * 0.028)
	row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_vh * 0.016))
	badge_lbl.modulate = _rarity_color(rarity)
	row.add_child(badge_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%de" % cost
	cost_lbl.add_theme_font_size_override("font_size", int(_vh * 0.017))
	cost_lbl.modulate = Color(0.5, 0.85, 1.0)
	cost_lbl.custom_minimum_size = Vector2(_vh * 0.06, 0)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost_lbl)

	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(_vh * 0.09, _vh * 0.038)
	craft_btn.add_theme_font_size_override("font_size", int(_vh * 0.017))
	craft_btn.disabled = player_essence < cost
	craft_btn.pressed.connect(_do_craft.bind(tid, rarity, cost))
	row.add_child(craft_btn)

	return row

func _do_craft(template_id: String, rarity: String, cost: int) -> void:
	if not SceneManager.save_manager.spend_essence(cost):
		return
	var stats: Dictionary = _CardDropUtil.roll_stats(template_id, rarity)
	SceneManager.save_manager.add_card_instance(
		template_id, rarity,
		int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1))
	)
	_refresh_craft()

func _show_confirm(action_row: HBoxContainer, confirm_row: HBoxContainer, label: String, on_confirm: Callable) -> void:
	action_row.visible = false
	for child in confirm_row.get_children():
		child.queue_free()
	confirm_row.visible = true

	var lbl := Label.new()
	lbl.text = "%s?" % label
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.015))
	lbl.modulate = Color(1.0, 0.6, 0.3)
	confirm_row.add_child(lbl)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(_vh * 0.07, _vh * 0.038)
	yes_btn.add_theme_font_size_override("font_size", int(_vh * 0.015))
	yes_btn.pressed.connect(on_confirm)
	confirm_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(_vh * 0.07, _vh * 0.038)
	no_btn.add_theme_font_size_override("font_size", int(_vh * 0.015))
	no_btn.pressed.connect(func() -> void:
		confirm_row.visible = false
		action_row.visible = true)
	confirm_row.add_child(no_btn)

func _count_available(template_id: String, rarity: String) -> int:
	var count: int = 0
	for inst in SceneManager.save_manager.get_owned_instances():
		if str(inst.get("template_id", "")) == template_id and str(inst.get("rarity", "")) == rarity:
			if not _working_deck.has(str(inst.get("uid", ""))):
				count += 1
	return count

func _do_sell(uid: String) -> void:
	SceneManager.save_manager.sell_card_instance(uid)
	_refresh_cards()

func _do_scrap(uid: String) -> void:
	SceneManager.save_manager.scrap_card_instance(uid)
	_refresh_cards()

func _on_tab_cards() -> void:
	_cards_panel.visible = true
	_craft_panel.visible = false

func _on_tab_craft() -> void:
	_cards_panel.visible = false
	_craft_panel.visible = true
	_refresh_craft()

func _refresh_craft() -> void:
	for child in _craft_list.get_children():
		child.queue_free()

	_craft_essence_label.text = "Essence: %d" % SceneManager.save_manager.essence

	var recipes: Array = CraftingRegistry.get_all_recipes()
	# Sort by template name then rarity tier index
	recipes.sort_custom(func(a, b) -> bool:
		var ta: String = str(a.template_id)
		var tb: String = str(b.template_id)
		var tmpl_a: Dictionary = CardRegistry.get_template(ta)
		var tmpl_b: Dictionary = CardRegistry.get_template(tb)
		var na: String = str(tmpl_a.get("name", ta))
		var nb: String = str(tmpl_b.get("name", tb))
		if na != nb:
			return na < nb
		var ra: int = IsoConst.RARITY_ORDER.find(str(a.rarity))
		var rb: int = IsoConst.RARITY_ORDER.find(str(b.rarity))
		return ra < rb
	)

	var player_essence: int = SceneManager.save_manager.essence
	for recipe in recipes:
		var row := _make_craft_row(recipe, player_essence)
		_craft_list.add_child(row)

func _on_add(uid: String) -> void:
	if _working_deck.size() >= IsoConst.DECK_MAX:
		return
	if _working_deck.has(uid):
		return
	_working_deck.append(uid)
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
