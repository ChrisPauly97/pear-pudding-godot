## Rankings panel: PvP ranked leaderboard (GID-102 / TID-373) + PvE leaderboards —
## Endless Spire runs and co-op boss clears (GID-102 / TID-379) — unified into one
## overlay with tabs, per the TID-379 task notes ("avoid two near-identical panels").
##
## Ranked tab lists the cached session leaderboard rows (rank, name, rating, W/L) that
## WorldScene maintains in `_leaderboard_rows`, fed by the authority's `recv_leaderboard`
## RPC. Spire / Co-op Clears tabs list `_pve_leaderboards` ({spire, coop_clears} arrays
## of {token, name, value, day}), fed by `recv_pve_leaderboards` — a distinct RPC/cache
## pair from the ranked board, never touching pvp_rating.
##
## Script-only overlay (instantiated via .new()), matching SettingsScene /
## MultiplayerLobbyScene (extends BaseOverlay by path string, viewport-relative,
## rebuilt on resize). Opened from a HUD button in WorldScene — a touch/click target,
## same as the Trade/Spectate/Emote buttons (mobile + desktop parity, CLAUDE.md).
extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

## Tab indices — order matches the tab button row.
const TAB_RANKED: int = 0
const TAB_SPIRE: int = 1
const TAB_COOP: int = 2

var _rows_vbox: VBoxContainer = null
var _header_hbox: HBoxContainer = null
var _title_lbl: Label = null
var _tab_buttons: Array[Button] = []

var _rows_cache: Array = []                                   # Ranked (PvP rating) rows
var _pve_cache: Dictionary = {"spire": [], "coop_clears": []}  # PvE {board: rows}

var _active_tab: int = TAB_RANKED

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.72, true)

	var panel_w: float = _vw * 0.62
	var panel_h: float = _vh * 0.7
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var outer_vbox := _build_margin_vbox(panel, 0.04, 0.03)

	_title_lbl = _UiUtil.make_title_label(_title_for_tab(_active_tab), _vh)
	outer_vbox.add_child(_title_lbl)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", int(_ref * 0.015))
	outer_vbox.add_child(tab_row)
	_tab_buttons = []
	_add_tab_button(tab_row, "Ranked", TAB_RANKED)
	_add_tab_button(tab_row, "Spire", TAB_SPIRE)
	_add_tab_button(tab_row, "Co-op Clears", TAB_COOP)
	_refresh_tab_styles()

	outer_vbox.add_child(_UiUtil.make_separator())

	_header_hbox = HBoxContainer.new()
	_header_hbox.add_theme_constant_override("separation", int(_ref * 0.02))
	outer_vbox.add_child(_header_hbox)
	_build_header()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	_rows_vbox = VBoxContainer.new()
	_rows_vbox.add_theme_constant_override("separation", int(_ref * 0.012))
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_vbox)

	_render_rows()

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	outer_vbox.add_child(btn_row)

func _add_tab_button(parent: HBoxContainer, text: String, tab: int) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(_vh * 0.16, _vh * 0.05)
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
	_build_header()
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
		TAB_SPIRE:
			return "Endless Spire — Best Runs"
		TAB_COOP:
			return "Co-op Boss Clears"
		_:
			return "Ranked Leaderboard"

func _build_header() -> void:
	for c in _header_hbox.get_children():
		c.queue_free()
	_add_header_cell(_header_hbox, "#", 0.08)
	_add_header_cell(_header_hbox, "Player", 0.40)
	if _active_tab == TAB_RANKED:
		_add_header_cell(_header_hbox, "Rating", 0.22)
		_add_header_cell(_header_hbox, "W-L", 0.22)
	elif _active_tab == TAB_SPIRE:
		_add_header_cell(_header_hbox, "Best Floor", 0.22)
		_add_header_cell(_header_hbox, "Day", 0.22)
	else:
		_add_header_cell(_header_hbox, "Party Size", 0.22)
		_add_header_cell(_header_hbox, "Day", 0.22)

