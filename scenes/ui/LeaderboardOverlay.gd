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


const _RiftDefs = preload("res://game_logic/spire/RiftDefs.gd")
## Tab indices — order matches the tab button row and _PVE_TABS below.
const TAB_RANKED: int = 0
const TAB_SPIRE: int = 1
const TAB_COOP: int = 2
const TAB_NIGHT: int = 3
const TAB_COOP_SPIRE: int = 4
const PANEL_W_FRAC: float = 0.62
## PvE tabs other than Rifts (which renders one section per rift): the
## SessionState board each lists, its value column and empty-state text. Night
## Hunts and Co-op Spire boards were recorded and synced but had no tab.
const _PVE_TABS: Dictionary = {
	TAB_COOP: {"board": "coop_clears", "title": "Co-op Boss Clears", "value": "Party Size",
			"empty": "No co-op boss clears recorded yet this session."},
	TAB_NIGHT: {"board": "night_hunts", "title": "Night Hunts — Best Night", "value": "Spectres",
			"empty": "No spectres hunted yet this session."},
	TAB_COOP_SPIRE: {"board": "coop_spire", "title": "Co-op Spire — Floors", "value": "Floors",
			"empty": "No co-op Spire runs finished yet this session."},
}

var _rows_vbox: VBoxContainer = null
var _header_hbox: HBoxContainer = null
var _title_lbl: Label = null
var _tab_buttons: Array[Button] = []

var _rows_cache: Array = []                                   # Ranked (PvP rating) rows
var _pve_cache: Dictionary = {}  # PvE {board: rows} (spire, coop_clears, rift_<id>…)

var _active_tab: int = TAB_RANKED

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	_build_backdrop(0.72, true)

	var panel_w: float = _vw * PANEL_W_FRAC
	var panel_h: float = _vh * 0.7
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var outer_vbox := _build_margin_vbox(panel, 0.04, 0.03)

	_title_lbl = _UiUtil.make_title_label(_title_for_tab(_active_tab), _vh)
	outer_vbox.add_child(_title_lbl)

	var tab_row := _UiUtil.make_hbox(int(_ref * 0.015), outer_vbox)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tab_w: float = minf(_vh * 0.16, _vw * 0.58 / 5.0)
	_tab_buttons = _UiUtil.make_tab_row(tab_row, ["Ranked", "Rifts", "Co-op Clears", "Night Hunts", "Co-op Spire"],
		Vector2(tab_w, _vh * 0.05), int(_vh * 0.018), _select_tab, _active_tab)

	outer_vbox.add_child(_UiUtil.make_separator())

	_header_hbox = _UiUtil.make_hbox(int(_ref * 0.02), outer_vbox)
	_build_header()

	var scroll := _build_scroll(outer_vbox)

	_rows_vbox = _UiUtil.make_vbox(int(_ref * 0.012), scroll)
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_render_rows()

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	outer_vbox.add_child(btn_row)

## make_tab_row already filtered out re-clicks of the active tab and restyled the
## buttons; this only has to re-render for the new tab.
func _select_tab(tab: int) -> void:
	_active_tab = tab
	if _title_lbl != null:
		_title_lbl.text = _title_for_tab(_active_tab)
	_build_header()
	_render_rows()

func _title_for_tab(tab: int) -> String:
	if _PVE_TABS.has(tab):
		return str((_PVE_TABS[tab] as Dictionary)["title"])
	return "Rifts — Best Tiers" if tab == TAB_SPIRE else "Ranked Leaderboard"

func _build_header() -> void:
	for c in _header_hbox.get_children():
		c.queue_free()
	_add_header_cell(_header_hbox, "#", 0.08)
	_add_header_cell(_header_hbox, "Player", 0.40)
	if _active_tab == TAB_RANKED:
		_add_header_cell(_header_hbox, "Rating", 0.22)
		_add_header_cell(_header_hbox, "W-L", 0.22)
	else:
		var value_header: String = "Best Tier"
		if _PVE_TABS.has(_active_tab):
			value_header = str((_PVE_TABS[_active_tab] as Dictionary)["value"])
		_add_header_cell(_header_hbox, value_header, 0.22)
		_add_header_cell(_header_hbox, "Day", 0.22)

func _add_header_cell(parent: HBoxContainer, text: String, width_frac: float) -> void:
	var lbl := _UiUtil.make_label(text, int(_vh * 0.022))
	lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	lbl.custom_minimum_size = Vector2(_col_w(width_frac), 0)
	parent.add_child(lbl)

## Called by WorldScene whenever a fresh ranked-rating snapshot arrives (TID-373).
func refresh_rows(rows: Array) -> void:
	_rows_cache = rows
	if _active_tab == TAB_RANKED and _rows_vbox != null and is_instance_valid(_rows_vbox):
		_render_rows()

