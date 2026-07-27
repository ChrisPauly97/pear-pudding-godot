## Session social & economy surface: emotes, world pings, party chat, card
## trading and gifting, the shared party stash, and the async auction house.
##
## A child node of WorldScene, registered with NetSync as an RPC handler target
## so the `_on_*` entry points below are reached exactly as they were when they
## lived in WorldScene itself. Everything world-side is reached via `_world`.
extends Node

## The WorldScene that owns this module. Everything the module needs from
## the world itself — the player node, the HUD, the entity tables — is
## reached through it. Sibling modules are reached as _world.<accessor>.
var _world: Node = null

const UiFx = preload("res://scenes/ui/UiFx.gd")
const WorldHUD          = preload("res://scenes/world/WorldHUD.gd")
const _AuctionHouseOverlay = preload("res://scenes/ui/AuctionHouseOverlay.gd")
const _AuctionSync = preload("res://game_logic/net/AuctionSync.gd")
const _AuctionTransfer = preload("res://game_logic/net/AuctionTransfer.gd")
const _ChatSync = preload("res://game_logic/net/ChatSync.gd")
const _GhostDuelOverlay  = preload("res://scenes/ui/GhostDuelOverlay.gd")
const _PartyStashOverlay = preload("res://scenes/ui/PartyStashOverlay.gd")
const _SocialSync = preload("res://game_logic/net/SocialSync.gd")
const _StashTransfer = preload("res://game_logic/net/StashTransfer.gd")
const _TradeSync = preload("res://game_logic/net/TradeSync.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _auction_cache: Array = []            # last-known listings snapshot
var _auction_overlay: Node = null         # AuctionHouseOverlay instance, nil when closed
var _chat_lines: Array[Dictionary] = []    # retained {name, color, text} rows, capped
var _chat_log_panel: Control = null        # outer panel (always visible while in co-op)
var _chat_log_vbox: VBoxContainer = null   # scrolling log of chat lines
var _chat_quick_panel: Control = null      # quick-chat preset button row; nil when closed
var _chat_send_btn: Button = null          # send button next to the free-text input
var _chat_toggle_btn: Button = null        # HUD button: opens quick-chat row + reveals input (mobile parity)
var _emote_btn: Button = null            # HUD button that opens the emote wheel
var _emote_label_self: Label3D = null   # local avatar emote bubble
var _emote_timer_self: float = 0.0      # local avatar emote bubble countdown
var _emote_wheel_panel: Control = null   # the radial preset panel; nil when closed
var _ghost_duel_overlay: Node = null
var _pending_trade: Dictionary = {}      # active trade offer held by authority
var _ping_btn: Button = null             # HUD toggle button for ping mode
var _ping_markers: Array[Node3D] = []    # active world-space ping markers
var _stash_cache: Dictionary = {"cards": [], "coins": 0}  # last-known stash snapshot
var _stash_overlay: Node = null           # PartyStashOverlay instance, nil when closed
var _trade_target_peer: int = -1         # peer we'd trade with (nearest in range)
var _trade_window_mine: Button = null    # "Trade" HUD button (proximity-gated)

func _ensure_social_buttons() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	# Social strip (GID-107 / TID-397): Emote / Ping / Chat share one compact,
	# registry-backed cluster (WorldHUD.ZONE_SOCIAL) instead of three buttons that
	# happen to share a y-coordinate by hand-picked position.
	if _emote_btn == null or not is_instance_valid(_emote_btn):
		_emote_btn = _world._world_hud.register_action("emote", ":)", WorldHUD.ZONE_SOCIAL,
			_toggle_emote_wheel, Callable(), Vector2(vh * 0.08, vh * 0.06))
		_emote_btn.tooltip_text = "Emote"
		_emote_btn.add_theme_font_size_override("font_size", int(vh * 0.026))
	if _ping_btn == null or not is_instance_valid(_ping_btn):
		# Built directly (not via register_action) since it needs a `.toggled`
		# connection, not a simple `.pressed` callback — same reasoning as the
		# Ranked toggle in _ensure_challenge_button().
		_ping_btn = _UiUtil.make_button("Ping", Vector2(vh * 0.10, vh * 0.06), int(vh * 0.024))
		_ping_btn.tooltip_text = "Toggle ping mode — tap the world to place a ping"
		_ping_btn.toggle_mode = true
		_ping_btn.toggled.connect(func(on: bool) -> void: _world._ping_mode_active = on)
		var social_zone: Container = _world._world_hud.get_zone_container(WorldHUD.ZONE_SOCIAL)
		if social_zone != null:
			social_zone.add_child(_ping_btn)
		else:
			_world._hud.add_child(_ping_btn)
		UiFx.attach(_ping_btn)
	# Trade / Spectate (GID-107 / TID-396): registered into WorldHUD.ZONE_CONTEXT —
	# the shared contextual bar — instead of each computing its own raw position.
	if _trade_window_mine == null or not is_instance_valid(_trade_window_mine):
		_trade_window_mine = _world._world_hud.register_action("trade", "Trade", WorldHUD.ZONE_CONTEXT,
			_open_trade_offer, Callable(), Vector2(vh * 0.22, vh * 0.06))
		_trade_window_mine.hide()
	if _world.coop_pvp._spectate_btn == null or not is_instance_valid(_world.coop_pvp._spectate_btn):
		_world.coop_pvp._spectate_btn = _world._world_hud.register_action("spectate", "Spectate Duel", WorldHUD.ZONE_CONTEXT,
			_world.coop_pvp._request_spectate, Callable(), Vector2(vh * 0.28, vh * 0.06))
		_world.coop_pvp._spectate_btn.hide()
	# Leaderboard, Stash, and Auction (GID-102 / TID-373, TID-376, TID-378): now
	# Party-panel actions (GID-107 / TID-395; Auction folded in by BID-042)
	# instead of their own standalone always-visible buttons.


## Ghost Duels (GID-102 / TID-377). Host-only: gated on SessionStore.is_open()
## rather than NetworkManager.is_active() — a client never opens SessionStore
## locally (see WorldScene._setup_session). Now a Party-panel action (GID-107 /
## TID-395) whose show_ghost_duels condition reproduces this same gate on open.

## Builds the {token, name, rating} row list from the host's own SessionState and
## opens (or closes) the GhostDuelOverlay. The local host's own token is excluded
## — dueling your own live snapshot is a no-op curiosity, not the intended use.

func _toggle_ghost_duel_overlay() -> void:
	if _ghost_duel_overlay != null and is_instance_valid(_ghost_duel_overlay):
		_ghost_duel_overlay.queue_free()
		_ghost_duel_overlay = null
		return
	if not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var local_token: String = MpProfile.get_token()
	var rows: Array = []
	for token in st.members.keys():
		var t: String = str(token)
		if t == local_token:
			continue
		var rec: Dictionary = st.get_member(t)
		if rec.is_empty():
			continue
		rows.append({
			"token": t,
			"name": str(rec.get("display_name", "Player")),
			"rating": int(rec.get("pvp_rating", 1000)),
		})
	var overlay := _GhostDuelOverlay.new()
	overlay.set_rows(rows)
	overlay.on_duel_requested = func(token: String) -> void:
		var snapshot: Dictionary = st.get_ghost_snapshot(token)
		if snapshot.is_empty():
			GameBus.hud_message_requested.emit("That ghost's deck couldn't be resolved.")
			return
		SceneManager.enter_ghost_duel(snapshot)
	overlay.closed.connect(func() -> void:
		_ghost_duel_overlay = null
		overlay.queue_free())
	_world._hud.add_child(overlay)
	_ghost_duel_overlay = overlay


## GID-107 / TID-396 priority rule: the world-interact prompt always wins the shared
## contextual slot over Trade/Spectate, same as it does over Challenge above.

func _update_social_proximity() -> void:
	if _world._player == null:
		return
	if _world._world_hud != null and _world._world_hud.is_interact_visible():
		if _trade_window_mine != null and is_instance_valid(_trade_window_mine):
			_trade_window_mine.hide()
		if _world.coop_pvp._spectate_btn != null and is_instance_valid(_world.coop_pvp._spectate_btn):
			_world.coop_pvp._spectate_btn.hide()
		return
	var range_world: float = _world._CHALLENGE_RANGE * IsoConst.TILE_SIZE
	var nearest_pid: int = -1
	var nearest_d: float = range_world
	for pid in _world._remote_player_nodes.keys():
		var rp: Node3D = _world._valid_node3d(_world._remote_player_nodes[pid])
		if not is_instance_valid(rp) or not rp.visible:
			continue
		var d: float = Vector2(rp.position.x, rp.position.z).distance_to(
			Vector2(_world._player.position.x, _world._player.position.z))
		if d < nearest_d:
			nearest_d = d
			nearest_pid = int(pid)
	_trade_target_peer = nearest_pid
	if _trade_window_mine != null and is_instance_valid(_trade_window_mine):
		_trade_window_mine.visible = nearest_pid != -1 and _world._pending_challenge_from == -1 \
			and _world.coop_pvp._pending_wager_from == -1
	if _world.coop_pvp._spectate_btn != null and is_instance_valid(_world.coop_pvp._spectate_btn):
		_world.coop_pvp._spectate_btn.visible = _world._pvp_active_peers.size() >= 2


# ── TID-365: Emotes ────────────────────────────────────────────────────────────

func _toggle_emote_wheel() -> void:
	if _emote_wheel_panel != null and is_instance_valid(_emote_wheel_panel):
		_emote_wheel_panel.queue_free()
		_emote_wheel_panel = null
		return
	_show_emote_wheel()

func _show_emote_wheel() -> void:
	if _emote_wheel_panel != null and is_instance_valid(_emote_wheel_panel):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var panel := PanelContainer.new()
	var style := _UiUtil.make_style(Color(0.05, 0.05, 0.1, 0.90), 8)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(vp.x - vh * 0.52, vh * 0.66)
	_world._hud.add_child(panel)
	_emote_wheel_panel = panel
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(vh * 0.010))
	grid.add_theme_constant_override("v_separation", int(vh * 0.010))
	panel.add_child(grid)
	var emote_ids: Array[String] = _SocialSync.EMOTE_IDS
	for eid: String in emote_ids:
		var label: String = str(_SocialSync.EMOTE_LABELS.get(eid, eid))
		var btn := _UiUtil.make_button(label, Vector2(vh * 0.14, vh * 0.055), int(vh * 0.020))
		var captured: String = eid
		btn.pressed.connect(func() -> void:
			if _emote_wheel_panel != null and is_instance_valid(_emote_wheel_panel):
				_emote_wheel_panel.queue_free()
				_emote_wheel_panel = null
			_send_emote(captured)
		)
		grid.add_child(btn)

