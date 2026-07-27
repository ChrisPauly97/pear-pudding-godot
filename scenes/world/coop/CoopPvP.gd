## Competitive play against other session members: the challenge handshake and
## its timeouts, team duels, dedicated-server referee routing, spectating,
## wagered duels and the champion record, ranked ratings and the leaderboard,
## sealed-deck draft duels, and session tournaments.
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
const _ChallengeTimeout = preload("res://game_logic/net/ChallengeTimeout.gd")
const _DraftDuelGen = preload("res://game_logic/net/DraftDuelGen.gd")
const _DraftDuelPickScene = preload("res://scenes/ui/DraftDuelPickScene.gd")
const _LeaderboardOverlay = preload("res://scenes/ui/LeaderboardOverlay.gd")
const _RatingMath        = preload("res://game_logic/net/RatingMath.gd")
const _TournamentSync    = preload("res://game_logic/net/TournamentSync.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")

var _active_team_duel_peer_ids: Array[int] = []
var _active_team_duel_teams: Array = []
var _challenge_accept_panel: Node = null
var _challenge_btn: Button = null
var _challenge_target_peer: int = -1     # nearby remote peer eligible to challenge
var _draft_accept_panel: Node = null    # Accept/Decline prompt (CanvasLayer)
var _draft_duel_btn: Button = null      # proximity-gated HUD button (mobile + desktop)
var _draft_local_deck: Array = []       # my finished transient deck (instance dicts)
var _draft_local_done: bool = false
var _draft_opp_deck: Array = []         # opponent's finished transient deck
var _draft_opp_done: bool = false
var _draft_peer: int = -1               # opponent peer for the outgoing/active draft
var _draft_peer_armed_at: int = -1      # TID-431: armed only while awaiting accept (not mid-duel)
var _draft_picker: Node = null          # DraftDuelPickScene instance, nil when closed
var _draft_picker_layer: Node = null    # its CanvasLayer wrapper
var _draft_picking: bool = false        # true once the pick overlay is open
var _draft_seed: int = 0                # agreed shared seed for the active draft
var _pending_challenge_armed_at: int = -1  # TID-431: Time.get_ticks_msec() when set, -1 = idle
var _pending_challenge_deck: Array = []  # challenger's deck stored until we accept
var _pending_challenge_ranked: bool = false  # GID-102 (TID-373): challenger's ranked opt-in
var _pending_draft_from: int = -1       # incoming draft challenge awaiting our response
var _pending_draft_from_armed_at: int = -1  # TID-431: Time.get_ticks_msec() when set, -1 = idle
var _pending_draft_seed: int = 0        # seed carried by that pending challenge
var _pending_wager_armed_at: int = -1    # TID-431: Time.get_ticks_msec() when set, -1 = idle
var _pending_wager_coins: int = 0        # ante for the pending wagered challenge
var _pending_wager_deck: Array = []      # challenger's deck for a wagered challenge
var _pending_wager_from: int = -1        # peer_id of an incoming wagered challenge
var _pvp_ante_coins: int = 0             # ante for the active duel (escrowed on start)
var _pvp_ranked: bool = false            # ranked flag captured for the active duel (both peers)
var _pvp_relay_challenger_armed_at: int = -1  # TID-431: relay-side timeout arm timestamp
var _pvp_relay_challenger_deck: Array = [] # server: challenger's deck
var _pvp_relay_challenger_id: int = -1   # server: peer_id of the challenger awaiting response
var _pvp_relay_target_id: int = -1       # server: peer_id of the challenged player
var _ranked_toggle_btn: Button = null    # "Ranked" opt-in toggle next to the challenge button
var _ranked_toggle_on: bool = false      # local challenger's ranked opt-in state
var _spectate_btn: Button = null         # shown to non-participants while duel active
var _tournament_ante: int = 0                 # host-only: ante used to build the current bracket
var _tournament_canonical_to_participant: Dictionary = {}  # host-only: {0: participant_idx, 1: participant_idx}
var _tournament_current_is_host_match: bool = false  # host-only: is the in-flight match one the host is playing?
var _tournament_decks: Array = []             # host-only: participant idx -> deck instances
var _tournament_match_countdown: float = 0.0  # host-only: seconds until the next match starts (lets peers return to world + read the bracket)
var _tournament_panel: VBoxContainer = null   # inner row container
var _tournament_panel_outer: Control = null   # outer panel Control, nil when never built
var _tournament_pending_result: Dictionary = {}  # host-only: {} or {"winner_participant_idx": int}
var _tournament_tokens: Array[String] = []    # host-only: participant idx -> identity token

func _ensure_challenge_button() -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_challenge_btn = _world._world_hud.register_action("challenge", "Challenge to Battle",
		WorldHUD.ZONE_CONTEXT, _request_challenge, Callable(), Vector2(vp.y * 0.34, vp.y * 0.07))
	_challenge_btn.hide()
	# Ranked opt-in toggle (GID-102 / TID-373): stacks below the challenge button in
	# the shared contextual zone — a touch/click target like every other HUD toggle
	# (no separate keybind needed). Built directly (not via register_action) since it
	# needs a `.toggled` connection, not a simple `.pressed` callback.
	_ranked_toggle_btn = _UiUtil.make_button("Ranked: OFF", Vector2(vp.y * 0.20, vp.y * 0.05), int(vp.y * 0.020))
	_ranked_toggle_btn.toggle_mode = true
	_ranked_toggle_btn.tooltip_text = "When ON, this duel counts toward your ranked rating."
	_ranked_toggle_btn.hide()
	_ranked_toggle_btn.toggled.connect(func(on: bool) -> void:
		_ranked_toggle_on = on
		_ranked_toggle_btn.text = "Ranked: ON" if on else "Ranked: OFF")
	var context_zone: Container = _world._world_hud.get_zone_container(WorldHUD.ZONE_CONTEXT)
	if context_zone != null:
		context_zone.add_child(_ranked_toggle_btn)
	else:
		_world._hud.add_child(_ranked_toggle_btn)
	UiFx.attach(_ranked_toggle_btn)

## Shows/hides the challenge button based on proximity to a remote player. Called
## each frame from _process while co-op is active. GID-107 / TID-396 priority rule:
## the world-interact prompt (door/chest/NPC/scroll) always wins the shared
## contextual slot over a social action — interacting with the world is the more
## frequent, lower-friction action.

func _update_challenge_proximity() -> void:
	if _challenge_btn == null or not is_instance_valid(_challenge_btn):
		return
	if _world._world_hud != null and _world._world_hud.is_interact_visible():
		_challenge_btn.hide()
		if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
			_ranked_toggle_btn.hide()
		return
	# Suppress while a challenge is pending or we're not in the world.
	if _world._pending_challenge_from != -1 or SceneManager._state != SceneManager.State.WORLD:
		_challenge_btn.hide()
		if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
			_ranked_toggle_btn.hide()
		return
	if _world._player == null:
		_challenge_btn.hide()
		if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
			_ranked_toggle_btn.hide()
		return
	var range_world: float = _world._CHALLENGE_RANGE * IsoConst.TILE_SIZE
	var nearest_pid: int = -1
	var nearest_d: float = range_world
	for pid in _world._remote_player_nodes.keys():
		var rp: Node3D = _world._valid_node3d(_world._remote_player_nodes[pid])
		if not is_instance_valid(rp):
			continue
		var d: float = Vector2(rp.position.x, rp.position.z).distance_to(
			Vector2(_world._player.position.x, _world._player.position.z))
		if d <= nearest_d:
			nearest_d = d
			nearest_pid = int(pid)
	_challenge_target_peer = nearest_pid
	_challenge_btn.visible = nearest_pid != -1
	if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
		_ranked_toggle_btn.visible = nearest_pid != -1

## Local deck as a plain Array of Dictionaries for RPC transmission.

func _request_challenge() -> void:
	if _challenge_target_peer == -1 or _world._net_sync == null:
		return
	var my_deck: Array = _world._local_deck_for_net()
	if my_deck.size() < IsoConst.DECK_MIN:
		_world._show_tip("Your deck is too small to duel — add at least %d cards." % IsoConst.DECK_MIN)
		return
	if _world._session_dedicated:
		# Dedicated server: route through the server referee (peer_id 1). Ranked toggle
		# is not threaded through the dedicated-server relay path in this task — out of
		# scope (see TID-373 task file); always casual on a dedicated server for now.
		_world._net_sync.rpc_id(1, "relay_pvp_request", _challenge_target_peer, my_deck)
	else:
		_world._net_sync.rpc_id(_challenge_target_peer, "request_battle", my_deck, _ranked_toggle_on)
	_world._show_tip("Ranked challenge sent…" if _ranked_toggle_on else "Challenge sent…")

