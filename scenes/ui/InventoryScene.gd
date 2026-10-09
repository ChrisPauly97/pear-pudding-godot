# gdlint: disable=max-file-lines
# BID-053 lint debt: oversized script. Shrink it by extraction; don't add to it.
extends "res://scenes/ui/CardBrowserOverlay.gd"

const CardRegistry      = preload("res://autoloads/CardRegistry.gd")
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")
const VeterancyUtil     = preload("res://game_logic/VeterancyUtil.gd")
const BagOps            = preload("res://game_logic/inventory/BagOps.gd")
const _CardTile         = preload("res://scenes/ui/inventory/CardTile.gd")
const _TileCache        = preload("res://scenes/ui/inventory/TileCache.gd")
const _CraftPanel       = preload("res://scenes/ui/inventory/CraftPanel.gd")
const _ItemsPanel       = preload("res://scenes/ui/inventory/ItemsPanel.gd")
const _DeckPile         = preload("res://scenes/ui/inventory/DeckPile.gd")
const _DeckUndo         = preload("res://game_logic/inventory/DeckUndo.gd")
const _CardJuice        = preload("res://scenes/ui/inventory/CardJuice.gd")
const _BagFilters       = preload("res://scenes/ui/inventory/BagFilters.gd")
const BinderOps         = preload("res://game_logic/inventory/BinderOps.gd")
const DeckInsights      = preload("res://game_logic/inventory/DeckInsights.gd")
const _TestHandOverlay  = preload("res://scenes/ui/inventory/TestHandOverlay.gd")
const _CombatOnboarding = preload("res://game_logic/battle/CombatOnboarding.gd")
const _ForgeFx          = preload("res://scenes/ui/inventory/ForgeFx.gd")
const _CombineRitual    = preload("res://scenes/ui/inventory/CombineRitual.gd")
const _LoadoutBar       = preload("res://scenes/ui/inventory/LoadoutBar.gd")
const _CompareTip       = preload("res://scenes/ui/inventory/CompareTip.gd")
const _Satchel          = preload("res://scenes/ui/inventory/Satchel.gd")
const DeckBarkRules     = preload("res://game_logic/inventory/DeckBarkRules.gd")
const _UnlockLadder     = preload("res://game_logic/progression/UnlockLadder.gd")

const DeckAutoFill = preload("res://game_logic/DeckAutoFill.gd")
const _TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")

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
var _collection_scroll: ScrollContainer
## Deck side of the table (GID-180). Every edit auto-saves; `_undo` reverts.
var _pile: _DeckPile
var _undo: _DeckUndo = _DeckUndo.new()
var _filter_row: HBoxContainer
var _filter_toggle: Button
var _wallet_label: Label
var _satchel: _Satchel
var _bark_last_id: String = ""
var _bark_last_ms: int = -100000
var _hint_label: Label

# Collection filters + binder page, search, sort (session-only state)
var _filters: _BagFilters = _BagFilters.new()
## Binder stack being browsed copy by copy ("" = stacked view). GID-180 / TID-739.
var _expand_key: String = ""
var _page_label: Label
var _compare_tip: _CompareTip = null
var _query: String = ""
var _tiles: _TileCache = _TileCache.new()  # reused bag tiles (GID-164 / TID-684)
var _search_timer: Timer = null  # search refresh waits for typing to pause
var _sort: String = "name"
var _sort_btn: Button

# Bulk select (GID-148): tap toggles selection instead of adding to the deck.
var _select_mode: bool = false
var _selected: Dictionary = {}    # uid -> true
var _select_btn: Button
var _bulk_bar: HBoxContainer
var _bulk_label: Label
var _bulk_flag_btn: Button
var _forge: PanelContainer
var _bulk_scrap_btn: Button

var _cards_panel: Control
var _tab_btns: Array[Button] = []
var _craft_panel: _CraftPanel
var _items_panel: _ItemsPanel