func _send_emote(emote_id: String) -> void:
	if _world._net_sync == null or not _world._coop_active:
		return
	var payload: Array = _SocialSync.encode_emote(emote_id, _world.map_name)
	_world._net_sync.rpc("recv_emote", payload)
	var label_text: String = str(_SocialSync.EMOTE_LABELS.get(emote_id, emote_id))
	_show_emote_self(label_text)

func _show_emote_self(text: String) -> void:
	if _emote_label_self == null or not is_instance_valid(_emote_label_self):
		_emote_label_self = Label3D.new()
		_emote_label_self.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_emote_label_self.font_size = 28
		_emote_label_self.modulate = Color(1.0, 1.0, 0.8)
		if _world._player != null:
			_world._player.add_child(_emote_label_self)
			_emote_label_self.position = Vector3(0.0, 2.0, 0.0)
	if _emote_label_self != null and is_instance_valid(_emote_label_self):
		_emote_label_self.text = text
		_emote_label_self.visible = true
	_emote_timer_self = _SocialSync.EMOTE_DURATION

func _tick_emote_self(delta: float) -> void:
	if _emote_timer_self > 0.0:
		_emote_timer_self -= delta
		if _emote_timer_self <= 0.0 and _emote_label_self != null \
				and is_instance_valid(_emote_label_self):
			_emote_label_self.visible = false

func _on_emote_received(sender: int, payload: Array) -> void:
	var d: Dictionary = _SocialSync.decode_emote(payload)
	var sender_map: String = str(d.get("map", ""))
	if sender_map != "" and sender_map != _world.map_name:
		return
	var rp: Node = _world._valid_node(_world._remote_player_nodes.get(sender))
	if not is_instance_valid(rp):
		return
	var emote_id: String = str(d.get("emote_id", ""))
	var label_text: String = str(_SocialSync.EMOTE_LABELS.get(emote_id, emote_id))
	if rp.has_method("show_emote"):
		rp.call("show_emote", label_text)