# ── Team PvP duels (GID-102 / TID-371) ────────────────────────────────────────
# GID-107 (TID-395): Team Duel is now a Party-panel action (see _open_party_panel's
# show_team_duel, computed fresh on open) instead of its own standalone HUD button.

## Host-only: resolves a connected peer's current deck as instances for the team duel.
## The host's own deck comes straight from SaveManager; a client's deck is read from
## its already-synced GID-095 session character record — no extra RPC round-trip needed.

func _team_deck_for_peer(pid: int) -> Array:
	if pid == multiplayer.get_unique_id():
		return _world._local_deck_for_net()
	var token: String = str(_world._session_token_by_peer.get(pid, ""))
	if token == "" or not SessionStore.is_open():
		return []
	var st = SessionStore.get_state()
	if st == null:
		return []
	var rec: Dictionary = st.get_member(token)
	if rec.is_empty():
		return []
	var by_uid: Dictionary = {}
	for inst in rec.get("owned_cards", []):
		if inst is Dictionary:
			by_uid[str(inst.get("uid", ""))] = inst
	var out: Array = []
	for uid in rec.get("player_deck", []):
		if by_uid.has(str(uid)):
			out.append(by_uid[str(uid)])
	return out

## Host: assigns teams from the connected 4-peer session and starts a 2v2 duel for
## everyone immediately — no individual accept/decline (keeps team-formation UI
## minimal, per the task notes). Host + the first-sorted client form team 0; the other
## two clients form team 1. Absolute GameState indices: [host, client_b, host's
## partner, client_c] so the interleaved [teamA_0,teamB_0,teamA_1,teamB_1] layout in
## GameState.setup_team_battle puts the host's chosen partner on the host's team.

func _start_team_duel() -> void:
	if not NetworkManager.is_host() or _world._net_sync == null:
		return
	var clients: Array = multiplayer.get_peers()
	if clients.size() < 3:
		_world._show_tip("Need 4 players for a team duel.")
		return
	clients.sort()
	var host_id: int = multiplayer.get_unique_id()
	var abs_peer_ids: Array[int] = [host_id, int(clients[1]), int(clients[0]), int(clients[2])]
	var team_assignments: Array = [0, 1, 0, 1]
	var all_decks: Array = []
	for pid in abs_peer_ids:
		all_decks.append(_team_deck_for_peer(pid))
	for i in range(abs_peer_ids.size()):
		var pid: int = abs_peer_ids[i]
		if pid != host_id:
			_world._net_sync.rpc_id(pid, "notify_team_duel_start", i, team_assignments, all_decks)
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	_active_team_duel_peer_ids = abs_peer_ids
	_active_team_duel_teams = team_assignments
	SceneManager.enter_team_battle(0, team_assignments, all_decks)

## Client: the host started a team duel — enter it with the assigned absolute index.

func _on_notify_team_duel_start(my_idx: int, team_assignments: Array, all_decks: Array) -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	SceneManager.enter_team_battle(my_idx, team_assignments, all_decks)

## Incoming challenge — show an Accept/Decline prompt.

func _on_battle_requested(from_id: int, challenger_deck: Array, ranked: bool = false) -> void:
	if _world._pending_challenge_from != -1:
		return  # already handling one
	_world._pending_challenge_from = from_id
	_pending_challenge_deck = challenger_deck
	_pending_challenge_ranked = ranked
	_pending_challenge_armed_at = Time.get_ticks_msec()
	_show_challenge_accept_panel(from_id, ranked)

## Challenger learns the response.

func _on_battle_responded(_from_id: int, accepted: bool, responder_deck: Array, ranked: bool = false) -> void:
	if not accepted:
		_world._show_tip("Challenge declined.")
		return
	_enter_pvp(responder_deck, ranked)

# ── Dedicated-server PvP routing (GID-097 / TID-353) ──────────────────────────

## Client handler: server told us we're in a dedicated-server session.

func _on_relay_pvp_request(sender_id: int, target_peer_id: int, challenger_deck: Array) -> void:
	if not NetworkManager.is_dedicated_server():
		return
	if _pvp_relay_challenger_id != -1:
		return  # a challenge is already pending
	_pvp_relay_challenger_id = sender_id
	_pvp_relay_challenger_deck = challenger_deck
	_pvp_relay_target_id = target_peer_id
	_pvp_relay_challenger_armed_at = Time.get_ticks_msec()
	if _world._net_sync != null:
		_world._net_sync.rpc_id(target_peer_id, "request_battle", challenger_deck)

## Server handler: the challenged peer accepted or declined.
## On accept: launch a headless referee BattleScene and notify both clients.

func _on_relay_pvp_response(sender_id: int, challenger_id: int, accepted: bool, responder_deck: Array) -> void:
	if not NetworkManager.is_dedicated_server():
		return
	if _pvp_relay_challenger_id != challenger_id or _pvp_relay_target_id != sender_id:
		return  # stale or mismatched response
	var challenger: int = _pvp_relay_challenger_id
	var target: int = _pvp_relay_target_id
	var deck_a: Array = _pvp_relay_challenger_deck.duplicate()
	_pvp_relay_challenger_id = -1
	_pvp_relay_challenger_deck = []
	_pvp_relay_target_id = -1
	_pvp_relay_challenger_armed_at = -1
	if not accepted:
		if _world._net_sync != null:
			_world._net_sync.rpc_id(challenger, "respond_battle", false, [])
		return
	# Notify both clients: each will call enter_pvp_battle with their role.
	if _world._net_sync != null:
		_world._net_sync.rpc_id(challenger, "notify_pvp_start", 0, responder_deck)
		_world._net_sync.rpc_id(target, "notify_pvp_start", 1, deck_a)
	# Launch the headless referee on the server itself. Tokens (GID-102 / TID-372) let
	# the referee verify a later reconnect from either combatant.
	var token_a: String = str(_world._session_token_by_peer.get(challenger, ""))
	var token_b: String = str(_world._session_token_by_peer.get(target, ""))
	SceneManager.enter_pvp_referee(deck_a, responder_deck, challenger, target, token_a, token_b)

## Client handler: server assigned us a player index; start the PvP battle.

func _on_notify_pvp_start(my_player_idx: int, opponent_deck: Array) -> void:
	if NetworkManager.is_dedicated_server():
		return
	SceneManager.enter_pvp_battle(my_player_idx, opponent_deck)