var _loadouts: _LoadoutBar

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
	_maybe_bark.call_deferred()

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
	_satchel = _Satchel.new()
	tab_bar.add_child(_satchel)
	_satchel.setup(_ref)
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

	# ---- Filter row (folded behind the toolbar's Filters toggle) ----
	_filter_row = _UiUtil.make_hbox(int(_ref * 0.005), left_vbox)
	_filter_row.visible = false
	_filters.build(_filter_row, _ref, _refresh)

	# ---- Binder pages (one per magic type) ----
	var page_row := _UiUtil.make_hbox(int(_ref * 0.005), left_vbox)
	var page_names: Array[String] = []
	for pg: String in BinderOps.PAGES:
		page_names.append(BinderOps.page_label(pg))
	_UiUtil.make_tab_row(page_row, page_names, Vector2(_ref * 0.1, _ref * 0.046), int(_ref * 0.017),
			func(i: int) -> void:
				_filters.page = BinderOps.PAGES[i]
				_expand_key = ""
				_refresh_cards())
	_page_label = _UiUtil.make_label("", int(_ref * 0.017), Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_RIGHT,
			page_row)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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
	_bulk_flag_btn = _UiUtil.make_button("For sale", bb, bfs, _apply_bulk.bind("flag"), _bulk_bar)
	_bulk_flag_btn.modulate = _GOLD
	_bulk_flag_btn.tooltip_text = "Flag for sale — vendors buy flagged cards in one go"
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

	# ---- Forge: drop a bag card here to scrap it for essence (GID-180 / TID-742) ----
	_forge = PanelContainer.new()
	_forge.custom_minimum_size = Vector2(0.0, _ref * 0.06)
	_forge.add_theme_stylebox_override("panel", _UiUtil.make_style(Color(0.22, 0.09, 0.04, 0.9), int(_ref * 0.01),
			Color(1.0, 0.5, 0.2), 2))
	_forge.tooltip_text = "Scrap cards for essence. Craft new cards with essence in the Craft tab."
	left_vbox.add_child(_forge)
	var forge_lbl := _UiUtil.make_label("♨  Forge — drag a card here to scrap it for essence", int(_ref * 0.019),
			Color(1.0, 0.75, 0.45), HORIZONTAL_ALIGNMENT_CENTER, _forge)
	forge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_forge.set_drag_forwarding(Callable(), _can_drop_into_forge, _drop_into_forge)

	if not is_portrait:
		root_box.add_child(VSeparator.new())

	# ---- Deck pile (right / bottom) ----
	_pile = _DeckPile.new()
	_pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_portrait:
		_pile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_pile)
	_pile.setup(_ref, scroll_min_h)
	_pile.undo_pressed.connect(_on_undo)
	_pile.best_pressed.connect(_on_auto_fill)
	_pile.test_hand_pressed.connect(func() -> void:
		var overlay: _TestHandOverlay = _TestHandOverlay.new()
		add_child(overlay)
		overlay.open(SceneManager.save_manager.get_deck_instances(),
				_CombatOnboarding.opening_hand(SceneManager.save_manager.level), _template, _ref))
	attach_drag_scroll(_pile.scroll)
	_pile.scroll.set_drag_forwarding(Callable(), _can_drop_into_deck, _drop_into_deck)

	# ---- Loadout tabs + actions (Rename / Copy / Delete) ----
	_loadouts = _LoadoutBar.new()
	_pile.loadout_slot.add_child(_loadouts)
	_loadouts.setup(_ref)
	_loadouts.switched.connect(func() -> void:
		_working_deck.assign(SceneManager.save_manager.player_deck)
		_undo.clear()
		_refresh_cards())
	_loadouts.loadout_renamed.connect(_refresh_cards)

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
	if _search_timer == null:
		_search_timer = Timer.new()
		_search_timer.one_shot = true
		_search_timer.wait_time = 0.15
		_search_timer.timeout.connect(_refresh_cards)
		add_child(_search_timer)
	search.text_changed.connect(func(t: String) -> void:
		_query = t
		_search_timer.start())
	row.add_child(search)
	_filter_toggle = _UiUtil.make_button("Filters", Vector2(_ref * 0.12, h), int(_ref * 0.018), func() -> void:
		_filter_row.visible = not _filter_row.visible
		_refresh_toolbar(), row)
	_filter_toggle.tooltip_text = "Filter by class, cost and rarity"
	_sort_btn = _UiUtil.make_button("", Vector2(_ref * 0.17, h), int(_ref * 0.018), _on_cycle_sort, row)
	_sort_btn.tooltip_text = "Change the bag's sort order"
	_select_btn = _UiUtil.make_button("", Vector2(_ref * 0.13, h), int(_ref * 0.018), _on_toggle_select, row)
	_select_btn.tooltip_text = "Pick several cards to scrap or flag for sale at once"