## Called by WorldScene whenever a fresh PvE {spire, coop_clears} snapshot arrives
## (TID-379). `snapshot` mirrors SessionState.get_pve_leaderboards_snapshot().
func refresh_pve_rows(snapshot: Dictionary) -> void:
	_pve_cache = {}
	for board: Variant in snapshot:
		var rows: Variant = snapshot[board]
		_pve_cache[str(board)] = rows if rows is Array else []
	if _active_tab != TAB_RANKED and _rows_vbox != null and is_instance_valid(_rows_vbox):
		_render_rows()

func _current_rows() -> Array:
	if _PVE_TABS.has(_active_tab):
		return _pve_cache.get(str((_PVE_TABS[_active_tab] as Dictionary)["board"]), [])
	if _active_tab == TAB_SPIRE:
		return _pve_cache.get("spire", [])
	return _rows_cache

func _empty_message_for_tab() -> String:
	if _PVE_TABS.has(_active_tab):
		return str((_PVE_TABS[_active_tab] as Dictionary)["empty"])
	if _active_tab == TAB_SPIRE:
		return "No rift tiers cleared yet this session."
	return "No ranked duels played yet this session."

func _render_rows() -> void:
	for c in _rows_vbox.get_children():
		c.queue_free()
	if _active_tab == TAB_SPIRE:
		_render_rift_rows()
		return
	var rows: Array = _current_rows()
	if rows.is_empty():
		var empty_lbl := _UiUtil.make_label(_empty_message_for_tab(), int(_vh * 0.022), Color(0.7, 0.7, 0.7),
				HORIZONTAL_ALIGNMENT_LEFT, _rows_vbox)
		return
	for i in range(rows.size()):
		var row: Variant = rows[i]
		if row is Dictionary:
			_add_row(i + 1, row as Dictionary)

## GID-142: one section per rift (board "rift_<id>", value = best tier cleared).
func _render_rift_rows() -> void:
	var any: bool = false
	for r: Dictionary in _RiftDefs.all():
		var rows: Array = _pve_cache.get("rift_" + str(r["id"]), [])
		if rows.is_empty():
			continue
		any = true
		_UiUtil.make_label(str(r["name"]), int(_vh * 0.024), Color(0.85, 0.5, 1.0), HORIZONTAL_ALIGNMENT_LEFT,
				_rows_vbox)
		for i in range(rows.size()):
			var row: Variant = rows[i]
			if row is Dictionary:
				_add_row(i + 1, row as Dictionary)
	if not any:
		_UiUtil.make_label(_empty_message_for_tab(), int(_vh * 0.022), Color(0.7, 0.7, 0.7),
				HORIZONTAL_ALIGNMENT_LEFT, _rows_vbox)

func _add_row(rank: int, row: Dictionary) -> void:
	var hb := _UiUtil.make_hbox(int(_ref * 0.02), _rows_vbox)

	var rank_lbl := _UiUtil.make_label("#%d" % rank, int(_vh * 0.022))
	rank_lbl.custom_minimum_size = Vector2(_col_w(0.08), 0)
	if rank == 1:
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hb.add_child(rank_lbl)

	var name_lbl := _UiUtil.make_label(str(row.get("name", "Player")), int(_vh * 0.022), Color.WHITE,
			HORIZONTAL_ALIGNMENT_LEFT, hb)
	name_lbl.custom_minimum_size = Vector2(_col_w(0.40), 0)

	if _active_tab == TAB_RANKED:
		var rating_lbl := _UiUtil.make_label(str(int(row.get("rating", 1000))), int(_vh * 0.022), Color(0.6, 1.0, 0.6),
				HORIZONTAL_ALIGNMENT_LEFT, hb)
		rating_lbl.custom_minimum_size = Vector2(_col_w(0.22), 0)

		var wl_lbl := _UiUtil.make_label("%d-%d" % [int(row.get("wins", 0)), int(row.get("losses", 0))],
				int(_vh * 0.022), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, hb)
		wl_lbl.custom_minimum_size = Vector2(_col_w(0.22), 0)
	else:
		var value_lbl := _UiUtil.make_label(str(int(row.get("value", 0))), int(_vh * 0.022), Color(0.6, 1.0, 0.6),
				HORIZONTAL_ALIGNMENT_LEFT, hb)
		value_lbl.custom_minimum_size = Vector2(_col_w(0.22), 0)

		var day_lbl := _UiUtil.make_label(str(int(row.get("day", 0))), int(_vh * 0.022), Color.WHITE,
				HORIZONTAL_ALIGNMENT_LEFT, hb)
		day_lbl.custom_minimum_size = Vector2(_col_w(0.22), 0)

## Column width for a fraction of the panel's inner width. The fractions add up to
## 0.92, and the panel is PANEL_W_FRAC of the viewport; sizing columns off the
## whole viewport pushed the panel off the right edge.
func _col_w(frac: float) -> float:
	return _vw * PANEL_W_FRAC * 0.9 * frac

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_rebuild_ui()
