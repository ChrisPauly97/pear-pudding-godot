extends "res://scenes/ui/BaseOverlay.gd"

const CardRegistry      = preload("res://autoloads/CardRegistry.gd")
const CraftingRegistry  = preload("res://autoloads/CraftingRegistry.gd")
const GardenDefs        = preload("res://game_logic/GardenDefs.gd")
const _CardDropUtil     = preload("res://game_logic/CardDropUtil.gd")
const CardInspectOverlay = preload("res://scenes/battle/CardInspectOverlay.gd")
const CardInstance      = preload("res://game_logic/battle/CardInstance.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const _UiUtil           = preload("res://scenes/ui/UiUtil.gd")

var _working_deck: Array[String] = []

var _collection_list: VBoxContainer
var _deck_list: VBoxContainer
var _collection_scroll: ScrollContainer
var _deck_scroll: ScrollContainer
var _deck_count_label: Label
var _coin_label: Label
var _essence_label: Label
var _slot_label: Label

var _cards_panel: Control
var _tab_cards_btn: Button
var _tab_craft_btn: Button
var _craft_panel: Control
var _craft_list: VBoxContainer
var _craft_essence_label: Label
var _inspect_overlay: Control = null

func _ready() -> void:
	super._ready()
	_working_deck.assign(SceneManager.save_manager.player_deck)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	_build_backdrop(0.78)

	var is_portrait: bool = _vw < _vh
	var panel_w: float = _vw * 0.95 if is_portrait else _vw * 0.86
	var panel_h: float = _vh * 0.92 if is_portrait else _vh * 0.86
	var outer := _build_centered_panel(panel_w, panel_h)
	var wrapper := _build_margin_vbox(outer, 0.015, 0.008)

	# ---- Tab bar ----
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", int(_vw * 0.008))
	wrapper.add_child(tab_bar)

	_tab_cards_btn = Button.new()
	_tab_cards_btn.text = "Cards"
	_tab_cards_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.065)
	_tab_cards_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_tab_cards_btn.pressed.connect(_on_tab_cards)
	tab_bar.add_child(_tab_cards_btn)

	_tab_craft_btn = Button.new()
	_tab_craft_btn.text = "Craft"
	_tab_craft_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.065)
	_tab_craft_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_tab_craft_btn.pressed.connect(_on_tab_craft)
	tab_bar.add_child(_tab_craft_btn)

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

	# ---- Collection panel (left) ----
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

	_slot_label = Label.new()
	_slot_label.add_theme_font_size_override("font_size", int(_vh * 0.020))
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.modulate = Color(0.8, 0.8, 0.8)
	left_vbox.add_child(_slot_label)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.modulate = Color(1.0, 0.85, 0.1)
	left_vbox.add_child(_coin_label)

	_essence_label = Label.new()
	_essence_label.add_theme_font_size_override("font_size", int(_vh * 0.022))
	_essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_essence_label.modulate = Color(0.5, 0.85, 1.0)
	left_vbox.add_child(_essence_label)

	_collection_scroll = ScrollContainer.new()
	var left_scroll: ScrollContainer = _collection_scroll
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

	# ---- Deck panel (right) ----
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

	_deck_scroll = ScrollContainer.new()
	var right_scroll: ScrollContainer = _deck_scroll
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if scroll_min_h > 0.0:
		right_scroll.custom_minimum_size = Vector2(0.0, scroll_min_h)
	right_vbox.add_child(right_scroll)

	_deck_list = VBoxContainer.new()
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_list.add_theme_constant_override("separation", int(_vh * 0.008))
	right_scroll.add_child(_deck_list)

	# ---- Buttons ----
	if is_portrait:
		var btn_hbox := HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", int(_vw * 0.04))
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		root_box.add_child(btn_hbox)

		var save_btn := Button.new()
		save_btn.text = "Save Deck"
		save_btn.custom_minimum_size = Vector2(_vw * 0.35, _vh * 0.065)
		save_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		save_btn.pressed.connect(_on_save)
		btn_hbox.add_child(save_btn)

		var close_btn := Button.new()
		close_btn.text = "Close"
		close_btn.custom_minimum_size = Vector2(_vw * 0.35, _vh * 0.065)
		close_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		close_btn.pressed.connect(_on_close)
		btn_hbox.add_child(close_btn)
	else:
		var btn_vbox := VBoxContainer.new()
		btn_vbox.add_theme_constant_override("separation", int(_vh * 0.012))
		btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		root_box.add_child(btn_vbox)

		var save_btn := Button.new()
		save_btn.text = "Save Deck"
		save_btn.custom_minimum_size = Vector2(_vw * 0.1, _vh * 0.065)
		save_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		save_btn.pressed.connect(_on_save)
		btn_vbox.add_child(save_btn)

		var close_btn := Button.new()
		close_btn.text = "Close  [I]" if not OS.has_feature("android") else "Close"
		close_btn.custom_minimum_size = Vector2(_vw * 0.1, _vh * 0.065)
		close_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
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
	craft_close_btn.custom_minimum_size = Vector2(_vw * 0.1, _vh * 0.065)
	craft_close_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	craft_close_btn.pressed.connect(_on_close)
	craft_box.add_child(craft_close_btn)

