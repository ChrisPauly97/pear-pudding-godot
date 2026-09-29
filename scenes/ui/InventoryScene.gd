# gdlint: disable=max-file-lines
# BID-053 lint debt: oversized script. Shrink it by extraction; don't add to it.
extends "res://scenes/ui/CardBrowserOverlay.gd"

const CardRegistry      = preload("res://autoloads/CardRegistry.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const VeterancyUtil     = preload("res://game_logic/VeterancyUtil.gd")
const BagOps            = preload("res://game_logic/inventory/BagOps.gd")
const _CardTile         = preload("res://scenes/ui/inventory/CardTile.gd")
const _CraftPanel       = preload("res://scenes/ui/inventory/CraftPanel.gd")
const _ItemsPanel       = preload("res://scenes/ui/inventory/ItemsPanel.gd")

const DeckAutoFill = preload("res://game_logic/DeckAutoFill.gd")

# -------------------------------------------------------------------------
# Drag and drop between the collection and the deck
#
# Tapping a card still moves it — that is the fast path and the only one that
# works with a single touch. Dragging exists because tapping gives no sense of
# where the card went, which reads as the card vanishing.
#
# Sideways drags start a card drag; up/down drags stay a list scroll. That split
# is deliberate: the collection sits left of the deck, so "move this card over
# there" is naturally horizontal, and TID-454 made tile-started vertical drags
# scroll the grid on touch. Starting a card drag on any movement would take that
# back and leave the grid un-scrollable from a tile.
# -------------------------------------------------------------------------

const _DRAG_KIND := "inv_card"
const _WORKING_DECK_NAME := "this deck"
const _ESSENCE := Color(0.5, 0.85, 1.0)
const _GOLD := Color(1.0, 0.85, 0.3)

# Set to true by MenuHubScene before add_child() so the scene skips its own
# backdrop/panel and builds content directly into the hub's content area.
var hub_mode: bool = false

var _working_deck: Array[String] = []

var _collection_list: VBoxContainer
var _deck_list: VBoxContainer
var _collection_scroll: ScrollContainer
var _deck_scroll: ScrollContainer
var _deck_count_label: Label
var _wallet_label: Label
var _hint_label: Label

# Collection filters, search, sort (session-only state)
var _filter_class: String = ""    # "" = all, "minion", "spell"
var _filter_cost: String = ""     # "" = all, "low" (0-2), "mid" (3-5), "high" (6+)
var _filter_rarity: String = ""   # "" = all, "common", "rare", "epic", "legendary"
var _filter_btns: Array[Button] = []
var _query: String = ""
var _sort: String = "name"
var _sort_btn: Button

# Bulk select (GID-148): tap toggles selection instead of adding to the deck.
var _select_mode: bool = false
var _selected: Dictionary = {}    # uid -> true
var _select_btn: Button
var _bulk_bar: HBoxContainer
var _bulk_label: Label
var _bulk_sell_btn: Button
var _bulk_scrap_btn: Button

var _cards_panel: Control
var _tab_btns: Array[Button] = []
var _craft_panel: _CraftPanel
var _items_panel: _ItemsPanel

var _loadout_tab_row: HBoxContainer
var _loadout_action_row: HBoxContainer
var _rename_btn: Button
var _dup_btn: Button
var _del_btn: Button

## Where each in-flight press began, so _get_drag_data can tell a sideways drag
## from a scroll. Keyed by the control being pressed.
var _press_origin: Dictionary = {}

# -------------------------------------------------------------------------
# Instance detail popup (hover / tap-and-hold)
# -------------------------------------------------------------------------

var _detail_popup: PopupPanel = null

func _ready() -> void:
	super._ready()
	_working_deck.assign(SceneManager.save_manager.player_deck)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var is_portrait: bool = _vw < _vh
	var wrapper: VBoxContainer
	if hub_mode:
		var m: int = int(_ref * 0.010)
		var margin := _UiUtil.make_margin(m, m, m, m, self)
		# _and_offsets_: the plain preset sets anchors but leaves the offsets, so the
		# margin stays at its minimum size instead of filling the hub content area.
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrapper = _UiUtil.make_vbox(int(_ref * 0.008), margin)
	else:
		_build_backdrop(0.78)
		var panel_w: float = _vw * 0.95 if is_portrait else _vw * 0.86
		var panel_h: float = _vh * 0.92 if is_portrait else _vh * 0.86
		var outer := _build_centered_panel(panel_w, panel_h)
		wrapper = _build_margin_vbox(outer, 0.015, 0.008)

	# ---- Tab bar + wallet (bag / gold / essence, shared by every tab) ----
	var tab_bar := _UiUtil.make_hbox(int(_vw * 0.008), wrapper)
	var labels: Array[String] = ["Cards", "Craft", "Items"]
	_tab_btns = _UiUtil.make_tab_row(tab_bar, labels, Vector2(_ref * 0.13, _ref * 0.06), int(_ref * 0.022),
			_show_tab)
	_wallet_label = _UiUtil.make_label("", int(_ref * 0.021), Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_RIGHT,
			tab_bar)
	_wallet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not hub_mode:
		_UiUtil.make_button("Close  [I]" if not OS.has_feature("android") else "Close",
				Vector2(_ref * 0.14, _ref * 0.06), int(_ref * 0.020), _on_close, tab_bar)

	var scroll_min_h: float = _ref * 0.25 if is_portrait else 0.0

	# ====================================================================
	# CARDS PANEL
	# ====================================================================
	var root_box: BoxContainer
	if is_portrait:
		var vb := _UiUtil.make_vbox(int(_ref * 0.008))
		root_box = vb
	else:
		var hb := _UiUtil.make_hbox(int(_vw * 0.012))
		root_box = hb
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_panel = root_box
	wrapper.add_child(root_box)

	# ---- Collection panel (left) ----
	var left_vbox := _UiUtil.make_vbox(int(_ref * 0.005), root_box)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.6
	if is_portrait:
		left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_build_toolbar(_UiUtil.make_hbox(int(_ref * 0.006), left_vbox))

	# ---- Filter row ----
	var filter_row := _UiUtil.make_hbox(int(_ref * 0.005), left_vbox)
	_build_filter_buttons(filter_row)

	_hint_label = _UiUtil.make_label("", int(_ref * 0.016), Color(0.65, 0.65, 0.7), HORIZONTAL_ALIGNMENT_CENTER,
			left_vbox)

	# ---- Bulk action bar (select mode only) ----
	_bulk_bar = _UiUtil.make_hbox(int(_ref * 0.006), left_vbox)
	_bulk_label = _UiUtil.make_label("", int(_ref * 0.019), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, _bulk_bar)
	_bulk_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bulk_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bb := Vector2(_ref * 0.12, _ref * 0.052)
	var bfs: int = int(_ref * 0.018)
	var extras_btn := _UiUtil.make_button("Extras", bb, bfs, _on_select_extras, _bulk_bar)
	extras_btn.tooltip_text = ("Select spare copies: keeps your best copy of each card, and skips\n"
			+ "cards in any deck, renamed cards and veterans")
	_UiUtil.make_button("None", bb, bfs, _on_select_none, _bulk_bar)
	_bulk_sell_btn = _UiUtil.make_button("Sell", bb, bfs, _on_bulk_action.bind("sell"), _bulk_bar)
	_bulk_sell_btn.modulate = _GOLD
	_bulk_scrap_btn = _UiUtil.make_button("Scrap", bb, bfs, _on_bulk_action.bind("scrap"), _bulk_bar)
	_bulk_scrap_btn.modulate = _ESSENCE

	_collection_scroll = ScrollContainer.new()
	var left_scroll: ScrollContainer = _collection_scroll
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if scroll_min_h > 0.0:
		left_scroll.custom_minimum_size = Vector2(0.0, scroll_min_h)
	left_vbox.add_child(left_scroll)
	attach_drag_scroll(left_scroll)
	left_scroll.set_drag_forwarding(Callable(), _can_drop_into_collection, _drop_into_collection)

	_collection_list = _UiUtil.make_vbox(int(_ref * 0.008), left_scroll)
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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
	_loadout_tab_row = _UiUtil.make_hbox(int(_ref * 0.005), right_vbox)

	# ---- Loadout action row (Rename / Copy / Delete) ----
	_loadout_action_row = _UiUtil.make_hbox(int(_ref * 0.006), right_vbox)

	_rename_btn = _UiUtil.make_button("Rename", Vector2(_ref * 0.12, _ref * 0.055), int(_ref * 0.020),
			_on_rename_loadout, _loadout_action_row)

	_dup_btn = _UiUtil.make_button("Copy", Vector2(_ref * 0.10, _ref * 0.055), int(_ref * 0.020), _on_dup_loadout,
			_loadout_action_row)

	_del_btn = _UiUtil.make_button("Delete", Vector2(_ref * 0.12, _ref * 0.055), int(_ref * 0.020), _on_del_loadout,
			_loadout_action_row)
	_del_btn.modulate = Color(1.0, 0.4, 0.4)

	var count_row := _UiUtil.make_hbox(int(_ref * 0.008), right_vbox)
	_deck_count_label = _UiUtil.make_label("", int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, count_row)
	_deck_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_UiUtil.make_button("Auto-Fill", Vector2(_ref * 0.14, _ref * 0.052), int(_ref * 0.019), _on_auto_fill, count_row)
	_UiUtil.make_button("Save Deck", Vector2(_ref * 0.15, _ref * 0.052), int(_ref * 0.019), _on_save, count_row)

	_deck_scroll = ScrollContainer.new()
	var right_scroll: ScrollContainer = _deck_scroll
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if scroll_min_h > 0.0:
		right_scroll.custom_minimum_size = Vector2(0.0, scroll_min_h)
	right_vbox.add_child(right_scroll)
	attach_drag_scroll(right_scroll)
	right_scroll.set_drag_forwarding(Callable(), _can_drop_into_deck, _drop_into_deck)

	_deck_list = _UiUtil.make_vbox(int(_ref * 0.008), right_scroll)
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# ====================================================================
	# CRAFT + ITEMS PANELS
	# ====================================================================
	_craft_panel = _CraftPanel.new()
	_craft_panel.visible = false
	wrapper.add_child(_craft_panel)
	_craft_panel.setup(_ref)
	_craft_panel.crafted.connect(_refresh_wallet)

	_items_panel = _ItemsPanel.new()
	_items_panel.visible = false
	wrapper.add_child(_items_panel)
	_items_panel.setup(_ref)

## Search box, sort cycle and the Select toggle above the bag grid.
func _build_toolbar(row: HBoxContainer) -> void:
	var h: float = _ref * 0.052
	var search := LineEdit.new()
	search.placeholder_text = "Search name or text…"
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size = Vector2(_ref * 0.16, h)
	search.add_theme_font_size_override("font_size", int(_ref * 0.019))
	search.text_changed.connect(func(t: String) -> void:
		_query = t
		_refresh_cards())
	row.add_child(search)
	_sort_btn = _UiUtil.make_button("", Vector2(_ref * 0.17, h), int(_ref * 0.018), _on_cycle_sort, row)
	_sort_btn.tooltip_text = "Change the bag's sort order"
	_select_btn = _UiUtil.make_button("", Vector2(_ref * 0.13, h), int(_ref * 0.018), _on_toggle_select, row)
	_select_btn.tooltip_text = "Pick several cards to sell or scrap at once"

# -------------------------------------------------------------------------
# Refresh
# -------------------------------------------------------------------------

func _refresh() -> void:
	_refresh_cards()
	if _craft_panel.visible:
		_craft_panel.refresh()
	if _items_panel.visible:
		_items_panel.refresh()

func _rebuild_loadout_bar() -> void:
	var sm := SceneManager.save_manager
	for child in _loadout_tab_row.get_children():
		child.queue_free()

	var names: Array[String] = sm.decks.get_loadout_names()
	var active_idx: int = sm.active_loadout
	var at_cap: bool = names.size() >= sm.MAX_LOADOUTS

	for i in range(names.size()):
		var tab_btn := _UiUtil.make_button(names[i], Vector2(_ref * 0.12, _ref * 0.055), int(_ref * 0.020))
		tab_btn.flat = true
		var is_valid: bool
		if i == active_idx:
			is_valid = _working_deck.size() >= IsoConst.DECK_MIN and _working_deck.size() <= IsoConst.DECK_MAX
		else:
			is_valid = sm.decks.is_loadout_valid(i)
		if i == active_idx:
			tab_btn.modulate = Color.WHITE if is_valid else Color(1.0, 0.35, 0.35)
		else:
			tab_btn.modulate = Color(0.7, 0.7, 0.7) if is_valid else Color(0.75, 0.28, 0.28)
		tab_btn.pressed.connect(_on_loadout_tab.bind(i))
		_loadout_tab_row.add_child(tab_btn)

	var new_btn := _UiUtil.make_button("+", Vector2(_ref * 0.055, _ref * 0.055), int(_ref * 0.025), _on_new_loadout,
			_loadout_tab_row)
	new_btn.disabled = at_cap

	_del_btn.disabled = names.size() <= 1
	_dup_btn.disabled = at_cap

func _refresh_wallet() -> void:
	var sm := SceneManager.save_manager
	var used: int = sm.get_slot_count(_working_deck)
	var cap: int = sm.bag_size
	_wallet_label.text = "Bag %d/%d    %d gold    %d essence" % [used, cap, sm.coins, sm.essence]
	_wallet_label.modulate = Color(1.0, 0.45, 0.45) if used >= cap else Color.WHITE

func _template(tid: String) -> Dictionary:
	return CardRegistry.get_template_for_face(tid, "dark" if CardRegistry.is_dark_aligned() else "light")

## uid -> deck name for every card sitting in a deck (saved loadouts + the
## working deck). Those cards are shown tagged and can't be bulk-selected.
func _deck_membership() -> Dictionary:
	var sm := SceneManager.save_manager
	return BagOps.deck_membership(sm.loadouts, _working_deck, sm.active_loadout, _WORKING_DECK_NAME)

func _is_selectable(inst: Dictionary, membership: Dictionary) -> bool:
	return not membership.has(str(inst.get("uid", ""))) \
		and not bool(_template(str(inst.get("template_id", ""))).get("is_unique", false))

func _refresh_cards() -> void:
	_rebuild_loadout_bar()
	_refresh_wallet()
	var col_scroll: int = _collection_scroll.scroll_vertical if _collection_scroll else 0
	var deck_scroll: int = _deck_scroll.scroll_vertical if _deck_scroll else 0
	for child in _collection_list.get_children():
		child.queue_free()
	for child in _deck_list.get_children():
		child.queue_free()

	var sm := SceneManager.save_manager
	var membership: Dictionary = _deck_membership()

	# Every instance has its own rolled stats, so each takes its own tile/row.
	var avail: Array[Dictionary] = []
	var deck_insts: Array[Dictionary] = []
	var bag_total: int = 0
	for inst: Dictionary in sm.get_owned_instances():
		var uid: String    = str(inst.get("uid", ""))
		var tid: String    = str(inst.get("template_id", ""))
		if tid == "":
			continue
		if _working_deck.has(uid):
			deck_insts.append(inst)
			continue
		bag_total += 1
		if _passes_filter(tid, str(inst.get("rarity", "common"))) and BagOps.matches_search(_template(tid), _query):
			avail.append(inst)

	# Drop selections that no longer point at a pickable card.
	for uid: String in _selected.keys():
		var inst: Dictionary = sm.get_instance_by_uid(uid)
		if inst.is_empty() or not _is_selectable(inst, membership):
			_selected.erase(uid)

	# ---- Backpack grid ----
	if not avail.is_empty():
		BagOps.sort_instances(avail, _sort, _template)
		var grid := HFlowContainer.new()
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", int(_ref * 0.008))
		grid.add_theme_constant_override("v_separation", int(_ref * 0.008))
		_collection_list.add_child(grid)
		for inst: Dictionary in avail:
			grid.add_child(_make_card_tile(inst, membership))
	else:
		var msg: String = "Your bag is empty — cards not in a deck live here" if bag_total == 0 \
				else "No cards match the search / filters"
		_UiUtil.make_label(msg, int(_ref * 0.020), Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, _collection_list)

	# ---- Deck list ----
	if not deck_insts.is_empty():
		BagOps.sort_instances(deck_insts, "cost", _template)
		for inst: Dictionary in deck_insts:
			_deck_list.add_child(_make_deck_row_instance(str(inst.get("uid", "")), inst))

	var deck_sz: int = _working_deck.size()
	_deck_count_label.text = "Deck  %d / %d" % [deck_sz, IsoConst.DECK_MAX]
	if deck_sz < IsoConst.DECK_MIN or deck_sz > IsoConst.DECK_MAX:
		_deck_count_label.modulate = Color.RED
	else:
		_deck_count_label.modulate = Color.WHITE
	_refresh_toolbar()
	if _collection_scroll and col_scroll > 0:
		_collection_scroll.scroll_vertical = col_scroll
	if _deck_scroll and deck_scroll > 0:
		_deck_scroll.scroll_vertical = deck_scroll

func _refresh_toolbar() -> void:
	_sort_btn.text = "Sort: %s" % str(BagOps.SORT_LABELS.get(_sort, _sort))
	_select_btn.text = "Done" if _select_mode else "Select"
	_select_btn.modulate = Color(0.55, 1.0, 0.6) if _select_mode else Color.WHITE
	_bulk_bar.visible = _select_mode
	if _select_mode:
		_hint_label.text = "Tap cards to select them  ·  Extras = spare copies"
	elif OS.has_feature("android"):
		_hint_label.text = "Tap: add to deck  ·  Hold: details  ·  Swipe sideways: drag"
	else:
		_hint_label.text = "Click: add to deck  ·  Right-click / hold: details  ·  Drag sideways into the deck"
	var picked: Array[Dictionary] = _selected_instances()
	var value: Dictionary = BagOps.bulk_value(picked)
	_bulk_label.text = "%d selected" % picked.size()
	_bulk_sell_btn.text = "Sell +%dg" % int(value.get("gold", 0))
	_bulk_scrap_btn.text = "Scrap +%de" % int(value.get("essence", 0))
	_bulk_sell_btn.disabled = picked.is_empty()
	_bulk_scrap_btn.disabled = picked.is_empty()

func _selected_instances() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for uid: String in _selected:
		var inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(uid)
		if not inst.is_empty():
			out.append(inst)
	return out

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
		var btn := _UiUtil.make_button(lbl_text, Vector2(0.0, btn_h), int(btn_fs), Callable(), row)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_filter_btn.bind(kind, val, btn))
		_filter_btns.append(btn)
	_update_filter_visuals()