# -------------------------------------------------------------------------
# Refresh
# -------------------------------------------------------------------------

func _refresh() -> void:
	_refresh_cards()
	if _craft_panel.visible:
		_craft_panel.refresh()
	if _items_panel.visible:
		_items_panel.refresh()

func _refresh_wallet() -> void:
	var sm := SceneManager.save_manager
	var used: int = sm.get_slot_count(_working_deck)
	var cap: int = sm.bag_size
	_wallet_label.text = "%d gold    %d essence" % [sm.coins, sm.essence]
	_satchel.set_counts(used, cap, sm.mailbox_cards.size())

func _template(tid: String) -> Dictionary:
	# Read-only cached view: sort, search and tiles only read it (GID-164 / TID-684).
	return CardRegistry.get_template_view(tid, "dark" if CardRegistry.is_dark_aligned() else "light")

## uid -> deck name for every card sitting in a deck (saved loadouts + the
## working deck). Those cards are shown tagged and can't be bulk-selected.
func _deck_membership() -> Dictionary:
	var sm := SceneManager.save_manager
	return BagOps.deck_membership(sm.loadouts, _working_deck, sm.active_loadout, _WORKING_DECK_NAME)

func _is_selectable(inst: Dictionary, membership: Dictionary) -> bool:
	return not membership.has(str(inst.get("uid", ""))) \
		and not bool(_template(str(inst.get("template_id", ""))).get("is_unique", false))

func _refresh_cards() -> void:
	_loadouts.refresh(_working_deck.size())
	_refresh_wallet()
	var col_scroll: int = _collection_scroll.scroll_vertical if _collection_scroll else 0
	_tiles.detach_all()
	for child in _collection_list.get_children():
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
		if _filters.passes(_template(tid), str(inst.get("rarity", "common"))) \
				and BagOps.matches_search(_template(tid), _query):
			avail.append(inst)

	# Drop selections that no longer point at a pickable card.
	for uid: String in _selected.keys():
		var inst: Dictionary = sm.get_instance_by_uid(uid)
		if inst.is_empty() or not _is_selectable(inst, membership):
			_selected.erase(uid)

	# ---- Binder grid: stacks of copies, or one stack's copies, plus silhouettes ----
	BagOps.sort_instances(avail, _sort, _template)
	var stacked: bool = not _select_mode and _expand_key == ""
	var stacks: Array[Dictionary] = BinderOps.stack(avail, membership)
	if _expand_key != "":
		var only: Array[Dictionary] = []
		for inst: Dictionary in avail:
			if BinderOps.stack_key(inst) == _expand_key:
				only.append(inst)
		avail = only
		if avail.is_empty():
			_expand_key = ""
			stacked = not _select_mode
	if _expand_key != "":
		var back := _UiUtil.make_button("‹ Back to binder  ·  %d copies, best first" % avail.size(),
				Vector2(0.0, _ref * 0.05), int(_ref * 0.018), func() -> void:
					_expand_key = ""
					_refresh_cards(), _collection_list)
		back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		avail = (BinderOps.stack(avail, membership)[0]["copies"] as Array[Dictionary]) if not avail.is_empty() \
				else avail
	var missing: Array[String] = _missing_on_page()
	if not avail.is_empty() or not missing.is_empty():
		var grid := HFlowContainer.new()
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", int(_ref * 0.008))
		grid.add_theme_constant_override("v_separation", int(_ref * 0.008))
		_collection_list.add_child(grid)
		var face: bool = CardRegistry.is_dark_aligned()
		var deck_now: Array[Dictionary] = sm.get_deck_instances()
		var shown: Array[Dictionary] = []
		if stacked:
			for st: Dictionary in stacks:
				shown.append(st)
		else:
			for inst: Dictionary in avail:
				shown.append({"best": inst, "copies": [inst]})
		for st: Dictionary in shown:
			var inst: Dictionary = st["best"]
			var n: int = (st["copies"] as Array).size()
			var uid: String = str(inst.get("uid", ""))
			var sig: String = "%d|%s|%s|%s|%s|%d|%d|%s|%s|%s" % [inst.hash(), str(membership.get(uid, "")),
					_selected.has(uid), _select_mode, face, int(_ref), n, DeckInsights.is_upgrade(inst, deck_now),
					sm.is_for_sale(uid), sm.is_new_card(uid)]
			var tile: Control = _tiles.take(uid, sig)
			if tile == null:
				tile = _make_card_tile(inst, membership)
				_CardTile.add_count(tile, n, _ref)
				if DeckInsights.is_upgrade(inst, deck_now):
					_CardTile.add_upgrade_mark(tile, _ref)
				if DeckInsights.is_perfect_roll(inst):
					tile.set_meta(&"perfect_star", _CardTile.add_perfect_mark(tile, _ref))
				_tiles.put(uid, sig, tile)
			grid.add_child(tile)
			_CardJuice.shimmer(tile, str(inst.get("rarity", "")))
			if sm.is_new_card(uid):
				_CardJuice.new_glow(tile)
			if tile.has_meta(&"perfect_star"):
				_CardJuice.twinkle(tile.get_meta(&"perfect_star") as Control)
		for tid: String in missing:
			var sil: Button = _CardTile.build_silhouette(tid, _template(tid), _ref)
			sil.pressed.connect(_on_silhouette.bind(tid))
			grid.add_child(sil)
	else:
		var msg: String = "Your bag is empty — cards not in a deck live here" if bag_total == 0 \
				else "No cards match the search / filters"
		_UiUtil.make_label(msg, int(_ref * 0.020), Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, _collection_list)

	_tiles.sweep()

	# ---- Deck pile ----
	BagOps.sort_instances(deck_insts, "cost", _template)
	_pile.show_deck(deck_insts, _template, _decorate_deck_tile, _undo.can_undo())
	_refresh_toolbar()
	if _collection_scroll and col_scroll > 0:
		_collection_scroll.scroll_vertical = col_scroll

