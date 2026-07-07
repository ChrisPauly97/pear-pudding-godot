extends "res://scenes/ui/BaseOverlay.gd"

const CardRegistry      = preload("res://autoloads/CardRegistry.gd")
const CraftingRegistry  = preload("res://autoloads/CraftingRegistry.gd")
const GardenDefs        = preload("res://game_logic/GardenDefs.gd")
const _CardDropUtil     = preload("res://game_logic/CardDropUtil.gd")
const CardInspectOverlay = preload("res://scenes/battle/CardInspectOverlay.gd")
const CardInstance      = preload("res://game_logic/battle/CardInstance.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const _UiUtil           = preload("res://scenes/ui/UiUtil.gd")
const VeterancyUtil     = preload("res://game_logic/VeterancyUtil.gd")

const DeckAutoFill = preload("res://game_logic/DeckAutoFill.gd")

var _working_deck: Array[String] = []

var _collection_list: VBoxContainer
var _deck_list: VBoxContainer
var _collection_scroll: ScrollContainer
var _deck_scroll: ScrollContainer
var _deck_count_label: Label
var _coin_label: Label
var _essence_label: Label
var _slot_label: Label

# Collection filters (session-only state)
var _filter_class: String = ""    # "" = all, "minion", "spell"
var _filter_cost: String = ""     # "" = all, "low" (0-2), "mid" (3-5), "high" (6+)
var _filter_rarity: String = ""   # "" = all, "common", "rare", "epic", "legendary"
var _filter_btns: Array[Button] = []

var _cards_panel: Control
var _tab_cards_btn: Button
var _tab_craft_btn: Button
var _craft_panel: Control
var _craft_list: VBoxContainer
var _craft_essence_label: Label
var _craft_rarity_row: HBoxContainer
var _craft_rarity: String = "common"
var _inspect_overlay: Control = null

var _loadout_tab_row: HBoxContainer
var _loadout_action_row: HBoxContainer
var _rename_btn: Button
var _dup_btn: Button
var _del_btn: Button

# Set to true by MenuHubScene before add_child() so the scene skips its own
# backdrop/panel and builds content directly into the hub's content area.
var hub_mode: bool = false

func _ready() -> void:
	super._ready()
	_working_deck.assign(SceneManager.save_manager.player_deck)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var is_portrait: bool = _vw < _vh
	var wrapper: VBoxContainer
	if hub_mode:
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		var m: int = int(_ref * 0.010)
		margin.add_theme_constant_override("margin_left", m)
		margin.add_theme_constant_override("margin_right", m)
		margin.add_theme_constant_override("margin_top", m)
		margin.add_theme_constant_override("margin_bottom", m)
		add_child(margin)
		wrapper = VBoxContainer.new()
		wrapper.add_theme_constant_override("separation", int(_ref * 0.008))
		margin.add_child(wrapper)
	else:
		_build_backdrop(0.78)
		var panel_w: float = _vw * 0.95 if is_portrait else _vw * 0.86
		var panel_h: float = _vh * 0.92 if is_portrait else _vh * 0.86
		var outer := _build_centered_panel(panel_w, panel_h)
		wrapper = _build_margin_vbox(outer, 0.015, 0.008)

	# ---- Tab bar ----
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", int(_vw * 0.008))
	wrapper.add_child(tab_bar)

	_tab_cards_btn = Button.new()
	_tab_cards_btn.text = "Cards"
	_tab_cards_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.065)
	_tab_cards_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	_tab_cards_btn.pressed.connect(_on_tab_cards)
	tab_bar.add_child(_tab_cards_btn)

	_tab_craft_btn = Button.new()
	_tab_craft_btn.text = "Craft"
	_tab_craft_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.065)
	_tab_craft_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	_tab_craft_btn.pressed.connect(_on_tab_craft)
	tab_bar.add_child(_tab_craft_btn)

	var scroll_min_h: float = _ref * 0.25 if is_portrait else 0.0

	# ====================================================================
	# CARDS PANEL
	# ====================================================================
	var root_box: BoxContainer
	if is_portrait:
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", int(_ref * 0.008))
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
	col_title.add_theme_font_size_override("font_size", int(_ref * 0.026))
	col_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(col_title)

	_slot_label = Label.new()
	_slot_label.add_theme_font_size_override("font_size", int(_ref * 0.020))
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.modulate = Color(0.8, 0.8, 0.8)
	left_vbox.add_child(_slot_label)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", int(_ref * 0.022))
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.modulate = Color(1.0, 0.85, 0.1)
	left_vbox.add_child(_coin_label)

	_essence_label = Label.new()
	_essence_label.add_theme_font_size_override("font_size", int(_ref * 0.022))
	_essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_essence_label.modulate = Color(0.5, 0.85, 1.0)
	left_vbox.add_child(_essence_label)

	# ---- Filter row ----
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", int(_ref * 0.005))
	left_vbox.add_child(filter_row)
	_build_filter_buttons(filter_row)

	_collection_scroll = ScrollContainer.new()
	var left_scroll: ScrollContainer = _collection_scroll
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if scroll_min_h > 0.0:
		left_scroll.custom_minimum_size = Vector2(0.0, scroll_min_h)
	left_vbox.add_child(left_scroll)
	attach_drag_scroll(left_scroll)

	_collection_list = VBoxContainer.new()
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("separation", int(_ref * 0.008))
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

	# ---- Loadout tab row ----
	_loadout_tab_row = HBoxContainer.new()
	_loadout_tab_row.add_theme_constant_override("separation", int(_ref * 0.005))
	right_vbox.add_child(_loadout_tab_row)

	# ---- Loadout action row (Rename / Copy / Delete) ----
	_loadout_action_row = HBoxContainer.new()
	_loadout_action_row.add_theme_constant_override("separation", int(_ref * 0.006))
	right_vbox.add_child(_loadout_action_row)

	_rename_btn = Button.new()
	_rename_btn.text = "Rename"
	_rename_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.055)
	_rename_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
	_rename_btn.pressed.connect(_on_rename_loadout)
	_loadout_action_row.add_child(_rename_btn)

	_dup_btn = Button.new()
	_dup_btn.text = "Copy"
	_dup_btn.custom_minimum_size = Vector2(_ref * 0.10, _ref * 0.055)
	_dup_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
	_dup_btn.pressed.connect(_on_dup_loadout)
	_loadout_action_row.add_child(_dup_btn)

	_del_btn = Button.new()
	_del_btn.text = "Delete"
	_del_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.055)
	_del_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
	_del_btn.modulate = Color(1.0, 0.4, 0.4)
	_del_btn.pressed.connect(_on_del_loadout)
	_loadout_action_row.add_child(_del_btn)

	_deck_count_label = Label.new()
	_deck_count_label.add_theme_font_size_override("font_size", int(_ref * 0.026))
	_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(_deck_count_label)

	var autofill_btn := Button.new()
	autofill_btn.text = "Auto-Fill"
	autofill_btn.custom_minimum_size = Vector2(_ref * 0.18, _ref * 0.055)
	autofill_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
	autofill_btn.pressed.connect(_on_auto_fill)
	right_vbox.add_child(autofill_btn)

	_deck_scroll = ScrollContainer.new()
	var right_scroll: ScrollContainer = _deck_scroll
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if scroll_min_h > 0.0:
		right_scroll.custom_minimum_size = Vector2(0.0, scroll_min_h)
	right_vbox.add_child(right_scroll)
	attach_drag_scroll(right_scroll)

	_deck_list = VBoxContainer.new()
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_list.add_theme_constant_override("separation", int(_ref * 0.008))
	right_scroll.add_child(_deck_list)

	# ---- Buttons ----
	if is_portrait:
		var btn_hbox := HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", int(_vw * 0.04))
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		root_box.add_child(btn_hbox)

		var save_btn := Button.new()
		save_btn.text = "Save Deck"
		save_btn.custom_minimum_size = Vector2(_vw * 0.35, _ref * 0.065)
		save_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
		save_btn.pressed.connect(_on_save)
		btn_hbox.add_child(save_btn)

		if not hub_mode:
			var close_btn := Button.new()
			close_btn.text = "Close"
			close_btn.custom_minimum_size = Vector2(_vw * 0.35, _ref * 0.065)
			close_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
			close_btn.pressed.connect(_on_close)
			btn_hbox.add_child(close_btn)
	else:
		var btn_vbox := VBoxContainer.new()
		btn_vbox.add_theme_constant_override("separation", int(_ref * 0.012))
		btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		root_box.add_child(btn_vbox)

		var save_btn := Button.new()
		save_btn.text = "Save Deck"
		save_btn.custom_minimum_size = Vector2(_vw * 0.1, _ref * 0.065)
		save_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
		save_btn.pressed.connect(_on_save)
		btn_vbox.add_child(save_btn)

		if not hub_mode:
			var close_btn := Button.new()
			close_btn.text = "Close  [I]" if not OS.has_feature("android") else "Close"
			close_btn.custom_minimum_size = Vector2(_vw * 0.1, _ref * 0.065)
			close_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
			close_btn.pressed.connect(_on_close)
			btn_vbox.add_child(close_btn)

	# ====================================================================
	# CRAFT PANEL
	# ====================================================================
	var craft_box := VBoxContainer.new()
	craft_box.add_theme_constant_override("separation", int(_ref * 0.008))
	craft_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	craft_box.visible = false
	_craft_panel = craft_box
	wrapper.add_child(craft_box)

	_craft_essence_label = Label.new()
	_craft_essence_label.add_theme_font_size_override("font_size", int(_ref * 0.022))
	_craft_essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_craft_essence_label.modulate = Color(0.5, 0.85, 1.0)
	craft_box.add_child(_craft_essence_label)

	_craft_rarity_row = HBoxContainer.new()
	_craft_rarity_row.add_theme_constant_override("separation", int(_ref * 0.006))
	_craft_rarity_row.alignment = BoxContainer.ALIGNMENT_CENTER
	craft_box.add_child(_craft_rarity_row)

	var craft_scroll := ScrollContainer.new()
	craft_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	craft_box.add_child(craft_scroll)
	attach_drag_scroll(craft_scroll)

	_craft_list = VBoxContainer.new()
	_craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_list.add_theme_constant_override("separation", int(_ref * 0.006))
	craft_scroll.add_child(_craft_list)

	if not hub_mode:
		var craft_close_btn := Button.new()
		craft_close_btn.text = "Close  [I]" if not OS.has_feature("android") else "Close"
		craft_close_btn.custom_minimum_size = Vector2(_vw * 0.1, _ref * 0.065)
		craft_close_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
		craft_close_btn.pressed.connect(_on_close)
		craft_box.add_child(craft_close_btn)