func _show_challenge_accept_panel(from_id: int, ranked: bool = false) -> void:
	if _challenge_accept_panel != null and is_instance_valid(_challenge_accept_panel):
		_challenge_accept_panel.queue_free()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var prompt: Dictionary = _world._build_prompt(180, 0.025)
	var layer: CanvasLayer = prompt["layer"]
	_challenge_accept_panel = layer
	var vbox: VBoxContainer = prompt["vbox"]

	var lbl := Label.new()
	lbl.text = "A player challenges you to a RANKED card battle!" if ranked \
		else "A player challenges you to a card battle!"
	lbl.add_theme_font_size_override("font_size", int(vp.y * 0.03))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ranked:
		lbl.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(lbl)

	var row := _UiUtil.make_hbox(int(vp.y * 0.03), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var accept_btn := _UiUtil.make_button("Accept", Vector2(vp.y * 0.2, vp.y * 0.07), int(vp.y * 0.026), _accept_challenge.bind(from_id), row)

	var decline_btn := _UiUtil.make_button("Decline", Vector2(vp.y * 0.2, vp.y * 0.07), int(vp.y * 0.026), _decline_challenge.bind(from_id), row)

func _dismiss_challenge_panel() -> void:
	if _challenge_accept_panel != null and is_instance_valid(_challenge_accept_panel):
		_challenge_accept_panel.queue_free()
	_challenge_accept_panel = null

func _accept_challenge(from_id: int) -> void:
	_dismiss_challenge_panel()
	var my_deck: Array = _world._local_deck_for_net()
	var ranked: bool = _pending_challenge_ranked
	if my_deck.size() < IsoConst.DECK_MIN:
		_world._show_tip("Your deck is too small to duel.")
		if _world._net_sync != null:
			if _world._session_dedicated:
				_world._net_sync.rpc_id(1, "relay_pvp_response", from_id, false, [])
			else:
				_world._net_sync.rpc_id(from_id, "respond_battle", false, [])
		_world._pending_challenge_from = -1
		_pending_challenge_ranked = false
		_pending_challenge_armed_at = -1
		return
	var opp_deck: Array = _pending_challenge_deck
	_world._pending_challenge_from = -1
	_pending_challenge_deck = []
	_pending_challenge_ranked = false
	_pending_challenge_armed_at = -1
	if _world._net_sync != null:
		if _world._session_dedicated:
			# Server will send notify_pvp_start to both peers — don't call _enter_pvp here.
			_world._net_sync.rpc_id(1, "relay_pvp_response", from_id, true, my_deck)
			return
		_world._net_sync.rpc_id(from_id, "respond_battle", true, my_deck, ranked)
	# Record the opponent peer so the host's spectator + rating (TID-370) paths know
	# who it dueled when accepting an incoming challenge (not just when challenging).
	_challenge_target_peer = from_id
	_enter_pvp(opp_deck, ranked)

func _decline_challenge(from_id: int) -> void:
	_dismiss_challenge_panel()
	_pending_challenge_ranked = false
	if _world._net_sync != null:
		if _world._session_dedicated:
			_world._net_sync.rpc_id(1, "relay_pvp_response", from_id, false, [])
		else:
			_world._net_sync.rpc_id(from_id, "respond_battle", false, [])
	_world._pending_challenge_from = -1
	_pending_challenge_deck = []
	_pending_challenge_armed_at = -1

# ── TID-431 (BID-034): challenge handshake timeouts ───────────────────────────
# An unanswered duel/wager/draft-duel challenge (or a stuck dedicated-server
# relay) previously left the holder's pending state set forever — buttons
# stayed hidden and no new challenge could be issued until the peer
# disconnected. Polled once per frame from _process while co-op is active;
# each flow reuses its own existing decline/abort path so the reset, RPC
# notification, and armed_at clearing all happen in exactly one place.

func _check_challenge_timeouts() -> void:
	var now: int = Time.get_ticks_msec()
	if _ChallengeTimeout.has_expired(_pending_challenge_armed_at, now):
		_world._show_tip("Challenge expired — no response in time.")
		_decline_challenge(_world._pending_challenge_from)
	if _ChallengeTimeout.has_expired(_pending_wager_armed_at, now):
		_world._show_tip("Wagered challenge expired — no response in time.")
		_decline_wager_challenge(_pending_wager_from)
	if _ChallengeTimeout.has_expired(_pending_draft_from_armed_at, now):
		_world._show_tip("Draft duel challenge expired — no response in time.")
		_decline_draft_duel(_pending_draft_from)
	if _ChallengeTimeout.has_expired(_draft_peer_armed_at, now):
		_abort_draft_duel("No response to your draft duel challenge.")
	if _ChallengeTimeout.has_expired(_pvp_relay_challenger_armed_at, now):
		_on_relay_pvp_response(_pvp_relay_target_id, _pvp_relay_challenger_id, false, [])

## Both peers route into SceneManager. The co-op host is always the battle
## authority (canonical player 0); the client is player 1.
## ranked (GID-102 / TID-373): agreed by both peers via the request_battle/respond_battle
## handshake before either calls this, so both pass the same value into enter_pvp_battle.

func _enter_pvp(opponent_deck: Array, ranked: bool = false) -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
		_ranked_toggle_btn.hide()
	_pvp_ranked = ranked
	var local_idx: int = 0 if NetworkManager.is_host() else 1
	# GID-101 (TID-367): host broadcasts duel-start to spectators
	if NetworkManager.is_host() and _world._net_sync != null:
		var my_id: int = multiplayer.get_unique_id()
		_world._pvp_ante_peer0 = my_id
		_world._pvp_ante_peer1 = _challenge_target_peer
		for pid in multiplayer.get_peers():
			var p: int = int(pid)
			if p != _challenge_target_peer:
				_world._net_sync.rpc_id(p, "recv_pvp_active", true, my_id, _challenge_target_peer)
	# GID-102 (TID-372): opponent's identity token, so the host can verify a later
	# reconnect. Only meaningful on the host's own call (_session_token_by_peer is
	# host-side only); harmless empty string on the client's own call.
	var opp_token: String = str(_world._session_token_by_peer.get(_challenge_target_peer, ""))
	SceneManager.enter_pvp_battle(local_idx, opponent_deck, 0, opp_token, ranked)

## Returns the biome and time context at the moment of engagement (GID-059).
## Called by SceneManager._on_enemy_engaged() to stamp context into enemy_data.

func _on_pvp_active_received(in_battle: bool, peer_a: int, peer_b: int) -> void:
	if in_battle:
		if not _world._pvp_active_peers.has(peer_a):
			_world._pvp_active_peers.append(peer_a)
		if not _world._pvp_active_peers.has(peer_b):
			_world._pvp_active_peers.append(peer_b)
	else:
		_world._pvp_active_peers.erase(peer_a)
		_world._pvp_active_peers.erase(peer_b)
	if _spectate_btn != null and is_instance_valid(_spectate_btn):
		_spectate_btn.visible = _world._pvp_active_peers.size() >= 2

func _request_spectate() -> void:
	if _world._net_sync == null:
		return
	if NetworkManager.is_host():
		_world._show_tip("You are in the duel — cannot spectate.")
		return
	_world._net_sync.rpc_id(1, "request_spectate_pvp")

func _on_spectate_pvp_requested(sender: int) -> void:
	if not NetworkManager.is_host():
		return
	if _world._pvp_active_peers.size() < 2:
		return
	if _world._net_sync != null:
		_world._net_sync.rpc_id(sender, "recv_spectate_approved")

func _on_spectate_approved() -> void:
	SceneManager.enter_pvp_spectator()


# ── TID-368: Wagered duels & champion record ──────────────────────────────────

func _on_battle_wager_requested(sender: int, challenger_deck: Array, ante_coins: int) -> void:
	if _world._pending_challenge_from != -1 or _pending_wager_from != -1:
		return
	_pending_wager_from = sender
	_pending_wager_deck = challenger_deck
	_pending_wager_coins = ante_coins
	_pending_wager_armed_at = Time.get_ticks_msec()
	_show_wager_accept_panel(sender, ante_coins)

func _show_wager_accept_panel(from_id: int, ante_coins: int) -> void:
	if _challenge_accept_panel != null and is_instance_valid(_challenge_accept_panel):
		_challenge_accept_panel.queue_free()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vh: float = vp.y
	var prompt: Dictionary = _world._build_prompt(181, 0.025)
	var layer: CanvasLayer = prompt["layer"]
	_challenge_accept_panel = layer
	var vbox: VBoxContainer = prompt["vbox"]
	var lbl := _UiUtil.make_label("Wagered duel challenge!\nAnte: %d coins each. Accept?" % ante_coins, int(vh * 0.03), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := _UiUtil.make_hbox(int(vh * 0.03), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var accept_btn := _UiUtil.make_button("Accept (%d coins)" % ante_coins, Vector2(vh * 0.26, vh * 0.07), int(vh * 0.024), _accept_wager_challenge.bind(from_id, ante_coins), row)
	var decline_btn := _UiUtil.make_button("Decline", Vector2(vh * 0.18, vh * 0.07), int(vh * 0.024), _decline_wager_challenge.bind(from_id), row)


## Drops the queued wager offer. Every path out of the wager prompt — accepted,
## declined, or refused for lack of coins/cards — clears all four fields.

func _clear_pending_wager() -> void:
	_pending_wager_from = -1
	_pending_wager_deck = []
	_pending_wager_coins = 0
	_pending_wager_armed_at = -1

func _accept_wager_challenge(from_id: int, ante_coins: int) -> void:
	_dismiss_challenge_panel()
	if SceneManager.save_manager.coins < ante_coins:
		_world._show_tip("Not enough coins for the wager.")
		if _world._net_sync != null:
			_world._net_sync.rpc_id(from_id, "respond_battle_wager", false, [], 0)
		_clear_pending_wager()
		return
	var my_deck: Array = _world._local_deck_for_net()
	if my_deck.size() < IsoConst.DECK_MIN:
		_world._show_tip("Your deck is too small to duel.")
		if _world._net_sync != null:
			_world._net_sync.rpc_id(from_id, "respond_battle_wager", false, [], 0)
		_clear_pending_wager()
		return
	var opp_deck: Array = _pending_wager_deck
	_clear_pending_wager()
	if _world._net_sync != null:
		_world._net_sync.rpc_id(from_id, "respond_battle_wager", true, my_deck, ante_coins)
	_enter_pvp_wagered(ante_coins, opp_deck)

func _decline_wager_challenge(from_id: int) -> void:
	_dismiss_challenge_panel()
	if _world._net_sync != null:
		_world._net_sync.rpc_id(from_id, "respond_battle_wager", false, [], 0)
	_clear_pending_wager()

func _on_battle_wager_responded(_sender: int, accepted: bool, responder_deck: Array, ante_coins: int) -> void:
	if not accepted:
		_world._show_tip("Wagered challenge declined.")
		return
	_enter_pvp_wagered(ante_coins, responder_deck)

func _enter_pvp_wagered(ante: int, opp_deck: Array) -> void:
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	SceneManager.save_manager.add_coins(-ante)
	_pvp_ante_coins = ante
	var local_idx: int = 0 if NetworkManager.is_host() else 1
	if NetworkManager.is_host() and _world._net_sync != null:
		var my_id: int = multiplayer.get_unique_id()
		_world._pvp_ante_peer0 = my_id
		_world._pvp_ante_peer1 = _challenge_target_peer
		for pid in multiplayer.get_peers():
			var p: int = int(pid)
			if p != _challenge_target_peer:
				_world._net_sync.rpc_id(p, "recv_pvp_active", true, my_id, _challenge_target_peer)
	var opp_token: String = str(_world._session_token_by_peer.get(_challenge_target_peer, ""))
	SceneManager.enter_pvp_battle(local_idx, opp_deck, ante, opp_token)

func _on_pvp_battle_ended_coop(did_win: bool) -> void:
	if not _world._coop_active:
		return
	# GID-104 (TID-386): tournament matches have their own bracket-scoped payout
	# and never touch the champion-record/rating/ante-wager systems below — a
	# tournament match is never wagered/ranked through the normal challenge flow.
	if _world._tournament_active:
		_on_tournament_pvp_ended(did_win)
		return
	# Wager payout (TID-368): winner gets both antes back.
	if _pvp_ante_coins > 0:
		if did_win:
			SceneManager.save_manager.add_coins(_pvp_ante_coins * 2)
		_pvp_ante_coins = 0
	# Champion record (TID-368): update pvp stats in session record (host only).
	if NetworkManager.is_host() and SessionStore.is_open():
		var token: String = MpProfile.get_token()
		var st = SessionStore.get_state()
		if st != null:
			var rec: Dictionary = st.get_member(token)
			if not rec.is_empty():
				var wins: int = int(rec.get("pvp_wins", 0))
				var losses: int = int(rec.get("pvp_losses", 0))
				var streak: int = int(rec.get("pvp_streak", 0))
				var best: int = int(rec.get("pvp_best_streak", 0))
				if did_win:
					wins += 1
					streak += 1
					if streak > best:
						best = streak
				else:
					losses += 1
					streak = 0
				rec["pvp_wins"] = wins
				rec["pvp_losses"] = losses
				rec["pvp_streak"] = streak
				rec["pvp_best_streak"] = best
				st.update_member(token, rec)
				SessionStore.mark_dirty()
			# Ranked rating (TID-370) — gated on the duel's ranked opt-in (GID-102 / TID-373):
			# the authority owns both records, so it computes both combatants' ELO deltas and
			# writes both. The host is one combatant; the opponent is the duel peer captured
			# at battle-start (_pvp_ante_peer1). Casual (non-ranked) duels never touch rating.
			if _pvp_ranked:
				_update_pvp_ratings(st, token, did_win)
				# Broadcast a fresh leaderboard snapshot now that ratings changed.
				_broadcast_leaderboard()
	_pvp_ranked = false
	# Signal spectators to return to world when WorldScene re-enters the tree.
	_world._pvp_ended_pending_broadcast = true


## Host-authority ranked rating update for a finished duel (GID-102 / TID-370).
## `host_token` is the host's own member; `_pvp_ante_peer1` identifies the opponent peer
## (set in `_enter_pvp` / `_enter_pvp_wagered`). Both ratings move zero-sum-ish via ELO;
## a client never rates itself, so this only runs on the host (caller already guards that).
## Only called for ranked duels (see _on_pvp_battle_ended_coop).
##
## Rating-delta display (GID-102 / TID-373): BattleResultUI.show_pvp_result() is shown by
## BattleScene._finish_pvp BEFORE GameBus.pvp_battle_ended fires, but this update only runs
## AFTER that signal, here in WorldScene once the battle has ended — so the result screen
## cannot know the delta at the moment it is shown without restructuring the host-authoritative
## battle-end sequencing (out of scope / risky, see task file). Instead each combatant gets a
## toast once back in the world: the host shows its own delta locally; the opponent's delta is
## unicast via a tiny dedicated RPC (recv_rating_delta) right after this update, reusing the
## existing low-risk end-of-action toast pattern (hud_message_requested).

func _update_pvp_ratings(st, host_token: String, host_won: bool) -> void:
	var opp_peer: int = _world._pvp_ante_peer1
	if opp_peer <= 0:
		return
	var opp_token: String = str(_world._session_token_by_peer.get(opp_peer, ""))
	if host_token == "" or opp_token == "" or host_token == opp_token:
		return
	var host_rec: Dictionary = st.get_member(host_token)
	var opp_rec: Dictionary = st.get_member(opp_token)
	if host_rec.is_empty() or opp_rec.is_empty():
		return
	var r_host: int = int(host_rec.get("pvp_rating", _RatingMath.START_RATING))
	var r_opp: int = int(opp_rec.get("pvp_rating", _RatingMath.START_RATING))
	var g_host: int = int(host_rec.get("pvp_games", 0))
	var g_opp: int = int(opp_rec.get("pvp_games", 0))
	var host_score: float = 1.0 if host_won else 0.0
	var new_host_rating: int = _RatingMath.updated(r_host, r_opp, host_score, g_host)
	var new_opp_rating: int = _RatingMath.updated(r_opp, r_host, 1.0 - host_score, g_opp)
	var host_delta: int = new_host_rating - r_host
	var opp_delta: int = new_opp_rating - r_opp
	host_rec["pvp_rating"] = new_host_rating
	host_rec["pvp_games"] = g_host + 1
	opp_rec["pvp_rating"] = new_opp_rating
	opp_rec["pvp_games"] = g_opp + 1
	st.update_member(host_token, host_rec)
	st.update_member(opp_token, opp_rec)
	SessionStore.mark_dirty()
	# Toast both combatants with their rating delta (TID-373). The host shows its own
	# locally; the opponent's is unicast since only the host computed it.
	GameBus.hud_message_requested.emit(_format_rating_delta(host_delta))
	if _world._net_sync != null:
		_world._net_sync.rpc_id(opp_peer, "recv_rating_delta", opp_delta)


## "+N rating" (gold) / "-N rating" formatted as plain text for hud_message_requested
## (that signal carries text only, no color — color is the toast UI's own styling).

func _format_rating_delta(delta: int) -> String:
	return "+%d rating" % delta if delta >= 0 else "%d rating" % delta


## Client: receive our own rating delta toast from the host after a ranked duel.

func _on_rating_delta_received(delta: int) -> void:
	GameBus.hud_message_requested.emit(_format_rating_delta(delta))


## Host-only: ranked rating update for a finished 2v2 team duel (GID-102 / TID-371).
## did_win is the host's own perspective (team_assignments[0]'s result). Uses the
## formation _start_team_duel recorded to resolve all 4 tokens, then applies a
## "team-average expected score" ELO update per the task notes: each player's rating
## moves against the *average* rating of the opposing team, scored 1.0/0.0 for their
## team's win/loss (not pairwise per-opponent). A client never rates itself — this is
## a no-op when _active_team_duel_peer_ids is empty (every non-host peer, and the host
## itself once the formation has been consumed/cleared).

func _on_team_battle_ended_coop(did_win: bool) -> void:
	if not NetworkManager.is_host() or _active_team_duel_peer_ids.is_empty():
		return
	var peer_ids: Array[int] = _active_team_duel_peer_ids
	var teams: Array = _active_team_duel_teams
	_active_team_duel_peer_ids = []
	_active_team_duel_teams = []
	if not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var host_id: int = multiplayer.get_unique_id()
	var tokens: Array[String] = []
	for pid in peer_ids:
		var token: String = MpProfile.get_token() if pid == host_id else str(_world._session_token_by_peer.get(pid, ""))
		tokens.append(token)
	if tokens.has(""):
		return  # an unresolved token means a peer left mid-duel — skip the rating update
	var recs: Array[Dictionary] = []
	for token in tokens:
		var rec: Dictionary = st.get_member(token)
		if rec.is_empty():
			return
		recs.append(rec)
	var team0_idxs: Array[int] = []
	var team1_idxs: Array[int] = []
	for i in range(teams.size()):
		if int(teams[i]) == 0:
			team0_idxs.append(i)
		else:
			team1_idxs.append(i)
	var avg_rating := func(idxs: Array[int]) -> float:
		var sum: int = 0
		for i in idxs:
			sum += int(recs[i].get("pvp_rating", _RatingMath.START_RATING))
		return float(sum) / float(idxs.size())
	var avg0: float = avg_rating.call(team0_idxs)
	var avg1: float = avg_rating.call(team1_idxs)
	var team0_won: bool = did_win  # team_assignments[0] is the host's team
	for i in team0_idxs:
		var r: int = int(recs[i].get("pvp_rating", _RatingMath.START_RATING))
		var g: int = int(recs[i].get("pvp_games", 0))
		recs[i]["pvp_rating"] = _RatingMath.updated(r, int(round(avg1)), 1.0 if team0_won else 0.0, g)
		recs[i]["pvp_games"] = g + 1
	for i in team1_idxs:
		var r: int = int(recs[i].get("pvp_rating", _RatingMath.START_RATING))
		var g: int = int(recs[i].get("pvp_games", 0))
		recs[i]["pvp_rating"] = _RatingMath.updated(r, int(round(avg0)), 0.0 if team0_won else 1.0, g)
		recs[i]["pvp_games"] = g + 1
	for i in range(tokens.size()):
		st.update_member(tokens[i], recs[i])
	SessionStore.mark_dirty()


# ── GID-102 (TID-373): Ranked UI & leaderboard ────────────────────────────────

## Host: push the current leaderboard to one peer (target_peer == 0 broadcasts to all).

func _broadcast_leaderboard(target_peer: int = 0) -> void:
	if not NetworkManager.is_host() or _world._net_sync == null or not SessionStore.is_open():
		return
	var st = SessionStore.get_state()
	if st == null:
		return
	var rows: Array = st.get_leaderboard(20)
	# Update the host's own cache too so its roster badge + overlay stay in sync.
	_world._leaderboard_rows = rows
	if target_peer == 0:
		_world._net_sync.rpc("recv_leaderboard", rows)
	else:
		_world._net_sync.rpc_id(target_peer, "recv_leaderboard", rows)
	_world._refresh_coop_roster()
	if _world._leaderboard_overlay != null and is_instance_valid(_world._leaderboard_overlay) \
			and _world._leaderboard_overlay.has_method("refresh_rows"):
		_world._leaderboard_overlay.refresh_rows(_world._leaderboard_rows)


## Any peer: receive a leaderboard snapshot (initial push, post-duel update, or an
## on-demand refresh reply) and refresh the roster badges + open overlay if any.

func _on_leaderboard_received(rows: Array) -> void:
	_world._leaderboard_rows = rows
	_world._refresh_coop_roster()
	if _world._leaderboard_overlay != null and is_instance_valid(_world._leaderboard_overlay) \
			and _world._leaderboard_overlay.has_method("refresh_rows"):
		_world._leaderboard_overlay.refresh_rows(_world._leaderboard_rows)


## Host: a client asked for a fresh leaderboard snapshot (e.g. opening the panel).

func _on_leaderboard_request_submitted(sender: int) -> void:
	_broadcast_leaderboard(sender)


## token -> row lookup derived from the cache, for the roster badge + overlay.

func _leaderboard_lookup_by_token() -> Dictionary:
	var out: Dictionary = {}
	for row in _world._leaderboard_rows:
		if row is Dictionary:
			out[str((row as Dictionary).get("token", ""))] = row
	return out


## Returns "1234" for a cached rating or "—" if the token isn't in the cache yet
## (e.g. before the first leaderboard snapshot arrives).

func _rating_badge_for_token(token: String) -> String:
	if token == "":
		return "—"
	var lookup: Dictionary = _leaderboard_lookup_by_token()
	if not lookup.has(token):
		return "—"
	return str(int((lookup[token] as Dictionary).get("rating", _RatingMath.START_RATING)))


## Opens (or closes, if already open) the leaderboard overlay. Requests a fresh
## snapshot from the host on open. HUD button + mobile/desktop parity (TID-373).

func _toggle_leaderboard_overlay() -> void:
	if _world._leaderboard_overlay != null and is_instance_valid(_world._leaderboard_overlay):
		_world._leaderboard_overlay.queue_free()
		_world._leaderboard_overlay = null
		return
	_world._leaderboard_overlay = _LeaderboardOverlay.new()
	add_child(_world._leaderboard_overlay)
	_world._leaderboard_overlay.closed.connect(func() -> void: _world._leaderboard_overlay = null)
	_world._leaderboard_overlay.refresh_rows(_world._leaderboard_rows)
	if NetworkManager.is_host():
		_broadcast_leaderboard()
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(1, "submit_leaderboard_request")
	if _world._leaderboard_overlay.has_method("refresh_pve_rows"):
		_world._leaderboard_overlay.refresh_pve_rows(_world._pve_leaderboards)
	if NetworkManager.is_host():
		_world._broadcast_pve_leaderboards()
	elif _world._net_sync != null:
		_world._net_sync.rpc_id(1, "submit_pve_leaderboard_request")


# ── GID-102 (TID-379): PvE leaderboards — Spire + co-op boss clears ──────────
# Distinct symbol/RPC names from the TID-373 ranked-rating board above
# (recv_leaderboard/submit_leaderboard_request/_broadcast_leaderboard/etc.) —
# these never touch pvp_rating. Reuses the LeaderboardOverlay's tabs (extended
# by this task) rather than a second panel, per the task's "unified Rankings"
# guidance.

## Endless Spire is single-player; only submit a session-scoped board entry when a
## co-op session is actually active (per task notes — a Spire run can happen with no
## co-op session running at all, in which case this is purely a local result).
## Offline/no-session best is intentionally NOT duplicated into MpProfile: the
## fully-offline case is already covered by SaveManager.spire_best_floor (the "New
## Record!" badge on RunSummaryScene reads that field already) — adding a second
## local-best store here would just be a second source of truth for the same fact.

func _ensure_draft_duel_button() -> void:
	if _draft_duel_btn != null and is_instance_valid(_draft_duel_btn):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_draft_duel_btn = _world._world_hud.register_action("draft_duel", "Draft Duel",
		WorldHUD.ZONE_CONTEXT, _request_draft_duel, Callable(), Vector2(vp.y * 0.20, vp.y * 0.05))
	_draft_duel_btn.tooltip_text = "Sealed-deck duel: both players draft %d cards from identical seeded packs. No collection advantage; drafted cards last one duel." % _DraftDuelGen.NUM_ROUNDS
	_draft_duel_btn.hide()

## Shows/hides the draft-duel button. Piggybacks on the proximity result
## (_challenge_target_peer) computed by _update_challenge_proximity, which runs
## immediately before this in _process. Hidden while any challenge/draft is
## pending, and on dedicated servers (draft routing is listen-server only in v1).

func _update_draft_duel_proximity() -> void:
	if _draft_duel_btn == null or not is_instance_valid(_draft_duel_btn):
		return
	if _draft_peer != -1 or _pending_draft_from != -1 or _world._pending_challenge_from != -1 \
			or _world._session_dedicated or SceneManager._state != SceneManager.State.WORLD:
		_draft_duel_btn.hide()
		return
	_draft_duel_btn.visible = _challenge_target_peer != -1

## Send a draft-duel challenge to the nearby peer, carrying a freshly rolled seed.
## No DECK_MIN gate — a draft duel needs no collection at all (that's the point).

func _request_draft_duel() -> void:
	if _challenge_target_peer == -1 or _world._net_sync == null or _draft_peer != -1:
		return
	if _world._session_dedicated:
		_world._show_tip("Draft duels aren't available on dedicated servers yet.")
		return
	var seed_val: int = randi()
	_draft_peer = _challenge_target_peer
	_draft_seed = seed_val
	_draft_peer_armed_at = Time.get_ticks_msec()
	_world._net_sync.rpc_id(_draft_peer, "request_draft_duel", _DraftDuelGen.encode_seed(seed_val))
	_world._show_tip("Draft duel challenge sent…")

## Incoming draft challenge — show an Accept/Decline prompt (auto-decline if busy
## so the challenger isn't left hanging on a peer already in another handshake).

func _on_draft_duel_requested(from_id: int, payload: Dictionary) -> void:
	if _world._pending_challenge_from != -1 or _pending_draft_from != -1 or _draft_peer != -1:
		if _world._net_sync != null:
			_world._net_sync.rpc_id(from_id, "respond_draft_duel", false, {})
		return
	var decoded: Dictionary = _DraftDuelGen.decode_seed(payload)
	if not bool(decoded["valid"]):
		return
	_pending_draft_from = from_id
	_pending_draft_seed = int(decoded["seed"])
	_pending_draft_from_armed_at = Time.get_ticks_msec()
	_show_draft_accept_panel(from_id)

## Challenger learns the response. On accept, the echoed seed payload is used
## (defensively falling back to the seed we sent) and both peers start drafting.

func _on_draft_duel_responded(from_id: int, accepted: bool, payload: Dictionary) -> void:
	if from_id != _draft_peer or _draft_picking:
		return
	if not accepted:
		_world._show_tip("Draft duel declined.")
		_draft_peer = -1
		_draft_seed = 0
		_draft_peer_armed_at = -1
		return
	var decoded: Dictionary = _DraftDuelGen.decode_seed(payload)
	var seed_val: int = int(decoded["seed"]) if bool(decoded["valid"]) else _draft_seed
	_start_draft(from_id, seed_val)

func _show_draft_accept_panel(from_id: int) -> void:
	if _draft_accept_panel != null and is_instance_valid(_draft_accept_panel):
		_draft_accept_panel.queue_free()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var prompt: Dictionary = _world._build_prompt(180, 0.025)
	var layer: CanvasLayer = prompt["layer"]
	_draft_accept_panel = layer
	var vbox: VBoxContainer = prompt["vbox"]

	var lbl := _UiUtil.make_label("A player challenges you to a DRAFT DUEL!\nBoth of you draft %d cards from identical sealed packs." % _DraftDuelGen.NUM_ROUNDS, int(vp.y * 0.026), Color(0.6, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var row := _UiUtil.make_hbox(int(vp.y * 0.03), vbox)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var accept_btn := _UiUtil.make_button("Accept", Vector2(vp.y * 0.2, vp.y * 0.07), int(vp.y * 0.026), _accept_draft_duel.bind(from_id), row)

	var decline_btn := _UiUtil.make_button("Decline", Vector2(vp.y * 0.2, vp.y * 0.07), int(vp.y * 0.026), _decline_draft_duel.bind(from_id), row)

func _dismiss_draft_panel() -> void:
	if _draft_accept_panel != null and is_instance_valid(_draft_accept_panel):
		_draft_accept_panel.queue_free()
	_draft_accept_panel = null

func _accept_draft_duel(from_id: int) -> void:
	_dismiss_draft_panel()
	var seed_val: int = _pending_draft_seed
	_pending_draft_from = -1
	_pending_draft_seed = 0
	_pending_draft_from_armed_at = -1
	if _world._net_sync != null:
		_world._net_sync.rpc_id(from_id, "respond_draft_duel", true, _DraftDuelGen.encode_seed(seed_val))
	_start_draft(from_id, seed_val)

func _decline_draft_duel(from_id: int) -> void:
	_dismiss_draft_panel()
	_pending_draft_from = -1
	_pending_draft_seed = 0
	_pending_draft_from_armed_at = -1
	if _world._net_sync != null:
		_world._net_sync.rpc_id(from_id, "respond_draft_duel", false, {})

## Both peers: open the local pick overlay with the agreed shared seed. From here
## on there is zero network traffic until a peer finishes its last pick.

func _start_draft(peer_id: int, seed_val: int) -> void:
	_draft_peer = peer_id
	_draft_seed = seed_val
	_draft_peer_armed_at = -1  # TID-431: duel now active/underway — stop timing it out
	_draft_picking = true
	_draft_local_deck = []
	_draft_opp_deck = []
	_draft_local_done = false
	_draft_opp_done = false
	# Shared bookkeeping with the normal challenge path: the host's battle-end
	# champion-record path resolves the opponent via _challenge_target_peer.
	_challenge_target_peer = peer_id
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	if _ranked_toggle_btn != null and is_instance_valid(_ranked_toggle_btn):
		_ranked_toggle_btn.hide()
	if _draft_duel_btn != null and is_instance_valid(_draft_duel_btn):
		_draft_duel_btn.hide()
	var layer := CanvasLayer.new()
	layer.layer = 190
	add_child(layer)
	_draft_picker_layer = layer
	var picker := _DraftDuelPickScene.new()
	layer.add_child(picker)
	picker.draft_finished.connect(_on_local_draft_finished)
	_draft_picker = picker
	# setup() can finish synchronously (empty card registry edge) and cascade into
	# _maybe_enter_draft_duel → _free_draft_picker, so it must run after the
	# member references above are in place.
	picker.setup(seed_val, MpProfile.get_token())

func _free_draft_picker() -> void:
	if _draft_picker_layer != null and is_instance_valid(_draft_picker_layer):
		_draft_picker_layer.queue_free()
	_draft_picker_layer = null
	_draft_picker = null

## Local draft complete: send my transient deck to the opponent, then start the
## duel if theirs already arrived (whichever peer finishes second triggers entry).

func _on_local_draft_finished(deck: Array) -> void:
	_draft_local_deck = deck
	_draft_local_done = true
	if _world._net_sync != null and _draft_peer != -1:
		_world._net_sync.rpc_id(_draft_peer, "submit_draft_duel_deck", deck)
	_maybe_enter_draft_duel()

func _on_draft_duel_deck_submitted(from_id: int, deck: Array) -> void:
	if from_id != _draft_peer:
		return
	_draft_opp_deck = deck
	_draft_opp_done = true
	_maybe_enter_draft_duel()

## Both decks ready → enter the duel. Mirrors _enter_pvp (spectator broadcast +
## opponent token), but passes the local drafted deck as the override so the
## battle never reads the host's persisted collection. Never ranked, no ante.

func _maybe_enter_draft_duel() -> void:
	if not (_draft_local_done and _draft_opp_done):
		return
	_free_draft_picker()
	var local_idx: int = 0 if NetworkManager.is_host() else 1
	_pvp_ranked = false
	if NetworkManager.is_host() and _world._net_sync != null:
		var my_id: int = multiplayer.get_unique_id()
		_world._pvp_ante_peer0 = my_id
		_world._pvp_ante_peer1 = _draft_peer
		for pid in multiplayer.get_peers():
			var p: int = int(pid)
			if p != _draft_peer:
				_world._net_sync.rpc_id(p, "recv_pvp_active", true, my_id, _draft_peer)
	var opp_token: String = str(_world._session_token_by_peer.get(_draft_peer, ""))
	var opp_deck: Array = _draft_opp_deck
	var my_deck: Array = _draft_local_deck
	_reset_draft_state()
	SceneManager.enter_pvp_battle(local_idx, opp_deck, 0, opp_token, false, my_deck)

func _reset_draft_state() -> void:
	_draft_peer = -1
	_draft_seed = 0
	_draft_peer_armed_at = -1
	_draft_picking = false
	_draft_local_deck = []
	_draft_opp_deck = []
	_draft_local_done = false
	_draft_opp_done = false

## Abort hooks: called from _on_coop_peer_disconnected / _on_coop_session_ended.

func _abort_draft_duel_for_peer(pid: int) -> void:
	if _draft_peer != -1 and pid == _draft_peer:
		_abort_draft_duel("Draft duel cancelled — opponent disconnected.")
	elif _pending_draft_from != -1 and pid == _pending_draft_from:
		_dismiss_draft_panel()
		_pending_draft_from = -1
		_pending_draft_seed = 0
		_pending_draft_from_armed_at = -1

func _abort_draft_duel(reason: String = "") -> void:
	if _draft_peer == -1 and _pending_draft_from == -1 and _draft_picker == null:
		return
	_free_draft_picker()
	_dismiss_draft_panel()
	_pending_draft_from = -1
	_pending_draft_seed = 0
	_pending_draft_from_armed_at = -1
	_reset_draft_state()
	if reason != "":
		_world._show_tip(reason)
# ── Session tournaments (GID-104 / TID-386) ───────────────────────────────────
# Host-run round-robin bracket for 3-4 session players. The host is the
# authority: it schedules matches one at a time, plays its own matches through
# the normal enter_pvp_battle flow, referees client-vs-client matches through
# the GID-097 enter_pvp_referee flow, auto-spectates every non-combatant, and
# pays the pot to the bracket winner. Pure scheduling/wire logic lives in
# game_logic/net/TournamentSync.gd; everything here is guarded end-to-end by
# _tournament_active / NetworkManager.is_active() so single-player and normal
# co-op PvP are untouched.

## Host: builds the bracket from every connected peer (host + all clients),
## deducts the flat ante from every participant (host locally; clients via
## notify_tournament_start doing the same on their side — the existing
## ante-wager precedent), broadcasts the bracket, and schedules match 1.

func _start_tournament() -> void:
	if not NetworkManager.is_host() or _world._net_sync == null or _world._tournament_active:
		return
	var clients: Array = multiplayer.get_peers()
	if clients.size() < 2:
		_world._show_tip("Need 3-4 players for a tournament.")
		return
	clients.sort()
	var host_id: int = multiplayer.get_unique_id()
	var peer_ids: Array[int] = [host_id]
	for pid in clients:
		peer_ids.append(int(pid))
	var tokens: Array = []
	var names: Array = []
	var decks: Array = []
	for pid in peer_ids:
		var token: String = MpProfile.get_token() if pid == host_id \
				else str(_world._session_token_by_peer.get(pid, ""))
		if token == "":
			_world._show_tip("A player's identity isn't synced yet — try again shortly.")
			return
		var deck: Array = _team_deck_for_peer(pid)
		if deck.size() < IsoConst.DECK_MIN:
			_world._show_tip("%s's deck is too small to duel." % _world._display_name_for_token(token))
			return
		tokens.append(token)
		names.append(_world._display_name_for_token(token))
		decks.append(deck)
	if SceneManager.save_manager.coins < _world.TOURNAMENT_ANTE_COINS:
		_world._show_tip("Not enough coins for the ante (%d)." % _world.TOURNAMENT_ANTE_COINS)
		return
	var bracket: Dictionary = _TournamentSync.new_bracket(tokens, names, _world.TOURNAMENT_ANTE_COINS)
	if bracket.is_empty():
		_world._show_tip("Tournaments support 3-4 players.")
		return
	SceneManager.save_manager.add_coins(-_world.TOURNAMENT_ANTE_COINS)
	_world._tournament_active = true
	_world._tournament_bracket = bracket
	_world._tournament_peer_ids = peer_ids
	_tournament_tokens.assign(tokens)
	_tournament_decks = decks
	_tournament_ante = _world.TOURNAMENT_ANTE_COINS
	_tournament_pending_result = {}
	for pid in peer_ids:
		if pid != host_id:
			_world._net_sync.rpc_id(pid, "notify_tournament_start",
				_TournamentSync.encode_bracket(bracket), _world.TOURNAMENT_ANTE_COINS)
	_build_tournament_panel()
	GameBus.hud_message_requested.emit("Tournament started — %d matches. Pot: %d coins." % [
		(bracket.get("matches", []) as Array).size(), int(bracket.get("pot", 0))])
	# Brief pause before match 1 so everyone can read the bracket panel first.
	_tournament_match_countdown = 3.0


## Host: launches the bracket's current match. The host plays its own matches
## (canonical GameState idx 0, the enter_pvp_battle host path); a match between
## two clients runs through the GID-097 referee path with the host arbitrating.
## Every peer not in the match is told to auto-spectate.

func _start_current_tournament_match() -> void:
	if not NetworkManager.is_host() or _world._net_sync == null or not _world._tournament_active:
		return
	var m: Dictionary = _TournamentSync.get_current_match(_world._tournament_bracket)
	if m.is_empty():
		return
	var pa: int = int(m.get("a", -1))
	var pb: int = int(m.get("b", -1))
	if pa < 0 or pb < 0 or pa >= _world._tournament_peer_ids.size() or pb >= _world._tournament_peer_ids.size():
		return
	var host_id: int = multiplayer.get_unique_id()
	var peer_a: int = _world._tournament_peer_ids[pa]
	var peer_b: int = _world._tournament_peer_ids[pb]
	var deck_a: Array = _tournament_decks[pa]
	var deck_b: Array = _tournament_decks[pb]
	_world._net_sync.rpc("recv_tournament_update", _TournamentSync.encode_bracket(_world._tournament_bracket))
	if _challenge_btn != null and is_instance_valid(_challenge_btn):
		_challenge_btn.hide()
	# Duel-active + auto-spectate broadcasts to everyone not in this match
	# (reuses the TID-367 spectate plumbing; _enter_tree clears it after the match
	# via the _pvp_ended_pending_broadcast pattern).
	_world._pvp_ante_peer0 = peer_a
	_world._pvp_ante_peer1 = peer_b
	for pid in multiplayer.get_peers():
		var p: int = int(pid)
		if p == peer_a or p == peer_b:
			continue
		_world._net_sync.rpc_id(p, "recv_pvp_active", true, peer_a, peer_b)
		_world._net_sync.rpc_id(p, "notify_tournament_spectate")
	var names: Array = _world._tournament_bracket.get("names", [])
	if pa < names.size() and pb < names.size():
		GameBus.hud_message_requested.emit("Tournament match: %s vs %s" % [str(names[pa]), str(names[pb])])
	if peer_a == host_id or peer_b == host_id:
		# The host is a combatant — canonical idx 0 is always the host on this path.
		_tournament_current_is_host_match = true
		var host_participant: int = pa if peer_a == host_id else pb
		var opp_participant: int = pb if peer_a == host_id else pa
		var opp_peer: int = _world._tournament_peer_ids[opp_participant]
		var opp_deck: Array = _tournament_decks[opp_participant]
		var host_deck: Array = _tournament_decks[host_participant]
		_tournament_canonical_to_participant = {0: host_participant, 1: opp_participant}
		_world._net_sync.rpc_id(opp_peer, "notify_pvp_start", 1, host_deck)
		var opp_token: String = str(_world._session_token_by_peer.get(opp_peer, ""))
		SceneManager.enter_pvp_battle(0, opp_deck, 0, opp_token, false)
	else:
		# Two clients play; the listen-server host referees (GID-097 path,
		# _local_player_idx = -1) — the winner arrives via pvp_referee_match_ended.
		_tournament_current_is_host_match = false
		_tournament_canonical_to_participant = {0: pa, 1: pb}
		_world._net_sync.rpc_id(peer_a, "notify_pvp_start", 0, deck_b)
		_world._net_sync.rpc_id(peer_b, "notify_pvp_start", 1, deck_a)
		SceneManager.enter_pvp_referee(deck_a, deck_b, peer_a, peer_b,
			str(_world._session_token_by_peer.get(peer_a, "")),
			str(_world._session_token_by_peer.get(peer_b, "")))


## All peers (routed from _on_pvp_battle_ended_coop's _tournament_active guard):
## a tournament match this peer FOUGHT in just ended. The host captures the
## winner for the bracket advance; every peer re-arms the duel-clear broadcast
## exactly like the normal PvP path it replaced.

func _on_tournament_pvp_ended(did_win: bool) -> void:
	_pvp_ranked = false
	_world._pvp_ended_pending_broadcast = true
	if not NetworkManager.is_host():
		return
	if _tournament_current_is_host_match:
		var canonical: int = 0 if did_win else 1
		var participant: int = int(_tournament_canonical_to_participant.get(canonical, -1))
		if participant >= 0:
			_tournament_pending_result = {"winner_participant_idx": participant}


## Host: a referee'd (client-vs-client) tournament match ended — the winner's
## canonical GameState index arrives via the dedicated GID-104 signal because
## pvp_battle_ended's bool can't express it for a non-participant. The GID-097
## dedicated-server relay also fires this signal, but _tournament_active is
## never true there, so it stays inert outside tournaments.

func _on_pvp_referee_match_ended(winner_idx: int) -> void:
	if not _world._tournament_active or not NetworkManager.is_host() or _tournament_current_is_host_match:
		return
	var participant: int = int(_tournament_canonical_to_participant.get(winner_idx, -1))
	if participant >= 0:
		_tournament_pending_result = {"winner_participant_idx": participant}


## Host, from _process once WorldScene is back in the tree (a match result can
## only be applied here — during the battle this scene is detached and _net_sync
## is freed): drains the pending result, advances + broadcasts the bracket, and
## either schedules the next match (short countdown so peers get back to the
## world and read the panel) or finishes the tournament.

func _tick_tournament(delta: float) -> void:
	if not _world._tournament_active or not NetworkManager.is_host():
		return
	if not _tournament_pending_result.is_empty():
		var w: int = int(_tournament_pending_result.get("winner_participant_idx", -1))
		_tournament_pending_result = {}
		if w >= 0:
			_world._tournament_bracket = _TournamentSync.record_match_result(_world._tournament_bracket, w)
			if _world._net_sync != null:
				_world._net_sync.rpc("recv_tournament_update", _TournamentSync.encode_bracket(_world._tournament_bracket))
			_refresh_tournament_panel()
			if _TournamentSync.is_finished(_world._tournament_bracket):
				_finish_tournament()
				return
			var names: Array = _world._tournament_bracket.get("names", [])
			if w < names.size():
				GameBus.hud_message_requested.emit("%s wins the match!" % str(names[w]))
			_tournament_match_countdown = 4.0
		return
	if _tournament_match_countdown > 0.0:
		_tournament_match_countdown -= delta
		if _tournament_match_countdown <= 0.0:
			_start_current_tournament_match()


## Host: pays the pot to the bracket winner — locally for the host itself,
## otherwise straight into the winner's session member record (the
## _grant_chest_loot_to_token direct-write pattern). Clients learn the outcome
## from the finished bracket broadcast in _tick_tournament.

func _finish_tournament() -> void:
	var w: int = int(_world._tournament_bracket.get("winner_idx", -1))
	var players: Array = _world._tournament_bracket.get("players", [])
	var names: Array = _world._tournament_bracket.get("names", [])
	var pot: int = int(_world._tournament_bracket.get("pot", 0))
	if w >= 0 and w < players.size():
		var token: String = str(players[w])
		var wname: String = str(names[w]) if w < names.size() else "?"
		if token == MpProfile.get_token():
			SceneManager.save_manager.add_coins(pot)
		elif SessionStore.is_open():
			var st = SessionStore.get_state()
			if st != null:
				var rec: Dictionary = st.get_member(token)
				if not rec.is_empty():
					rec["coins"] = int(rec.get("coins", 0)) + pot
					st.update_member(token, rec)
					SessionStore.mark_dirty()
		GameBus.hud_message_requested.emit("%s wins the tournament (+%d coins)!" % [wname, pot])
	_reset_tournament_state()
	_refresh_tournament_panel()


## Clears every host-side orchestration field. Keeps _tournament_bracket so the
## final standings stay on the panel — callers that need a blank panel (abort,
## session end) clear the bracket themselves.

func _reset_tournament_state() -> void:
	_world._tournament_active = false
	_world._tournament_peer_ids = []
	_tournament_tokens = []
	_tournament_decks = []
	_tournament_ante = 0
	_tournament_pending_result = {}
	_tournament_current_is_host_match = false
	_tournament_canonical_to_participant = {}
	_tournament_match_countdown = 0.0


## Client (notify_tournament_start): the host started a tournament that
## includes us — deduct our ante locally (existing ante-wager precedent) and
## build the bracket panel.

func _on_tournament_started(bracket: Dictionary, ante: int) -> void:
	if NetworkManager.is_host():
		return
	var b: Dictionary = _TournamentSync.decode_bracket(bracket)
	if (b.get("players", []) as Array).is_empty():
		return
	_world._tournament_active = true
	_world._tournament_bracket = b
	if ante > 0:
		SceneManager.save_manager.add_coins(-ante)
	_build_tournament_panel()
	GameBus.hud_message_requested.emit("Tournament started — ante %d coins. Pot: %d." % [
		ante, int(b.get("pot", 0))])


## Client (recv_tournament_update): bracket changed. An empty bracket means the
## host aborted (participant disconnect); a finished one carries the winner.

func _on_tournament_update_received(payload: Dictionary) -> void:
	if NetworkManager.is_host():
		return
	var b: Dictionary = _TournamentSync.decode_bracket(payload)
	if (b.get("players", []) as Array).is_empty():
		if _world._tournament_active:
			GameBus.hud_message_requested.emit("Tournament aborted.")
		_world._tournament_active = false
		_world._tournament_bracket = {}
		_refresh_tournament_panel()
		return
	_world._tournament_bracket = b
	if _TournamentSync.is_finished(b):
		_world._tournament_active = false
		var w: int = int(b.get("winner_idx", -1))
		var names: Array = b.get("names", [])
		if w >= 0 and w < names.size():
			GameBus.hud_message_requested.emit("%s wins the tournament (+%d coins)!" % [
				str(names[w]), int(b.get("pot", 0))])
	_build_tournament_panel()


## Client (notify_tournament_spectate): the host scheduled a match we're not in —
## auto-enter the spectator view (no manual Spectate press, unlike TID-367).

func _on_tournament_spectate_notified() -> void:
	if not _world._tournament_active or NetworkManager.is_dedicated_server():
		return
	SceneManager.enter_pvp_spectator()


## Bracket HUD panel (all peers) — mirrors _build_party_bounty_panel
## structurally; right side of the screen (bounties/roster/chat own the left).

func _build_tournament_panel() -> void:
	if _tournament_panel != null and is_instance_valid(_tournament_panel):
		_refresh_tournament_panel()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var outer := PanelContainer.new()
	outer.name = "TournamentPanel"
	outer.position = Vector2(vp.x * 0.76, vp.y * 0.34)
	var style := _UiUtil.make_style(Color(0.04, 0.04, 0.08, 0.88), 6)
	outer.add_theme_stylebox_override("panel", style)
	_world._hud.add_child(outer)
	var vbox := _UiUtil.make_vbox(int(vp.y * 0.006), outer)
	_tournament_panel_outer = outer
	_tournament_panel = vbox
	_refresh_tournament_panel()

func _refresh_tournament_panel() -> void:
	if _tournament_panel == null or not is_instance_valid(_tournament_panel):
		return
	if (_world._tournament_bracket.get("players", []) as Array).is_empty():
		if _tournament_panel_outer != null and is_instance_valid(_tournament_panel_outer):
			_tournament_panel_outer.hide()
		return
	if _tournament_panel_outer != null and is_instance_valid(_tournament_panel_outer):
		_tournament_panel_outer.show()
	for c in _tournament_panel.get_children():
		c.queue_free()
	var vh: float = get_viewport().get_visible_rect().size.y
	var title := _UiUtil.make_label("Tournament — Pot: %d" % int(_world._tournament_bracket.get("pot", 0)), int(vh * 0.020))
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	_tournament_panel.add_child(title)
	var names: Array = _world._tournament_bracket.get("names", [])
	var matches: Array = _world._tournament_bracket.get("matches", [])
	var cur: int = int(_world._tournament_bracket.get("current_match", 0))
	var finished: bool = bool(_world._tournament_bracket.get("finished", false))
	for i in range(matches.size()):
		var mv: Variant = matches[i]
		if not (mv is Dictionary):
			continue
		var md: Dictionary = mv
		var a: int = int(md.get("a", -1))
		var b: int = int(md.get("b", -1))
		var name_a: String = str(names[a]) if a >= 0 and a < names.size() else "?"
		var name_b: String = str(names[b]) if b >= 0 and b < names.size() else "?"
		var lbl := Label.new()
		if bool(md.get("done", false)):
			var w: int = int(md.get("winner", -1))
			var wname: String = str(names[w]) if w >= 0 and w < names.size() else "?"
			lbl.text = "%s def. %s" % [wname, name_b if w == a else name_a]
			lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			lbl.text = "%s vs %s" % [name_a, name_b]
			if i == cur and not finished:
				lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		lbl.add_theme_font_size_override("font_size", int(vh * 0.016))
		_tournament_panel.add_child(lbl)
	if finished:
		var wi: int = int(_world._tournament_bracket.get("winner_idx", -1))
		if wi >= 0 and wi < names.size():
			var win_lbl := _UiUtil.make_label("Winner: %s" % str(names[wi]), int(vh * 0.018))
			win_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			_tournament_panel.add_child(win_lbl)