# ── TID-365: World-space pings ─────────────────────────────────────────────────

func _handle_ping_tap(screen_pos: Vector2) -> void:
	if _world._camera == null:
		return
	var ray_origin: Vector3 = _world._camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = _world._camera.project_ray_normal(screen_pos)
	if abs(ray_dir.y) < 0.0001:
		return
	var t: float = -ray_origin.y / ray_dir.y
	var world_pos: Vector3 = ray_origin + t * ray_dir
	var my_col: Color = MpProfile.get_color()
	var hex: String = "#%02x%02x%02x" % [
		int(my_col.r * 255), int(my_col.g * 255), int(my_col.b * 255)]
	_send_ping(world_pos.x, world_pos.z, _SocialSync.PING_PLACE, hex)

func _send_ping(wx: float, wz: float, kind: String, color_hex: String) -> void:
	if _world._net_sync == null or not _world._coop_active:
		return
	var payload: Array = _SocialSync.encode_ping(wx, wz, kind, color_hex, _world.map_name)
	_world._net_sync.rpc("recv_ping", payload)
	_spawn_ping_marker(wx, wz, kind, color_hex)

func _on_ping_received(sender: int, payload: Array) -> void:
	var d: Dictionary = _SocialSync.decode_ping(payload)
	var sender_map: String = str(d.get("map", ""))
	if sender_map != "" and sender_map != _world.map_name:
		return
	var wx: float = float(d.get("x", 0.0))
	var wz: float = float(d.get("z", 0.0))
	var kind: String = str(d.get("kind", _SocialSync.PING_PLACE))
	var col_hex: String = str(d.get("color_hex", "#ffffff"))
	_spawn_ping_marker(wx, wz, kind, col_hex)

func _spawn_ping_marker(wx: float, wz: float, _kind: String, color_hex: String) -> Node3D:
	var wy: float = _world.get_terrain_height(wx, wz) + 0.3
	var root := Node3D.new()
	root.position = Vector3(wx, wy, wz)
	_world._entity_root.add_child(root)
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.30
	torus.outer_radius = 0.45
	torus.rings = 10
	torus.ring_segments = 12
	mesh_inst.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var c: Color = Color.html(color_hex)
	mat.albedo_color = Color(c.r, c.g, c.b, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(c.r, c.g, c.b)
	mat.emission_energy_multiplier = 1.5
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)
	var tw: Tween = create_tween().set_loops(3)
	tw.tween_property(root, "scale", Vector3(1.4, 1.0, 1.4), 0.4)
	tw.tween_property(root, "scale", Vector3(0.8, 1.0, 0.8), 0.4)
	root.set_meta("ping_timer", _SocialSync.PING_DURATION)
	_ping_markers.append(root)
	return root

func _tick_ping_markers(delta: float) -> void:
	var to_remove: Array[Node3D] = []
	for m: Node3D in _ping_markers:
		if not is_instance_valid(m):
			to_remove.append(m)
			continue
		var t: float = float(m.get_meta("ping_timer", 0.0)) - delta
		m.set_meta("ping_timer", t)
		if t <= 0.0:
			m.queue_free()
			to_remove.append(m)
	for m: Node3D in to_remove:
		_ping_markers.erase(m)


# ── TID-374: Party chat ──────────────────────────────────────────────────────
# Quick-chat presets (reuses the emote-wheel GridContainer pattern) plus an
# optional free-text LineEdit, with a scrolling log panel. The log panel stays
# always-visible while in co-op (simplest option, matches the always-visible
# party bounty panel) rather than auto-fading — no extra show/hide state to
# manage, and chat is low-frequency enough that it won't clutter the screen.

func _ensure_chat_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y

	# Scrolling log panel, upper-left-ish (clear of the party bounty panel which
	# sits at vp.y * 0.50; chat log sits above it).
	if _chat_log_panel == null or not is_instance_valid(_chat_log_panel):
		var outer := PanelContainer.new()
		outer.name = "ChatLogPanel"
		outer.position = Vector2(vp.x * 0.012, vh * 0.16)
		outer.custom_minimum_size = Vector2(vp.x * 0.26, vh * 0.30)
		var style := _UiUtil.make_style(Color(0.04, 0.04, 0.08, 0.78), 6)
		outer.add_theme_stylebox_override("panel", style)
		_world._hud.add_child(outer)
		_chat_log_panel = outer
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(vp.x * 0.26, vh * 0.30)
		outer.add_child(scroll)
		var vbox := _UiUtil.make_vbox(int(vh * 0.004), scroll)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_chat_log_vbox = vbox

	# HUD toggle button: opens the quick-chat row and reveals the free-text input
	# (mobile parity — desktop also has the Enter-key shortcut below). Part of the
	# social strip (GID-107 / TID-397) alongside Emote/Ping — see _ensure_social_buttons().
	if _chat_toggle_btn == null or not is_instance_valid(_chat_toggle_btn):
		_chat_toggle_btn = _world._world_hud.register_action("chat", "Chat", WorldHUD.ZONE_SOCIAL,
			_toggle_chat_quick_panel, Callable(), Vector2(vh * 0.10, vh * 0.06))
		_chat_toggle_btn.tooltip_text = "Open chat (or press Enter)"
		_chat_toggle_btn.add_theme_font_size_override("font_size", int(vh * 0.024))

	# Free-text input + send button. Visible by default on desktop; mobile
	# users reveal it via the Chat HUD button (parity is satisfied either way
	# since both platforms can always tap "Chat" — desktop additionally gets
	# the Enter-key shortcut to focus it directly).
	if _world._chat_input == null or not is_instance_valid(_world._chat_input):
		_world._chat_input = LineEdit.new()
		_world._chat_input.placeholder_text = "Say something…"
		_world._chat_input.custom_minimum_size = Vector2(vp.x * 0.30, vh * 0.05)
		_world._chat_input.position = Vector2(vp.x * 0.012, vh * 0.93)
		_world._chat_input.add_theme_font_size_override("font_size", int(vh * 0.020))
		_world._chat_input.text_submitted.connect(func(_t: String) -> void: _submit_chat_input())
		_world._hud.add_child(_world._chat_input)
	if _chat_send_btn == null or not is_instance_valid(_chat_send_btn):
		_chat_send_btn = _UiUtil.make_button("Send", Vector2(vh * 0.10, vh * 0.05), int(vh * 0.020), _submit_chat_input, _world._hud)
		_chat_send_btn.position = Vector2(vp.x * 0.32, vh * 0.93)
		UiFx.attach(_chat_send_btn)