# -------------------------------------------------------------------------
# Refresh
# -------------------------------------------------------------------------

func _refresh() -> void:
	_refresh_cards()
	if _craft_panel.visible:
		_refresh_craft()

func _rebuild_loadout_bar() -> void:
	var sm := SceneManager.save_manager
	for child in _loadout_tab_row.get_children():
		child.queue_free()

	var names: Array[String] = sm.get_loadout_names()
	var active_idx: int = sm.active_loadout
	var at_cap: bool = names.size() >= sm.MAX_LOADOUTS

	for i in range(names.size()):
		var tab_btn := Button.new()
		tab_btn.text = names[i]
		tab_btn.flat = true
		tab_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.055)
		tab_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
		var is_valid: bool
		if i == active_idx:
			is_valid = _working_deck.size() >= IsoConst.DECK_MIN and _working_deck.size() <= IsoConst.DECK_MAX
		else:
			is_valid = sm.is_loadout_valid(i)
		if i == active_idx:
			tab_btn.modulate = Color.WHITE if is_valid else Color(1.0, 0.35, 0.35)
		else:
			tab_btn.modulate = Color(0.7, 0.7, 0.7) if is_valid else Color(0.75, 0.28, 0.28)
		tab_btn.pressed.connect(_on_loadout_tab.bind(i))
		_loadout_tab_row.add_child(tab_btn)

	var new_btn := Button.new()
	new_btn.text = "+"
	new_btn.custom_minimum_size = Vector2(_ref * 0.055, _ref * 0.055)
	new_btn.add_theme_font_size_override("font_size", int(_ref * 0.025))
	new_btn.disabled = at_cap
	new_btn.pressed.connect(_on_new_loadout)
	_loadout_tab_row.add_child(new_btn)

	_del_btn.disabled = names.size() <= 1
	_dup_btn.disabled = at_cap

