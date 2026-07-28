## Session lifecycle and world-state replication: joining and leaving a co-op
## session, the identity and persistent-character handshakes, the in-world
## roster, world-object sync, the synced clock and weather, shared story flags,
## map transitions, rally waystones, downed-and-rescue, and the shared dungeon
## crawl and guildhall.
##
## A child node of WorldScene, registered with NetSync as an RPC handler target
## so the `_on_*` entry points below are reached exactly as they were when they
## lived in WorldScene itself. Everything world-side is reached via `_world`.
extends Node

## The WorldScene that owns this module. Everything the module needs from
## the world itself — the player node, the HUD, the entity tables — is
## reached through it. Sibling modules are reached as _world.<accessor>.
var _world: Node = null

const WorldHUD          = preload("res://scenes/world/WorldHUD.gd")
const _AvatarSync        = preload("res://game_logic/net/AvatarSync.gd")
const _CoopSiege         = preload("res://game_logic/CoopSiege.gd")
const _DownedSync        = preload("res://game_logic/net/DownedSync.gd")
const _EnemySync         = preload("res://game_logic/net/EnemySync.gd")
const _EnvSync           = preload("res://game_logic/net/EnvSync.gd")
const _NetSyncScript     = preload("res://scenes/world/NetSync.gd")
const _PartyPanel        = preload("res://scenes/ui/PartyPanel.gd")
const _PlayerIdentity    = preload("res://game_logic/net/PlayerIdentity.gd")
const _RemotePlayerScene = preload("res://scenes/world/entities/RemotePlayer.tscn")
const _SessionState      = preload("res://game_logic/net/SessionState.gd")
const _TournamentSync    = preload("res://game_logic/net/TournamentSync.gd")
const _WorldObjectSync   = preload("res://game_logic/net/WorldObjectSync.gd")

var _coop_downed_peers: Dictionary = {}       # peer_id -> bool, mirrored via the avatar stream
var _coop_enemy_targets: Dictionary = {}    # enemy id -> Vector2(x,z) interp target (clients)
var _coop_env_broadcast_timer: float = 0.0
var _coop_env_days_elapsed: int = 0
var _coop_env_weather_id: String = ""
var _coop_last_engaged_enemy_id: String = ""  # id of the enemy the local battle is against
var _coop_opened_objects: Dictionary = {}   # object id -> true (chest opened this session)
var _coop_story_flag_syncing: bool = false
var _coop_weather_rng: RandomNumberGenerator = null
var _coop_weather_timer: float = 0.0
var _enemy_pos_accum: float = 0.0
var _last_rally_time: float = -999.0
var _maiteln_broadcast_accum: float = 0.0
var _net_broadcast_accum: float = 0.0
var _party_panel: Node = null              # Party panel overlay (GID-107); roster lives inside it
var _party_roster_rows: Array = []         # cached roster row data fed into _party_panel
var _remote_player_maps: Dictionary = {}   # peer_id -> last-known map name (TID-352)
var _session_adopted: bool = false
var _session_snapshot_accum: float = 0.0

func _setup_coop() -> void:
	if not NetworkManager.is_active():
		return
	if _world._coop_active:
		return
	_world._coop_active = true

	# Fixed-name RPC relay child. Path /root/WorldScene/NetSync matches on both
	# peers. Reused across a PvP battle detach (not freed in _teardown_coop).
	if _world._net_sync == null or not is_instance_valid(_world._net_sync):
		_world._net_sync = _NetSyncScript.new()
		_world._net_sync.name = "NetSync"
		_world._net_sync.set("world_scene", _world)
		_world.add_child(_world._net_sync)
	_world._ensure_coop_modules()

	NetworkManager.peer_connected.connect(_on_coop_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_coop_peer_disconnected)
	NetworkManager.session_ended.connect(_on_coop_session_ended)

	# Dedicated server has no player, no HUD, no identity to share.
	if not NetworkManager.is_dedicated_server():
		_world.coop_pvp._ensure_challenge_button()
		_world.coop_pvp._ensure_draft_duel_button()
		_world.coop_social._ensure_social_buttons()
		_world.coop_social._ensure_chat_ui()
		# Party panel (GID-107 / TID-395; Siege/Tournament added GID-115 / TID-433):
		# single entry point for Roster, Loot Mode, Stash, Leaderboard, Ghost Duels,
		# Team Duel, Dungeon Crawl, Siege, Tournament.
		_world._world_hud.register_action("party", "Party", WorldHUD.ZONE_NAV, _open_party_panel)
		# Discoverability (GID-107 / TID-398): players used to the old scattered
		# buttons need a one-time nudge to the new consolidated entry point.
		# SceneManager dedups via the "seen_tutorial_party_panel" flag, so this is
		# safe to emit every time co-op becomes active (matches the "night_hunts"
		# precedent — emitter just emits, the handler owns the seen-once logic).
		GameBus.tutorial_popup_requested.emit("party_panel")
	# GID-101 (TID-369): host initialises party bounties; all peers build the HUD.
	_world.coop_activities._setup_party_bounties()
	if not NetworkManager.is_dedicated_server():
		_world.coop_activities._build_party_bounty_panel()

	# Host: surface the LAN IP so the other player knows what to type into
	# "Join by IP" (only shown on the first co-op entry, not on battle re-attach).
	if NetworkManager.is_host() and not NetworkManager.is_dedicated_server() and not _world._initial_ready_done:
		var lan_ip: String = NetworkManager.get_lan_ip()
		if lan_ip != "":
			SceneManager.show_toast("Hosting", "Other player: Join by IP  →  %s" % lan_ip)

	# Spawn avatars for peers already connected when this world loads (the
	# client-joining-host case; the host's peer is already present).
	for pid in multiplayer.get_peers():
		_spawn_remote_player(int(pid))

	# Persistent session (GID-095 / TID-346): the host (authority) opens its session
	# file and adopts its own character; clients adopt on the character handshake.
	_setup_session()

	# Co-op story mode (GID-098): sync story flag changes through the authority.
	if not GameBus.story_flag_set.is_connected(_on_local_story_flag_set):
		GameBus.story_flag_set.connect(_on_local_story_flag_set)

	# Identity handshake (TID-342): broadcast this peer's identity to everyone
	# already in-world. Dedicated server has no player identity to share.
	if not NetworkManager.is_dedicated_server():
		_refresh_coop_roster()
		_send_local_identity(false, 0)

func _teardown_coop() -> void:
	if not _world._coop_active:
		return
	if NetworkManager.peer_connected.is_connected(_on_coop_peer_connected):
		NetworkManager.peer_connected.disconnect(_on_coop_peer_connected)
	if NetworkManager.peer_disconnected.is_connected(_on_coop_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_coop_peer_disconnected)
	if NetworkManager.session_ended.is_connected(_on_coop_session_ended):
		NetworkManager.session_ended.disconnect(_on_coop_session_ended)
	if GameBus.story_flag_set.is_connected(_on_local_story_flag_set):
		GameBus.story_flag_set.disconnect(_on_local_story_flag_set)
	# Keep _net_sync alive across a battle detach so the RPC node persists; set
	# inactive so re-entry (_enter_tree) re-runs setup and reconnects signals.
	_world._coop_active = false

func _spawn_remote_player(pid: int) -> void:
	if _world._remote_player_nodes.has(pid):
		return
	# Seed near the local player but fan out by a deterministic per-peer ring offset
	# so up to 4 avatars don't stack on the shared SPAWN tile before packets flow.
	var base_x: float = _world._player.position.x if _world._player != null else 0.0
	var base_z: float = _world._player.position.z if _world._player != null else 0.0
	var off: Vector2 = _AvatarSync.spawn_offset(pid, IsoConst.TILE_SIZE)
	var spawn_x: float = base_x + off.x
	var spawn_z: float = base_z + off.y
	var rp: Node3D = _RemotePlayerScene.instantiate() as Node3D
	rp.set("world_scene", _world)
	rp.init_from_data({"peer_id": pid, "x": spawn_x, "z": spawn_z})
	# Map-scoped sync (TID-352): hidden until the first packet confirms the peer is on
	# our map, so a peer on a different map never flashes a cross-map ghost on load.
	rp.visible = false
	_world._entity_root.add_child(rp)
	_world._remote_player_nodes[pid] = rp
	# Apply identity if it already arrived before the avatar spawned (lazy ordering).
	if _world._remote_identities.has(pid):
		_apply_identity_to_avatar(pid)

func _on_coop_peer_connected(pid: int) -> void:
	_spawn_remote_player(pid)