func _toggle_chat_quick_panel() -> void:
	if _chat_quick_panel != null and is_instance_valid(_chat_quick_panel):
		_chat_quick_panel.queue_free()
		_chat_quick_panel = null
		return
	_show_chat_quick_panel()

func _show_chat_quick_panel() -> void:
	if _chat_quick_panel != null and is_instance_valid(_chat_quick_panel):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var panel := PanelContainer.new()
	var style := _UiUtil.make_style(Color(0.05, 0.05, 0.1, 0.90), 8)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(vp.x - vh * 0.40, vh * 0.66)
	_world._hud.add_child(panel)
	_chat_quick_panel = panel
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(vh * 0.010))
	grid.add_theme_constant_override("v_separation", int(vh * 0.010))
	panel.add_child(grid)
	var presets: Array[String] = _ChatSync.QUICK_PRESETS
	for preset: String in presets:
		var btn := _UiUtil.make_button(preset, Vector2(vh * 0.18, vh * 0.055), int(vh * 0.018))
		var captured: String = preset
		btn.pressed.connect(func() -> void:
			if _chat_quick_panel != null and is_instance_valid(_chat_quick_panel):
				_chat_quick_panel.queue_free()
				_chat_quick_panel = null
			_send_chat_quick(captured)
		)
		grid.add_child(btn)
	# Mobile parity: opening the quick-chat row also surfaces the free-text
	# entry point, so a touch-only user can reach both from one "Chat" tap.
	if _world._chat_input != null and is_instance_valid(_world._chat_input):
		_world._chat_input.grab_focus()

func _submit_chat_input() -> void:
	if _world._chat_input == null or not is_instance_valid(_world._chat_input):
		return
	var raw: String = _world._chat_input.text
	_world._chat_input.text = ""
	if raw.strip_edges() == "":
		return
	_send_chat_text(raw)

func _send_chat_quick(preset: String) -> void:
	if _world._net_sync == null or not _world._coop_active:
		return
	var payload: Array = _ChatSync.encode_quick(preset, _world.map_name)
	_world._net_sync.rpc("recv_chat", payload)
	var d: Dictionary = _ChatSync.decode(payload)
	_append_chat_line(MpProfile.get_display_name(), MpProfile.get_color(), str(d.get("text", preset)))

func _send_chat_text(raw_text: String) -> void:
	if _world._net_sync == null or not _world._coop_active:
		return
	var payload: Array = _ChatSync.encode_text(raw_text, _world.map_name)
	_world._net_sync.rpc("recv_chat", payload)
	var d: Dictionary = _ChatSync.decode(payload)
	_append_chat_line(MpProfile.get_display_name(), MpProfile.get_color(), str(d.get("text", "")))


## Same-map filter mirrors `_on_emote_received`: a message from a peer on a
## different map is dropped rather than shown-but-tagged, for HUD consistency
## with how emotes already behave (an off-map peer's expression never appears).

func _on_chat_received(sender: int, payload: Array) -> void:
	var d: Dictionary = _ChatSync.decode(payload)
	var sender_map: String = str(d.get("map", ""))
	if sender_map != "" and sender_map != _world.map_name:
		return
	var id: Dictionary = _world._remote_identities.get(sender, {})
	var nm: String = str(id.get("name", "Player"))
	var col: Color = id.get("color", Color(0.7, 0.85, 1.0))
	_append_chat_line(nm, col, str(d.get("text", "")))

func _append_chat_line(sender_name: String, color: Color, text: String) -> void:
	if text == "":
		return
	if _chat_log_vbox == null or not is_instance_valid(_chat_log_vbox):
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	var lbl := _UiUtil.make_label("[%s] %s: %s" % [Time.get_time_string_from_system().substr(0, 5), sender_name, text], int(vh * 0.016))
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_log_vbox.add_child(lbl)
	_chat_lines.append({"name": sender_name, "color": color, "text": text})
	while _chat_lines.size() > _ChatSync.LOG_MAX_LINES:
		_chat_lines.pop_front()
		if _chat_log_vbox.get_child_count() > 0:
			_chat_log_vbox.get_child(0).queue_free()


# ── TID-366: Card trading & gifting ─────────────────────────────────────────────

func _open_trade_offer() -> void:
	if _trade_target_peer == -1 or _world._net_sync == null:
		return
	var deck: Array = _world._local_deck_for_net()
	if deck.is_empty():
		_world._show_tip("No cards in deck to trade.")
		return
	var top_card: Dictionary = {}
	for c: Variant in deck:
		if c is Dictionary and not _TradeSync.is_card_instance_unique(c as Dictionary):
			top_card = c as Dictionary
			break
	if top_card.is_empty():
		_world._show_tip("No tradeable cards — unique cards can't be traded.")
		return
	var card_uid: String = str(top_card.get("uid", ""))
	if card_uid == "":
		_world._show_tip("No valid card UID.")
		return
	var trade_id: String = "%d_%d_%d" % [
		multiplayer.get_unique_id(), _trade_target_peer, Time.get_ticks_msec()]
	var payload: Dictionary = _TradeSync.encode_offer(
		trade_id,
		multiplayer.get_unique_id(),
		_trade_target_peer,
		card_uid,
		0, 0)
	if NetworkManager.is_host():
		_on_trade_offer_submitted(multiplayer.get_unique_id(), payload)
	else:
		_world._net_sync.rpc_id(1, "submit_trade_offer", payload)
	_world._show_tip("Trade offer sent…")