func _add_header_cell(parent: HBoxContainer, text: String, width_frac: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	lbl.custom_minimum_size = Vector2(_vw * width_frac, 0)
	parent.add_child(lbl)

## Called by WorldScene whenever a fresh ranked-rating snapshot arrives (TID-373).
func refresh_rows(rows: Array) -> void:
	_rows_cache = rows
	if _active_tab == TAB_RANKED and _rows_vbox != null and is_instance_valid(_rows_vbox):
		_render_rows()

## Called by WorldScene whenever a fresh PvE {spire, coop_clears} snapshot arrives
## (TID-379). `snapshot` mirrors SessionState.get_pve_leaderboards_snapshot().
func refresh_pve_rows(snapshot: Dictionary) -> void:
	var spire: Variant = snapshot.get("spire", [])
	var coop: Variant = snapshot.get("coop_clears", [])
	_pve_cache = {
		"spire": spire if spire is Array else [],
		"coop_clears": coop if coop is Array else [],
	}
	if _active_tab != TAB_RANKED and _rows_vbox != null and is_instance_valid(_rows_vbox):
		_render_rows()

func _current_rows() -> Array:
	match _active_tab:
		TAB_SPIRE:
			return _pve_cache.get("spire", [])
		TAB_COOP:
			return _pve_cache.get("coop_clears", [])
		_:
			return _rows_cache

func _empty_message_for_tab() -> String:
	match _active_tab:
		TAB_SPIRE:
			return "No Endless Spire runs recorded yet this session."
		TAB_COOP:
			return "No co-op boss clears recorded yet this session."
		_:
			return "No ranked duels played yet this session."

func _render_rows() -> void:
	for c in _rows_vbox.get_children():
		c.queue_free()
	var rows: Array = _current_rows()
	if rows.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = _empty_message_for_tab()
		empty_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		_rows_vbox.add_child(empty_lbl)
		return
	for i in range(rows.size()):
		var row: Variant = rows[i]
		if row is Dictionary:
			_add_row(i + 1, row as Dictionary)

func _add_row(rank: int, row: Dictionary) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(_ref * 0.02))
	_rows_vbox.add_child(hb)

	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank
	rank_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	rank_lbl.custom_minimum_size = Vector2(_vw * 0.08, 0)
	if rank == 1:
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hb.add_child(rank_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(row.get("name", "Player"))
	name_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	name_lbl.custom_minimum_size = Vector2(_vw * 0.40, 0)
	hb.add_child(name_lbl)

	if _active_tab == TAB_RANKED:
		var rating_lbl := Label.new()
		rating_lbl.text = str(int(row.get("rating", 1000)))
		rating_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		rating_lbl.custom_minimum_size = Vector2(_vw * 0.22, 0)
		rating_lbl.modulate = Color(0.6, 1.0, 0.6)
		hb.add_child(rating_lbl)

		var wl_lbl := Label.new()
		wl_lbl.text = "%d-%d" % [int(row.get("wins", 0)), int(row.get("losses", 0))]
		wl_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		wl_lbl.custom_minimum_size = Vector2(_vw * 0.22, 0)
		hb.add_child(wl_lbl)
	else:
		var value_lbl := Label.new()
		value_lbl.text = str(int(row.get("value", 0)))
		value_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		value_lbl.custom_minimum_size = Vector2(_vw * 0.22, 0)
		value_lbl.modulate = Color(0.6, 1.0, 0.6)
		hb.add_child(value_lbl)

		var day_lbl := Label.new()
		day_lbl.text = str(int(row.get("day", 0)))
		day_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		day_lbl.custom_minimum_size = Vector2(_vw * 0.22, 0)
		hb.add_child(day_lbl)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_vh = get_viewport().get_visible_rect().size.y
		_vw = get_viewport().get_visible_rect().size.x
		_ref = minf(_vh, _vw)
		for c in get_children():
			c.queue_free()
		_build_ui()
