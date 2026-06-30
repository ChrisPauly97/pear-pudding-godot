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

# Reconnection / diagnostics (GID-095 / TID-347)
var _recent_box: VBoxContainer
var _wan_box: VBoxContainer
var _retry_row: HBoxContainer
# Friends list (GID-102 / TID-375)
var _friends_box: VBoxContainer
# The join attempt in flight, so a successful connect can be recorded as a recent
# server and a failed one can be retried with one tap.
var _pending_addr: String = ""
var _pending_port: int = 0
var _pending_label: String = ""


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

	var panel := _build_centered_panel(_vw * 0.6, _vh * 0.90)
	panel.add_theme_stylebox_override("panel", _make_dark_glass_style())

	# Outer margin + vbox: scroll area on top, sticky close button on bottom.
	var outer_margin := MarginContainer.new()
	var m: int = int(_ref * 0.04)
	outer_margin.add_theme_constant_override("margin_left",   m)
	outer_margin.add_theme_constant_override("margin_right",  m)
	outer_margin.add_theme_constant_override("margin_top",    m)
	outer_margin.add_theme_constant_override("margin_bottom", m)
	panel.add_child(outer_margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", int(_ref * 0.015))
	outer_margin.add_child(outer_vbox)

	# Scrollable content area.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)
	attach_drag_scroll(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", int(_ref * 0.03))
	scroll.add_child(vbox)

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

	# Friends (GID-102 / TID-375): device-local list, added from the session roster.
	# No presence backend exists, so "online" only means "currently a connected peer
	# in the session you're in right now" — shown honestly as last-seen otherwise.
	var friends: Array = MpProfile.get_friends()
	if not friends.is_empty():
		vbox.add_child(_UiUtil.make_body_label("Friends", _vh))
		_friends_box = VBoxContainer.new()
		_friends_box.add_theme_constant_override("separation", int(_ref * 0.012))
		_friends_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(_friends_box)
		_populate_friends(friends)
		vbox.add_child(_UiUtil.make_separator())

	# Rejoin: one-tap reconnect to a server we were in before (GID-095 / TID-347).
	# The host's stable session id resumes the same world + character.
	var recent: Array = MpProfile.get_recent_servers()
	if not recent.is_empty():
		vbox.add_child(_UiUtil.make_body_label("Rejoin a recent server", _vh))
		_recent_box = VBoxContainer.new()
		_recent_box.add_theme_constant_override("separation", int(_ref * 0.012))
		_recent_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(_recent_box)
		_populate_recent(recent)
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

	# Retry row: hidden until a join attempt times out or fails (TID-347).
	_retry_row = HBoxContainer.new()
	_retry_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_retry_row.visible = false
	_retry_row.add_child(_make_button("Retry", _on_retry))
	vbox.add_child(_retry_row)

	# Play-over-the-internet guidance — collapsed by default (TID-347).
	vbox.add_child(_make_button("Play over the internet ▸", _toggle_wan))
	_wan_box = VBoxContainer.new()
	_wan_box.visible = false
	var wan_text := _UiUtil.make_body_label(
		"LAN only by default. To play across the internet:\n" +
		"• Host: forward UDP port 24565 on your router to this device, then share " +
		"your PUBLIC IP (search \"what is my ip\").\n" +
		"• Joiner: type that public IP into \"Or join by IP\" below.\n" +
		"\"Find Games\" only discovers hosts on the same Wi-Fi, not over the internet.",
		_vh)
	wan_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wan_box.add_child(wan_text)
	vbox.add_child(_wan_box)

	# Close button is pinned outside the scroll so it's always reachable.
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(_UiUtil.make_close_button(_vh, _close))
	outer_vbox.add_child(btn_row)


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
	_start_join(ip, NetworkManager.DEFAULT_PORT, ip)


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
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT
	_start_join(ip, port, str(hd.get("name", ip)))


## Tap a remembered server to reconnect (GID-095 / TID-347).
func _on_rejoin(entry: Dictionary) -> void:
	_save_name()
	var ip: String = str(entry.get("address", ""))
	if ip.is_empty():
		return
	var port: int = int(entry.get("port", NetworkManager.DEFAULT_PORT))
	_start_join(ip, port, str(entry.get("label", ip)))


## Shared join entry point: remembers the attempt (for record-on-success / retry),
## starts the connection, and arms the watchdog.
func _start_join(ip: String, port: int, label: String) -> void:
	_pending_addr = ip
	_pending_port = port
	_pending_label = label
	if _retry_row != null:
		_retry_row.visible = false
	var err: Error = NetworkManager.join(ip, port)
	if err != OK:
		_set_status("Could not start joining (error %d)." % err)
		if _retry_row != null:
			_retry_row.visible = true
		return
	_set_status("Connecting to %s…" % label)
	_arm_join_timeout()


func _on_retry() -> void:
	if _pending_addr == "":
		return
	_start_join(_pending_addr, _pending_port, _pending_label)


func _toggle_wan() -> void:
	if _wan_box != null:
		_wan_box.visible = not _wan_box.visible


## Render one row per saved friend: color swatch + name + status. Display-only —
## no "invite" mechanism (no presence/matchmaking backend exists), and no join-
## shortcut (a friend's server, if known, already shows in the Rejoin list above).
## The token is never shown, only used to check in-session presence.
func _populate_friends(friends: Array) -> void:
	if _friends_box == null:
		return
	for c in _friends_box.get_children():
		c.queue_free()
	# "Online here" is only knowable for peers in the CURRENT session (no global
	# presence service). The lobby itself is pre-connection, so this will normally
	# show "Last seen" — it only flips to "online" if NetworkManager is already
	# active with this friend's token among the connected peers' identities.
	var online_tokens: Array = _online_friend_tokens()
	for f in friends:
		if not f is Dictionary:
			continue
		var fd: Dictionary = f
		var token: String = str(fd.get("token", ""))
		var nm: String = str(fd.get("name", "Player"))
		var color_hex: String = str(fd.get("color_hex", "ffffff"))
		var col: Color = Color.html(color_hex) if Color.html_is_valid(color_hex) else Color.WHITE
		var status: String = "Online here" if online_tokens.has(token) else \
			"Last seen %s" % str(fd.get("last_seen", "—"))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(_ref * 0.012))
		var swatch := ColorRect.new()
		swatch.color = col
		var sz: float = _vh * 0.03
		swatch.custom_minimum_size = Vector2(sz, sz)
		row.add_child(swatch)
		var lbl := _UiUtil.make_body_label("%s — %s" % [nm, status], _vh)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		_friends_box.add_child(row)


## Tokens of saved friends currently visible as connected peers in an active
## session (in-session presence only — there is no global presence/matchmaking
## service). Empty whenever no session is active, which is the common case while
## still in the lobby.
func _online_friend_tokens() -> Array:
	var out: Array = []
	if not NetworkManager.is_active():
		return out
	var world: Node = get_tree().root.get_node_or_null("WorldScene")
	if world == null:
		return out
	var identities: Variant = world.get("_remote_identities")
	if not identities is Dictionary:
		return out
	for pid in (identities as Dictionary).keys():
		var d: Dictionary = (identities as Dictionary)[pid]
		var token: String = str(d.get("token", ""))
		if token != "" and MpProfile.is_friend(token):
			out.append(token)
	return out


## Render one tap-to-rejoin button per remembered server.
func _populate_recent(recent: Array) -> void:
	if _recent_box == null:
		return
	for c in _recent_box.get_children():
		c.queue_free()
	for e in recent:
		if not e is Dictionary:
			continue
		var ed: Dictionary = e
		var label: String = "%s   (%s:%d)" % [
			str(ed.get("label", "Server")), str(ed.get("address", "")), int(ed.get("port", 0))]
		_recent_box.add_child(_make_button(label, _on_rejoin.bind(ed)))


## Watchdog: if neither connection_succeeded nor connection_failed has resolved
## the attempt within the window, give an actionable message (covers silent
## timeouts from a wrong IP, AP isolation, or the host not actually listening).
func _arm_join_timeout() -> void:
	var t: SceneTreeTimer = get_tree().create_timer(12.0)
	t.timeout.connect(func() -> void:
		if not is_instance_valid(self) or not is_inside_tree():
			return  # already connected & transitioned away
		if not NetworkManager.is_active():
			_set_status("Couldn't reach the host. Check: both on the SAME Wi-Fi (or, over the internet, the host forwarded UDP 24565 and you used their public IP), the host tapped Host Game first, and the router allows device-to-device (some networks block this).")
			if _retry_row != null:
				_retry_row.visible = true
	)


func _on_connection_succeeded() -> void:
	# Remember this server so it appears in the Rejoin list next time (TID-347).
	if _pending_addr != "":
		MpProfile.add_recent_server(_pending_addr, _pending_port, _pending_label)
	_set_status("Connected — entering Madrian…")
	SceneManager.enter_map_coop(_COOP_MAP)


func _on_connection_failed() -> void:
	_set_status("Connection failed. Check the IP and that the host is running.")
	if _retry_row != null:
		_retry_row.visible = true
	NetworkManager.leave()


func _set_status(text: String) -> void:
	if _status_lbl != null:
		_status_lbl.text = text