func _on_trade_offer_submitted(sender: int, payload: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var offer: Dictionary = _TradeSync.decode_offer(payload)
	if offer.is_empty():
		return
	var trade_id: String = str(offer.get("trade_id", ""))
	var target_peer: int = int(offer.get("target_peer", -1))
	var initiator_peer: int = int(offer.get("initiator_peer", sender))
	var card_uid: String = str(offer.get("card_uid", ""))
	var token_init: String = str(_world._session_token_by_peer.get(initiator_peer,
		MpProfile.get_token() if initiator_peer == multiplayer.get_unique_id() else ""))
	var st = SessionStore.get_state()
	var valid: bool = false
	if st != null and token_init != "":
		var rec: Dictionary = st.get_member(token_init)
		var owned: Array = rec.get("owned_cards", []) as Array
		for card: Variant in owned:
			if card is Dictionary and str((card as Dictionary).get("uid", "")) == card_uid:
				valid = not _TradeSync.is_card_instance_unique(card as Dictionary)
				break
	if not valid:
		var cancel: Dictionary = _TradeSync.encode_update(
			trade_id, _TradeSync.STATUS_CANCELLED, {})
		if _world._net_sync != null:
			_world._net_sync.rpc_id(initiator_peer, "recv_trade_update", cancel)
		return
	_pending_trade = offer
	var update: Dictionary = _TradeSync.encode_update(
		trade_id, _TradeSync.STATUS_PROPOSED, offer)
	if target_peer == multiplayer.get_unique_id():
		_on_trade_update_received(update)
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(target_peer, "recv_trade_update", update)

func _on_trade_confirm_submitted(sender: int, trade_id: String, confirmed: bool) -> void:
	if not NetworkManager.is_host():
		return
	if str(_pending_trade.get("trade_id", "")) != trade_id:
		return
	var offer: Dictionary = _pending_trade.duplicate(true)
	_pending_trade = {}
	var init_p: int = int(offer.get("initiator_peer", -1))
	var tgt_p: int = int(offer.get("target_peer", -1))
	if not confirmed:
		var cancel: Dictionary = _TradeSync.encode_update(
			trade_id, _TradeSync.STATUS_CANCELLED, {})
		if init_p == multiplayer.get_unique_id():
			_on_trade_update_received(cancel)
		elif _world._net_sync != null:
			_world._net_sync.rpc_id(init_p, "recv_trade_update", cancel)
		return
	var card_uid: String = str(offer.get("card_uid", ""))
	var st = SessionStore.get_state()
	if st != null:
		var token_i: String = str(_world._session_token_by_peer.get(init_p,
			MpProfile.get_token() if init_p == multiplayer.get_unique_id() else ""))
		var token_t: String = str(_world._session_token_by_peer.get(tgt_p,
			MpProfile.get_token() if tgt_p == multiplayer.get_unique_id() else ""))
		_transfer_card_in_session(st, token_i, token_t, card_uid)
	var complete: Dictionary = _TradeSync.encode_update(
		trade_id, _TradeSync.STATUS_COMPLETED, offer)
	if init_p == multiplayer.get_unique_id():
		_on_trade_update_received(complete)
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(init_p, "recv_trade_update", complete)
	if tgt_p == multiplayer.get_unique_id():
		_on_trade_update_received(complete)
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(tgt_p, "recv_trade_update", complete)

func _transfer_card_in_session(st: RefCounted, giver_token: String, target_token: String, card_uid: String) -> void:
	if giver_token == "" or target_token == "":
		return
	var g_rec: Dictionary = st.get_member(giver_token)
	var t_rec: Dictionary = st.get_member(target_token)
	if g_rec.is_empty() or t_rec.is_empty():
		return
	var g_owned: Array = g_rec.get("owned_cards", []) as Array
	var g_deck: Array = g_rec.get("player_deck", []) as Array
	var card_inst: Dictionary = {}
	var found_idx: int = -1
	for i: int in range(g_owned.size() - 1, -1, -1):
		var c: Variant = g_owned[i]
		if c is Dictionary and str((c as Dictionary).get("uid", "")) == card_uid:
			found_idx = i
			card_inst = (c as Dictionary).duplicate(true)
			break
	if found_idx == -1:
		return
	if _TradeSync.is_card_instance_unique(card_inst):
		return
	g_owned.remove_at(found_idx)
	g_deck.erase(card_uid)
	g_rec["owned_cards"] = g_owned
	g_rec["player_deck"] = g_deck
	var new_uid: String = card_uid + "_gift_" + target_token.substr(0, 4)
	card_inst["uid"] = new_uid
	var t_owned: Array = t_rec.get("owned_cards", []) as Array
	t_owned.append(card_inst)
	t_rec["owned_cards"] = t_owned
	st.update_member(giver_token, g_rec)
	st.update_member(target_token, t_rec)
	SessionStore.mark_dirty()

func _on_trade_update_received(payload: Dictionary) -> void:
	var update: Dictionary = _TradeSync.decode_update(payload)
	var status: String = str(update.get("status", ""))
	var trade_id: String = str(update.get("trade_id", ""))
	match status:
		_TradeSync.STATUS_PROPOSED:
			var detail: Dictionary = update.get("detail", {}) as Dictionary
			_show_trade_accept_panel(trade_id, detail)
		_TradeSync.STATUS_COMPLETED:
			SceneManager.show_toast("Trade Complete", "Card transferred successfully!")
		_TradeSync.STATUS_CANCELLED:
			_world._show_tip("Trade cancelled.")

func _show_trade_accept_panel(trade_id: String, offer: Dictionary) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var prompt: Dictionary = _world._build_prompt(182, 0.02)
	var layer: CanvasLayer = prompt["layer"]
	var vbox: VBoxContainer = prompt["vbox"]
	var lbl := Label.new()
	var card_uid: String = str(offer.get("card_uid", "unknown"))
	lbl.text = "Trade offer received!\nCard: %s\nAccept?" % card_uid
	lbl.add_theme_font_size_override("font_size", int(vh * 0.026))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	var row := _UiUtil.make_hbox(int(vh * 0.03), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var captured_id: String = trade_id
	var accept_btn := _UiUtil.make_button("Accept", Vector2(vh * 0.18, vh * 0.06), int(vh * 0.024))
	accept_btn.pressed.connect(func() -> void:
		layer.queue_free()
		if NetworkManager.is_host():
			_on_trade_confirm_submitted(multiplayer.get_unique_id(), captured_id, true)
		elif _world._net_sync != null:
			_world._net_sync.rpc_id(1, "submit_trade_confirm", captured_id, true)
	)
	row.add_child(accept_btn)
	var decline_btn := _UiUtil.make_button("Decline", Vector2(vh * 0.18, vh * 0.06), int(vh * 0.024))
	decline_btn.pressed.connect(func() -> void:
		layer.queue_free()
		if NetworkManager.is_host():
			_on_trade_confirm_submitted(multiplayer.get_unique_id(), captured_id, false)
		elif _world._net_sync != null:
			_world._net_sync.rpc_id(1, "submit_trade_confirm", captured_id, false)
	)
	row.add_child(decline_btn)


# ── GID-102 / TID-376: Shared party stash ───────────────────────────────────────
# A session-owned chest any member can deposit into / withdraw from — unlike trading,
# this is global to the session (no proximity gate). Transfer logic delegates to the
# pure, unit-tested StashTransfer helper; only the authority mutates SessionState.

## Resolve the local token for `peer_id` — the identity token map for remote peers,
## or our own MpProfile token when the sender is us (host acting on its own behalf).

func _stash_token_for_peer(peer_id: int) -> String:
	return str(_world._session_token_by_peer.get(peer_id,
		MpProfile.get_token() if peer_id == multiplayer.get_unique_id() else ""))


## Authority-side guard shared by every session-scoped RPC (party stash, auction
## house): the receiver must be the host, the session must be open, and the
## sender must resolve to a known member. Returns {"state", "token"}, or {} when
## the RPC must be ignored — an unauthenticated sender is dropped silently.

func _session_actor(sender: int) -> Dictionary:
	if not NetworkManager.is_host():
		return {}
	var st = SessionStore.get_state()
	if st == null:
		return {}
	var token: String = _stash_token_for_peer(sender)
	if token == "" or not st.has_member(token):
		return {}
	return {"state": st, "token": token}

func _on_stash_deposit_submitted(sender: int, payload: Dictionary) -> void:
	var actor: Dictionary = _session_actor(sender)
	if actor.is_empty():
		return
	var st = actor["state"]
	var token: String = actor["token"]
	var member_rec: Dictionary = st.get_member(token)
	var kind: String = str(payload.get("kind", "card"))
	var result: Dictionary
	if kind == "coins":
		result = _StashTransfer.deposit_coins(st.stash, member_rec, int(payload.get("amount", 0)))
	else:
		result = _StashTransfer.deposit_card(st.stash, member_rec, str(payload.get("card_uid", "")))
	if not bool(result.get("ok", false)):
		if kind != "coins":
			_world._show_tip("Could not deposit that card.")
		return
	st.stash = result.get("stash", st.stash)
	var updated_member: Dictionary = result.get("member", member_rec)
	st.update_member(token, updated_member)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_member)
	_broadcast_stash_update()

func _on_stash_withdraw_submitted(sender: int, payload: Dictionary) -> void:
	var actor: Dictionary = _session_actor(sender)
	if actor.is_empty():
		return
	var st = actor["state"]
	var token: String = actor["token"]
	var member_rec: Dictionary = st.get_member(token)
	var kind: String = str(payload.get("kind", "card"))
	var result: Dictionary
	if kind == "coins":
		result = _StashTransfer.withdraw_coins(st.stash, member_rec, int(payload.get("amount", 0)))
	else:
		result = _StashTransfer.withdraw_card(st.stash, member_rec, str(payload.get("card_uid", "")), token)
	if not bool(result.get("ok", false)):
		if kind != "coins":
			_world._show_tip("Could not withdraw that card.")
		return
	st.stash = result.get("stash", st.stash)
	var updated_member2: Dictionary = result.get("member", member_rec)
	st.update_member(token, updated_member2)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_member2)
	_broadcast_stash_update()


