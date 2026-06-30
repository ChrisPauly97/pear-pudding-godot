## Ranked leaderboard panel (GID-102 / TID-373).
##
## Lists the cached session leaderboard rows (rank, name, rating, W/L) that WorldScene
## maintains in `_leaderboard_rows`, fed by the authority's `recv_leaderboard` RPC.
## Script-only overlay (instantiated via .new()), matching SettingsScene /
## MultiplayerLobbyScene (extends BaseOverlay by path string, viewport-relative,
## rebuilt on resize). Opened from a HUD button in WorldScene — a touch/click target,
## same as the Trade/Spectate/Emote buttons (mobile + desktop parity, CLAUDE.md).
extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _rows_vbox: VBoxContainer = null
var _rows_cache: Array = []

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

	outer_vbox.add_child(_UiUtil.make_title_label("Ranked Leaderboard", _vh))
	outer_vbox.add_child(_UiUtil.make_separator())

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(_ref * 0.02))
	outer_vbox.add_child(header)
	_add_header_cell(header, "#", 0.08)
	_add_header_cell(header, "Player", 0.40)
	_add_header_cell(header, "Rating", 0.22)
	_add_header_cell(header, "W-L", 0.22)

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

func _add_header_cell(parent: HBoxContainer, text: String, width_frac: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	lbl.custom_minimum_size = Vector2(_vw * width_frac, 0)
	parent.add_child(lbl)

## Called by WorldScene whenever a fresh leaderboard snapshot arrives.
func refresh_rows(rows: Array) -> void:
	_rows_cache = rows
	if _rows_vbox != null and is_instance_valid(_rows_vbox):
		_render_rows()

func _render_rows() -> void:
	for c in _rows_vbox.get_children():
		c.queue_free()
	if _rows_cache.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No ranked duels played yet this session."
		empty_lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		_rows_vbox.add_child(empty_lbl)
		return
	for i in range(_rows_cache.size()):
		var row: Variant = _rows_cache[i]
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_vh = get_viewport().get_visible_rect().size.y
		_vw = get_viewport().get_visible_rect().size.x
		_ref = minf(_vh, _vw)
		for c in get_children():
			c.queue_free()
		_build_ui()