func _on_coop_peer_disconnected(pid: int) -> void:
	var rp: Node = _world._valid_node(_world._remote_player_nodes.get(pid))
	if is_instance_valid(rp):
		rp.queue_free()
	_world._remote_player_nodes.erase(pid)
	_world._remote_identities.erase(pid)
	_remote_player_maps.erase(pid)
	_world._session_token_by_peer.erase(pid)
	# Downed & rescue (GID-105 / TID-389): a disconnected peer can't be revived or
	# time out anymore — drop their entry so a stale revive request can't match it.
	_coop_downed_peers.erase(pid)
	# Draft duel (GID-104 / TID-385): abort a draft in flight with this peer.
	_world.coop_pvp._abort_draft_duel_for_peer(pid)
	# Flush so the leaving player's last persisted snapshot is on disk (host only).
	if NetworkManager.is_host():
		SessionStore.flush_now()
	# GID-104 (TID-386): a tournament participant disconnecting mid-bracket has no
	# resume/refund path in v1 (documented gap) — abort cleanly rather than leave
	# the bracket stuck forever waiting for a match that can never finish.
	if _world._tournament_active and NetworkManager.is_host() and _world._tournament_peer_ids.has(pid):
		_world.coop_pvp._reset_tournament_state()
		_world._tournament_bracket = {}
		if _world._net_sync != null:
			_world._net_sync.rpc("recv_tournament_update", _TournamentSync.encode_bracket({}))
		_world.coop_pvp._refresh_tournament_panel()
		GameBus.hud_message_requested.emit("Tournament aborted — a player disconnected.")
	_refresh_coop_roster()

func _on_coop_session_ended() -> void:
	for pid in _world._remote_player_nodes.keys():
		var rp: Node = _world._valid_node(_world._remote_player_nodes[pid])
		if is_instance_valid(rp):
			rp.queue_free()
	_world._remote_player_nodes.clear()
	_world._remote_identities.clear()
	_remote_player_maps.clear()
	_world._session_token_by_peer.clear()
	# Downed & rescue (GID-105 / TID-389) is session-scoped state.
	_coop_downed_peers.clear()
	if _world._coop_downed:
		_exit_downed_state()
	# Co-op world-object sync state (GID-096) is session-scoped; clear it so a fresh
	# session starts from the deterministic spawn (persisted progress reloads via
	# _setup_session / the join snapshot).
	_world._coop_removed_enemies.clear()
	_coop_opened_objects.clear()
	_world._coop_collected_scrolls.clear()
	_coop_enemy_targets.clear()
	_coop_last_engaged_enemy_id = ""
	# Party loot rolls (GID-102 / TID-381) are session-scoped too.
	_world._loot_rolls_active.clear()
	_world._pending_loot_roll = {}
	# Draft duel (GID-104 / TID-385): session gone — abort any draft in flight.
	_world.coop_pvp._abort_draft_duel()
	# Session tournaments (GID-104 / TID-386) are session-scoped: a bracket cannot
	# outlive the session that scheduled it. No refunds in v1 (documented gap).
	_world.coop_pvp._reset_tournament_state()
	_world._tournament_bracket = {}
	_world.coop_pvp._refresh_tournament_panel()
	if _world._loot_roll_panel != null and is_instance_valid(_world._loot_roll_panel):
		_world._loot_roll_panel.queue_free()
	_world._loot_roll_panel = null
	# Co-op Endless Spire (GID-106 / TID-390): session gone — the run itself lives on
	# SceneManager (survives this WorldScene instance), but any in-flight draft round
	# on THIS instance is aborted, matching the loot-roll precedent above.
	_world._coop_spire_draft_active = {}
	_world._pending_coop_spire_draft = {}
	if _world._coop_spire_draft_overlay != null and is_instance_valid(_world._coop_spire_draft_overlay):
		_world._coop_spire_draft_overlay.queue_free()
	_world._coop_spire_draft_overlay = null
	# TID-391: same cleanup for the run-ended summary overlay, if one is showing.
	if _world._coop_spire_summary_overlay != null and is_instance_valid(_world._coop_spire_summary_overlay):
		_world._coop_spire_summary_overlay.queue_free()
	_world._coop_spire_summary_overlay = null
	if _party_panel != null and is_instance_valid(_party_panel):
		_party_panel.queue_free()
	_party_panel = null
	# Authority owns the session file: flush + close it on session end (host left /
	# server stopped). On clients SessionStore is never open, so this is a no-op.
	if SessionStore.is_open():
		SessionStore.close(true)
	_session_adopted = false
	_refresh_coop_roster()
	# Shared world life (GID-103) is session-scoped: clear the night hunt and
	# siege state so a fresh session starts clean.
	_world.coop_activities._coop_despawn_night_hunt()
	_world._coop_siege_active = false
	_world._coop_siege_wave = -1
	_world._coop_siege_wave_nodes.clear()
	if _world._siege_banner != null and is_instance_valid(_world._siege_banner):
		_world._siege_banner.queue_free()
	_world._siege_banner = null
	_coop_env_weather_id = ""
	_coop_weather_rng = null
	_world._coop_active = false

# ── Player identity handshake (GID-094 / TID-342) ─────────────────────────────

## Broadcast (target_peer == 0) or unicast this peer's identity. `is_reply` marks
## the one-shot direct answer so the exchange terminates after one round-trip.

func _send_local_identity(is_reply: bool, target_peer: int) -> void:
	if not _world._coop_active or _world._net_sync == null or not NetworkManager.is_active():
		return
	var payload: Array = _PlayerIdentity.encode(
		MpProfile.get_token(), MpProfile.get_display_name(), MpProfile.get_color())
	if target_peer == 0:
		_world._net_sync.rpc("recv_identity", payload, is_reply)
	else:
		_world._net_sync.rpc_id(target_peer, "recv_identity", payload, is_reply)

## Called by NetSync when a peer's identity packet arrives.

func _on_identity_received(sender: int, payload: Array, is_reply: bool) -> void:
	var d: Dictionary = _PlayerIdentity.decode(payload)
	_world._remote_identities[sender] = d
	_apply_identity_to_avatar(sender)
	_refresh_coop_roster()
	# Authority: now that we know this peer's token, resolve + send its session
	# character (resume or fresh starter). GID-095 / TID-346.
	if NetworkManager.is_host():
		_send_character_to_peer(sender, str(d.get("token", "")), str(d.get("name", "Player")))
		# World-object snapshot (GID-096): reconcile the joiner's freshly-spawned
		# enemies/chests to the live + persisted removed/opened sets.
		_send_world_snapshot_to_peer(sender)
		# Co-op story mode (GID-098): send the shared story flags so the new peer
		# has the same story state as the rest of the party.
		_send_story_flags_snapshot_to_peer(sender)
		# Co-op story mode (GID-098): if the party has already moved beyond the
		# default lobby map, redirect the late joiner to the party's current map.
		if SessionStore.is_open() and _world._net_sync != null:
			var st = SessionStore.get_state()
			if st != null and st.current_map != "" and st.current_map != _world.map_name:
				_world._net_sync.rpc_id(sender, "recv_map_transition", st.current_map, "")
	# Answer an initiator's broadcast exactly once so it learns our identity too.
	if not is_reply:
		_send_local_identity(true, sender)

## Push a stored identity onto the matching RemotePlayer avatar, if spawned.

func _apply_identity_to_avatar(pid: int) -> void:
	var rp: Node = _world._valid_node(_world._remote_player_nodes.get(pid))
	if not is_instance_valid(rp) or not rp.has_method("set_player_identity"):
		return
	var d: Dictionary = _world._remote_identities.get(pid, {})
	var nm: String = str(d.get("name", "Player"))
	var col: Color = d.get("color", Color.WHITE)
	rp.set_player_identity(nm, col)

# ── Persistent session character (GID-095 / TID-346) ──────────────────────────
# The authority (host) owns SessionStore and the per-player character roster, keyed
# by the GID-094 identity token. The host adopts its own character here; each client
# adopts the record the host sends on the identity handshake. All guarded by
# _coop_active / NetworkManager.is_host(); inert in single-player and on clients.