## Keeps the acting peer's in-memory character (SaveManager fields / adopted session
## character) in sync with the record `StashTransfer` just mutated, so the next
## periodic persist-back tick (`_tick_session_persist`) doesn't clobber the stash
## change with stale in-memory data — the host re-adopts directly; a remote client
## gets an updated `recv_character` mirror (resume flag false: this isn't a reconnect,
## just a refresh, so no position restore).

func _apply_updated_member_to_actor(sender: int, updated_member: Dictionary) -> void:
	if sender == multiplayer.get_unique_id():
		SceneManager.save_manager.adopt_session_character(updated_member)
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(sender, "recv_character", updated_member, false)


## Host: push the current stash snapshot to one peer (target_peer == 0 broadcasts to all).

func _broadcast_stash_update(target_peer: int = 0) -> void:
	if not NetworkManager.is_host() or _world._net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	_stash_cache = st.stash
	if target_peer == 0:
		_world._net_sync.rpc("recv_stash_update", st.stash)
	else:
		_world._net_sync.rpc_id(target_peer, "recv_stash_update", st.stash)
	if NetworkManager.is_host():
		_refresh_stash_overlay()


## Any peer: receive a stash snapshot (initial push, post-transfer update, or the
## late-join send) and refresh the overlay if it's open.

func _on_stash_update_received(snapshot: Dictionary) -> void:
	_stash_cache = snapshot
	_refresh_stash_overlay()

func _refresh_stash_overlay() -> void:
	if _stash_overlay != null and is_instance_valid(_stash_overlay) \
			and _stash_overlay.has_method("refresh"):
		_stash_overlay.refresh(_my_collection_for_stash_ui(), _stash_cache)


## My current owned-card collection for the stash UI's "deposit" column.

func _my_collection_for_stash_ui() -> Array:
	var out: Array = []
	for inst in SceneManager.save_manager.owned_cards:
		out.append(inst)
	return out


## Opens (or closes, if already open) the party stash overlay. HUD button, always
## visible while co-op is active — global to the session (mobile/desktop parity).

func _toggle_stash_overlay() -> void:
	if _stash_overlay != null and is_instance_valid(_stash_overlay):
		_stash_overlay.queue_free()
		_stash_overlay = null
		return
	_stash_overlay = _PartyStashOverlay.new()
	_stash_overlay.world_scene = self
	add_child(_stash_overlay)
	_stash_overlay.closed.connect(func() -> void: _stash_overlay = null)
	_stash_overlay.refresh(_my_collection_for_stash_ui(), _stash_cache)