func _on_filter_btn(kind: String, val: String, _btn: Button) -> void:
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

# Card-face tile per owned instance (CardTile). Right-click (desktop) or
# tap-and-hold (mobile) opens the detail popup with rolled stats + actions.
# A plain tap adds the card to the working deck — or toggles it in select mode.
func _make_card_tile(inst: Dictionary, membership: Dictionary) -> Control:
	var uid: String    = str(inst.get("uid", ""))
	var tid: String    = str(inst.get("template_id", ""))
	var tmpl: Dictionary  = _template(tid)
	var card_color: Color = tmpl.get("color", Color(0.3, 0.3, 0.35))
	var tag: String = "In %s" % str(membership[uid]) if membership.has(uid) else ""
	var selectable: bool = _is_selectable(inst, membership)
	var cube := _CardTile.build(inst, tmpl, _ref, tag, _selected.has(uid), _select_mode and not selectable)

	# Scroll-safe tap (GID-120 / TID-454): a scroll gesture ending on a tile must
	# not silently edit the working deck; a tile-started drag scrolls the grid.
	var on_tap: Callable = func() -> void:
		if _select_mode:
			_toggle_selected(uid, selectable)
		else:
			_on_add_by_uid(uid)
	_UiUtil.bind_scroll_safe_press(cube, on_tap, _collection_scroll)

	_make_card_draggable(cube, uid, false, card_color)

	var lpd := LongPressDetector.new()
	cube.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_instance_detail(inst, cube))

	# Right-click is the quick desktop path to the same detail panel that
	# long-press opens on touch. Hover used to open it and mouse_exited used to
	# close it, which made the Sell/Scrap buttons impossible to reach: the panel
	# opened over the tile, so moving the pointer towards a button left the tile
	# and destroyed the panel under the cursor.
	cube.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb: InputEventMouseButton = ev
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				_show_instance_detail(inst, cube)
				cube.accept_event())

	return cube