func _refresh_cards() -> void:
	_rebuild_loadout_bar()
	var col_scroll: int = _collection_scroll.scroll_vertical if _collection_scroll else 0
	var deck_scroll: int = _deck_scroll.scroll_vertical if _deck_scroll else 0
	for child in _collection_list.get_children():
		child.queue_free()
	for child in _deck_list.get_children():
		child.queue_free()

	var sm := SceneManager.save_manager

	_coin_label.text    = "Coins: %d" % sm.coins
	_essence_label.text = "Essence: %d" % sm.essence

	var used: int   = sm.get_slot_count(_working_deck)
	var cap: int    = sm.bag_size
	_slot_label.text    = "Bag: %d / %d" % [used, cap]
	_slot_label.modulate = Color(1.0, 0.35, 0.35) if used >= cap else Color(0.80, 0.80, 0.80)

	var all_instances: Array[Dictionary] = sm.get_owned_instances()

	# Every instance has its own rolled stats, so each takes its own tile/row —
	# no more grouping same-template commons into a single stack.
	var avail: Array[Dictionary] = []
	var deck_insts: Array[Dictionary] = []

	for inst: Dictionary in all_instances:
		var uid: String    = str(inst.get("uid", ""))
		var tid: String    = str(inst.get("template_id", ""))
		var rarity: String = str(inst.get("rarity", "common"))
		if tid == "":
			continue
		if _working_deck.has(uid):
			deck_insts.append(inst)
		else:
			if not _passes_filter(tid, rarity):
				continue
			avail.append(inst)

	var by_name_then_rarity := func(a: Dictionary, b: Dictionary) -> bool:
		var ta: String = str(a.get("template_id", ""))
		var tb: String = str(b.get("template_id", ""))
		if ta != tb:
			return ta < tb
		return IsoConst.RARITY_ORDER.find(str(a.get("rarity", "common"))) > \
		       IsoConst.RARITY_ORDER.find(str(b.get("rarity", "common")))

	# ---- Backpack grid ----
	if not avail.is_empty():
		avail.sort_custom(by_name_then_rarity)
		var grid := GridContainer.new()
		var tile_size: float = _ref * 0.11
		var cols: int = maxi(1, int(_collection_scroll.size.x / (tile_size + _ref * 0.01)))
		grid.columns = cols if cols > 1 else 4
		grid.add_theme_constant_override("h_separation", int(_ref * 0.010))
		grid.add_theme_constant_override("v_separation", int(_ref * 0.010))
		_collection_list.add_child(grid)
		for inst: Dictionary in avail:
			grid.add_child(_make_card_tile(inst, false))
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "No spare cards"
		empty_lbl.add_theme_font_size_override("font_size", int(_ref * 0.020))
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_collection_list.add_child(empty_lbl)

	# ---- Deck list ----
	if not deck_insts.is_empty():
		deck_insts.sort_custom(by_name_then_rarity)
		for inst: Dictionary in deck_insts:
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
# Filter helpers
# -------------------------------------------------------------------------