## Called by PartyStashOverlay when the player presses "Deposit" on a card.

func request_stash_deposit_card(card_uid: String) -> void:
	if _world._net_sync == null:
		return
	var payload: Dictionary = {"kind": "card", "card_uid": card_uid, "amount": 0}
	if NetworkManager.is_host():
		_on_stash_deposit_submitted(multiplayer.get_unique_id(), payload)
	else:
		_world._net_sync.rpc_id(1, "submit_stash_deposit", payload)


## Called by PartyStashOverlay when the player presses "Withdraw" on a stash card.

func request_stash_withdraw_card(stash_uid: String) -> void:
	if _world._net_sync == null:
		return
	var payload: Dictionary = {"kind": "card", "card_uid": stash_uid, "amount": 0}
	if NetworkManager.is_host():
		_on_stash_withdraw_submitted(multiplayer.get_unique_id(), payload)
	else:
		_world._net_sync.rpc_id(1, "submit_stash_withdraw", payload)


## Called by PartyStashOverlay's coin deposit stepper.

func request_stash_deposit_coins(amount: int) -> void:
	if _world._net_sync == null or amount <= 0:
		return
	var payload: Dictionary = {"kind": "coins", "card_uid": "", "amount": amount}
	if NetworkManager.is_host():
		_on_stash_deposit_submitted(multiplayer.get_unique_id(), payload)
	else:
		_world._net_sync.rpc_id(1, "submit_stash_deposit", payload)


## Called by PartyStashOverlay's coin withdraw stepper.

func request_stash_withdraw_coins(amount: int) -> void:
	if _world._net_sync == null or amount <= 0:
		return
	var payload: Dictionary = {"kind": "coins", "card_uid": "", "amount": amount}
	if NetworkManager.is_host():
		_on_stash_withdraw_submitted(multiplayer.get_unique_id(), payload)
	else:
		_world._net_sync.rpc_id(1, "submit_stash_withdraw", payload)


# ── GID-102 / TID-378: Async card auction house ──────────────────────────────────
# Global to the session, same as the stash — no proximity gate. Transfer logic
# delegates to the pure, unit-tested AuctionTransfer helper; only the authority
# mutates SessionState. Reuses _stash_token_for_peer for sender -> token lookup.

func _on_auction_list_submitted(sender: int, payload: Dictionary) -> void:
	var actor: Dictionary = _session_actor(sender)
	if actor.is_empty():
		return
	var st = actor["state"]
	var token: String = actor["token"]
	var intent: Dictionary = _AuctionSync.decode_list_intent(payload)
	var member_rec: Dictionary = st.get_member(token)
	var expires_day: int = st.days_elapsed + _AuctionSync.LISTING_DURATION_DAYS
	var list_card_uid: String = str(intent.get("card_uid", ""))
	var list_buyout: int = int(intent.get("buyout", 0))
	var result: Dictionary = _AuctionTransfer.list_card(
		st.auctions, member_rec, token, list_card_uid, list_buyout, expires_day)
	if not bool(result.get("ok", false)):
		_world._show_tip("Could not list that card.")
		return
	st.auctions = result.get("auctions", st.auctions)
	var updated_member: Dictionary = result.get("member", member_rec)
	st.update_member(token, updated_member)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_member)
	_broadcast_auction_update()

func _on_auction_bid_submitted(sender: int, payload: Dictionary) -> void:
	var actor: Dictionary = _session_actor(sender)
	if actor.is_empty():
		return
	var st = actor["state"]
	var token: String = actor["token"]
	var intent: Dictionary = _AuctionSync.decode_bid_intent(payload)
	var member_rec: Dictionary = st.get_member(token)
	var bid_auction_id: String = str(intent.get("auction_id", ""))
	var bid_amount: int = int(intent.get("amount", 0))
	var result: Dictionary = _AuctionTransfer.place_bid(
		st.auctions, member_rec, token, bid_auction_id, bid_amount)
	if not bool(result.get("ok", false)):
		_world._show_tip("Could not place that bid.")
		return
	st.auctions = result.get("auctions", st.auctions)
	SessionStore.mark_dirty()
	_broadcast_auction_update()

func _on_auction_buyout_submitted(sender: int, payload: Dictionary) -> void:
	var actor: Dictionary = _session_actor(sender)
	if actor.is_empty():
		return
	var st = actor["state"]
	var buyer_token: String = actor["token"]
	var intent: Dictionary = _AuctionSync.decode_id_intent(payload)
	var buyout_auction_id: String = str(intent.get("auction_id", ""))
	var listing: Dictionary = _find_auction(st.auctions, buyout_auction_id)
	var seller_token: String = str(listing.get("seller_token", ""))
	if seller_token == "" or not st.has_member(seller_token):
		_world._show_tip("Could not buy that listing.")
		return
	var buyer_rec: Dictionary = st.get_member(buyer_token)
	var seller_rec: Dictionary = st.get_member(seller_token)
	var result: Dictionary = _AuctionTransfer.buyout(
		st.auctions, buyer_rec, buyer_token, seller_rec, buyout_auction_id)
	if not bool(result.get("ok", false)):
		_world._show_tip("Could not buy that listing.")
		return
	st.auctions = result.get("auctions", st.auctions)
	var updated_buyer: Dictionary = result.get("buyer", buyer_rec)
	var updated_seller: Dictionary = result.get("seller", seller_rec)
	st.update_member(buyer_token, updated_buyer)
	st.update_member(seller_token, updated_seller)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_buyer)
	_apply_updated_member_to_peer_by_token(seller_token, updated_seller)
	_broadcast_auction_update()

func _on_auction_cancel_submitted(sender: int, payload: Dictionary) -> void:
	var actor: Dictionary = _session_actor(sender)
	if actor.is_empty():
		return
	var st = actor["state"]
	var token: String = actor["token"]
	var intent: Dictionary = _AuctionSync.decode_id_intent(payload)
	var member_rec: Dictionary = st.get_member(token)
	var cancel_auction_id: String = str(intent.get("auction_id", ""))
	var result: Dictionary = _AuctionTransfer.cancel(st.auctions, member_rec, token, cancel_auction_id)
	if not bool(result.get("ok", false)):
		_world._show_tip("Could not cancel that listing.")
		return
	st.auctions = result.get("auctions", st.auctions)
	var updated_member: Dictionary = result.get("member", member_rec)
	st.update_member(token, updated_member)
	SessionStore.mark_dirty()
	_apply_updated_member_to_actor(sender, updated_member)
	_broadcast_auction_update()