func _make_card_draggable(ctrl: Button, uid: String, in_deck: bool, tint: Color) -> void:
	ctrl.button_down.connect(func() -> void:
		_press_origin[ctrl] = ctrl.get_local_mouse_position())
	ctrl.set_drag_forwarding(
		func(at: Vector2) -> Variant: return _drag_card(ctrl, at, uid, in_deck, tint),
		Callable(), Callable())

func _drag_card(ctrl: Control, at: Vector2, uid: String, in_deck: bool, tint: Color) -> Variant:
	var origin: Vector2 = _press_origin.get(ctrl, at)
	var delta: Vector2 = at - origin
	if absf(delta.y) > absf(delta.x):
		return null   # vertical gesture — let the ScrollContainer have it
	_hide_instance_detail()
	# set_drag_preview needs a live viewport; skip it out of tree so the rules
	# above stay unit-testable without standing up the whole panel.
	if ctrl.is_inside_tree():
		var preview := ColorRect.new()
		preview.color = Color(tint.r, tint.g, tint.b, 0.85)
		preview.custom_minimum_size = Vector2(_ref * 0.08, _ref * 0.08)
		preview.size = preview.custom_minimum_size
		var holder := Control.new()
		holder.add_child(preview)
		preview.position = -preview.size * 0.5
		ctrl.set_drag_preview(holder)
	return {"kind": _DRAG_KIND, "uid": uid, "from_deck": in_deck}