func _build_filter_buttons(row: HBoxContainer) -> void:
	_filter_btns.clear()
	var btn_h: float = _ref * 0.048
	var btn_fs: int = int(_ref * 0.018)
	var specs: Array = [
		["All", "class", ""],
		["Minion", "class", "minion"],
		["Spell", "class", "spell"],
		["0-2", "cost", "low"],
		["3-5", "cost", "mid"],
		["6+", "cost", "high"],
		["C", "rarity", "common"],
		["R", "rarity", "rare"],
		["E", "rarity", "epic"],
		["L", "rarity", "legendary"],
	]
	for spec in specs:
		var lbl_text: String = str(spec[0])
		var kind: String = str(spec[1])
		var val: String = str(spec[2])
		var btn := Button.new()
		btn.text = lbl_text
		btn.custom_minimum_size = Vector2(0.0, btn_h)
		btn.add_theme_font_size_override("font_size", btn_fs)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_filter_btn.bind(kind, val, btn))
		row.add_child(btn)
		_filter_btns.append(btn)
	_update_filter_visuals()

func _on_filter_btn(kind: String, val: String, btn: Button) -> void:
	match kind:
		"class":
			_filter_class = "" if _filter_class == val else val
		"cost":
			_filter_cost = "" if _filter_cost == val else val
		"rarity":
			_filter_rarity = "" if _filter_rarity == val else val
	_update_filter_visuals()
	_refresh()

func _update_filter_visuals() -> void:
	var specs: Array = [
		["class", ""], ["class", "minion"], ["class", "spell"],
		["cost", "low"], ["cost", "mid"], ["cost", "high"],
		["rarity", "common"], ["rarity", "rare"], ["rarity", "epic"], ["rarity", "legendary"],
	]
	for i in range(mini(specs.size(), _filter_btns.size())):
		var kind: String = str(specs[i][0])
		var val: String = str(specs[i][1])
		var active: bool
		match kind:
			"class":  active = (_filter_class == val)
			"cost":   active = (_filter_cost == val)
			_:        active = (_filter_rarity == val)
		_filter_btns[i].modulate = Color(1.0, 0.85, 0.3) if active else Color.WHITE

func _passes_filter(tid: String, rarity: String) -> bool:
	if _filter_rarity != "" and rarity != _filter_rarity:
		return false
	var tmpl: Dictionary = CardRegistry.get_template(tid)
	if _filter_class != "" and str(tmpl.get("card_class", "minion")) != _filter_class:
		return false
	if _filter_cost != "":
		var cost: int = int(tmpl.get("cost", 0))
		match _filter_cost:
			"low":  if cost > 2: return false
			"mid":  if cost < 3 or cost > 5: return false
			"high": if cost < 6: return false
	return true

func _on_auto_fill() -> void:
	var sm := SceneManager.save_manager
	var all_instances: Array[Dictionary] = sm.get_owned_instances()
	var available: Array[Dictionary] = []
	for inst: Dictionary in all_instances:
		var uid: String = str(inst.get("uid", ""))
		if uid != "" and not _working_deck.has(uid):
			available.append(inst)
	var target: int = maxi(IsoConst.DECK_MIN, _working_deck.size())
	target = mini(target, IsoConst.DECK_MAX)
	_working_deck = DeckAutoFill.fill(_working_deck, available, target)
	_refresh()

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
	lbl.add_theme_font_size_override("font_size", int(_ref * 0.019))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.60, 0.72, 0.92)
	return lbl

