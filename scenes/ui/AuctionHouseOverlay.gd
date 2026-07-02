## Async card auction house panel (GID-102 / TID-378).
##
## Three tabs: **Sell** (list a card from your collection at a buyout price),
## **Browse** (active listings from other party members — bid or buy outright),
## and **My Listings** (your own active/settled listings, with Cancel on active
## ones). Tab-button pattern mirrors LeaderboardOverlay.
##
## Script-only overlay (instantiated via .new()), matching PartyStashOverlay /
## LeaderboardOverlay (extends BaseOverlay by path string, viewport-relative,
## rebuilt on resize). Opened from an "Auction" HUD button in WorldScene — a
## touch/click target, mobile + desktop parity per CLAUDE.md.
##
## Unique cards never appear in the Sell list, same guard as the party stash
## (WorldScene.request_auction_list only fires for cards shown here, and the
## authority double-checks via AuctionTransfer.list_card regardless).
extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _CardRegistry = preload("res://autoloads/CardRegistry.gd")
const _AuctionSync = preload("res://game_logic/net/AuctionSync.gd")

const TAB_SELL: int = 0
const TAB_BROWSE: int = 1
const TAB_MINE: int = 2

const _PRICE_STEP: int = 25
const _DEFAULT_PRICE: int = 100
const _BID_STEP: int = 25

## Set by WorldScene right after instantiation so button presses can call back.
var world_scene: Node = null

var _rows_vbox: VBoxContainer = null
var _title_lbl: Label = null
var _tab_buttons: Array[Button] = []
var _active_tab: int = TAB_SELL

var _my_cards_cache: Array = []
var _auctions_cache: Array = []
var _my_token: String = ""

## Per-uid chosen listing price, kept across refreshes so the stepper doesn't
## reset while the player is dialing in a price.
var _list_prices: Dictionary = {}


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	_build_backdrop(0.72, true)

	var panel_w: float = _vw * 0.82
	var panel_h: float = _vh * 0.78
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var outer_vbox := _build_margin_vbox(panel, 0.04, 0.02)

	_title_lbl = _UiUtil.make_title_label(_title_for_tab(_active_tab), _vh)
	outer_vbox.add_child(_title_lbl)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", int(_ref * 0.015))
	outer_vbox.add_child(tab_row)
	_tab_buttons = []
	_add_tab_button(tab_row, "Sell", TAB_SELL)
	_add_tab_button(tab_row, "Browse", TAB_BROWSE)
	_add_tab_button(tab_row, "My Listings", TAB_MINE)
	_refresh_tab_styles()

	outer_vbox.add_child(_UiUtil.make_separator())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	_rows_vbox = VBoxContainer.new()
	_rows_vbox.add_theme_constant_override("separation", int(_ref * 0.014))
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_vbox)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	outer_vbox.add_child(btn_row)

	_render_rows()


func _add_tab_button(parent: HBoxContainer, text: String, tab: int) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(_vh * 0.18, _vh * 0.05)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.020))
	btn.pressed.connect(func() -> void: _select_tab(tab))
	parent.add_child(btn)
	_tab_buttons.append(btn)


func _select_tab(tab: int) -> void:
	if tab == _active_tab:
		return
	_active_tab = tab
	_refresh_tab_styles()
	if _title_lbl != null:
		_title_lbl.text = _title_for_tab(_active_tab)
	_render_rows()


func _refresh_tab_styles() -> void:
	for i in range(_tab_buttons.size()):
		var btn: Button = _tab_buttons[i]
		if i == _active_tab:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			btn.remove_theme_color_override("font_color")


func _title_for_tab(tab: int) -> String:
	match tab:
		TAB_BROWSE:
			return "Auction House — Browse"
		TAB_MINE:
			return "Auction House — My Listings"
		_:
			return "Auction House — Sell"


## Called by WorldScene whenever the local collection or a fresh listings
## snapshot changes. `my_token` is the local player's identity token, used to
## split listings into "Browse" (others') vs "My Listings" (mine).
func refresh(my_cards: Array, auctions: Array, my_token: String) -> void:
	_my_cards_cache = my_cards
	_auctions_cache = auctions
	_my_token = my_token
	if is_inside_tree() and _rows_vbox != null and is_instance_valid(_rows_vbox):
		_render_rows()


func _render_rows() -> void:
	for c in _rows_vbox.get_children():
		c.queue_free()
	match _active_tab:
		TAB_SELL:
			_render_sell_rows()
		TAB_BROWSE:
			_render_browse_rows()
		_:
			_render_mine_rows()


func _add_empty_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.020))
	lbl.modulate = Color(0.7, 0.7, 0.7)
	_rows_vbox.add_child(lbl)


# ---------------------------------------------------------------------------
# Sell tab
# ---------------------------------------------------------------------------

func _render_sell_rows() -> void:
	var any: bool = false
	for inst: Variant in _my_cards_cache:
		if not (inst is Dictionary):
			continue
		var d: Dictionary = inst as Dictionary
		var tmpl: Dictionary = _CardRegistry.get_template(str(d.get("template_id", "")))
		if bool(tmpl.get("is_unique", false)):
			continue  # unique cards can never be listed — not offered here
		any = true
		_add_sell_row(d)
	if not any:
		_add_empty_label("No sellable cards.")