func _is_card_drag(data: Variant, from_deck: bool) -> bool:
	return data is Dictionary \
		and str((data as Dictionary).get("kind", "")) == _DRAG_KIND \
		and bool((data as Dictionary).get("from_deck", false)) == from_deck

## Drop onto the deck side: only accepts a card coming from the collection.
func _can_drop_into_deck(_at: Vector2, data: Variant) -> bool:
	return _is_card_drag(data, false)

func _drop_into_deck(_at: Vector2, data: Variant) -> void:
	_on_add_by_uid(str((data as Dictionary).get("uid", "")))

## Drop onto the collection side: only accepts a card coming from the deck.
func _can_drop_into_collection(_at: Vector2, data: Variant) -> bool:
	return _is_card_drag(data, true)

func _drop_into_collection(_at: Vector2, data: Variant) -> void:
	_on_remove_by_uid(str((data as Dictionary).get("uid", "")))

func _hide_instance_detail() -> void:
	if _detail_popup != null and is_instance_valid(_detail_popup):
		_detail_popup.queue_free()
	_detail_popup = null


func _show_instance_detail(inst: Dictionary, anchor: Control) -> void:
	_hide_instance_detail()

	var uid: String    = str(inst.get("uid", ""))
	var tid: String    = str(inst.get("template_id", ""))
	var rarity: String = str(inst.get("rarity", "common"))
	var tmpl: Dictionary  = _template(tid)
	var disp_name: String = VeterancyUtil.display_name(inst, str(tmpl.get("name", tid)))
	var is_dual: bool = str(tmpl.get("dual_card_id", "")) != ""
	var is_spell: bool = str(tmpl.get("card_class", "minion")) == "spell"
	var membership: Dictionary = _deck_membership()

	var popup := PopupPanel.new()
	add_child(popup)
	_detail_popup = popup

	var vb := _UiUtil.make_vbox(int(_ref * 0.008), popup)
	vb.custom_minimum_size = Vector2(_ref * 0.36, 0)

	var title_row := _UiUtil.make_hbox(int(_ref * 0.006), vb)
	var name_lbl := _UiUtil.make_label(disp_name + (" ◑" if is_dual else ""), int(_ref * 0.024), Color.WHITE,
			HORIZONTAL_ALIGNMENT_LEFT, title_row)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_UiUtil.make_label(rarity.capitalize(), int(_ref * 0.020), _UiUtil.rarity_color(rarity),
			HORIZONTAL_ALIGNMENT_RIGHT, title_row)

	var kind: String = "Spell" if is_spell else "Minion  ⚔ %d  ♥ %d" % [int(inst.get("attack", 0)),
			int(inst.get("health", 0))]
	_UiUtil.make_label("%d mana  ·  %s" % [int(inst.get("cost", 0)), kind], int(_ref * 0.021),
			_UiUtil.rarity_color(rarity).lerp(Color(0.85, 0.85, 0.85), 0.55), HORIZONTAL_ALIGNMENT_LEFT, vb)

	var desc := _UiUtil.make_label(str(tmpl.get("description", "")), int(_ref * 0.019), Color(0.8, 0.8, 0.8),
			HORIZONTAL_ALIGNMENT_LEFT, vb)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var kills: int = int(inst.get("kills", 0))
	var survived: int = int(inst.get("battles_survived", 0))
	if kills > 0 or survived > 0:
		_UiUtil.make_label("%d kills  ·  %d battles survived" % [kills, survived], int(_ref * 0.017),
				Color(1.0, 0.82, 0.2), HORIZONTAL_ALIGNMENT_LEFT, vb)
	if membership.has(uid):
		var warn := _UiUtil.make_label("In %s — selling or scrapping removes it from that deck."
				% str(membership[uid]), int(_ref * 0.017), Color(1.0, 0.7, 0.4), HORIZONTAL_ALIGNMENT_LEFT, vb)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var top_row := _UiUtil.make_hbox(int(_ref * 0.006), vb)
	var add_btn := _UiUtil.make_button("Add to Deck", Vector2(_ref * 0.17, _ref * 0.058), int(_ref * 0.019),
			_on_add_by_uid.bind(uid), top_row)
	add_btn.disabled = _working_deck.size() >= IsoConst.DECK_MAX
	_UiUtil.make_button("Inspect", Vector2(_ref * 0.14, _ref * 0.058), int(_ref * 0.019), func() -> void:
		_hide_instance_detail()
		_show_inspect(tid), top_row)

	if not bool(tmpl.get("is_unique", false)):
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
		var action_row := _UiUtil.make_hbox(int(_ref * 0.006), vb)
		var sell_btn := _UiUtil.make_button("Sell +%dg" % int(cfg.get("sell_gold", 0)),
				Vector2(_ref * 0.155, _ref * 0.058), int(_ref * 0.019), _detail_action.bind(uid, "sell"), action_row)
		sell_btn.modulate = _GOLD
		var scrap_btn := _UiUtil.make_button("Scrap +%de" % int(cfg.get("scrap_essence", 0)),
				Vector2(_ref * 0.155, _ref * 0.058), int(_ref * 0.019), _detail_action.bind(uid, "scrap"), action_row)
		scrap_btn.modulate = _ESSENCE

		# Combine 3× same template+rarity → next tier (not for legendaries).
		var next_idx: int = IsoConst.RARITY_ORDER.find(rarity) + 1
		if next_idx > 0 and next_idx < IsoConst.RARITY_ORDER.size():
			var avail_count: int = 0
			for other: Dictionary in SceneManager.save_manager.get_owned_instances():
				if str(other.get("template_id", "")) == tid and str(other.get("rarity", "")) == rarity \
						and not SceneManager.save_manager.player_deck.has(str(other.get("uid", ""))) \
						and not _working_deck.has(str(other.get("uid", ""))):
					avail_count += 1
			var next_rarity: String = IsoConst.RARITY_ORDER[next_idx]
			var combine_btn := _UiUtil.make_button("Combine 3 → %s  (%d/3)" % [next_rarity.capitalize(),
					mini(avail_count, 3)], Vector2(_ref * 0.3, _ref * 0.058), int(_ref * 0.019), func() -> void:
				SceneManager.save_manager.combine_cards(tid, rarity)
				_prune_working_deck()
				_hide_instance_detail()
				_refresh_cards(), vb)
			combine_btn.modulate = _UiUtil.rarity_color(next_rarity)
			combine_btn.disabled = avail_count < 3
			combine_btn.tooltip_text = "Merge three spare %s copies into one %s" % [rarity, next_rarity]

		var rename_row := _UiUtil.make_hbox(int(_ref * 0.006), vb)
		var rename_edit := LineEdit.new()
		rename_edit.text = str(inst.get("custom_name", ""))
		rename_edit.placeholder_text = disp_name
		rename_edit.max_length = 24
		rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rename_edit.custom_minimum_size = Vector2(0, _ref * 0.058)
		rename_edit.add_theme_font_size_override("font_size", int(_ref * 0.019))
		rename_row.add_child(rename_edit)
		_UiUtil.make_button("Rename", Vector2(_ref * 0.12, _ref * 0.058), int(_ref * 0.019), func() -> void:
			SceneManager.save_manager.set_card_custom_name(uid, rename_edit.text)
			_hide_instance_detail()
			_refresh_cards(), rename_row)

	var close_btn := _UiUtil.make_button("Close", Vector2(_ref * 0.12, _ref * 0.052), int(_ref * 0.019),
		_hide_instance_detail, vb)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Beside the tile, not over it — the panel has buttons the player has to be
	# able to travel to without crossing back out of it. Clamped so a tile near
	# the right or bottom edge does not push the panel off screen.
	# Width from the content too: the combine / rename rows can be wider than the
	# nominal width, and a popup that grows past it would overlap the tile.
	var chrome: Vector2 = popup.get_theme_stylebox("panel").get_minimum_size()
	var w: int = ceili(maxf(_ref * 0.36, vb.get_combined_minimum_size().x + chrome.x))
	var tile_rect: Rect2 = anchor.get_screen_transform() * Rect2(Vector2.ZERO, anchor.size)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var px: float = tile_rect.end.x + _ref * 0.01
	if px + float(w) > screen.x:
		px = tile_rect.position.x - float(w) - _ref * 0.01
	# Height comes from the content's own minimum size: Window.size still reads 0
	# on this frame and even a deferred read lands before the popup lays out, so
	# clamping afterwards never actually moved it. Without this, a card low in
	# the grid opens a panel whose Sell/Scrap row sits below the screen edge.
	var content_h: float = vb.get_combined_minimum_size().y + chrome.y + _ref * 0.02
	var py: float = clampf(tile_rect.position.y, 0.0, maxf(0.0, screen.y - content_h))
	popup.popup(Rect2i(Vector2i(int(maxf(px, 0.0)), int(py)), Vector2i(w, 0)))
	# popup() may grow the window to its content and nudge it left; pin the
	# left edge back beside the tile.
	if px > tile_rect.position.x and px + float(popup.size.x) > screen.x:
		px = tile_rect.position.x - float(popup.size.x) - _ref * 0.01
	popup.position.x = int(maxf(px, 0.0))