# -------------------------------------------------------------------------
# Refresh
# -------------------------------------------------------------------------

func _refresh() -> void:
	_refresh_cards()
	if _craft_panel.visible:
		_refresh_craft()

func _refresh_cards() -> void:
	var col_scroll: int = _collection_scroll.scroll_vertical if _collection_scroll else 0
	var deck_scroll: int = _deck_scroll.scroll_vertical if _deck_scroll else 0
	for child in _collection_list.get_children():
		child.queue_free()
	for child in _deck_list.get_children():
		child.queue_free()

	var sm := SceneManager.save_manager

	_coin_label.text    = "Coins: %d" % sm.coins
	_essence_label.text = "Essence: %d" % sm.essence

	var used: int   = sm.get_slot_count()
	var cap: int    = sm.bag_size
	_slot_label.text    = "Bag: %d / %d" % [used, cap]
	_slot_label.modulate = Color(1.0, 0.35, 0.35) if used >= cap else Color(0.80, 0.80, 0.80)

	var all_instances: Array[Dictionary] = sm.get_owned_instances()

	# Separate into available (not in deck) vs in-deck, and common vs rare+.
	var common_avail: Dictionary   = {}   # tid -> count
	var rare_avail: Array[Dictionary] = []
	var common_deck: Dictionary    = {}   # tid -> count
	var rare_deck: Array[Dictionary]  = []

	for inst: Dictionary in all_instances:
		var uid: String    = str(inst.get("uid", ""))
		var tid: String    = str(inst.get("template_id", ""))
		var rarity: String = str(inst.get("rarity", "common"))
		if tid == "":
			continue
		if _working_deck.has(uid):
			if rarity == "common":
				common_deck[tid] = int(common_deck.get(tid, 0)) + 1
			else:
				rare_deck.append(inst)
		else:
			if rarity == "common":
				common_avail[tid] = int(common_avail.get(tid, 0)) + 1
			else:
				rare_avail.append(inst)

	# ---- Collection list ----
	if not common_avail.is_empty():
		_collection_list.add_child(_make_section_label("Common"))
		var keys: Array = common_avail.keys()
		keys.sort()
		for tid: String in keys:
			_collection_list.add_child(_make_collection_row_stacked(tid, int(common_avail[tid])))

	if not rare_avail.is_empty():
		_collection_list.add_child(_make_section_label("Rare & Above"))
		rare_avail.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ta: String = str(a.get("template_id", ""))
			var tb: String = str(b.get("template_id", ""))
			if ta != tb:
				return ta < tb
			var ra: int = IsoConst.RARITY_ORDER.find(str(a.get("rarity", "common")))
			var rb: int = IsoConst.RARITY_ORDER.find(str(b.get("rarity", "common")))
			return ra > rb
		)
		for inst: Dictionary in rare_avail:
			_collection_list.add_child(_make_collection_row_instance(inst))

	# ---- Deck list ----
	if not common_deck.is_empty():
		var dkeys: Array = common_deck.keys()
		dkeys.sort()
		for tid: String in dkeys:
			_deck_list.add_child(_make_deck_row_stacked(tid, int(common_deck[tid])))

	if not rare_deck.is_empty():
		rare_deck.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ta: String = str(a.get("template_id", ""))
			var tb: String = str(b.get("template_id", ""))
			if ta != tb:
				return ta < tb
			return IsoConst.RARITY_ORDER.find(str(a.get("rarity", "common"))) > \
			       IsoConst.RARITY_ORDER.find(str(b.get("rarity", "common")))
		)
		for inst: Dictionary in rare_deck:
			_deck_list.add_child(_make_deck_row_instance(str(inst.get("uid", "")), inst))

	var deck_sz: int = _working_deck.size()
	_deck_count_label.text = "Deck  (%d / %d)" % [deck_sz, IsoConst.DECK_MAX]
	if deck_sz < IsoConst.DECK_MIN or deck_sz > IsoConst.DECK_MAX:
		_deck_count_label.modulate = Color.RED
	else:
		_deck_count_label.modulate = Color.WHITE
	if _collection_scroll and col_scroll > 0:
		_collection_scroll.scroll_vertical = col_scroll
	if _deck_scroll and deck_scroll > 0:
		_deck_scroll.scroll_vertical = deck_scroll