## Templates on the current binder page the player owns no copy of (decks included).
## Hidden while searching or filtering — silhouettes answer "what am I missing", not a query.
func _missing_on_page() -> Array[String]:
	if _filters.page == "all" or _query != "" or _filters.any_active() or _select_mode or _expand_key != "":
		_refresh_page_label({})
		return []
	var owned: Dictionary = {}
	for inst: Dictionary in SceneManager.save_manager.get_owned_instances():
		owned[str(inst.get("template_id", ""))] = true
	_refresh_page_label(owned)
	return BinderOps.missing_on_page(_filters.page, owned, _collectable_ids(), _template)

func _refresh_page_label(owned: Dictionary) -> void:
	if owned.is_empty():
		_page_label.text = ""
		return
	var prog: Vector2i = BinderOps.page_progress(_filters.page, owned, _collectable_ids(), _template)
	_page_label.text = "Found %d / %d" % [prog.x, prog.y]

func _on_silhouette(tid: String) -> void:
	var card_name: String = str(_template(tid).get("name", tid))
	var how: String = "craft it in the Craft tab" if CardRegistry.is_craftable(tid) \
			else "find it out in the world"
	GameBus.hud_message_requested.emit("%s — not found yet. You can %s." % [card_name, how])

## Cards a player can collect into the binder: not techniques (taught by trainers) or co-op-only cards.
func _collectable_ids() -> Array[String]:
	var out: Array[String] = []
	for tid: String in CardRegistry.get_all_ids():
		if not _TechniqueDefs.is_technique(tid) and not tid.begins_with("coop_"):
			out.append(tid)
	return out

func _refresh_toolbar() -> void:
	_sort_btn.text = "Sort: %s" % str(BagOps.SORT_LABELS.get(_sort, _sort))
	_select_btn.text = "Done" if _select_mode else "Select"
	_select_btn.modulate = Color(0.55, 1.0, 0.6) if _select_mode else Color.WHITE
	var filtering: bool = _filters.any_active()
	_filter_toggle.text = "Filters •" if filtering else "Filters"
	_filter_toggle.modulate = _GOLD if _filter_row.visible or filtering else Color.WHITE
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
	_bulk_flag_btn.text = "For sale (%dg)" % int(value.get("gold", 0))
	_bulk_scrap_btn.text = "Scrap +%de" % int(value.get("essence", 0))
	_bulk_flag_btn.disabled = picked.is_empty()
	_bulk_scrap_btn.disabled = picked.is_empty()

func _selected_instances() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for uid: String in _selected:
		var inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(uid)
		if not inst.is_empty():
			out.append(inst)
	return out

