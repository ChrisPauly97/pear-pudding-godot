## Ghost Duel panel (GID-102 / TID-377).
##
## Lists every known session member (from the host's own SessionStore-backed
## SessionState) so the host can pick one to fight as an async, AI-piloted
## snapshot of that member's deck — zero live networking, works even if that
## member is currently offline. Host-only entry point: a client has no local
## SessionState to read (the session file lives only on the authority), which
## mirrors the existing host-only constraint on other session reads
## (WorldScene._setup_session).
##
## Script-only overlay (instantiated via .new()), matching MultiplayerLobbyScene /
## SettingsScene: extends BaseOverlay by path string, viewport-relative, rebuilt
## on NOTIFICATION_RESIZED.
extends "res://scenes/ui/BaseOverlay.gd"


## rows: Array of {token, name, rating} — the caller (WorldScene) builds this from
## SessionStore.get_state().members, excluding the local host's own token. Kept as
## plain data (not a SessionState reference) so this overlay stays decoupled from
## the session-storage layer.
var _rows: Array = []
## Called with a token when "Ghost Duel" is pressed; WorldScene wires this to
## resolve the snapshot (SessionState.get_ghost_snapshot) and call
## SceneManager.enter_ghost_duel.
var on_duel_requested: Callable = Callable()

var _rows_vbox: VBoxContainer = null


func set_rows(rows: Array) -> void:
	_rows = rows
	if _rows_vbox != null and is_instance_valid(_rows_vbox):
		_render_rows()


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	_build_backdrop(0.72, true)

	var panel_w: float = _vw * 0.6
	var panel_h: float = _vh * 0.65
	var panel := _build_centered_panel(panel_w, panel_h)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var outer_vbox := _build_margin_vbox(panel, 0.04, 0.03)

	outer_vbox.add_child(_UiUtil.make_title_label("Ghost Duels", _vh))
	outer_vbox.add_child(_UiUtil.make_body_label(
		"Battle an AI-piloted snapshot of a party member's deck — even while they're offline.", _vh))
	outer_vbox.add_child(_UiUtil.make_separator())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	_rows_vbox = _UiUtil.make_vbox(int(_ref * 0.015), scroll)
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_render_rows()

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	outer_vbox.add_child(btn_row)


func _render_rows() -> void:
	for c in _rows_vbox.get_children():
		c.queue_free()
	if _rows.is_empty():
		var empty_lbl := _UiUtil.make_label("No other party members in this session yet.", int(_vh * 0.022), Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_LEFT, _rows_vbox)
		return
	for row: Variant in _rows:
		if row is Dictionary:
			_add_row(row as Dictionary)


func _add_row(row: Dictionary) -> void:
	var hb := _UiUtil.make_hbox(int(_ref * 0.02), _rows_vbox)

	var name_lbl := _UiUtil.make_label(str(row.get("name", "Player")), int(_vh * 0.024), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, hb)
	name_lbl.custom_minimum_size = Vector2(_vw * 0.28, 0)

	var rating_lbl := _UiUtil.make_label("Rating: %d" % int(row.get("rating", 1000)), int(_vh * 0.022), Color(0.7, 0.85, 1.0), HORIZONTAL_ALIGNMENT_LEFT, hb)
	rating_lbl.custom_minimum_size = Vector2(_vw * 0.18, 0)

	var token: String = str(row.get("token", ""))
	var duel_btn := _UiUtil.make_button("Ghost Duel", Vector2(_vw * 0.16, _vh * 0.06), int(_vh * 0.022))
	duel_btn.pressed.connect(func() -> void:
		if on_duel_requested.is_valid():
			on_duel_requested.call(token)
		_close()
	)
	hb.add_child(duel_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_rebuild_ui()