func _detail_action(uid: String, action: String) -> void:
	if action == "sell":
		SceneManager.save_manager.sell_card_instance(uid)
	else:
		SceneManager.save_manager.scrap_card_instance(uid)
	_selected.erase(uid)
	_hide_instance_detail()
	_refresh_cards()

# -------------------------------------------------------------------------
# Sort + bulk select
# -------------------------------------------------------------------------

func _on_cycle_sort() -> void:
	_sort = BagOps.next_sort(_sort)
	_refresh_cards()

func _on_toggle_select() -> void:
	_select_mode = not _select_mode
	if not _select_mode:
		_selected.clear()
	_refresh_cards()

func _toggle_selected(uid: String, selectable: bool) -> void:
	if not selectable:
		GameBus.hud_message_requested.emit("That card is in a deck or can't be sold")
		return
	if _selected.has(uid):
		_selected.erase(uid)
	else:
		_selected[uid] = true
	_refresh_cards()

func _on_select_none() -> void:
	_selected.clear()
	_refresh_cards()

func _on_select_extras() -> void:
	var sm := SceneManager.save_manager
	var picks: Array[String] = BagOps.pick_extras(sm.get_owned_instances(), _deck_membership(), _template)
	_selected.clear()
	for uid: String in picks:
		_selected[uid] = true
	if picks.is_empty():
		GameBus.hud_message_requested.emit("No spare copies — you only hold your best copy of each card")
	_refresh_cards()

