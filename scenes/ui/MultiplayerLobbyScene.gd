## Co-op lobby overlay (GID-090).
##
## Opened from MenuScene. Lets a player host a session or join one by IP on the
## same LAN, then routes both peers into the shared "madrian" map. Script-only
## overlay (instantiated via .new()), matching SettingsScene/DiagnosticsScene.
extends "res://scenes/ui/BaseOverlay.gd"

const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

const _COOP_MAP: String = "madrian"

## Touch-friendly preset tints for the avatar color swatches (TID-342).
const _COLOR_PRESETS: Array[Color] = [
	Color(0.95, 0.45, 0.45),
	Color(0.45, 0.75, 0.95),
	Color(0.55, 0.85, 0.55),
	Color(0.92, 0.82, 0.45),
	Color(0.80, 0.55, 0.92),
	Color(0.97, 0.67, 0.40),
]

var _ip_edit: LineEdit
var _name_edit: LineEdit
var _swatch_row: HBoxContainer
var _status_lbl: Label
var _results_box: VBoxContainer
var _hosts: Array = []


func _ready() -> void:
	super._ready()
	_build_ui()
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.hosts_discovered.connect(_on_hosts_discovered)
	# Leave any half-open session if the player backs out before entering the world.
	closed.connect(func() -> void:
		NetworkManager.stop_discovery()
		if NetworkManager.is_active():
			NetworkManager.leave()
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_save_name()  # don't lose an unsaved edit across the rebuild
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
		"Host a session, find nearby games, or join by IP on the same Wi-Fi.", _vh)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	# Player identity (TID-342): name + avatar color, remembered between launches.
	vbox.add_child(_UiUtil.make_body_label("Your name", _vh))
	_name_edit = LineEdit.new()
	_name_edit.text = MpProfile.get_display_name()
	_name_edit.max_length = 16
	_name_edit.add_theme_font_size_override("font_size", int(_vh * 0.028))
	_name_edit.custom_minimum_size = Vector2(0.0, _vh * 0.07)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_t: String) -> void: _save_name())
	_name_edit.focus_exited.connect(_save_name)
	vbox.add_child(_name_edit)

	vbox.add_child(_UiUtil.make_body_label("Your color", _vh))
	_swatch_row = HBoxContainer.new()
	_swatch_row.add_theme_constant_override("separation", int(_ref * 0.012))
	vbox.add_child(_swatch_row)
	_build_swatches()

	vbox.add_child(_UiUtil.make_separator())

	vbox.add_child(_make_button("Host Game", _on_host))

	vbox.add_child(_UiUtil.make_separator())

	# Discovery: scan the LAN and list hosts to tap-join.
	vbox.add_child(_make_button("Find Games", _on_find))
	_results_box = VBoxContainer.new()
	_results_box.add_theme_constant_override("separation", int(_ref * 0.012))
	_results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_results_box)
	_populate_results()

	vbox.add_child(_UiUtil.make_separator())

	# Manual fallback: join by IP (needed where broadcast is blocked).
	var ip_lbl := _UiUtil.make_body_label("Or join by IP", _vh)
	vbox.add_child(ip_lbl)

	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.add_theme_font_size_override("font_size", int(_vh * 0.028))
	_ip_edit.custom_minimum_size = Vector2(0.0, _vh * 0.07)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_ip_edit)

	vbox.add_child(_make_button("Join by IP", _on_join))

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


## Persist the typed name to the device profile (fallback handled by MpProfile).
func _save_name() -> void:
	if _name_edit != null:
		MpProfile.set_display_name(_name_edit.text)


## Build one swatch button per preset; the current color gets a selected outline.
func _build_swatches() -> void:
	if _swatch_row == null:
		return
	for c in _swatch_row.get_children():
		c.queue_free()
	var current: Color = MpProfile.get_color()
	var sz: float = _vh * 0.06
	for preset in _COLOR_PRESETS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(sz, sz)
		var sb := StyleBoxFlat.new()
		sb.bg_color = preset
		sb.set_corner_radius_all(int(sz * 0.18))
		if preset.is_equal_approx(current):
			sb.border_color = Color.WHITE
			sb.set_border_width_all(max(2, int(sz * 0.12)))
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.pressed.connect(_on_pick_color.bind(preset))
		_swatch_row.add_child(btn)