func _setup_session() -> void:
	# Re-entry after a PvP battle keeps the same WorldScene (SessionStore stays open),
	# so only the first co-op entry initialises + adopts.
	if _session_adopted:
		return
	if not NetworkManager.is_host():
		return  # clients adopt later, in _on_character_received
	SessionStore.open(MpProfile.get_host_session_id(),
		"%s's world" % MpProfile.get_display_name())
	var st = SessionStore.get_state()
	if st != null:
		st.current_map = _world.map_name
		st.world_seed = SceneManager.save_manager.world_seed
		SessionStore.mark_dirty()
		# GID-103 (TID-382): resume the host's own clock from the persisted session
		# value (a fresh session's default 0.4 matches _dnc's own default, so this is
		# a no-op the first time a session file is created).
		if _world._dnc != null:
			_world._dnc.set_time_of_day(st.time_of_day)
	var token: String = MpProfile.get_token()
	var resume: bool = st != null and st.has_member(token)
	var rec: Dictionary = SessionStore.ensure_member(token, MpProfile.get_display_name())
	if rec.is_empty():
		return
	SceneManager.save_manager.adopt_session_character(rec)
	if resume:
		_restore_session_position(rec)
	_session_adopted = true
	# Reconcile the deterministically-spawned world to the session's persisted
	# progress (defeated enemies / opened chests) so a resumed host world matches
	# what was left behind (GID-096).
	if st != null:
		_coop_apply_world_progress(st.defeated_enemies, st.opened_chests, st.collected_scrolls)
		for eid in st.defeated_enemies:
			_world._coop_removed_enemies[str(eid)] = true
		for cid in st.opened_chests:
			_coop_opened_objects[str(cid)] = true
		# Co-op story mode (GID-098): restore session story flags so the host
		# re-entering a saved co-op session sees the correct story state.
		if not st.story_flags.is_empty():
			_coop_story_flag_syncing = true
			for key in st.story_flags:
				SceneManager.save_manager.story_flags[str(key)] = bool(st.story_flags[key])
			_coop_story_flag_syncing = false
		# GID-102 (TID-373): seed the host's own leaderboard cache immediately so the
		# roster badge + leaderboard panel are populated even before any peer joins or
		# any duel has been played this session (e.g. a solo host re-entering a session
		# with existing ranked history).
		_world._leaderboard_rows = st.get_leaderboard(20) if st != null else []
		# GID-102 (TID-379): same seeding for the PvE leaderboards cache.
		_world._pve_leaderboards = st.get_pve_leaderboards_snapshot() if st != null else \
			{"spire": [], "coop_clears": []}

## Client: adopt the character record the host resolved for our token. On a resume
## the host flags it so we also restore our saved position.

func _on_character_received(record: Dictionary, resume: bool) -> void:
	if record.is_empty():
		return
	SceneManager.save_manager.adopt_session_character(record)
	if resume:
		_restore_session_position(record)
	_session_adopted = true
	_refresh_coop_roster()

## Host: a client pushed its latest character snapshot — persist it under its token.

func _on_character_submitted(sender: int, record: Dictionary) -> void:
	if not NetworkManager.is_host():
		return
	var token: String = str(_world._session_token_by_peer.get(sender, ""))
	if token == "":
		token = str(record.get("token", ""))
	if token == "":
		return
	SessionStore.update_member(token, record)

## Host: resolve (or create) the character for a just-identified client and send it.
## Called from _on_identity_received once the client's token is known.

func _send_character_to_peer(peer_id: int, token: String, member_name: String) -> void:
	if not NetworkManager.is_host() or _world._net_sync == null:
		return
	if token == "" or not SessionStore.is_open():
		return
	_world._session_token_by_peer[peer_id] = token
	var st = SessionStore.get_state()
	var resume: bool = st != null and st.has_member(token)
	var rec: Dictionary = SessionStore.ensure_member(token, member_name)
	if rec.is_empty():
		return
	_world._net_sync.rpc_id(peer_id, "recv_character", rec, resume)
	if NetworkManager.is_dedicated_server():
		_world._net_sync.rpc_id(peer_id, "set_session_flags", {"dedicated": true})
	# GID-101 (TID-369): send party bounties snapshot so joining client is in sync.
	if st != null and not (st.party_bounties as Array).is_empty():
		_world._net_sync.rpc_id(peer_id, "recv_party_bounties_snapshot", st.party_bounties)
	# GID-102 (TID-373): send the current leaderboard so the joining client's roster
	# badges + leaderboard panel start populated instead of showing "—" until the
	# next duel ends.
	if st != null:
		_world._net_sync.rpc_id(peer_id, "recv_leaderboard", st.get_leaderboard(20))
	# GID-102 (TID-376): send the current stash snapshot so the joining client's
	# panel starts populated instead of showing stale/empty until the next change.
	if st != null:
		_world._net_sync.rpc_id(peer_id, "recv_stash_update", st.stash)
		# GID-102 (TID-379): send the current PvE leaderboards snapshot alongside it so
		# a joining client's Spire/Co-op-clears tabs start populated too.
		_world._net_sync.rpc_id(peer_id, "recv_pve_leaderboards", st.get_pve_leaderboards_snapshot())
		# GID-102 (TID-378): send the current auction listings snapshot so a joining
		# client's Auction House panel starts populated instead of empty.
		_world._net_sync.rpc_id(peer_id, "recv_auction_update", st.auctions)
		# GID-103 (TID-382): send the current clock/weather so a late joiner never
		# sees a mismatched sky before the next low-Hz broadcast tick.
		if _world._dnc != null:
			_world._net_sync.rpc_id(peer_id, "recv_env_state",
				_EnvSync.encode(_world._dnc.get_time_of_day(), st.days_elapsed, st.weather_id))

## Move the local player to the position stored in a session record (same map only).

func _restore_session_position(record: Dictionary) -> void:
	if _world._player == null or str(record.get("map", "")) != _world.map_name:
		return
	var x: float = float(record.get("x", 0.0))
	var z: float = float(record.get("z", 0.0))
	_world._player.position = Vector3(x, _world.get_terrain_height(x, z), z)

## Build a session record from the local in-memory character + current position.

func _build_local_character_record() -> Dictionary:
	var rec: Dictionary = SceneManager.save_manager.export_session_character()
	rec["token"] = MpProfile.get_token()
	rec["display_name"] = MpProfile.get_display_name()
	rec["map"] = _world.map_name
	rec["x"] = _world._player.position.x if _world._player != null else 0.0
	rec["z"] = _world._player.position.z if _world._player != null else 0.0
	return rec

## Persist-back tick (called from _process at _SESSION_SNAPSHOT_INTERVAL): host writes
## its own member directly; clients send an intent the host merges + persists.

func _tick_session_persist(delta: float) -> void:
	if not _world._coop_active or not _session_adopted or not NetworkManager.is_active():
		return
	_session_snapshot_accum += delta
	if _session_snapshot_accum < _world._SESSION_SNAPSHOT_INTERVAL:
		return
	_session_snapshot_accum = 0.0
	var rec: Dictionary = _build_local_character_record()
	if NetworkManager.is_host():
		SessionStore.update_member(MpProfile.get_token(), rec)
		_world.coop_social._sweep_expired_auctions()
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(1, "submit_character", rec)

# ── In-world session roster (GID-094 / TID-342) ───────────────────────────────
# GID-107 (TID-395): the roster no longer builds its own always-visible HUD panel —
# it recomputes _party_roster_rows and, if the Party panel is currently open,
# pushes the update into it. The row data/shape is unchanged from the old
# _add_roster_row() calls, just collected into an Array[Dictionary] instead of
# built straight into Control nodes.

## Rebuild the roster row data: local player first, then each connected remote.

func _refresh_coop_roster() -> void:
	_party_roster_rows.clear()
	if _world._coop_active:
		# Rating badge (GID-102 / TID-373): looked up from the cached leaderboard rows by
		# identity token; shows "—" until the first snapshot arrives.
		var my_rating: String = _world.coop_pvp._rating_badge_for_token(MpProfile.get_token())
		_party_roster_rows.append({
			"text": "%s (you)  [%s]" % [MpProfile.get_display_name(), my_rating],
			"color": MpProfile.get_color(),
			"token": "",
		})
		for pid in _world._remote_player_nodes.keys():
			var d: Dictionary = _world._remote_identities.get(pid, {})
			var nm: String = str(d.get("name", "Player"))
			var col: Color = d.get("color", Color(0.7, 0.85, 1.0))
			var token: String = str(d.get("token", ""))
			# Friends list (GID-102 / TID-375): a friend currently in-session is "seen now".
			if token != "":
				MpProfile.touch_friend_last_seen(token)
			var clean_name: String = nm
			# Rating badge (GID-102 / TID-373): looked up from the cached leaderboard rows.
			var rating_badge: String = _world.coop_pvp._rating_badge_for_token(token)
			nm += "  [%s]" % rating_badge
			# Map-scoped sync (TID-352): peers on another map are greyed + "(elsewhere)".
			var peer_map: String = str(_remote_player_maps.get(pid, _world.map_name))
			if peer_map != "" and peer_map != _world.map_name:
				nm += " (elsewhere)"
				col = col.darkened(0.45)
			_party_roster_rows.append({
				"text": nm,
				"color": col,
				"token": token,
				"clean_name": clean_name,
				"is_friend": MpProfile.is_friend(token) if token != "" else false,
			})
	if _party_panel != null and is_instance_valid(_party_panel):
		_party_panel.refresh_roster(_party_roster_rows)