# -------------------------------------------------------------------------
# Row helpers
# -------------------------------------------------------------------------

func _stat_range_text(rolled: int, base: int, rarity: String) -> String:
	var disp: int = rolled if rolled >= 0 else base
	if base <= 0:
		return str(max(disp, 0))
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	var mult: float = float(cfg.get("multiplier", 1.0))
	var var_: float = float(cfg.get("variance", 0.0))
	var min_val: int = roundi(float(base) * mult * (1.0 - var_))
	var max_val: int = roundi(float(base) * mult * (1.0 + var_))
	if min_val == max_val:
		return str(disp)
	return "%d (%d–%d)" % [disp, min_val, max_val]

func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "— %s —" % text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.019))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.60, 0.72, 0.92)
	return lbl

# Stacked row for common cards (all copies identical — variance = 0).
func _make_collection_row_stacked(tid: String, count: int) -> VBoxContainer:
	var tmpl: Dictionary  = CardRegistry.get_template(tid)
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
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "×%d" % count
	count_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	count_lbl.modulate = Color(0.85, 0.85, 0.85)
	top_row.add_child(count_lbl)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.custom_minimum_size = Vector2(_vh * 0.065, _vh * 0.065)
	add_btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	add_btn.disabled = _working_deck.size() >= IsoConst.DECK_MAX
	add_btn.pressed.connect(_on_add_by_type.bind(tid, "common"))
	top_row.add_child(add_btn)

	var base_atk: int  = int(tmpl.get("attack", 0))
	var base_hp: int   = int(tmpl.get("health", 0))
	var base_cost: int = int(tmpl.get("cost", 0))
	var stats_lbl := Label.new()
	stats_lbl.text = "Cost %d  ATK %d  HP %d" % [base_cost, base_atk, base_hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	stats_lbl.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(stats_lbl)

	var lpd := LongPressDetector.new()
	vbox.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_inspect(tid))

	# Sell / Scrap / Combine
	var is_unique: bool = bool(tmpl.get("is_unique", false))
	if not is_unique:
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get("common", {})
		var sell_gold: int  = int(cfg.get("sell_gold", 0))
		var scrap_ess: int  = int(cfg.get("scrap_essence", 0))

		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", int(_vw * 0.006))
		vbox.add_child(action_row)

		var sell_btn := Button.new()
		sell_btn.text = "Sell +%dg" % sell_gold
		sell_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.065)
		sell_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		sell_btn.modulate = Color(1.0, 0.9, 0.3)
		sell_btn.pressed.connect(_do_sell_by_type.bind(tid, "common"))
		action_row.add_child(sell_btn)

		var scrap_btn := Button.new()
		scrap_btn.text = "Scrap +%de" % scrap_ess
		scrap_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.065)
		scrap_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		scrap_btn.modulate = Color(0.5, 0.85, 1.0)
		scrap_btn.pressed.connect(_do_scrap_by_type.bind(tid, "common"))
		action_row.add_child(scrap_btn)

		# Combine 3× common → 1× rare
		var next_idx: int = IsoConst.RARITY_ORDER.find("common") + 1
		if next_idx < IsoConst.RARITY_ORDER.size():
			var next_rarity: String = IsoConst.RARITY_ORDER[next_idx]
			var combine_btn := Button.new()
			combine_btn.text = "Combine 3× → %s" % _UiUtil.rarity_badge(next_rarity)
			combine_btn.custom_minimum_size = Vector2(_vh * 0.22, _vh * 0.065)
			combine_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
			combine_btn.modulate = _UiUtil.rarity_color(next_rarity)
			combine_btn.disabled = count < 3
			combine_btn.pressed.connect(func() -> void:
				SceneManager.save_manager.combine_cards(tid, "common")
				_refresh_cards())
			action_row.add_child(combine_btn)

	return vbox