# Diablo-3-style cube: one tile per owned instance. Hover (desktop) or
# tap-and-hold (mobile) opens the detail popup with rolled stats + actions.
# A plain tap adds the card to the working deck.
func _make_card_tile(inst: Dictionary, in_deck: bool) -> Control:
	var uid: String    = str(inst.get("uid", ""))
	var tid: String    = str(inst.get("template_id", ""))
	var rarity: String = str(inst.get("rarity", "common"))
	var _face: String = "dark" if CardRegistry.is_dark_aligned() else "light"
	var tmpl: Dictionary  = CardRegistry.get_template_for_face(tid, _face)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))

	var kills: int    = int(inst.get("kills", 0))
	var survived: int = int(inst.get("battles_survived", 0))
	var rank: int     = VeterancyUtil.rank_for(kills, survived)

	var tile_size: float = _ref * 0.11
	var cube := Button.new()
	cube.custom_minimum_size = Vector2(tile_size, tile_size)
	cube.focus_mode = Control.FOCUS_NONE

	var sb := StyleBoxFlat.new()
	sb.bg_color = card_color
	sb.border_color = _UiUtil.rarity_color(rarity)
	sb.set_border_width_all(maxi(2, int(_ref * 0.006)))
	sb.set_corner_radius_all(int(_ref * 0.012))
	cube.add_theme_stylebox_override("normal", sb)
	cube.add_theme_stylebox_override("hover", sb)
	cube.add_theme_stylebox_override("pressed", sb)
	cube.add_theme_stylebox_override("focus", sb)

	var badge_lbl := Label.new()
	badge_lbl.text = _UiUtil.rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_ref * 0.016))
	badge_lbl.modulate = _UiUtil.rarity_color(rarity)
	badge_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge_lbl.position = Vector2(_ref * 0.006, _ref * 0.004)
	cube.add_child(badge_lbl)

	if rank > 0:
		var chev_lbl := Label.new()
		chev_lbl.text = VeterancyUtil.rank_chevrons(rank)
		chev_lbl.add_theme_font_size_override("font_size", int(_ref * 0.014))
		chev_lbl.modulate = Color(1.0, 0.82, 0.2)
		chev_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		chev_lbl.position = Vector2(tile_size - _ref * 0.03, tile_size - _ref * 0.022)
		cube.add_child(chev_lbl)

	cube.pressed.connect(func() -> void:
		if in_deck:
			_on_remove_by_uid(uid)
		else:
			_on_add_by_uid(uid))

	var lpd := LongPressDetector.new()
	cube.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_instance_detail(inst, cube))

	cube.mouse_entered.connect(func() -> void: _show_instance_detail(inst, cube))
	cube.mouse_exited.connect(func() -> void: _hide_instance_detail())

	return cube

# -------------------------------------------------------------------------
# Instance detail popup (hover / tap-and-hold)
# -------------------------------------------------------------------------

var _detail_popup: PopupPanel = null

func _hide_instance_detail() -> void:
	if _detail_popup != null and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()
	_detail_popup = null