## Confirms, then sells or scraps every selected card in one go.
func _on_bulk_action(action: String) -> void:
	var picked: Array[Dictionary] = _selected_instances()
	if picked.is_empty():
		return
	var value: Dictionary = BagOps.bulk_value(picked)
	var reward: String = "+%d gold" % int(value.get("gold", 0)) if action == "sell" \
			else "+%d essence" % int(value.get("essence", 0))
	var by_rarity: Dictionary = {}
	for inst: Dictionary in picked:
		var r: String = str(inst.get("rarity", "common"))
		by_rarity[r] = int(by_rarity.get(r, 0)) + 1
	var parts: Array[String] = []
	for r: String in IsoConst.RARITY_ORDER:
		if by_rarity.has(r):
			parts.append("%d %s" % [int(by_rarity[r]), r])

	var popup := PopupPanel.new()
	add_child(popup)
	var vb := _UiUtil.make_vbox(int(_ref * 0.012), popup)
	vb.custom_minimum_size = Vector2(_ref * 0.5, 0)
	var lbl := _UiUtil.make_label("%s %d cards (%s) for %s?" % [action.capitalize(), picked.size(), ", ".join(parts),
			reward], int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vb)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn_row := _UiUtil.make_hbox(int(_ref * 0.012), vb)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := _UiUtil.make_button(action.capitalize(), Vector2(_ref * 0.14, _ref * 0.065), int(_ref * 0.022),
			func() -> void:
				popup.queue_free()
				_apply_bulk(action), btn_row)
	yes.modulate = _GOLD if action == "sell" else _ESSENCE
	_UiUtil.make_button("Cancel", Vector2(_ref * 0.14, _ref * 0.065), int(_ref * 0.022),
			func() -> void: popup.queue_free(), btn_row)
	popup.popup_centered()