# Individual slot for a rare/epic/legendary card — shows its specific rolled stats.
func _make_collection_row_instance(inst: Dictionary) -> VBoxContainer:
	var uid: String    = str(inst.get("uid", ""))
	var tid: String    = str(inst.get("template_id", ""))
	var rarity: String = str(inst.get("rarity", "common"))
	var tmpl: Dictionary  = CardRegistry.get_template(tid)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	var card_name: String = tmpl.get("name", tid)

	var rolled_atk: int  = int(inst.get("attack", int(tmpl.get("attack", 0))))
	var rolled_hp: int   = int(inst.get("health", int(tmpl.get("health", 0))))
	var rolled_cost: int = int(inst.get("cost",   int(tmpl.get("cost",   0))))

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
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _UiUtil.rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	badge_lbl.modulate = _UiUtil.rarity_color(rarity)
	top_row.add_child(badge_lbl)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.custom_minimum_size = Vector2(_vh * 0.065, _vh * 0.065)
	add_btn.add_theme_font_size_override("font_size", int(_vh * 0.025))
	add_btn.disabled = _working_deck.size() >= IsoConst.DECK_MAX
	add_btn.pressed.connect(_on_add_by_uid.bind(uid))
	top_row.add_child(add_btn)

	# Rolled stats (specific to this instance)
	var stats_lbl := Label.new()
	stats_lbl.text = "Cost %d  ATK %d  HP %d" % [rolled_cost, rolled_atk, rolled_hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	stats_lbl.modulate = _UiUtil.rarity_color(rarity).lerp(Color(0.75, 0.75, 0.75), 0.55)
	vbox.add_child(stats_lbl)

	var lpd := LongPressDetector.new()
	vbox.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_inspect(tid))

	var is_unique: bool = bool(tmpl.get("is_unique", false))
	if not is_unique:
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
		var sell_gold: int  = int(cfg.get("sell_gold", 0))
		var scrap_ess: int  = int(cfg.get("scrap_essence", 0))

		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", int(_vw * 0.006))
		vbox.add_child(action_row)

		var confirm_row := HBoxContainer.new()
		confirm_row.add_theme_constant_override("separation", int(_vw * 0.006))
		confirm_row.visible = false
		vbox.add_child(confirm_row)

		var sell_btn := Button.new()
		sell_btn.text = "Sell +%dg" % sell_gold
		sell_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.065)
		sell_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		sell_btn.modulate = Color(1.0, 0.9, 0.3)
		sell_btn.pressed.connect(func() -> void:
			_show_confirm(action_row, confirm_row, "Sell", func() -> void:
				SceneManager.save_manager.sell_card_instance(uid)
				_refresh_cards()))
		action_row.add_child(sell_btn)

		var scrap_btn := Button.new()
		scrap_btn.text = "Scrap +%de" % scrap_ess
		scrap_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.065)
		scrap_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
		scrap_btn.modulate = Color(0.5, 0.85, 1.0)
		scrap_btn.pressed.connect(func() -> void:
			_show_confirm(action_row, confirm_row, "Scrap", func() -> void:
				SceneManager.save_manager.scrap_card_instance(uid)
				_refresh_cards()))
		action_row.add_child(scrap_btn)

	return vbox