func _on_auto_fill() -> void:
	var sm := SceneManager.save_manager
	var all_instances: Array[Dictionary] = sm.get_owned_instances()
	var available: Array[Dictionary] = []
	for inst: Dictionary in all_instances:
		var uid: String = str(inst.get("uid", ""))
		# Techniques (GID-175) are picked by hand, never auto-filled.
		if uid != "" and not _working_deck.has(uid) \
				and not _TechniqueDefs.is_technique(str(inst.get("template_id", ""))):
			available.append(inst)
	var target: int = maxi(IsoConst.DECK_MIN, _working_deck.size())
	target = mini(target, IsoConst.DECK_MAX)
	# Upgrade each deck card to its best bag copy first, then top up (GID-180 / TID-741).
	var next: Array[String] = _working_deck.duplicate()
	var deck_insts: Array[Dictionary] = []
	for u: String in next:
		deck_insts.append(sm.get_instance_by_uid(u))
	var swaps: Array = DeckInsights.upgrade_swaps(deck_insts, available)
	for pair: Array in swaps:
		next[next.find(str(pair[0]))] = str(pair[1])
		available = available.filter(func(i: Dictionary) -> bool: return str(i.get("uid", "")) != str(pair[1]))
	var filled: Array[String] = DeckAutoFill.fill(next, available, target)
	var added: int = filled.size() - _working_deck.size()
	if swaps.is_empty() and added <= 0:
		GameBus.hud_message_requested.emit("Already your best — no stronger copies in the bag")
		return
	GameBus.hud_message_requested.emit("Best deck: %d upgraded, %d added" % [swaps.size(), maxi(added, 0)])
	_edit_deck(filled)

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
	if SceneManager.save_manager.is_for_sale(uid):
		tag = "For sale"
	elif SceneManager.save_manager.is_new_card(uid):
		tag = "✦ NEW"
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

func _make_card_draggable(ctrl: Button, uid: String, in_deck: bool, tint: Color,
		can_drop: Callable = Callable(), drop: Callable = Callable()) -> void:
	ctrl.button_down.connect(func() -> void:
		_press_origin[ctrl] = ctrl.get_local_mouse_position())
	ctrl.set_drag_forwarding(
		func(at: Vector2) -> Variant: return _drag_card(ctrl, at, uid, in_deck, tint),
		can_drop, drop)

