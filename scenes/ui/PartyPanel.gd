## Party panel (GID-107 / TID-395): a single discoverable entry point for the
## always-on co-op HUD affordances that used to be individually HUD-positioned
## buttons — Roster, Loot Mode, Stash, Leaderboard, Ghost Duels, Team Duel,
## Dungeon Crawl. Each action keeps its exact prior gating/behavior; this is a
## placement/discoverability change, not a feature change.
##
## Script-only overlay (matches GhostDuelOverlay / PartyStashOverlay / Leaderboard
## Overlay): extends BaseOverlay by path string, instantiated via .new(), built
## from data/Callables the caller (WorldScene) supplies — this file never reaches
## into WorldScene's internals directly, staying decoupled the same way the other
## social overlays already are.
extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

## Roster rows: Array of {text: String, color: Color, token: String,
## clean_name: String, is_friend: bool}. Mirrors the old
## WorldScene._add_roster_row() fields exactly (built by WorldScene).
var roster_rows: Array = []
## Callable(token: String, clean_name: String, color: Color) — add-friend action.
var on_add_friend: Callable = Callable()

var show_loot_mode: bool = false
var loot_mode_label: String = "Loot: First-Opener"
var on_loot_mode_toggle: Callable = Callable()

var show_stash: bool = false
var on_stash: Callable = Callable()

var show_leaderboard: bool = false
var on_leaderboard: Callable = Callable()

var show_ghost_duels: bool = false
var on_ghost_duels: Callable = Callable()

var show_team_duel: bool = false
var on_team_duel: Callable = Callable()

var show_dungeon_crawl: bool = false
var on_dungeon_crawl: Callable = Callable()

var _roster_vbox: VBoxContainer = null
var _loot_btn: Button = null


func refresh_roster(rows: Array) -> void:
	roster_rows = rows
	if _roster_vbox != null and is_instance_valid(_roster_vbox):
		_render_roster()


func refresh_loot_label(label_text: String) -> void:
	loot_mode_label = label_text
	if _loot_btn != null and is_instance_valid(_loot_btn):
		_loot_btn.text = label_text


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	_build_backdrop(0.72, true)

	var panel_w: float = _vw * 0.70
	var panel_h: float = _vh * 0.82
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var outer_vbox := _build_margin_vbox(panel, 0.03, 0.016)
	outer_vbox.add_child(_UiUtil.make_title_label("Party", _vh))
	outer_vbox.add_child(_UiUtil.make_separator())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(_ref * 0.02))
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# ── Roster ──
	var roster_title := Label.new()
	roster_title.text = "Roster"
	roster_title.add_theme_font_size_override("font_size", int(_vh * 0.026))
	content.add_child(roster_title)

	_roster_vbox = VBoxContainer.new()
	_roster_vbox.add_theme_constant_override("separation", int(_vh * 0.008))
	content.add_child(_roster_vbox)
	_render_roster()

	content.add_child(_UiUtil.make_separator())

	# ── Actions ──
	var actions_title := Label.new()
	actions_title.text = "Actions"
	actions_title.add_theme_font_size_override("font_size", int(_vh * 0.026))
	content.add_child(actions_title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_ref * 0.02))
	grid.add_theme_constant_override("v_separation", int(_ref * 0.015))
	content.add_child(grid)

	if show_loot_mode:
		_loot_btn = _add_action_button(grid, loot_mode_label, on_loot_mode_toggle, false)
	if show_stash:
		_add_action_button(grid, "Stash", on_stash, true)
	if show_leaderboard:
		_add_action_button(grid, "Leaderboard", on_leaderboard, true)
	if show_ghost_duels:
		_add_action_button(grid, "Ghost Duels", on_ghost_duels, true)
	if show_team_duel:
		_add_action_button(grid, "Team Duel (2v2)", on_team_duel, true)
	if show_dungeon_crawl:
		_add_action_button(grid, "Dungeon Crawl", on_dungeon_crawl, true)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	outer_vbox.add_child(btn_row)


func _add_action_button(grid: GridContainer, label: String, cb: Callable, close_after: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(_ref * 0.28, _ref * 0.065)
	btn.add_theme_font_size_override("font_size", int(_ref * 0.022))
	btn.pressed.connect(func() -> void:
		if cb.is_valid():
			cb.call()
		if close_after:
			_close()
	)
	grid.add_child(btn)
	return btn


func _render_roster() -> void:
	for c in _roster_vbox.get_children():
		c.queue_free()
	if roster_rows.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Just you so far."
		empty_lbl.add_theme_font_size_override("font_size", int(_vh * 0.02))
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		_roster_vbox.add_child(empty_lbl)
		return
	for row: Variant in roster_rows:
		if row is Dictionary:
			_add_roster_row(row as Dictionary)


func _add_roster_row(row: Dictionary) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(_ref * 0.015))
	_roster_vbox.add_child(hb)

	var color: Color = row.get("color", Color.WHITE)
	var swatch := ColorRect.new()
	swatch.color = Color(color.r, color.g, color.b, 1.0)
	swatch.custom_minimum_size = Vector2(_vh * 0.022, _vh * 0.022)
	hb.add_child(swatch)

	var lbl := Label.new()
	lbl.text = str(row.get("text", ""))
	lbl.add_theme_font_size_override("font_size", int(_vh * 0.022))
	hb.add_child(lbl)

	var token: String = str(row.get("token", ""))
	if token != "":
		var btn := Button.new()
		var sz: float = _vh * 0.026
		btn.custom_minimum_size = Vector2(sz, sz)
		btn.add_theme_font_size_override("font_size", int(_vh * 0.02))
		if bool(row.get("is_friend", false)):
			btn.text = "✓"
			btn.disabled = true
			btn.tooltip_text = "Friend"
		else:
			btn.text = "+"
			btn.tooltip_text = "Add friend"
			var clean_name: String = str(row.get("clean_name", row.get("text", "")))
			btn.pressed.connect(func() -> void:
				if on_add_friend.is_valid():
					on_add_friend.call(token, clean_name, color)
			)
		hb.add_child(btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_vh = get_viewport().get_visible_rect().size.y
		_vw = get_viewport().get_visible_rect().size.x
		_ref = minf(_vh, _vw)
		for c in get_children():
			c.queue_free()
		_build_ui()