func _show_instance_detail(inst: Dictionary, anchor: Control) -> void:
	_hide_instance_detail()

	var uid: String    = str(inst.get("uid", ""))
	var tid: String    = str(inst.get("template_id", ""))
	var rarity: String = str(inst.get("rarity", "common"))
	var _face: String = "dark" if CardRegistry.is_dark_aligned() else "light"
	var tmpl: Dictionary  = CardRegistry.get_template_for_face(tid, _face)
	var card_name: String = tmpl.get("name", tid)
	var disp_name: String = VeterancyUtil.display_name(inst, card_name)
	var is_dual: bool = str(tmpl.get("dual_card_id", "")) != ""
	var illustration: Texture2D = tmpl.get("illustration") as Texture2D

	var rolled_atk: int  = int(inst.get("attack", int(tmpl.get("attack", 0))))
	var rolled_hp: int   = int(inst.get("health", int(tmpl.get("health", 0))))
	var rolled_cost: int = int(inst.get("cost",   int(tmpl.get("cost",   0))))

	var popup := PopupPanel.new()
	add_child(popup)
	_detail_popup = popup

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(_ref * 0.008))
	vb.custom_minimum_size = Vector2(_ref * 0.34, 0)
	popup.add_child(vb)

	if illustration != null:
		var art := TextureRect.new()
		art.texture = illustration
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(0.0, _ref * 0.14)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vb.add_child(art)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", int(_ref * 0.006))
	vb.add_child(title_row)

	var name_lbl := Label.new()
	name_lbl.text = disp_name + (" ◑" if is_dual else "")
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.024))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _UiUtil.rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	badge_lbl.modulate = _UiUtil.rarity_color(rarity)
	title_row.add_child(badge_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "Cost %d  ATK %d  HP %d" % [rolled_cost, rolled_atk, rolled_hp]
	stats_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	stats_lbl.modulate = _UiUtil.rarity_color(rarity).lerp(Color(0.85, 0.85, 0.85), 0.55)
	vb.add_child(stats_lbl)

	var is_unique: bool = bool(tmpl.get("is_unique", false))
	if not is_unique:
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
		var sell_gold: int  = int(cfg.get("sell_gold", 0))
		var scrap_ess: int  = int(cfg.get("scrap_essence", 0))

		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", int(_ref * 0.006))
		vb.add_child(action_row)

		var sell_btn := Button.new()
		sell_btn.text = "Sell +%dg" % sell_gold
		sell_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.06)
		sell_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
		sell_btn.modulate = Color(1.0, 0.9, 0.3)
		sell_btn.pressed.connect(func() -> void:
			SceneManager.save_manager.sell_card_instance(uid)
			_hide_instance_detail()
			_refresh_cards())
		action_row.add_child(sell_btn)

		var scrap_btn := Button.new()
		scrap_btn.text = "Scrap +%de" % scrap_ess
		scrap_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.06)
		scrap_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
		scrap_btn.modulate = Color(0.5, 0.85, 1.0)
		scrap_btn.pressed.connect(func() -> void:
			SceneManager.save_manager.scrap_card_instance(uid)
			_hide_instance_detail()
			_refresh_cards())
		action_row.add_child(scrap_btn)

		# Combine 3× same template+rarity → next tier (only offered for commons).
		if rarity == "common":
			var avail_count: int = 0
			for other: Dictionary in SceneManager.save_manager.get_owned_instances():
				if str(other.get("template_id", "")) == tid and str(other.get("rarity", "")) == "common" \
						and not _working_deck.has(str(other.get("uid", ""))):
					avail_count += 1
			var next_idx: int = IsoConst.RARITY_ORDER.find("common") + 1
			if next_idx < IsoConst.RARITY_ORDER.size():
				var next_rarity: String = IsoConst.RARITY_ORDER[next_idx]
				var combine_btn := Button.new()
				combine_btn.text = "Combine 3× → %s" % _UiUtil.rarity_badge(next_rarity)
				combine_btn.custom_minimum_size = Vector2(_ref * 0.22, _ref * 0.06)
				combine_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
				combine_btn.modulate = _UiUtil.rarity_color(next_rarity)
				combine_btn.disabled = avail_count < 3
				combine_btn.pressed.connect(func() -> void:
					SceneManager.save_manager.combine_cards(tid, "common")
					_hide_instance_detail()
					_refresh_cards())
				vb.add_child(combine_btn)

		var rename_row := HBoxContainer.new()
		rename_row.add_theme_constant_override("separation", int(_ref * 0.006))
		vb.add_child(rename_row)

		var rename_edit := LineEdit.new()
		rename_edit.text = str(inst.get("custom_name", ""))
		rename_edit.placeholder_text = disp_name
		rename_edit.max_length = 24
		rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rename_edit.custom_minimum_size = Vector2(0, _ref * 0.06)
		rename_edit.add_theme_font_size_override("font_size", int(_ref * 0.020))
		rename_row.add_child(rename_edit)

		var rename_btn := Button.new()
		rename_btn.text = "Rename"
		rename_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.06)
		rename_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
		rename_btn.pressed.connect(func() -> void:
			SceneManager.save_manager.set_card_custom_name(uid, rename_edit.text)
			_hide_instance_detail()
			_refresh_cards())
		rename_row.add_child(rename_btn)

	popup.popup(Rect2i(anchor.get_screen_transform().origin as Vector2i, Vector2i(int(_ref * 0.34), 0)))