func _drag_card(ctrl: Control, at: Vector2, uid: String, in_deck: bool, tint: Color) -> Variant:
	var origin: Vector2 = _press_origin.get(ctrl, at)
	var delta: Vector2 = at - origin
	if absf(delta.y) > absf(delta.x):
		return null   # vertical gesture — let the ScrollContainer have it
	_hide_instance_detail()
	# set_drag_preview needs a live viewport; skip it out of tree so the rules
	# above stay unit-testable without standing up the whole panel.
	if ctrl.is_inside_tree():
		var inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(uid)
		var tmpl: Dictionary = _template(str(inst.get("template_id", "")))
		if tmpl.is_empty():
			tmpl = {"color": tint}
		ctrl.set_drag_preview(_CardJuice.drag_preview(inst, tmpl, _ref * (0.78 if in_deck else 1.0)))
		_CardJuice.sound("pick")
		_CardJuice.sparkle(ctrl, str(inst.get("rarity", "common")), _ref)
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

	var kind: String = "Spell" if is_spell else "Ally  ⚔ %d  ♥ %d" % [int(inst.get("attack", 0)),
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
		var warn := _UiUtil.make_label("In %s — scrapping removes it from that deck."
				% str(membership[uid]), int(_ref * 0.017), Color(1.0, 0.7, 0.4), HORIZONTAL_ALIGNMENT_LEFT, vb)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not _working_deck.has(uid):
		var twin: Dictionary = DeckInsights.replace_target(inst, SceneManager.save_manager.get_deck_instances())
		if not twin.is_empty():
			vb.add_child(_CompareTip.rows(inst, twin, "vs the copy in your deck:", _ref))
			var swap := _UiUtil.make_button("⇄ Swap into deck", Vector2(_ref * 0.22, _ref * 0.055), int(_ref * 0.019),
					_swap_in.bind(uid, str(twin.get("uid", ""))), vb)
			swap.modulate = Color(1.0, 0.9, 0.5) if DeckInsights.is_upgrade(inst,
					SceneManager.save_manager.get_deck_instances()) else Color.WHITE

	var top_row := _UiUtil.make_hbox(int(_ref * 0.006), vb)
	var add_btn := _UiUtil.make_button("Add to Deck", Vector2(_ref * 0.17, _ref * 0.058), int(_ref * 0.019),
			_on_add_by_uid.bind(uid), top_row)
	add_btn.disabled = _working_deck.size() >= IsoConst.DECK_MAX
	_UiUtil.make_button("Inspect", Vector2(_ref * 0.14, _ref * 0.058), int(_ref * 0.019), func() -> void:
		_hide_instance_detail()
		_show_inspect(tid), top_row)
	var copies: int = 0
	for other: Dictionary in SceneManager.save_manager.get_owned_instances():
		if BinderOps.stack_key(other) == BinderOps.stack_key(inst) and not _working_deck.has(str(other.get("uid", ""))):
			copies += 1
	if copies > 1 and _expand_key == "":
		_UiUtil.make_button("All %d copies" % copies, Vector2(_ref * 0.16, _ref * 0.058), int(_ref * 0.019),
				func() -> void:
					_expand_key = BinderOps.stack_key(inst)
					_hide_instance_detail()
					_refresh_cards(), top_row)

	if not bool(tmpl.get("is_unique", false)):
		var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
		var action_row := _UiUtil.make_hbox(int(_ref * 0.006), vb)
		var flagged: bool = SceneManager.save_manager.is_for_sale(uid)
		var flag_btn := _UiUtil.make_button("Unflag sale" if flagged else "For sale (%dg)" % int(cfg.get("sell_gold", 0)),
				Vector2(_ref * 0.17, _ref * 0.058), int(_ref * 0.019), _detail_action.bind(uid, "flag", Rect2()),
				action_row)
		flag_btn.modulate = _GOLD
		flag_btn.tooltip_text = "Vendors buy every flagged card in one go"
		flag_btn.disabled = _working_deck.has(uid)
		var scrap_btn := _UiUtil.make_button("Scrap +%de" % int(cfg.get("scrap_essence", 0)),
				Vector2(_ref * 0.155, _ref * 0.058), int(_ref * 0.019),
				_detail_action.bind(uid, "scrap", anchor.get_global_rect()), action_row)
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
				_combine(tid, rarity), vb)
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

func _detail_action(uid: String, action: String, from: Rect2) -> void:
	if action == "flag":
		SceneManager.save_manager.toggle_for_sale(uid)
	else:
		_forge_scrap(uid, from)
	_selected.erase(uid)
	_prune_working_deck()
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
		GameBus.hud_message_requested.emit("That card is in a deck or can't be scrapped")
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

## Scraps `uid` with the forge burn: the card burns at `from` (global rect; the
## forge when empty) and its essence flies to the wallet.
func _forge_scrap(uid: String, from: Rect2) -> void:
	var sm := SceneManager.save_manager
	var inst: Dictionary = sm.get_instance_by_uid(uid)
	if inst.is_empty():
		return
	if from.size == Vector2.ZERO:
		var fr: Rect2 = _forge.get_global_rect()
		from = Rect2(fr.get_center() - _CardTile.tile_size(_ref) * 0.5, _CardTile.tile_size(_ref))
	var wallet: Rect2 = _wallet_label.get_global_rect()
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(str(inst.get("rarity", "common")), {})
	var ess: int = int(cfg.get("scrap_essence", 0))
	_ForgeFx.burn(self, inst, _template(str(inst.get("template_id", ""))), from, wallet.get_center(), _ref,
			clampi(ess / 5, 4, 16))
	sm.scrap_card_instance(uid)

func _can_drop_into_forge(_at: Vector2, data: Variant) -> bool:
	if not _is_card_drag(data, false):
		return false
	var inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(str((data as Dictionary).get("uid", "")))
	var ok: bool = not inst.is_empty() and not bool(_template(str(inst.get("template_id", ""))).get("is_unique", false))
	_forge.modulate = Color(1.5, 1.2, 0.9) if ok else Color(0.7, 0.5, 0.5)
	return ok

## Commons and rares burn at once; an epic or legendary asks first.
func _drop_into_forge(_at: Vector2, data: Variant) -> void:
	_forge.modulate = Color.WHITE
	var uid: String = str((data as Dictionary).get("uid", ""))
	var inst: Dictionary = SceneManager.save_manager.get_instance_by_uid(uid)
	if IsoConst.RARITY_ORDER.find(str(inst.get("rarity", "common"))) < 2:
		_detail_action(uid, "scrap", Rect2())
		return
	_selected.clear()
	_selected[uid] = true
	_on_bulk_action("scrap")