# Stacked deck row for common cards.
func _make_deck_row_stacked(tid: String, count: int) -> VBoxContainer:
	var tmpl: Dictionary  = CardRegistry.get_template(tid)
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
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "×%d" % count
	count_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	count_lbl.modulate = Color(0.85, 0.85, 0.85)
	top_row.add_child(count_lbl)

	var rm_btn := Button.new()
	rm_btn.text = "−"
	rm_btn.custom_minimum_size = Vector2(_vh * 0.065, _vh * 0.065)
	rm_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	if _working_deck.size() <= IsoConst.DECK_MIN:
		if OS.has_feature("android"):
			rm_btn.modulate = Color(1, 1, 1, 0.4)
			rm_btn.pressed.connect(func() -> void:
				GameBus.hud_message_requested.emit("Minimum deck size reached"))
		else:
			rm_btn.disabled = true
			rm_btn.tooltip_text = "Minimum deck size reached"
	else:
		rm_btn.pressed.connect(_on_remove_by_type.bind(tid, "common"))
	top_row.add_child(rm_btn)

	var base_atk: int  = int(tmpl.get("attack", 0))
	var base_hp: int   = int(tmpl.get("health", 0))
	var base_cost: int = int(tmpl.get("cost", 0))
	var stats_lbl := Label.new()
	stats_lbl.text = "Cost %d  ATK %d  HP %d" % [base_cost, base_atk, base_hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	stats_lbl.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(stats_lbl)

	var lpd := LongPressDetector.new()
	vbox.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_inspect(tid))

	return vbox

# Individual deck slot for a rare/epic/legendary card — shows its rolled stats.
func _make_deck_row_instance(uid: String, inst: Dictionary) -> VBoxContainer:
	var tid: String    = str(inst.get("template_id", uid))
	var rarity: String = str(inst.get("rarity", "common"))
	var tmpl: Dictionary  = CardRegistry.get_template(tid)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	var card_name: String = tmpl.get("name", tid)

	var rolled_atk: int  = int(inst.get("attack", int(tmpl.get("attack", 0))))
	var rolled_hp: int   = int(inst.get("health", int(tmpl.get("health", 0))))
	var rolled_cost: int = int(inst.get("cost",   int(tmpl.get("cost",   0))))

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
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _UiUtil.rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	badge_lbl.modulate = _UiUtil.rarity_color(rarity)
	top_row.add_child(badge_lbl)

	var rm_btn := Button.new()
	rm_btn.text = "−"
	rm_btn.custom_minimum_size = Vector2(_vh * 0.065, _vh * 0.065)
	rm_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	if _working_deck.size() <= IsoConst.DECK_MIN:
		if OS.has_feature("android"):
			rm_btn.modulate = Color(1, 1, 1, 0.4)
			rm_btn.pressed.connect(func() -> void:
				GameBus.hud_message_requested.emit("Minimum deck size reached"))
		else:
			rm_btn.disabled = true
			rm_btn.tooltip_text = "Minimum deck size reached"
	else:
		rm_btn.pressed.connect(_on_remove_by_uid.bind(uid))
	top_row.add_child(rm_btn)

	var stats_lbl := Label.new()
	stats_lbl.text = "Cost %d  ATK %d  HP %d" % [rolled_cost, rolled_atk, rolled_hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	stats_lbl.modulate = _UiUtil.rarity_color(rarity).lerp(Color(0.75, 0.75, 0.75), 0.55)
	vbox.add_child(stats_lbl)

	var lpd := LongPressDetector.new()
	vbox.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_inspect(tid))

	return vbox