func _on_pick_color(c: Color) -> void:
	MpProfile.set_color(c)
	_build_swatches()  # redraw selection outline


func _make_button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, _vh * 0.075)
	btn.add_theme_font_size_override("font_size", int(_vh * 0.03))
	btn.pressed.connect(cb)
	return btn


func _on_host() -> void:
	_save_name()
	# Advertise the player's name in LAN discovery so it shows in others' lists.
	NetworkManager.host_label = "%s's game" % MpProfile.get_display_name()
	var err: Error = NetworkManager.host()
	if err != OK:
		_set_status("Could not host (error %d)." % err)
		return
	_set_status("Hosting — entering Madrian…")
	SceneManager.enter_map_coop(_COOP_MAP)


func _on_join() -> void:
	_save_name()
	var ip: String = _ip_edit.text.strip_edges()
	if ip.is_empty():
		_set_status("Enter the host's IP address first.")
		return
	var err: Error = NetworkManager.join(ip)
	if err != OK:
		_set_status("Could not start joining (error %d)." % err)
		return
	_set_status("Connecting to %s…" % ip)
	_arm_join_timeout()


func _on_find() -> void:
	_set_status("Scanning the local network…")
	NetworkManager.start_discovery()


func _on_hosts_discovered(hosts: Array) -> void:
	_hosts = hosts
	if _hosts.is_empty():
		_set_status("No games found. Check you're on the same Wi-Fi, or join by IP.")
	else:
		_set_status("Found %d game(s)." % _hosts.size())
	_populate_results()


func _populate_results() -> void:
	if _results_box == null:
		return
	for c in _results_box.get_children():
		c.queue_free()
	if _hosts.is_empty():
		var none := _UiUtil.make_body_label("No games found yet — tap Find Games.", _vh)
		_results_box.add_child(none)
		return
	for h in _hosts:
		var hd: Dictionary = h
		var label: String = "%s   (%s)   %d player(s)" % [
			str(hd.get("name", "Host")), str(hd.get("ip", "")), int(hd.get("players", 1))]
		_results_box.add_child(_make_button(label, _on_join_discovered.bind(hd)))


func _on_join_discovered(hd: Dictionary) -> void:
	_save_name()
	var ip: String = str(hd.get("ip", ""))
	if ip.is_empty():
		return
	var port: int = int(hd.get("game_port", 0))
	var err: Error = NetworkManager.join(ip, port) if port > 0 else NetworkManager.join(ip)
	if err != OK:
		_set_status("Could not join (error %d)." % err)
		return
	_set_status("Connecting to %s…" % ip)
	_arm_join_timeout()


## Watchdog: if neither connection_succeeded nor connection_failed has resolved
## the attempt within the window, give an actionable message (covers silent
## timeouts from a wrong IP, AP isolation, or the host not actually listening).
func _arm_join_timeout() -> void:
	var t: SceneTreeTimer = get_tree().create_timer(12.0)
	t.timeout.connect(func() -> void:
		if not is_instance_valid(self) or not is_inside_tree():
			return  # already connected & transitioned away
		if not NetworkManager.is_active():
			_set_status("Couldn't reach the host. Check: both on the SAME Wi-Fi, the IP is the host's Wi-Fi address, the host tapped Host Game first, and the router allows device-to-device (some networks block this).")
	)


func _on_connection_succeeded() -> void:
	_set_status("Connected — entering Madrian…")
	SceneManager.enter_map_coop(_COOP_MAP)


func _on_connection_failed() -> void:
	_set_status("Connection failed. Check the IP and that the host is running.")
	NetworkManager.leave()


func _set_status(text: String) -> void:
	if _status_lbl != null:
		_status_lbl.text = text