## Combine 3 → next tier, played as the orbit-and-merge ritual.
func _combine(tid: String, rarity: String) -> void:
	var sm := SceneManager.save_manager
	var sources: Array[Dictionary] = []
	for other: Dictionary in sm.get_owned_instances():
		if sources.size() < 3 and str(other.get("template_id", "")) == tid and str(other.get("rarity", "")) == rarity \
				and not sm.player_deck.has(str(other.get("uid", ""))):
			sources.append(other.duplicate())
	var result: Dictionary = sm.combine_cards(tid, rarity)
	_prune_working_deck()
	_hide_instance_detail()
	_refresh_cards()
	if result.is_empty():
		return
	var ritual: _CombineRitual = _CombineRitual.new()
	add_child(ritual)
	ritual.play(sources, result, _template(tid), _ref)

## Confirms, then scraps every selected card in one go.
func _on_bulk_action(action: String) -> void:
	var picked: Array[Dictionary] = _selected_instances()
	if picked.is_empty():
		return
	var value: Dictionary = BagOps.bulk_value(picked)
	var reward: String = "+%d essence" % int(value.get("essence", 0))
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
	yes.modulate = _ESSENCE
	_UiUtil.make_button("Cancel", Vector2(_ref * 0.14, _ref * 0.065), int(_ref * 0.022),
			func() -> void: popup.queue_free(), btn_row)
	popup.popup_centered()

func _apply_bulk(action: String) -> void:
	var sm := SceneManager.save_manager
	var membership: Dictionary = _deck_membership()
	for inst: Dictionary in _selected_instances():
		# Re-check at apply time: a deck edit since selecting must not be undone by a scrap.
		if not _is_selectable(inst, membership):
			continue
		var uid: String = str(inst.get("uid", ""))
		if action == "flag":
			if not sm.is_for_sale(uid):
				sm.toggle_for_sale(uid)
		else:
			_forge_scrap(uid, Rect2())
	_selected.clear()
	_select_mode = false
	_prune_working_deck()
	_refresh_cards()

## Wires a deck-pile tile: tap returns it to the binder, hold inspects, a
## sideways drag carries it back.
func _decorate_deck_tile(tile: Button, inst: Dictionary) -> void:
	var uid: String = str(inst.get("uid", ""))
	var tid: String = str(inst.get("template_id", ""))
	tile.tooltip_text += "\n(tap to take out of the deck)"
	_UiUtil.bind_scroll_safe_press(tile, _on_remove_by_uid.bind(uid), _pile.scroll)
	# A bag copy of the same card held over this tile shows the stat diff; dropping swaps them.
	_make_card_draggable(tile, uid, true, _template(tid).get("color", Color(0.3, 0.3, 0.35)),
			func(_at: Vector2, data: Variant) -> bool: return _hover_twin(tile, inst, data),
			func(at: Vector2, data: Variant) -> void:
				_hide_compare()
				var held: String = str((data as Dictionary).get("uid", ""))
				if str(SceneManager.save_manager.get_instance_by_uid(held).get("template_id", "")) == tid:
					_swap_in(held, uid)
				else:
					_drop_into_deck(at, data))
	var lpd := LongPressDetector.new()
	tile.add_child(lpd)
	lpd.long_pressed.connect(func() -> void: _show_inspect(tid))


# -------------------------------------------------------------------------
# Deck mutation actions
# -------------------------------------------------------------------------

# Add a specific instance by UID.
func _on_add_by_uid(uid: String) -> void:
	if _working_deck.size() >= IsoConst.DECK_MAX or _working_deck.has(uid):
		return
	var why: String = _technique_violation_with(uid)
	if why != "":
		GameBus.hud_message_requested.emit(why)
		return
	var next: Array[String] = _working_deck.duplicate()
	next.append(uid)
	_hide_instance_detail()
	_edit_deck(next)

# Why adding `uid` would break the deck's technique rules (GID-175), or "".
func _technique_violation_with(uid: String) -> String:
	var sm := SceneManager.save_manager
	var ids: Array = []
	for u: String in _working_deck + [uid]:
		ids.append(str(sm.get_instance_by_uid(u).get("template_id", "")))
	return _TechniqueDefs.deck_violation(ids)