# Individual deck slot for a rare/epic/legendary card — shows its rolled stats.
func _make_deck_row_instance(uid: String, inst: Dictionary) -> VBoxContainer:
	var tid: String    = str(inst.get("template_id", uid))
	var rarity: String = str(inst.get("rarity", "common"))
	var _face: String = "dark" if CardRegistry.is_dark_aligned() else "light"
	var tmpl: Dictionary  = CardRegistry.get_template_for_face(tid, _face)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	var card_name: String = tmpl.get("name", tid)
	var is_dual: bool = str(tmpl.get("dual_card_id", "")) != ""

	var kills: int    = int(inst.get("kills", 0))
	var survived: int = int(inst.get("battles_survived", 0))
	var rank: int     = VeterancyUtil.rank_for(kills, survived)
	var disp_name: String = VeterancyUtil.display_name(inst, card_name)

	var rolled_atk: int  = int(inst.get("attack", int(tmpl.get("attack", 0))))
	var rolled_hp: int   = int(inst.get("health", int(tmpl.get("health", 0))))
	var rolled_cost: int = int(inst.get("cost",   int(tmpl.get("cost",   0))))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(_ref * 0.003))

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", int(_vw * 0.008))
	vbox.add_child(top_row)

	var swatch := ColorRect.new()
	swatch.color = card_color
	swatch.custom_minimum_size = Vector2(_ref * 0.03, _ref * 0.03)
	top_row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = disp_name
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	if rank > 0:
		var chev_lbl := Label.new()
		chev_lbl.text = VeterancyUtil.rank_chevrons(rank)
		chev_lbl.add_theme_font_size_override("font_size", int(_ref * 0.018))
		chev_lbl.modulate = Color(1.0, 0.82, 0.2)
		top_row.add_child(chev_lbl)
	if is_dual:
		var dual_badge := Label.new()
		dual_badge.text = "◑"
		dual_badge.add_theme_font_size_override("font_size", int(_ref * 0.022))
		dual_badge.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		dual_badge.tooltip_text = "Dual-faced card"
		top_row.add_child(dual_badge)

	var badge_lbl := Label.new()
	badge_lbl.text = _UiUtil.rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	badge_lbl.modulate = _UiUtil.rarity_color(rarity)
	top_row.add_child(badge_lbl)

	var rm_btn := Button.new()
	rm_btn.text = "−"
	rm_btn.custom_minimum_size = Vector2(_ref * 0.065, _ref * 0.065)
	rm_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
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
	stats_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
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
	swatch.custom_minimum_size = Vector2(_ref * 0.028, _ref * 0.028)
	row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = card_name
	name_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _UiUtil.rarity_badge(rarity)
	badge_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	badge_lbl.modulate = _UiUtil.rarity_color(rarity)
	row.add_child(badge_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%de" % cost
	cost_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	cost_lbl.modulate = Color(0.5, 0.85, 1.0)
	cost_lbl.custom_minimum_size = Vector2(_ref * 0.06, 0)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost_lbl)

	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.065)
	craft_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
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
	info_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%de" % essence_cost
	cost_lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	cost_lbl.modulate = Color(0.5, 0.85, 1.0)
	cost_lbl.custom_minimum_size = Vector2(_ref * 0.06, 0)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost_lbl)

	var can_craft: bool = can_afford_ingredients and player_essence >= essence_cost
	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.065)
	craft_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
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
	lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	lbl.modulate = Color(1.0, 0.6, 0.3)
	confirm_row.add_child(lbl)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(_ref * 0.10, _ref * 0.065)
	yes_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	yes_btn.pressed.connect(on_confirm)
	confirm_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(_ref * 0.10, _ref * 0.065)
	no_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	no_btn.pressed.connect(func() -> void:
		confirm_row.visible = false
		action_row.visible = true)
	confirm_row.add_child(no_btn)

# -------------------------------------------------------------------------
# Deck mutation actions
# -------------------------------------------------------------------------

# Add a specific instance by UID.
func _on_add_by_uid(uid: String) -> void:
	if _working_deck.size() >= IsoConst.DECK_MAX or _working_deck.has(uid):
		return
	_working_deck.append(uid)
	_hide_instance_detail()
	_refresh_cards()

# Remove a specific instance by UID.
func _on_remove_by_uid(uid: String) -> void:
	if _working_deck.size() <= IsoConst.DECK_MIN:
		GameBus.hud_message_requested.emit("Minimum deck size reached")
		return
	_working_deck.erase(uid)
	_hide_instance_detail()
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

	# Rebuild rarity selector buttons.
	for child in _craft_rarity_row.get_children():
		child.queue_free()
	for rarity: String in IsoConst.RARITY_ORDER:
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
		var ess_cost: int = int(cfg.get("craft_essence", 0))
		var sel_btn := Button.new()
		sel_btn.text = "%s %de" % [_UiUtil.rarity_badge(rarity), ess_cost]
		sel_btn.custom_minimum_size = Vector2(_ref * 0.17, _ref * 0.058)
		sel_btn.add_theme_font_size_override("font_size", int(_ref * 0.020))
		if rarity == _craft_rarity:
			sel_btn.modulate = _UiUtil.rarity_color(rarity)
		else:
			sel_btn.modulate = Color(0.50, 0.50, 0.50)
		sel_btn.pressed.connect(func() -> void:
			_craft_rarity = rarity
			_refresh_craft())
		_craft_rarity_row.add_child(sel_btn)

	# Show only recipes for the selected rarity, sorted by card name.
	var recipes: Array = CraftingRegistry.get_all_recipes()
	var filtered: Array = []
	for recipe in recipes:
		if str(recipe.rarity) == _craft_rarity:
			filtered.append(recipe)
	filtered.sort_custom(func(a: Object, b: Object) -> bool:
		var na: String = str(CardRegistry.get_template(str(a.template_id)).get("name", str(a.template_id)))
		var nb: String = str(CardRegistry.get_template(str(b.template_id)).get("name", str(b.template_id)))
		return na < nb
	)

	var player_essence: int = SceneManager.save_manager.essence
	for recipe in filtered:
		_craft_list.add_child(_make_craft_row(recipe, player_essence))

	# Potions section
	var potion_header := Label.new()
	potion_header.text = "— Potions —"
	potion_header.add_theme_font_size_override("font_size", int(_ref * 0.022))
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
	if not hub_mode:
		closed.emit()