# -------------------------------------------------------------------------
# Craft panel
# -------------------------------------------------------------------------

func _make_craft_row(recipe: Object, player_essence: int) -> HBoxContainer:
	var tid: String    = str(recipe.template_id)
	var rarity: String = str(recipe.rarity)
	var cost: int      = int(recipe.essence_cost)
	var tmpl: Dictionary  = CardRegistry.get_template(tid)
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
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _UiUtil.rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	badge_lbl.modulate = _UiUtil.rarity_color(rarity)
	row.add_child(badge_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%de" % cost
	cost_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	cost_lbl.modulate = Color(0.5, 0.85, 1.0)
	cost_lbl.custom_minimum_size = Vector2(_vh * 0.06, 0)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost_lbl)

	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(_vh * 0.12, _vh * 0.065)
	craft_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
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

func _make_potion_craft_row(potion_id: String, recipe_data: Dictionary, player_essence: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_vw * 0.008))

	var sm := SceneManager.save_manager
	var display_name: String = str(recipe_data.get("display_name", potion_id))
	var essence_cost: int = int(recipe_data.get("essence_cost", 0))
	var ingredients: Dictionary = recipe_data.get("ingredients", {})

	var parts: Array[String] = []
	var can_afford_ingredients: bool = true
	for ingredient_id: String in ingredients:
		var required: int = int(ingredients[ingredient_id])
		var owned: int = int(sm.plants.get(ingredient_id, 0))
		var plant_name: String = str(GardenDefs.PLANTS.get(ingredient_id, {}).get("display_name", ingredient_id))
		parts.append("%d× %s" % [required, plant_name])
		if owned < required:
			can_afford_ingredients = false

	var info_lbl := Label.new()
	info_lbl.text = "%s  (%s)" % [display_name, ", ".join(parts)]
	info_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%de" % essence_cost
	cost_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	cost_lbl.modulate = Color(0.5, 0.85, 1.0)
	cost_lbl.custom_minimum_size = Vector2(_vh * 0.06, 0)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost_lbl)

	var can_craft: bool = can_afford_ingredients and player_essence >= essence_cost
	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(_vh * 0.12, _vh * 0.065)
	craft_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	craft_btn.disabled = not can_craft
	craft_btn.pressed.connect(_do_craft_potion.bind(potion_id, essence_cost, ingredients))
	row.add_child(craft_btn)

	return row

func _do_craft_potion(potion_id: String, essence_cost: int, ingredients: Dictionary) -> void:
	var sm := SceneManager.save_manager
	for ingredient_id: String in ingredients:
		var required: int = int(ingredients[ingredient_id])
		if not sm.remove_plants(ingredient_id, required):
			return
	if not sm.spend_essence(essence_cost):
		for ingredient_id: String in ingredients:
			sm.add_plants(ingredient_id, int(ingredients[ingredient_id]))
		return
	sm.add_potions(potion_id, 1)
	GameBus.potion_crafted.emit(potion_id)
	_refresh_craft()

func _show_confirm(action_row: HBoxContainer, confirm_row: HBoxContainer, label: String, on_confirm: Callable) -> void:
	action_row.visible = false
	for child in confirm_row.get_children():
		child.queue_free()
	confirm_row.visible = true

	var lbl := Label.new()
	lbl.text = "%s?" % label
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	lbl.modulate = Color(1.0, 0.6, 0.3)
	confirm_row.add_child(lbl)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(_vh * 0.10, _vh * 0.065)
	yes_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	yes_btn.pressed.connect(on_confirm)
	confirm_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(_vh * 0.10, _vh * 0.065)
	no_btn.add_theme_font_size_override("font_size", int(_vh * 0.022))
	no_btn.pressed.connect(func() -> void:
		confirm_row.visible = false
		action_row.visible = true)
	confirm_row.add_child(no_btn)

# -------------------------------------------------------------------------
# Deck mutation actions
# -------------------------------------------------------------------------