# Remove a specific instance by UID.
func _on_remove_by_uid(uid: String) -> void:
	if _working_deck.size() <= IsoConst.DECK_MIN:
		GameBus.hud_message_requested.emit("Minimum deck size reached")
		return
	var next: Array[String] = _working_deck.duplicate()
	next.erase(uid)
	_hide_instance_detail()
	_edit_deck(next)

## Compare tip while a bag card hovers its deck twin (TID-741). Returns
## whether the tile accepts the drop; any other drag just passes through.
func _hover_twin(tile: Control, deck_inst: Dictionary, data: Variant) -> bool:
	if not _is_card_drag(data, false):
		return false
	var held: Dictionary = SceneManager.save_manager.get_instance_by_uid(str((data as Dictionary).get("uid", "")))
	if str(held.get("template_id", "")) != str(deck_inst.get("template_id", "")):
		_hide_compare()
		return _can_drop_into_deck(Vector2.ZERO, data)
	if _compare_tip == null or not is_instance_valid(_compare_tip):
		_compare_tip = _CompareTip.new()
		add_child(_compare_tip)
	_compare_tip.show_over(tile, held, deck_inst, _ref)
	return true

func _hide_compare() -> void:
	if _compare_tip != null and is_instance_valid(_compare_tip):
		_compare_tip.queue_free()
	_compare_tip = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hide_compare()
		if _forge != null:
			_forge.modulate = Color.WHITE

## Puts bag card `new_uid` into the deck in place of `old_uid`.
func _swap_in(new_uid: String, old_uid: String) -> void:
	var idx: int = _working_deck.find(old_uid)
	if idx < 0 or new_uid == "" or _working_deck.has(new_uid):
		return
	var next: Array[String] = _working_deck.duplicate()
	next[idx] = new_uid
	_hide_instance_detail()
	_edit_deck(next)

## Every deck change goes through here: snapshot for undo, then save at once.
func _edit_deck(next: Array[String]) -> void:
	if next == _working_deck:
		return
	_undo.push(_working_deck)
	var added: Array[String] = []
	for uid: String in next:
		if not _working_deck.has(uid):
			added.append(uid)
	var removed: bool = next.size() < _working_deck.size()
	_working_deck = next
	_commit_deck()
	_refresh_cards()
	for uid: String in added:
		_pile.land(uid, str(SceneManager.save_manager.get_instance_by_uid(uid).get("rarity", "common")))
	_maybe_bark()
	if not added.is_empty():
		_CardJuice.sound("place")
	elif removed:
		_CardJuice.sound("return")

## Maiteln comments on the deck (TID-744), rate-limited by DeckBarkRules.
func _maybe_bark() -> void:
	var sm := SceneManager.save_manager
	if not DeckBarkRules.is_eligible(sm.active_companion, sm.has_learned(_UnlockLadder.FEAT_COMPANION)):
		return
	var bag: Array[Dictionary] = []
	for inst: Dictionary in sm.get_owned_instances():
		if not _working_deck.has(str(inst.get("uid", ""))):
			bag.append(inst)
	var id: String = DeckBarkRules.next_bark(DeckBarkRules.candidates(sm.get_deck_instances(), bag),
			_bark_last_id, float(Time.get_ticks_msec() - _bark_last_ms) / 1000.0)
	if id == "":
		return
	_bark_last_id = id
	_bark_last_ms = Time.get_ticks_msec()
	_pile.say("Maiteln", DeckBarkRules.text_for(id))

func _commit_deck() -> void:
	SceneManager.save_manager.set_active_deck(_working_deck)

func _on_undo() -> void:
	if not _undo.can_undo():
		return
	_working_deck = _undo.pop()
	_prune_working_deck()
	_commit_deck()
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

func _on_close() -> void:
	closed.emit()

## Leaving the deck table clears the "new" marks and the HUD badge (TID-747).
func _exit_tree() -> void:
	if SceneManager.save_manager != null:
		SceneManager.save_manager.mark_cards_seen()

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_Z \
			and (key.ctrl_pressed or key.meta_pressed) and is_visible_in_tree() and _cards_panel.visible:
		get_viewport().set_input_as_handled()
		_on_undo()
		return
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_on_close()