func _on_close() -> void:
	closed.emit()

# -------------------------------------------------------------------------
# Loadout handlers
# -------------------------------------------------------------------------

func _on_loadout_tab(index: int) -> void:
	var sm := SceneManager.save_manager
	sm.set_active_deck(_working_deck)
	sm.set_active_loadout(index)
	_working_deck.assign(sm.player_deck)
	_refresh_cards()

func _on_new_loadout() -> void:
	var sm := SceneManager.save_manager
	sm.set_active_deck(_working_deck)
	var new_idx: int = sm.add_loadout("Deck %d" % (sm.loadouts.size() + 1))
	if new_idx < 0:
		return
	sm.set_active_loadout(new_idx)
	_working_deck.assign(sm.player_deck)
	_refresh_cards()

func _on_rename_loadout() -> void:
	var sm := SceneManager.save_manager
	if sm.active_loadout < 0 or sm.active_loadout >= sm.loadouts.size():
		return
	var current_name: String = str(sm.loadouts[sm.active_loadout].get("name", ""))

	var popup := PopupPanel.new()
	add_child(popup)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(_ref * 0.012))
	vb.custom_minimum_size = Vector2(_ref * 0.5, 0)
	popup.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.text = "Rename Loadout"
	title_lbl.add_theme_font_size_override("font_size", int(_ref * 0.024))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title_lbl)

	var edit := LineEdit.new()
	edit.text = current_name
	edit.max_length = 20
	edit.add_theme_font_size_override("font_size", int(_ref * 0.024))
	edit.custom_minimum_size = Vector2(0, _ref * 0.065)
	vb.add_child(edit)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", int(_ref * 0.012))
	vb.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.065)
	ok_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	ok_btn.pressed.connect(func() -> void:
		var new_name: String = edit.text.strip_edges()
		if new_name.length() > 0:
			sm.rename_loadout(sm.active_loadout, new_name)
			_refresh_cards()
		popup.queue_free())
	btn_row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(_ref * 0.12, _ref * 0.065)
	cancel_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	cancel_btn.pressed.connect(func() -> void: popup.queue_free())
	btn_row.add_child(cancel_btn)

	popup.popup_centered()
	# Shift to top half so the Android keyboard doesn't cover the input field.
	popup.position.y = int(get_viewport_rect().size.y * 0.08)
	edit.grab_focus()
	edit.select_all()

func _on_dup_loadout() -> void:
	var sm := SceneManager.save_manager
	sm.set_active_deck(_working_deck)
	var new_idx: int = sm.duplicate_loadout(sm.active_loadout)
	if new_idx < 0:
		return
	sm.set_active_loadout(new_idx)
	_working_deck.assign(sm.player_deck)
	_refresh_cards()

func _on_del_loadout() -> void:
	var sm := SceneManager.save_manager
	if sm.loadouts.size() <= 1:
		return
	var loadout_name: String = str(sm.loadouts[sm.active_loadout].get("name", "this loadout"))

	var popup := PopupPanel.new()
	add_child(popup)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(_ref * 0.012))
	vb.custom_minimum_size = Vector2(_ref * 0.5, 0)
	popup.add_child(vb)

	var lbl := Label.new()
	lbl.text = "Delete '%s'?\nThis cannot be undone." % loadout_name
	lbl.add_theme_font_size_override("font_size", int(_ref * 0.022))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", int(_ref * 0.012))
	vb.add_child(btn_row)

	var yes_btn := Button.new()
	yes_btn.text = "Yes, Delete"
	yes_btn.custom_minimum_size = Vector2(_ref * 0.16, _ref * 0.065)
	yes_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	yes_btn.modulate = Color(1.0, 0.4, 0.4)
	yes_btn.pressed.connect(func() -> void:
		popup.queue_free()
		sm.delete_loadout(sm.active_loadout)
		_working_deck.assign(sm.player_deck)
		_refresh_cards())
	btn_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(_ref * 0.14, _ref * 0.065)
	no_btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	no_btn.pressed.connect(func() -> void: popup.queue_free())
	btn_row.add_child(no_btn)

	popup.popup_centered()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_on_close()