## Party loot rolls (GID-102 / TID-381): host-only toggle between the default
## first-opener-takes rule and the opt-in need/greed roll. Now a Party-panel
## action (GID-107 / TID-395) rather than its own always-visible HUD button.

func _loot_mode_label_text() -> String:
	return "Loot: Need/Greed" if _world.coop_activities._coop_loot_mode_is_need_greed() else "Loot: First-Opener"

func _on_loot_mode_toggle_pressed() -> void:
	if not NetworkManager.is_host() or not SessionStore.is_open():
		return
	var new_mode: String = _SessionState.LOOT_MODE_FIRST_OPENER
	if not _world.coop_activities._coop_loot_mode_is_need_greed():
		new_mode = _SessionState.LOOT_MODE_NEED_GREED
	SessionStore.set_loot_mode(new_mode)
	if _party_panel != null and is_instance_valid(_party_panel):
		_party_panel.refresh_loot_label(_loot_mode_label_text())
	GameBus.hud_message_requested.emit(
		"Loot mode: %s" % ("Need/Greed" if new_mode == _SessionState.LOOT_MODE_NEED_GREED else "First-Opener"))

## Opens (or closes, if already open) the Party panel (GID-107 / TID-395):
## Roster, Loot Mode, Stash, Leaderboard, Ghost Duels, Team Duel, Dungeon Crawl —
## each section keeps the exact gating/behavior its old standalone button had.

func _open_party_panel() -> void:
	if _party_panel != null and is_instance_valid(_party_panel):
		_party_panel.queue_free()
		_party_panel = null
		return
	var panel := _PartyPanel.new()
	panel.roster_rows = _party_roster_rows
	panel.on_add_friend = func(token: String, clean_name: String, color: Color) -> void:
		MpProfile.add_friend(token, clean_name, color.to_html(false))
		_refresh_coop_roster()
	# Loot mode (host-only, same gate as the old button's press-handler check).
	panel.show_loot_mode = NetworkManager.is_host() and SessionStore.is_open()
	panel.loot_mode_label = _loot_mode_label_text()
	panel.on_loot_mode_toggle = _on_loot_mode_toggle_pressed
	# Stash / Leaderboard: always available while co-op is active (global to the
	# session, not proximity-gated) — matches the old buttons' gating exactly.
	panel.show_stash = true
	panel.on_stash = _world.coop_social._toggle_stash_overlay
	panel.show_leaderboard = true
	panel.on_leaderboard = _world.coop_pvp._toggle_leaderboard_overlay
	# Auction (GID-102 / TID-378; folded in by BID-042): same always-on,
	# session-global gating as Stash/Leaderboard above — was left as a
	# standalone HUD button when GID-107 shipped the panel; not proximity-gated,
	# so it belongs here the same way.
	panel.show_auction = true
	panel.on_auction = _world.coop_social._toggle_auction_overlay
	# Ghost Duels: host-only, gated on SessionStore.is_open() (see _ensure_ghost_duel_button's
	# old comment — a client never opens SessionStore locally).
	panel.show_ghost_duels = SessionStore.is_open()
	panel.on_ghost_duels = _world.coop_social._toggle_ghost_duel_overlay
	# Team Duel: host-only, needs 3 connected clients (4 total) — mirrors the old
	# _update_team_duel_button_visibility() condition exactly.
	panel.show_team_duel = NetworkManager.is_host() and not NetworkManager.is_dedicated_server() \
		and SceneManager._state == SceneManager.State.WORLD \
		and multiplayer.get_peers().size() >= 3 and _world._pending_challenge_from == -1
	panel.on_team_duel = _world.coop_pvp._start_team_duel
	# Dungeon Crawl: host-only trigger — mirrors the old _ensure_dungeon_button() gate.
	panel.show_dungeon_crawl = NetworkManager.is_host()
	panel.on_dungeon_crawl = _start_dungeon_crawl
	# Co-op Spire (GID-106 / TID-390): host-only trigger — same rationale as Dungeon
	# Crawl (avoids a race where two peers start two different runs at once).
	panel.show_spire = NetworkManager.is_host()
	panel.on_spire = _world.coop_activities._start_coop_spire
	# Guildhall (GID-106 / TID-392): host-only trigger — same rationale as Dungeon
	# Crawl / Co-op Spire above.
	panel.show_guildhall = NetworkManager.is_host()
	panel.on_guildhall = _start_guildhall
	# Siege (GID-103, migrated GID-115 / TID-433): host-only trigger, only on a
	# siege-supported map, hidden while a siege is already in progress — mirrors
	# the old _ensure_siege_button() gate exactly.
	panel.show_siege = _CoopSiege.supports_map(_world.map_name) and NetworkManager.is_host() \
		and not _world._coop_siege_active
	panel.on_siege = _world.coop_activities._start_coop_siege
	# Tournament (GID-104, migrated GID-115 / TID-433): host-only, needs 2-3
	# connected clients (3-4 total) — mirrors the old
	# _update_tournament_button_visibility() condition exactly.
	panel.show_tournament = NetworkManager.is_host() and not NetworkManager.is_dedicated_server() \
		and SceneManager._state == SceneManager.State.WORLD and not _world._tournament_active \
		and multiplayer.get_peers().size() >= 2 and _world._pending_challenge_from == -1
	panel.on_tournament = _world.coop_pvp._start_tournament
	_world._hud.add_child(panel)
	panel.closed.connect(func() -> void: _party_panel = null)
	_party_panel = panel

# Called by NetSync when a remote avatar packet arrives.

func _on_avatar_received(sender: int, payload: Array) -> void:
	var rp: Node = _world._valid_node(_world._remote_player_nodes.get(sender))
	if not is_instance_valid(rp):
		# Packet arrived before the connect signal was processed — spawn now.
		_spawn_remote_player(sender)
		rp = _world._valid_node(_world._remote_player_nodes.get(sender))
	var d: Dictionary = _AvatarSync.decode(payload)
	# Map-scoped avatar sync (TID-352): only render a peer that is on our map. An
	# empty map (legacy/garbage payload) is treated as same-map so nothing regresses.
	var sender_map: String = str(d.get("map", ""))
	var prev_map: String = str(_remote_player_maps.get(sender, ""))
	_remote_player_maps[sender] = sender_map
	if prev_map != sender_map:
		_refresh_coop_roster()
	var same_map: bool = sender_map == "" or sender_map == _world.map_name
	# Downed & rescue (GID-105 / TID-389): mirror the sender's downed flag regardless
	# of map (cheap bookkeeping) but only apply the visual tint when they're rendered.
	var sender_downed: bool = bool(d.get("downed", false))
	_coop_downed_peers[sender] = sender_downed
	if not is_instance_valid(rp):
		return
	(rp as Node3D).visible = same_map
	if rp.has_method("set_downed"):
		rp.set_downed(sender_downed)
	# Only feed position while on the same map; otherwise the avatar holds its last
	# same-map position so re-convergence resumes cleanly (no cross-map coordinates).
	if same_map and rp.has_method("set_net_state"):
		rp.set_net_state(d["x"], d["z"], d["flip_h"], d["moving"])

# Broadcast the local avatar's state at 15 Hz. Called from _process.

func _broadcast_local_avatar(delta: float) -> void:
	if not _world._coop_active or _world._net_sync == null or _world._player == null:
		return
	if not NetworkManager.is_active():
		return
	_net_broadcast_accum += delta
	if _net_broadcast_accum < _world._NET_BROADCAST_INTERVAL:
		return
	_net_broadcast_accum = 0.0
	var flip_h: bool = false
	var spr: AnimatedSprite3D = _world._player.get("_sprite") as AnimatedSprite3D
	if spr != null:
		flip_h = spr.flip_h
	var moving: bool = bool(_world._player.get("_is_moving"))
	var payload: Array = _AvatarSync.encode(
		_world._player.position.x, _world._player.position.z, flip_h, moving, _world.map_name, _world._coop_downed)
	_world._net_sync.rpc("recv_avatar", payload)

## Co-op (GID-108 / TID-408): the authority's own Maiteln follower is the single
## source of truth; broadcast its position (with map_name for the cross-map
## filter) at the same low cadence as the local avatar. A no-op on clients and
## whenever no Maiteln is currently present.