# Add one common copy of tid to the working deck.
func _on_add_by_type(tid: String, rarity: String) -> void:
	if _working_deck.size() >= IsoConst.DECK_MAX:
		return
	for inst: Dictionary in SceneManager.save_manager.get_owned_instances():
		if str(inst.get("template_id", "")) == tid and str(inst.get("rarity", "")) == rarity:
			var uid: String = str(inst.get("uid", ""))
			if not _working_deck.has(uid):
				_working_deck.append(uid)
				_refresh_cards()
				return

# Add a specific rare/epic/legendary instance by UID.
func _on_add_by_uid(uid: String) -> void:
	if _working_deck.size() >= IsoConst.DECK_MAX or _working_deck.has(uid):
		return
	_working_deck.append(uid)
	_refresh_cards()

# Remove one common copy of tid from the working deck.
func _on_remove_by_type(tid: String, rarity: String) -> void:
	for uid: String in _working_deck:
		var inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(uid)
		if str(inst.get("template_id", "")) == tid and str(inst.get("rarity", "")) == rarity:
			_working_deck.erase(uid)
			_refresh_cards()
			return

# Remove a specific rare/epic/legendary instance by UID.
func _on_remove_by_uid(uid: String) -> void:
	_working_deck.erase(uid)
	_refresh_cards()

# Returns the first non-deck copy UID for (tid, rarity), or "".
func _find_available_uid(tid: String, rarity: String) -> String:
	for inst: Dictionary in SceneManager.save_manager.get_owned_instances():
		if str(inst.get("template_id", "")) == tid and str(inst.get("rarity", "")) == rarity:
			var uid: String = str(inst.get("uid", ""))
			if not _working_deck.has(uid):
				return uid
	return ""

func _do_sell_by_type(tid: String, rarity: String) -> void:
	var uid: String = _find_available_uid(tid, rarity)
	if uid == "":
		return
	SceneManager.save_manager.sell_card_instance(uid)
	_refresh_cards()

func _do_scrap_by_type(tid: String, rarity: String) -> void:
	var uid: String = _find_available_uid(tid, rarity)
	if uid == "":
		return
	SceneManager.save_manager.scrap_card_instance(uid)
	_refresh_cards()

# -------------------------------------------------------------------------
# Tab + craft
# -------------------------------------------------------------------------

func _on_tab_cards() -> void:
	_cards_panel.visible = true
	_craft_panel.visible = false
	_refresh_cards()

func _on_tab_craft() -> void:
	_cards_panel.visible = false
	_craft_panel.visible = true
	_refresh_craft()

func _refresh_craft() -> void:
	for child in _craft_list.get_children():
		child.queue_free()

	_craft_essence_label.text = "Essence: %d" % SceneManager.save_manager.essence

	var recipes: Array = CraftingRegistry.get_all_recipes()
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
		_craft_list.add_child(_make_craft_row(recipe, player_essence))

	# Potions section
	var potion_header := Label.new()
	potion_header.text = "— Potions —"
	potion_header.add_theme_font_size_override("font_size", int(_vh * 0.022))
	potion_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	potion_header.modulate = Color(0.75, 0.85, 1.0)
	_craft_list.add_child(potion_header)

	var potion_recipes: Dictionary = GardenDefs.POTION_RECIPES
	for potion_id: String in potion_recipes:
		var recipe_data: Dictionary = potion_recipes[potion_id]
		_craft_list.add_child(_make_potion_craft_row(potion_id, recipe_data, player_essence))

func _show_inspect(card_id: String) -> void:
	if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
		return
	var tmpl: Dictionary = CardRegistry.get_template(card_id)
	if tmpl.is_empty():
		return
	var card: CardInstance = CardInstance.new(tmpl)
	var overlay := CardInspectOverlay.new()
	add_child(overlay)
	move_child(overlay, get_child_count() - 1)
	overlay.show_card(card)
	overlay.closed.connect(func() -> void: _inspect_overlay = null)
	_inspect_overlay = overlay

func _on_save() -> void:
	SceneManager.save_manager.set_active_deck(_working_deck)
	closed.emit()

func _on_close() -> void:
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_on_close()