## Host-tick sweep (called from _tick_session_persist): settle any active listing
## whose expires_day has passed. See AuctionTransfer.settle_expired — a listing
## with a standing bid the bidder can still afford sells to them, otherwise the
## card returns to the seller. Silently updates any member whose actor is
## currently connected so their local collection stays in sync.

func _sweep_expired_auctions() -> void:
	var st = SessionStore.get_state()
	if st == null or (st.auctions as Array).is_empty():
		return
	var result: Dictionary = _AuctionTransfer.settle_expired(st.auctions, st.members, st.days_elapsed)
	var new_auctions: Array = result.get("auctions", st.auctions)
	if new_auctions == st.auctions:
		return
	var new_members: Dictionary = result.get("members", st.members)
	st.auctions = new_auctions
	for token in new_members.keys():
		var rec: Variant = new_members[token]
		if rec is Dictionary:
			st.update_member(str(token), rec as Dictionary)
			_apply_updated_member_to_peer_by_token(str(token), rec as Dictionary)
	SessionStore.mark_dirty()
	_broadcast_auction_update()


## Resolve the connected peer id for `token` (reverse of _stash_token_for_peer),
## or -1 if that member isn't a currently-connected peer.

func _peer_for_token(token: String) -> int:
	if token == MpProfile.get_token():
		return multiplayer.get_unique_id()
	for peer_id in _world._session_token_by_peer.keys():
		if str(_world._session_token_by_peer[peer_id]) == token:
			return int(peer_id)
	return -1


## Like _apply_updated_member_to_actor, but resolved from a token rather than a
## sender peer id — used when the auction settlement touches a member who isn't
## the RPC sender (the seller on a buyout, any party on an expiry sweep).

func _apply_updated_member_to_peer_by_token(token: String, updated_member: Dictionary) -> void:
	var peer_id: int = _peer_for_token(token)
	if peer_id == -1:
		return  # not currently connected — their next reconnect adopts the persisted record
	_apply_updated_member_to_actor(peer_id, updated_member)

func _find_auction(auctions: Array, auction_id: String) -> Dictionary:
	for a: Variant in auctions:
		if a is Dictionary and str((a as Dictionary).get("id", "")) == auction_id:
			return a as Dictionary
	return {}


## Host: push the current listings snapshot to one peer (target_peer == 0 broadcasts to all).

func _broadcast_auction_update(target_peer: int = 0) -> void:
	if not NetworkManager.is_host() or _world._net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	_auction_cache = _AuctionSync.decode_snapshot(st.auctions)
	if target_peer == 0:
		_world._net_sync.rpc("recv_auction_update", st.auctions)
	else:
		_world._net_sync.rpc_id(target_peer, "recv_auction_update", st.auctions)
	if NetworkManager.is_host():
		_refresh_auction_overlay()


## Any peer: receive a listings snapshot (initial push, post-transfer update, or
## the late-join send) and refresh the overlay if it's open.

func _on_auction_update_received(snapshot: Array) -> void:
	_auction_cache = _AuctionSync.decode_snapshot(snapshot)
	_refresh_auction_overlay()

func _refresh_auction_overlay() -> void:
	if _auction_overlay != null and is_instance_valid(_auction_overlay) \
			and _auction_overlay.has_method("refresh"):
		_auction_overlay.refresh(_my_collection_for_stash_ui(), _auction_cache, MpProfile.get_token())


## Opens (or closes, if already open) the auction house overlay. HUD button,
## always visible while co-op is active — global to the session.

func _toggle_auction_overlay() -> void:
	if _auction_overlay != null and is_instance_valid(_auction_overlay):
		_auction_overlay.queue_free()
		_auction_overlay = null
		return
	_auction_overlay = _AuctionHouseOverlay.new()
	_auction_overlay.world_scene = self
	add_child(_auction_overlay)
	_auction_overlay.closed.connect(func() -> void: _auction_overlay = null)
	_auction_overlay.refresh(_my_collection_for_stash_ui(), _auction_cache, MpProfile.get_token())


## Called by AuctionHouseOverlay when the player presses "List" on a card.

func request_auction_list(card_uid: String, buyout: int) -> void:
	if _world._net_sync == null or buyout <= 0:
		return
	var payload: Dictionary = _AuctionSync.encode_list_intent(card_uid, buyout)
	if NetworkManager.is_host():
		_on_auction_list_submitted(multiplayer.get_unique_id(), payload)
	else:
		_world._net_sync.rpc_id(1, "submit_auction_list", payload)


## Called by AuctionHouseOverlay's bid stepper.

func request_auction_bid(auction_id: String, amount: int) -> void:
	if _world._net_sync == null or amount <= 0:
		return
	var payload: Dictionary = _AuctionSync.encode_bid_intent(auction_id, amount)
	if NetworkManager.is_host():
		_on_auction_bid_submitted(multiplayer.get_unique_id(), payload)
	else:
		_world._net_sync.rpc_id(1, "submit_auction_bid", payload)


## Called by AuctionHouseOverlay's "Buyout" button.

func request_auction_buyout(auction_id: String) -> void:
	if _world._net_sync == null:
		return
	var payload: Dictionary = _AuctionSync.encode_id_intent(auction_id)
	if NetworkManager.is_host():
		_on_auction_buyout_submitted(multiplayer.get_unique_id(), payload)
	else:
		_world._net_sync.rpc_id(1, "submit_auction_buyout", payload)


## Called by AuctionHouseOverlay's "Cancel" button (My Listings tab).

func request_auction_cancel(auction_id: String) -> void:
	if _world._net_sync == null:
		return
	var payload: Dictionary = _AuctionSync.encode_id_intent(auction_id)
	if NetworkManager.is_host():
		_on_auction_cancel_submitted(multiplayer.get_unique_id(), payload)
	else:
		_world._net_sync.rpc_id(1, "submit_auction_cancel", payload)


# ── TID-367: PvP spectating ────────────────────────────────────────────────────