func _add_sell_row(inst: Dictionary) -> void:
	var uid: String = str(inst.get("uid", ""))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(_ref * 0.015))
	_rows_vbox.add_child(hb)

	var name_lbl := Label.new()
	name_lbl.text = "%s (%s)" % [str(inst.get("template_id", "?")), str(inst.get("rarity", "common"))]
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.020))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_lbl)

	if not _list_prices.has(uid):
		_list_prices[uid] = _DEFAULT_PRICE

	var price_lbl := Label.new()
	price_lbl.text = "%d coins" % int(_list_prices[uid])
	price_lbl.custom_minimum_size = Vector2(_vh * 0.14, 0)
	price_lbl.add_theme_font_size_override("font_size", int(_vh * 0.020))
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hb.add_child(price_lbl)

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(_vh * 0.05, _vh * 0.05)
	minus_btn.pressed.connect(func() -> void:
		_list_prices[uid] = max(_PRICE_STEP, int(_list_prices[uid]) - _PRICE_STEP)
		price_lbl.text = "%d coins" % int(_list_prices[uid])
	)
	hb.add_child(minus_btn)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(_vh * 0.05, _vh * 0.05)
	plus_btn.pressed.connect(func() -> void:
		_list_prices[uid] = int(_list_prices[uid]) + _PRICE_STEP
		price_lbl.text = "%d coins" % int(_list_prices[uid])
	)
	hb.add_child(plus_btn)

	var list_btn := Button.new()
	list_btn.text = "List"
	list_btn.custom_minimum_size = Vector2(_vh * 0.12, _vh * 0.05)
	list_btn.add_theme_font_size_override("font_size", int(_vh * 0.018))
	list_btn.pressed.connect(func() -> void:
		if world_scene != null and world_scene.has_method("request_auction_list"):
			world_scene.request_auction_list(uid, int(_list_prices[uid]))
	)
	hb.add_child(list_btn)


# ---------------------------------------------------------------------------
# Browse tab — active listings from other members
# ---------------------------------------------------------------------------

func _render_browse_rows() -> void:
	var any: bool = false
	for entry: Variant in _auctions_cache:
		if not (entry is Dictionary):
			continue
		var listing: Dictionary = entry as Dictionary
		if str(listing.get("status", "")) != _AuctionSync.STATUS_ACTIVE:
			continue
		if str(listing.get("seller_token", "")) == _my_token:
			continue
		any = true
		_add_browse_row(listing)
	if not any:
		_add_empty_label("No active listings from the party right now.")


func _add_browse_row(listing: Dictionary) -> void:
	var card: Dictionary = listing.get("card_instance", {}) as Dictionary
	var id: String = str(listing.get("id", ""))
	var buyout: int = int(listing.get("buyout", 0))
	var bid: int = int(listing.get("bid", 0))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(_ref * 0.015))
	_rows_vbox.add_child(hb)

	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [str(card.get("template_id", "?")), str(listing.get("seller_name", "Player"))]
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.020))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_lbl)

	var bid_lbl := Label.new()
	bid_lbl.text = "Bid: %d" % bid if bid > 0 else "No bids"
	bid_lbl.custom_minimum_size = Vector2(_vh * 0.14, 0)
	bid_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
	hb.add_child(bid_lbl)

	var bid_btn := Button.new()
	bid_btn.text = "Bid %d" % (bid + _BID_STEP)
	bid_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.05)
	bid_btn.add_theme_font_size_override("font_size", int(_vh * 0.018))
	bid_btn.pressed.connect(func() -> void:
		if world_scene != null and world_scene.has_method("request_auction_bid"):
			world_scene.request_auction_bid(id, bid + _BID_STEP)
	)
	hb.add_child(bid_btn)

	var buyout_btn := Button.new()
	buyout_btn.text = "Buyout %d" % buyout
	buyout_btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.05)
	buyout_btn.add_theme_font_size_override("font_size", int(_vh * 0.018))
	buyout_btn.pressed.connect(func() -> void:
		if world_scene != null and world_scene.has_method("request_auction_buyout"):
			world_scene.request_auction_buyout(id)
	)
	hb.add_child(buyout_btn)


# ---------------------------------------------------------------------------
# My Listings tab
# ---------------------------------------------------------------------------

func _render_mine_rows() -> void:
	var any: bool = false
	for entry: Variant in _auctions_cache:
		if not (entry is Dictionary):
			continue
		var listing: Dictionary = entry as Dictionary
		if str(listing.get("seller_token", "")) != _my_token:
			continue
		any = true
		_add_mine_row(listing)
	if not any:
		_add_empty_label("You have no listings.")


func _add_mine_row(listing: Dictionary) -> void:
	var card: Dictionary = listing.get("card_instance", {}) as Dictionary
	var id: String = str(listing.get("id", ""))
	var status: String = str(listing.get("status", ""))
	var buyout: int = int(listing.get("buyout", 0))
	var bid: int = int(listing.get("bid", 0))
	var is_active: bool = status == _AuctionSync.STATUS_ACTIVE

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(_ref * 0.015))
	_rows_vbox.add_child(hb)

	var card_name: String = str(card.get("template_id", "?")) if is_active else str(listing.get("id", "?"))
	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [card_name, status.capitalize()]
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.020))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not is_active:
		name_lbl.modulate = Color(0.7, 0.7, 0.7)
	hb.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "Buyout %d, bid %d" % [buyout, bid]
	price_lbl.custom_minimum_size = Vector2(_vh * 0.22, 0)
	price_lbl.add_theme_font_size_override("font_size", int(_vh * 0.018))
	hb.add_child(price_lbl)

	if is_active:
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.custom_minimum_size = Vector2(_vh * 0.14, _vh * 0.05)
		cancel_btn.add_theme_font_size_override("font_size", int(_vh * 0.018))
		cancel_btn.pressed.connect(func() -> void:
			if world_scene != null and world_scene.has_method("request_auction_cancel"):
				world_scene.request_auction_cancel(id)
		)
		hb.add_child(cancel_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_vh = get_viewport().get_visible_rect().size.y
		_vw = get_viewport().get_visible_rect().size.x
		_ref = minf(_vh, _vw)
		for c in get_children():
			c.queue_free()
		_build_ui()