func _broadcast_maiteln_state(delta: float) -> void:
	if not _coop_world_authority() or _world._net_sync == null:
		return
	if not is_instance_valid(_world._maiteln_node):
		return
	_maiteln_broadcast_accum += delta
	if _maiteln_broadcast_accum < _world._NET_BROADCAST_INTERVAL:
		return
	_maiteln_broadcast_accum = 0.0
	_world._net_sync.rpc("recv_maiteln_state", [_world._maiteln_node.position.x, _world._maiteln_node.position.z, _world.map_name])

## Client: apply the authority's Maiteln position, filtered to our own map (the
## same invariant AvatarSync enforces for RemotePlayer avatars — see CLAUDE.md
## "Co-op avatar sync was map-blind").

func _on_maiteln_state_received(payload: Array) -> void:
	if not _world._coop_active or _coop_world_authority() or not is_instance_valid(_world._maiteln_node):
		return
	if payload.size() < 3:
		return
	var sender_map: String = str(payload[2])
	var same_map: bool = sender_map == "" or sender_map == _world.map_name
	_world._maiteln_node.visible = same_map
	if same_map and _world._maiteln_node.has_method("set_net_state"):
		_world._maiteln_node.set_net_state(float(payload[0]), float(payload[1]))

# ── Co-op world-object sync (GID-096) ─────────────────────────────────────────
# The authority (host) owns the canonical lifecycle of shared world objects
# (enemies, chests). Enemies/chests are spawned deterministically from the shared
# map on every peer, so only *discrete* state changes are synced: an enemy engaged
# (removed for all — engage-locks), an enemy defeated (persisted to the session
# file), a chest opened (reflected for all + persisted). Positions are correct by
# construction; a low-Hz position stream exists for future moving enemies. All
# guarded by _coop_active; single-player hits none of this.

## True only when a co-op session is live and this peer is the authority (host).

func _coop_world_authority() -> bool:
	return _world._coop_active and NetworkManager.is_active() and NetworkManager.is_host()

## True on EVERY peer (host and clients alike) while a co-op Spire floor map is
## loaded. Deliberately NOT SceneManager.is_coop_spire_active() — that flag lives
## on the per-process SceneManager autoload and is only ever set true by the host
## (enter_spire_coop is host-only), so a client's own copy would always read false.
## map_name is reliable on every peer since it reflects the map that peer actually
## loaded, regardless of who initiated the transition.

func _in_coop_spire_floor() -> bool:
	return NetworkManager.is_active() and _world.map_name.begins_with("spire_floor_")

## Local player engaged an enemy. Authority broadcasts its removal to all peers;
## a client submits the intent and lets the authority fan it out. Either way the
## engaging peer already removed the node locally (EnemyNPC.engage queue_free'd it).
## Records the id so a subsequent battle win can persist the defeat.