func _apply_bulk(action: String) -> void:
	var sm := SceneManager.save_manager
	var membership: Dictionary = _deck_membership()
	for inst: Dictionary in _selected_instances():
		# Re-check at apply time: a deck edit since selecting must not be undone by a sale.
		if not _is_selectable(inst, membership):
			continue
		var uid: String = str(inst.get("uid", ""))
		if action == "sell":
			sm.sell_card_instance(uid)
		else:
			sm.scrap_card_instance(uid)
	_selected.clear()
	_select_mode = false
	_refresh_cards()

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

	var vbox := _UiUtil.make_vbox(int(_ref * 0.003))

	var top_row := _UiUtil.make_hbox(int(_vw * 0.008), vbox)

	var swatch_btn := Button.new()
	swatch_btn.custom_minimum_size = Vector2(_ref * 0.03, _ref * 0.03)
	swatch_btn.focus_mode = Control.FOCUS_NONE
	swatch_btn.tooltip_text = "Drag sideways to remove from the deck"
	var swatch_sb := _UiUtil.make_style(card_color, int(_ref * 0.004))
	for st: String in ["normal", "hover", "pressed", "focus"]:
		swatch_btn.add_theme_stylebox_override(st, swatch_sb)
	top_row.add_child(swatch_btn)

	var name_lbl := _UiUtil.make_label(disp_name, int(_ref * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, top_row)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if rank > 0:
		var chev_lbl := _UiUtil.make_label(VeterancyUtil.rank_chevrons(rank), int(_ref * 0.018), Color(1.0, 0.82, 0.2),
				HORIZONTAL_ALIGNMENT_LEFT, top_row)
	if is_dual:
		var dual_badge := _UiUtil.make_label("◑", int(_ref * 0.022))
		dual_badge.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		dual_badge.tooltip_text = "Dual-faced card"
		top_row.add_child(dual_badge)

	var badge_lbl := _UiUtil.make_label(_UiUtil.rarity_badge(rarity), int(_ref * 0.022), _UiUtil.rarity_color(rarity),
			HORIZONTAL_ALIGNMENT_LEFT, top_row)

	var rm_btn := _UiUtil.make_button("−", Vector2(_ref * 0.065, _ref * 0.065), int(_ref * 0.022))
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

	var stats_lbl := _UiUtil.make_label("Cost %d  ATK %d  HP %d" % [rolled_cost, rolled_atk, rolled_hp],
			int(_ref * 0.022), _UiUtil.rarity_color(rarity).lerp(Color(0.75, 0.75, 0.75), 0.55),
			HORIZONTAL_ALIGNMENT_LEFT, vbox)

	# The row is a plain VBox, not a Button, so it has no button_down to record a
	# press origin — drag it from the swatch, which is the card's colour chip and
	# the natural grab handle.
	_make_card_draggable(swatch_btn, uid, true, card_color)

	var lpd := LongPressDetector.new()
	vbox.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_inspect(tid))

	return vbox


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
## Drops working-deck uids that no longer exist (combine can consume a copy
## that is in the unsaved working deck but not the committed one).
func _prune_working_deck() -> void:
	var sm := SceneManager.save_manager
	var kept: Array[String] = []
	for uid: String in _working_deck:
		if not sm.get_instance_by_uid(uid).is_empty():
			kept.append(uid)
	_working_deck = kept

