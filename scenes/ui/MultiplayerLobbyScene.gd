## Co-op lobby overlay (GID-090).
##
## Opened from MenuScene. Lets a player host a session or join one by IP on the
## same LAN, then routes both peers into the shared "madrian" map. Script-only
## overlay (instantiated via .new()), matching SettingsScene/DiagnosticsScene.
extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const _COOP_MAP: String = "madrian"

var _ip_edit: LineEdit
var _status_lbl: Label


func _ready() -> void:
	super._ready()
	_build_ui()
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	# Leave any half-open session if the player backs out before entering the world.
	closed.connect(func() -> void:
		if NetworkManager.is_active():
			NetworkManager.leave()
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_vh = get_viewport().get_visible_rect().size.y
		_vw = get_viewport().get_visible_rect().size.x
		_ref = minf(_vh, _vw)
		var keep_ip: String = _ip_edit.text if _ip_edit != null else "127.0.0.1"
		var keep_status: String = _status_lbl.text if _status_lbl != null else ""
		for c in get_children():
			c.queue_free()
		_build_ui()
		_ip_edit.text = keep_ip
		_status_lbl.text = keep_status


func _build_ui() -> void:
	_build_backdrop(0.72)

	var panel := _build_centered_panel(_vw * 0.6, _vh * 0.62)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	var vbox := _build_margin_vbox(panel, 0.04, 0.03)

	vbox.add_child(_UiUtil.make_title_label("Co-op (Beta)", _vh))
	vbox.add_child(_UiUtil.make_separator())

	var info := _UiUtil.make_body_label(
		"Host a session, or join a host by IP on the same Wi-Fi.", _vh)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var ip_lbl := _UiUtil.make_body_label("Host IP", _vh)
	vbox.add_child(ip_lbl)

	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.add_theme_font_size_override("font_size", int(_vh * 0.028))
	_ip_edit.custom_minimum_size = Vector2(0.0, _vh * 0.07)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_ip_edit)

	vbox.add_child(_UiUtil.make_separator())

	vbox.add_child(_make_button("Host Game", _on_host))
	vbox.add_child(_make_button("Join Game", _on_join))

	_status_lbl = _UiUtil.make_body_label("", _vh)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	vbox.add_child(btn_row)


func _make_button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, _vh * 0.075)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.03))
	btn.pressed.connect(cb)
	return btn


func _on_host() -> void:
	var err: Error = NetworkManager.host()
	if err != OK:
		_set_status("Could not host (error %d)." % err)
		return
	_set_status("Hosting — entering Madrian…")
	SceneManager.enter_map_coop(_COOP_MAP)


func _on_join() -> void:
	var ip: String = _ip_edit.text.strip_edges()
	if ip.is_empty():
		_set_status("Enter the host's IP address first.")
		return
	var err: Error = NetworkManager.join(ip)
	if err != OK:
		_set_status("Could not start joining (error %d)." % err)
		return
	_set_status("Connecting to %s…" % ip)


func _on_connection_succeeded() -> void:
	_set_status("Connected — entering Madrian…")
	SceneManager.enter_map_coop(_COOP_MAP)


func _on_connection_failed() -> void:
	_set_status("Connection failed. Check the IP and that the host is running.")
	NetworkManager.leave()


func _set_status(text: String) -> void:
	if _status_lbl != null:
		_status_lbl.text = text