func _on_enemy_engaged_coop(edata: Dictionary) -> void:
	if not _world._coop_active or _world._net_sync == null or not NetworkManager.is_active():
		return
	var eid: String = str(edata.get("id", ""))
	if eid == "":
		return
	# GID-103 (TID-384): the siege finale boss is a joint battle for the whole
	# party, not a solo engage-lock fight — route it separately and skip the
	# normal single-player-battle path entirely.
	if _world._coop_siege_active and eid.begins_with("siege_boss_"):
		_world.coop_activities._coop_engage_siege_boss(edata)
		return
	# GID-106 (TID-391): the co-op Endless Spire floor boss is likewise a joint
	# battle for the whole party. SceneManager._on_enemy_engaged already skips its
	# own solo-battle path for this exact id while on a co-op Spire floor map.
	if _in_coop_spire_floor() and eid == "spire_enemy":
		_world.coop_activities._coop_engage_spire_boss(edata)
		return
	_coop_last_engaged_enemy_id = eid
	if NetworkManager.is_host():
		_world._coop_removed_enemies[eid] = true
		_world._net_sync.rpc("recv_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_ENEMY_REMOVED, eid))
	else:
		_world._net_sync.rpc_id(1, "submit_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_ENEMY_ENGAGED, eid))

## Persist a co-op battle victory against a shared enemy. Host writes the session
## file directly; a client submits the defeat for the host to persist. Called from
## _on_battle_won when a session is active.

func _coop_persist_enemy_defeat() -> void:
	if not _world._coop_active or not NetworkManager.is_active():
		return
	var eid: String = _coop_last_engaged_enemy_id
	_coop_last_engaged_enemy_id = ""
	if eid == "":
		return
	if NetworkManager.is_host():
		_coop_record_enemy_defeated(eid)
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(1, "submit_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_ENEMY_DEFEATED, eid))
	# GID-103 (TID-383): tally + announce a party night-hunt kill and record it to
	# the session's night_hunts leaderboard (best single-night tally per member).
	if eid.begins_with("night_hunt_"):
		_world._coop_night_hunt_kills += 1
		_world.coop_activities._submit_pve_score("night_hunts", _world._coop_night_hunt_kills)
		GameBus.hud_message_requested.emit("Spectral kill! (%d tonight)" % _world._coop_night_hunt_kills)
		if _world._coop_night_hunt_kills == 5:
			GameBus.hud_message_requested.emit("The party has defeated 5 spectral enemies tonight!")

## Host-only: record a defeated enemy into the session file (resumes on reconnect).

func _coop_record_enemy_defeated(eid: String) -> void:
	_world._coop_removed_enemies[eid] = true
	var st = SessionStore.get_state()
	if st != null and not st.defeated_enemies.has(eid):
		st.defeated_enemies.append(eid)
		SessionStore.mark_dirty()

## Local player opened a chest. Authority persists + broadcasts; a client submits the
## intent. The opener keeps the loot (first-opener-takes); peers only flip it open.

func _on_chest_opened_coop(cid: String) -> void:
	if not _world._coop_active or _world._net_sync == null or not NetworkManager.is_active() or cid == "":
		return
	_coop_opened_objects[cid] = true
	if NetworkManager.is_host():
		_coop_record_chest_opened(cid)
		_world._net_sync.rpc("recv_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_CHEST_OPENED, cid))
	else:
		_world._net_sync.rpc_id(1, "submit_world_event", _WorldObjectSync.encode_event(
			_WorldObjectSync.EV_CHEST_OPENED, cid))

## Host-only: persist an opened chest into the session file.

func _coop_record_chest_opened(cid: String) -> void:
	_coop_opened_objects[cid] = true
	var st = SessionStore.get_state()
	if st != null and not st.opened_chests.has(cid):
		st.opened_chests.append(cid)
		SessionStore.mark_dirty()

## Remove a shared enemy node locally (a peer reflecting the authority's removal).

func _coop_remove_enemy_node(eid: String) -> void:
	_world._coop_removed_enemies[eid] = true
	_coop_enemy_targets.erase(eid)
	var node: Node3D = _world._valid_node3d(_world._enemy_nodes.get(eid))
	if is_instance_valid(node):
		if node.has_method("mark_defeated"):
			node.mark_defeated()
		else:
			node.queue_free()
	_world._enemy_nodes.erase(eid)

## Flip a shared chest node to opened locally (no loot — first-opener already took it).

func _coop_mark_chest_opened_node(cid: String) -> void:
	_coop_opened_objects[cid] = true
	if _world._active_chest_data.has(cid):
		(_world._active_chest_data[cid] as Dictionary)["opened"] = true
	var node: Node3D = _world._valid_node3d(_world._chest_nodes.get(cid))
	if is_instance_valid(node) and node.has_method("mark_opened"):
		node.mark_opened()

## NetSync → peer: apply a discrete world event from the authority.

func _on_world_event_received(_sender: int, payload: Array) -> void:
	if not _world._coop_active:
		return
	var ev: Dictionary = _WorldObjectSync.decode_event(payload)
	var kind: String = str(ev.get("kind", ""))
	var id: String = str(ev.get("id", ""))
	if id == "":
		return
	match kind:
		_WorldObjectSync.EV_ENEMY_REMOVED:
			_coop_remove_enemy_node(id)
		_WorldObjectSync.EV_CHEST_OPENED:
			_coop_mark_chest_opened_node(id)
		_WorldObjectSync.EV_SCROLL_COLLECTED:
			_world._coop_apply_scroll_collected(id)

## NetSync → authority: apply a client's world-event intent (host only).

func _on_world_event_submitted(sender: int, payload: Array) -> void:
	if not _coop_world_authority():
		return
	var ev: Dictionary = _WorldObjectSync.decode_event(payload)
	var kind: String = str(ev.get("kind", ""))
	var id: String = str(ev.get("id", ""))
	if id == "":
		return
	match kind:
		_WorldObjectSync.EV_ENEMY_ENGAGED:
			# A client engaged a shared enemy: drop it on the host and fan the
			# removal out to every other peer (the sender already removed its own).
			_coop_remove_enemy_node(id)
			for pid in multiplayer.get_peers():
				if int(pid) != sender:
					_world._net_sync.rpc_id(int(pid), "recv_world_event",
						_WorldObjectSync.encode_event(_WorldObjectSync.EV_ENEMY_REMOVED, id))
		_WorldObjectSync.EV_ENEMY_DEFEATED:
			_coop_record_enemy_defeated(id)
		_WorldObjectSync.EV_CHEST_OPENED:
			_coop_record_chest_opened(id)
			_coop_mark_chest_opened_node(id)
			for pid in multiplayer.get_peers():
				if int(pid) != sender:
					_world._net_sync.rpc_id(int(pid), "recv_world_event",
						_WorldObjectSync.encode_event(_WorldObjectSync.EV_CHEST_OPENED, id))
		_WorldObjectSync.EV_SCROLL_COLLECTED:
			_world._coop_record_scroll_collected(id)
			_world._coop_apply_scroll_collected(id)
			for pid in multiplayer.get_peers():
				if int(pid) != sender:
					_world._net_sync.rpc_id(int(pid), "recv_world_event",
						_WorldObjectSync.encode_event(_WorldObjectSync.EV_SCROLL_COLLECTED, id))

## Host: send the current removed/opened/collected snapshot to a just-joined peer.

func _send_world_snapshot_to_peer(peer_id: int) -> void:
	if not _coop_world_authority() or _world._net_sync == null:
		return
	var payload: Array = _WorldObjectSync.encode_snapshot(
		_world._coop_removed_enemies.keys(), _coop_opened_objects.keys(), _world._coop_collected_scrolls.keys())
	_world._net_sync.rpc_id(peer_id, "recv_world_snapshot", payload)

## Client: reconcile freshly-spawned nodes to the authority's snapshot on join.

func _on_world_snapshot_received(payload: Array) -> void:
	if not _world._coop_active:
		return
	var snap: Dictionary = _WorldObjectSync.decode_snapshot(payload)
	_coop_apply_world_progress(
		snap.get("removed_enemies", []), snap.get("opened_objects", []),
		snap.get("collected_scrolls", []))

# ── Synced world clock & weather (GID-103 / TID-382) ──────────────────────────
# The authority (host) is the single source of truth for time_of_day/days_elapsed/
# weather. Its own local DayNightCycle (_dnc) already advances every frame — this
# section only adds the low-Hz broadcast (+ the co-op-only weather roll, since
# WeatherManager is hard-gated to the "main" infinite-world map). Clients apply the
# broadcast read-only to their own _dnc and to weather visuals. Guarded by
# _coop_active + not _is_infinite (co-op stays on finite named maps); single-player
# and the infinite world are completely untouched.

## Host-only: roll/broadcast tick, called every frame from _process while co-op is
## active. A no-op on clients (they only ever receive recv_env_state) and on the
## infinite world (WeatherManager already owns weather there).

func _tick_env_sync(delta: float) -> void:
	if _world._is_infinite or not _coop_world_authority() or _world._dnc == null:
		return
	_coop_weather_timer -= delta
	var weather_rolled: bool = false
	if _coop_weather_timer <= 0.0:
		_coop_weather_timer = _coop_roll_weather()
		weather_rolled = true
	_coop_env_broadcast_timer -= delta
	if weather_rolled or _coop_env_broadcast_timer <= 0.0:
		_coop_env_broadcast_timer = _world._ENV_BROADCAST_INTERVAL
		_broadcast_env_state()

## Host-only: pick the next weather id + duration, apply it locally, and persist it.
## Returns the seconds until the next reroll.

func _coop_roll_weather() -> float:
	if _coop_weather_rng == null:
		_coop_weather_rng = RandomNumberGenerator.new()
		var seed_val: int = 0
		if SessionStore.is_open():
			seed_val = SessionStore.get_state().world_seed
		_coop_weather_rng.seed = seed_val if seed_val != 0 else randi()
	var weather_id: String = _EnvSync.roll_weather(_coop_weather_rng)
	var duration: float = _EnvSync.roll_duration(_coop_weather_rng, weather_id)
	if SessionStore.is_open():
		SessionStore.get_state().weather_id = weather_id
		SessionStore.mark_dirty()
	_world._on_weather_changed(weather_id, duration)
	return duration

## Host-only: broadcast the current clock/weather to every peer.

func _broadcast_env_state() -> void:
	if not _coop_world_authority() or _world._net_sync == null or _world._dnc == null:
		return
	var days: int = 0
	var weather_id: String = ""
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		days = st.days_elapsed
		weather_id = st.weather_id
	_world._net_sync.rpc("recv_env_state", _EnvSync.encode(_world._dnc.get_time_of_day(), days, weather_id))

## Any peer: apply the authority's clock/weather broadcast (or late-join snapshot).

func _on_env_state_received(payload: Array) -> void:
	if not _world._coop_active:
		return
	var d: Dictionary = _EnvSync.decode(payload)
	if _world._dnc != null:
		_world._dnc.set_time_of_day(float(d.get("time_of_day", 0.4)))
	_coop_env_days_elapsed = int(d.get("days_elapsed", 0))
	var weather_id: String = str(d.get("weather_id", ""))
	if weather_id != _coop_env_weather_id:
		_coop_env_weather_id = weather_id
		if not _world._is_infinite:
			_world._on_weather_changed(weather_id, 0.0)

## The current shared co-op day counter, read from the authoritative SessionStore on
## the host or from the last-received broadcast on a client. Used to key the
## deterministic night-hunt/siege plans so every peer computes the same result.

func _coop_current_days_elapsed() -> int:
	if NetworkManager.is_host() and SessionStore.is_open():
		return SessionStore.get_state().days_elapsed
	return _coop_env_days_elapsed

# ── Party Night Hunts (GID-103 / TID-383) ─────────────────────────────────────
# Deterministic spectral spawns on the shared co-op map at synced night — reuses
# the GID-096 engage-lock/defeat sync generically (the spawn id alone keys it, no
# new event kind or RPC needed: EnemyNPC.engage() emits enemy_data["id"], and
# _on_enemy_engaged_coop already handles any id). Guarded by _coop_active + not
# _is_infinite — the infinite world keeps its own single-player nocturnal system
# (GID-055) untouched.

## Called every frame from _process while co-op is active. Spawns/despawns the
## whole nightly hunt as the synced clock crosses the night/day boundary.

func _send_story_flags_snapshot_to_peer(peer_id: int) -> void:
	if not _coop_world_authority() or _world._net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	_world._net_sync.rpc_id(peer_id, "recv_story_flags_snapshot", st.story_flags.duplicate())

## Client: apply the session story flags on join so NPCs/gates are consistent.

func _on_story_flags_snapshot_received(flags: Dictionary) -> void:
	if not _world._coop_active:
		return
	_coop_story_flag_syncing = true
	for key in flags:
		var val: bool = bool(flags[key])
		SceneManager.save_manager.story_flags[key] = val
		if val:
			GameBus.story_flag_set.emit(str(key))
	_coop_story_flag_syncing = false

## Called when GameBus.story_flag_set fires locally (any setter).
## Routes the flag change through the authority so the whole party stays in sync.

func _on_local_story_flag_set(key: String) -> void:
	# Re-evaluating the on-map cast (Maiteln's follower, hide_flag_key NPCs) is
	# WorldScene._on_story_flag_set_for_cast's job — it is wired for every mode,
	# not just co-op, because this handler only exists inside a session.
	if not _world._coop_active or _world._net_sync == null or not NetworkManager.is_active():
		return
	if _coop_story_flag_syncing:
		return
	var value: bool = SceneManager.save_manager.get_story_flag(key)
	if NetworkManager.is_host():
		# Apply to session state and broadcast to all clients.
		if SessionStore.is_open():
			var st = SessionStore.get_state()
			if st != null:
				st.story_flags[key] = value
				SessionStore.mark_dirty()
		_coop_story_flag_syncing = true
		_world._net_sync.rpc("recv_story_flag", key, value)
		_coop_story_flag_syncing = false
	else:
		# Submit intent to authority; the authority will broadcast back to everyone.
		_world._net_sync.rpc_id(1, "submit_story_flag", key, value)

## Any peer: the authority broadcast a flag change — apply locally.

func _on_story_flag_received(key: String, value: bool) -> void:
	if not _world._coop_active:
		return
	_coop_story_flag_syncing = true
	SceneManager.save_manager.story_flags[key] = value
	if value:
		GameBus.story_flag_set.emit(key)
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		if st != null:
			st.story_flags[key] = value
			SessionStore.mark_dirty()
	_coop_story_flag_syncing = false

## Authority: a client wants to set a flag — arbitrate (idempotent) and broadcast.

func _on_story_flag_submitted(sender: int, key: String, value: bool) -> void:
	if not _coop_world_authority() or _world._net_sync == null:
		return
	# Idempotency: if the flag is already this value, skip side-effects.
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		if st != null and st.story_flags.get(key, false) == value:
			return
		if st != null:
			st.story_flags[key] = value
			SessionStore.mark_dirty()
	_coop_story_flag_syncing = true
	SceneManager.save_manager.story_flags[key] = value
	if value:
		GameBus.story_flag_set.emit(key)
	# Broadcast to all peers (including the submitter so their SaveManager is synced).
	_world._net_sync.rpc("recv_story_flag", key, value)
	_coop_story_flag_syncing = false

## Remove already-resolved enemy nodes and flip opened chests. Shared by host resume
## (_setup_session) and client join (_on_world_snapshot_received).

func _coop_apply_world_progress(removed_enemies: Array, opened_objects: Array, collected_scrolls: Array = []) -> void:
	for eid in removed_enemies:
		_coop_remove_enemy_node(str(eid))
	for cid in opened_objects:
		_coop_mark_chest_opened_node(str(cid))
	for sid in collected_scrolls:
		_world._coop_apply_scroll_collected(str(sid))

## Host: broadcast positions for any live shared enemy at a low Hz (inert while all
## enemies are static, as on every current co-op map). Called from _process.

func _broadcast_enemy_positions(delta: float) -> void:
	if not _coop_world_authority() or _world._net_sync == null or _world._enemy_nodes.is_empty():
		return
	_enemy_pos_accum += delta
	if _enemy_pos_accum < _world._ENEMY_POS_INTERVAL:
		return
	_enemy_pos_accum = 0.0
	var states: Array = []
	for eid in _world._enemy_nodes.keys():
		var raw = _world._enemy_nodes.get(eid)
		if is_instance_valid(raw):
			var node: Node3D = raw
			states.append(_EnemySync.encode_state(
				str(eid), node.position.x, node.position.z, true))
	if not states.is_empty():
		_world._net_sync.rpc("recv_enemy_positions", _EnemySync.encode_batch(states))

## Client: store the latest authority positions; _process interpolates toward them.

func _on_enemy_positions_received(payload: Array) -> void:
	if not _world._coop_active or NetworkManager.is_host():
		return
	for st: Dictionary in _EnemySync.decode_batch(payload):
		var eid: String = str(st.get("id", ""))
		if eid == "" or _world._coop_removed_enemies.has(eid):
			continue
		_coop_enemy_targets[eid] = Vector2(float(st.get("x", 0.0)), float(st.get("z", 0.0)))

## Client: smooth shared enemies toward their last synced position (no-op for static
## enemies, where target == spawn). Called from _process.

func _interp_synced_enemies(delta: float) -> void:
	if _coop_enemy_targets.is_empty():
		return
	for eid in _coop_enemy_targets.keys():
		var node: Node3D = _world._valid_node3d(_world._enemy_nodes.get(eid))
		if not is_instance_valid(node):
			_coop_enemy_targets.erase(eid)
			continue
		var tgt2: Vector2 = _coop_enemy_targets[eid]
		var target: Vector3 = Vector3(tgt2.x, _world.get_terrain_height(tgt2.x, tgt2.y), tgt2.y)
		node.position = _EnemySync.interp(node.position, target, delta, 12.0)

# ── Co-op story mode — map transitions (GID-098 / TID-355) ───────────────────

## Received from any peer: follow them to target_map / door_id.
## Guards against double-transition on the same WorldScene instance.

func _on_map_transition_received(target_map: String, door_id: String) -> void:
	if not _world._coop_active:
		return
	if _world._coop_map_transitioning:
		return
	# A peer already on the destination map (e.g. everyone but the rallier, in a
	# rally-to-peer broadcast — GID-105 / TID-388) has nothing to follow; re-entering
	# would needlessly reload the map and reset their position to the spawn/door
	# default.
	if not target_map.is_empty() and target_map == _world.map_name:
		return
	_world._coop_map_transitioning = true
	if target_map.is_empty():
		SceneManager.exit_map()
	elif target_map.begins_with("spire_floor_") or _world.map_name.begins_with("spire_floor_"):
		# Co-op Endless Spire (TID-391): entering, advancing floors, and the final
		# return to madrian are all one-way automatic moves — see
		# enter_coop_map_no_stack's doc comment for why the normal stack-pushing
		# enter_map() would leave map_stack permanently polluted here.
		SceneManager.enter_coop_map_no_stack(target_map, door_id)
	else:
		SceneManager.enter_map(target_map, door_id)

# ── Rally waystones (GID-105 / TID-388) ──────────────────────────────────────
# Lets any connected party member teleport instantly to a teammate from the
# fast-travel UI — same-map is an instant local position sync, cross-map reuses
# the TID-355 followed-transition mechanism (so the rest of the party, if any,
# converges too). Guarded by NetworkManager.is_active(); single-player fast
# travel sees no rally section at all (MapViewOverlay._rally_targets is empty).

## Connected session members eligible for rally-to: everyone whose last-known
## map we've learned (skips late-joiners whose location hasn't arrived yet).

func _build_rally_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not NetworkManager.is_active():
		return out
	for pid in _world._remote_identities.keys():
		var peer_map: String = str(_remote_player_maps.get(pid, ""))
		if peer_map == "":
			continue
		var ident: Dictionary = _world._remote_identities[pid]
		out.append({
			"peer_id": int(pid),
			"name": str(ident.get("name", "Player")),
			"color": ident.get("color", Color.WHITE),
			"map": peer_map,
		})
	return out

## Rally to a connected teammate. Same-map: instant local position sync.
## Cross-map: broadcast the existing followed-transition RPC + follow locally.

func _rally_to_peer(peer_id: int) -> void:
	if not NetworkManager.is_active() or _world._player == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_rally_time < _world._RALLY_COOLDOWN:
		GameBus.hud_message_requested.emit("Rally is on cooldown.")
		return
	var target_map: String = str(_remote_player_maps.get(peer_id, ""))
	if target_map == "":
		return
	var target_name: String = str(_world._remote_identities.get(peer_id, {}).get("name", "Player"))
	_last_rally_time = now
	GameBus.hud_message_requested.emit("Rallying to %s…" % target_name)
	if _world._net_sync != null:
		_world._net_sync.rpc_id(peer_id, "recv_rally_notice", MpProfile.get_display_name())
	if target_map == _world.map_name:
		var rp: Node3D = _world._valid_node3d(_world._remote_player_nodes.get(peer_id))
		if rp != null and is_instance_valid(rp):
			_world._player.global_position = rp.global_position
		return
	if _world._coop_map_transitioning:
		return
	_world._coop_map_transitioning = true
	if _world._net_sync != null:
		_world._net_sync.rpc("recv_map_transition", target_map, "")
	SceneManager.enter_map(target_map, "")

## A teammate is rallying to us — surface a hero-moment toast.

func _on_rally_notice_received(rallier_name: String) -> void:
	GameBus.hud_message_requested.emit("%s is rallying to you!" % rallier_name)

# ── Downed & rescue in shared dungeons (GID-105 / TID-389) ───────────────────
# A PvE loss inside a co-op shared dungeon ("dungeon_*") leaves the player downed
# (frozen in place) instead of routing to the single-player defeat screen
# (SceneManager._on_battle_lost intercepts before that path). A teammate can
# revive them via the same interact prompt pattern as chests/NPCs; otherwise a
# self-managed timeout auto-respawns them at the dungeon entrance. The downed
# flag itself rides the existing AvatarSync stream (see _on_avatar_received);
# only the revive action needs host arbitration, to avoid two teammates racing
# to revive the same target.

## Called by SceneManager (via _saved_world_scene.call) right after the world is
## restored following a co-op-dungeon PvE loss.

func enter_downed_state() -> void:
	if not _world._coop_active or _world._player == null:
		return
	_world._coop_downed = true
	_coop_downed_peers[NetworkManager.local_id()] = true
	_world._downed_started_at = Time.get_ticks_msec() / 1000.0
	_world._player.set_physics_process(false)
	_world._set_player_alpha(0.55)
	_show_downed_banner()
	GameBus.hud_message_requested.emit("Downed! Waiting for rescue…")
	get_tree().create_timer(_DownedSync.RESCUE_TIMEOUT, false).timeout.connect(_on_downed_timeout)

## Fires RESCUE_TIMEOUT seconds after enter_downed_state(). No-ops if already
## revived (a stale timer from a downed period that already ended).

func _on_downed_timeout() -> void:
	if not _world._coop_downed:
		return
	GameBus.hud_message_requested.emit("Respawning at the dungeon entrance…")
	if _world._player != null:
		_world._player.position = _world._dungeon_spawn_pos
	_exit_downed_state()

## Un-freeze the local player and clear downed bookkeeping (revived or timed out).

func _exit_downed_state() -> void:
	_world._coop_downed = false
	_coop_downed_peers[NetworkManager.local_id()] = false
	if _world._player != null:
		_world._player.set_physics_process(true)
		_world._set_player_alpha(1.0)
	_hide_downed_banner()

func _show_downed_banner() -> void:
	if _world._downed_banner != null and is_instance_valid(_world._downed_banner):
		_world._downed_banner.show()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_world._downed_banner = Label.new()
	_world._downed_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world._downed_banner.add_theme_font_size_override("font_size", int(vp.y * 0.030))
	_world._downed_banner.add_theme_color_override("font_color", Color(0.75, 0.80, 1.0))
	_world._downed_banner.custom_minimum_size = Vector2(vp.x * 0.6, vp.y * 0.06)
	_world._downed_banner.position = Vector2(vp.x * 0.2, vp.y * 0.12)
	_world._hud.add_child(_world._downed_banner)

func _hide_downed_banner() -> void:
	if _world._downed_banner != null and is_instance_valid(_world._downed_banner):
		_world._downed_banner.queue_free()
		_world._downed_banner = null

## Nearest downed teammate within range, or -1. Local player is never a valid
## target here — you cannot revive yourself.

func _find_nearby_downed_peer(px: float, pz: float, range_dist: float) -> int:
	if not _world._coop_active:
		return -1
	for pid in _world._remote_player_nodes.keys():
		if not bool(_coop_downed_peers.get(pid, false)):
			continue
		var rp: Node3D = _world._valid_node3d(_world._remote_player_nodes[pid])
		if not is_instance_valid(rp) or not rp.visible:
			continue
		var d: float = Vector2(rp.position.x, rp.position.z).distance_to(Vector2(px, pz))
		if d <= range_dist:
			return int(pid)
	return -1

## Local player interacted with a downed teammate. Host applies directly;
## a client submits the request for the host to arbitrate.

func _request_revive(peer_id: int) -> void:
	if NetworkManager.is_host():
		_authority_apply_revive(peer_id)
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(1, "submit_revive_request", peer_id)

## Host-only: validate and apply a revive, then broadcast it. A stale request
## (target already respawned via timeout, or already revived) is silently
## discarded — DownedSync.can_revive centralizes that check.

func _authority_apply_revive(peer_id: int) -> void:
	if not NetworkManager.is_host():
		return
	if not _DownedSync.can_revive(bool(_coop_downed_peers.get(peer_id, false))):
		return
	_coop_downed_peers[peer_id] = false
	if peer_id == NetworkManager.local_id():
		_exit_downed_state()
	else:
		var rp: Node3D = _world._valid_node3d(_world._remote_player_nodes.get(peer_id))
		if rp != null and is_instance_valid(rp) and rp.has_method("set_downed"):
			rp.set_downed(false)
	GameBus.hud_message_requested.emit("Revived!")
	if _world._net_sync != null:
		_world._net_sync.rpc("recv_revive", peer_id)

## NetSync → host: a client's revive request.

func _on_revive_request_submitted(_sender: int, peer_id: int) -> void:
	_authority_apply_revive(peer_id)

## NetSync → peer: the host confirmed a revive.

func _on_revive_received(peer_id: int) -> void:
	if not _world._coop_active:
		return
	_coop_downed_peers[peer_id] = false
	if peer_id == NetworkManager.local_id():
		_exit_downed_state()
		GameBus.hud_message_requested.emit("Revived!")
	else:
		var rp: Node3D = _world._valid_node3d(_world._remote_player_nodes.get(peer_id))
		if rp != null and is_instance_valid(rp) and rp.has_method("set_downed"):
			rp.set_downed(false)

# ── Shared dungeon crawl (GID-102 / TID-380) ──────────────────────────────────
#
# madrian (and any other co-op-supported named map) has no authored dungeon
# door, so the party has no way to reach DungeonGen's procedural dungeons
# together. This adds a host-only HUD trigger that picks a shared seed and
# broadcasts the same "dungeon_<seed>" map name via the existing TID-355
# recv_map_transition RPC — no new sync RPC needed, since DungeonGen is a pure
# function of (name, seed) and WorldScene's dungeon-load branch only inspects
# the map_name string, not how it was constructed.

## Host-only: derive a shared seed and broadcast the transition so every peer
## follows into the identical generated dungeon.

func _start_dungeon_crawl() -> void:
	if not NetworkManager.is_host():
		return  # defensive: don't trust client-side button visibility alone
	if not _world._coop_active or _world._net_sync == null or _world._coop_map_transitioning:
		return
	var seed_val: int = randi()
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		# world_seed + days_elapsed: reopening the crawl on the same in-game day
		# reproduces the same dungeon; a new day yields a fresh one.
		seed_val = hash(str(st.world_seed) + "_dungeon_" + str(st.days_elapsed))
	var target_map: String = "dungeon_%d" % seed_val
	_world._coop_map_transitioning = true
	_world._net_sync.rpc("recv_map_transition", target_map, "")
	SceneManager.enter_map(target_map, "")

# ── Party Guildhall (GID-106 / TID-392) ──────────────────────────────────────
# A session-owned home base, separate from the single-player Player Home.
# Unlike the co-op Spire (a one-way run through many auto-generated floors),
# the guildhall is a normal single-room sub-map exactly like player_home: entry
# uses the standard stack-pushing enter_map() (not enter_coop_map_no_stack), so
# the map's authored exit door (target_map="") pops back to madrian through the
# existing generic door-interact + exit_map() machinery — no new code needed
# for the exit, late-joiner redirect (TID-355), or map-scoped avatar sync
# (TID-352), all of which are already fully map-name-agnostic.

## Host-only: broadcasts + performs the shared transition into the guildhall.
## Mirrors _start_dungeon_crawl exactly.

func _start_guildhall() -> void:
	if not NetworkManager.is_host():
		return  # defensive: don't trust client-side button visibility alone
	if not _world._coop_active or _world._net_sync == null or _world._coop_map_transitioning:
		return
	# has_guildhall() is always true post-migration (auto-unlocked, no purchase
	# flow) — this is a defensive guard, not a real gate.
	if SessionStore.is_open():
		var st = SessionStore.get_state()
		if st != null and not st.has_guildhall():
			return
	_world._coop_map_transitioning = true
	_world._net_sync.rpc("recv_map_transition", "guildhall", "")
	SceneManager.enter_map("guildhall", "")

# ── Co-op Endless Spire (GID-106 / TID-390) ──────────────────────────────────
#
# Adapts the single-player Endless Spire (GID-038) for a party: same seed-based
# floor composition, but the run deck is shared and built collaboratively via
# authority-orchestrated alternating draft picks (one pick per floor clear,
# rotating among members), reusing the loot-roll prompt-session pattern
# (TID-381). The run itself is entirely transient state living on
# SceneManager._coop_spire_run (see that file for why — it must survive
# floor-to-floor map transitions, which destroy/recreate this WorldScene).
#
# Scope note: this task delivers the entry point, shared-seed run start, and the
# full draft-orchestration engine below. _start_coop_spire_draft(floor) is the
# public hook TID-391 calls once it has a real floor-win condition (via the
# joint PvE battle engine, GID-099) — nothing calls it yet in this task, mirroring
# how TID-355 built recv_map_transition before TID-380 became its first real caller.

## Host-only: starts (or resumes) a co-op Spire run and broadcasts the floor-1 (or
## current-floor, if resuming) map transition so every peer follows in — reuses
## the existing recv_map_transition RPC verbatim, exactly like _start_dungeon_crawl.

func _on_session_flags(flags: Dictionary) -> void:
	_world._session_dedicated = bool(flags.get("dedicated", false))

## Server handler: client A wants to challenge client B.
## Stores the pending challenge and relays the request to B as a normal request_battle.