# -------------------------------------------------------------------------
# Tabs
# -------------------------------------------------------------------------

## 0 = Cards, 1 = Craft, 2 = Items.
func _show_tab(index: int) -> void:
	_hide_instance_detail()
	_cards_panel.visible = index == 0
	_craft_panel.visible = index == 1
	_items_panel.visible = index == 2
	_refresh()

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
	sm.decks.set_active_loadout(index)
	_working_deck.assign(sm.player_deck)
	_refresh_cards()

func _on_new_loadout() -> void:
	var sm := SceneManager.save_manager
	sm.set_active_deck(_working_deck)
	var new_idx: int = sm.decks.add_loadout("Deck %d" % (sm.loadouts.size() + 1))
	if new_idx < 0:
		return
	sm.decks.set_active_loadout(new_idx)
	_working_deck.assign(sm.player_deck)
	_refresh_cards()

func _on_rename_loadout() -> void:
	var sm := SceneManager.save_manager
	if sm.active_loadout < 0 or sm.active_loadout >= sm.loadouts.size():
		return
	var current_name: String = str(sm.loadouts[sm.active_loadout].get("name", ""))

	var popup := PopupPanel.new()
	add_child(popup)

	var vb := _UiUtil.make_vbox(int(_ref * 0.012), popup)
	vb.custom_minimum_size = Vector2(_ref * 0.5, 0)

	var title_lbl := _UiUtil.make_label("Rename Loadout", int(_ref * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER,
			vb)

	var edit := LineEdit.new()
	edit.text = current_name
	edit.max_length = 20
	edit.add_theme_font_size_override("font_size", int(_ref * 0.024))
	edit.custom_minimum_size = Vector2(0, _ref * 0.065)
	vb.add_child(edit)

	var btn_row := _UiUtil.make_hbox(int(_ref * 0.012), vb)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var ok_btn := _UiUtil.make_button("OK", Vector2(_ref * 0.12, _ref * 0.065), int(_ref * 0.022))
	ok_btn.pressed.connect(func() -> void:
		var new_name: String = edit.text.strip_edges()
		if new_name.length() > 0:
			sm.decks.rename_loadout(sm.active_loadout, new_name)
			_refresh_cards()
		popup.queue_free())
	btn_row.add_child(ok_btn)

	var cancel_btn := _UiUtil.make_button("Cancel", Vector2(_ref * 0.12, _ref * 0.065), int(_ref * 0.022),
			func() -> void: popup.queue_free(), btn_row)

	popup.popup_centered()
	# Shift to top half so the Android keyboard doesn't cover the input field.
	popup.position.y = int(get_viewport_rect().size.y * 0.08)
	edit.grab_focus()
	edit.select_all()

func _on_dup_loadout() -> void:
	var sm := SceneManager.save_manager
	sm.set_active_deck(_working_deck)
	var new_idx: int = sm.decks.duplicate_loadout(sm.active_loadout)
	if new_idx < 0:
		return
	sm.decks.set_active_loadout(new_idx)
	_working_deck.assign(sm.player_deck)
	_refresh_cards()

func _on_del_loadout() -> void:
	var sm := SceneManager.save_manager
	if sm.loadouts.size() <= 1:
		return
	var loadout_name: String = str(sm.loadouts[sm.active_loadout].get("name", "this loadout"))

	var popup := PopupPanel.new()
	add_child(popup)

	var vb := _UiUtil.make_vbox(int(_ref * 0.012), popup)
	vb.custom_minimum_size = Vector2(_ref * 0.5, 0)

	var lbl := _UiUtil.make_label("Delete '%s'?\nThis cannot be undone." % loadout_name, int(_ref * 0.022), Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, vb)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var btn_row := _UiUtil.make_hbox(int(_ref * 0.012), vb)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var yes_btn := _UiUtil.make_button("Yes, Delete", Vector2(_ref * 0.16, _ref * 0.065), int(_ref * 0.022))
	yes_btn.modulate = Color(1.0, 0.4, 0.4)
	yes_btn.pressed.connect(func() -> void:
		popup.queue_free()
		sm.decks.delete_loadout(sm.active_loadout)
		_working_deck.assign(sm.player_deck)
		_refresh_cards())
	btn_row.add_child(yes_btn)

	var no_btn := _UiUtil.make_button("Cancel", Vector2(_ref * 0.14, _ref * 0.065), int(_ref * 0.022),
			func() -> void: popup.queue_free(), btn_row)

	popup.popup_centered()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_on_close()
