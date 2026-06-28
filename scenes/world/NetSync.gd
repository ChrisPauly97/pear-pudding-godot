## RPC relay node for co-op avatar sync.
##
## Lives as a fixed-name child "NetSync" of WorldScene so the RPC path
## (/root/WorldScene/NetSync) matches on both peers and dies with the scene.
## Receives avatar packets and routes them to WorldScene._on_avatar_received().
extends Node

## Set by WorldScene after this node is created.
var world_scene: Node = null


## Receive a peer's latest avatar state. payload is AvatarSync.encode() output:
## [x: float, z: float, flip_h: bool, moving: bool].
@rpc("any_peer", "unreliable_ordered", "call_remote")
func recv_avatar(payload: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_avatar_received"):
		world_scene._on_avatar_received(sender, payload)


## Player identity handshake (GID-094 / TID-342). payload is PlayerIdentity.encode()
## output: [token, name, color_hex]. Reliable — a one-shot that must not drop.
## `is_reply` is false for the initiator's broadcast and true for the direct
## reply, so the receiver replies exactly once and the exchange terminates.
@rpc("any_peer", "reliable", "call_remote")
func recv_identity(payload: Array, is_reply: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_identity_received"):
		world_scene._on_identity_received(sender, payload, is_reply)


## Session character handshake (GID-095 / TID-346): host → client. Carries the
## resolved per-player character record (deck/inventory/coins/level/skills) for this
## session. `resume` is true when the record was matched to an existing member (a
## reconnect) so the client restores its saved position. Reliable — must not drop.
@rpc("any_peer", "reliable", "call_remote")
func recv_character(record: Dictionary, resume: bool) -> void:
	if world_scene != null and world_scene.has_method("_on_character_received"):
		world_scene._on_character_received(record, resume)


## Session persist-back intent (GID-095 / TID-346): client → host. The client sends
## its latest character snapshot; only the host (authority) writes the session file.
@rpc("any_peer", "reliable", "call_remote")
func submit_character(record: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_character_submitted"):
		world_scene._on_character_submitted(sender, record)


## Co-op world-object sync (GID-096) ───────────────────────────────────────────

## Authority → clients: a discrete world event. payload is WorldObjectSync.encode_event()
## output: [kind, id] (e.g. ["enemy_removed", "orc_3"], ["chest_opened", "dc_1"]).
## Reliable — discrete state changes must not drop.
@rpc("any_peer", "reliable", "call_remote")
func recv_world_event(payload: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_world_event_received"):
		world_scene._on_world_event_received(sender, payload)


## Client → authority: a world-event intent (I engaged enemy id / opened chest id /
## won against enemy id). Only the authority mutates shared/persisted state.
@rpc("any_peer", "reliable", "call_remote")
func submit_world_event(payload: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_world_event_submitted"):
		world_scene._on_world_event_submitted(sender, payload)


## Authority → a just-joined client: the current world snapshot (removed enemy ids +
## opened object ids) so the client's deterministically-spawned nodes are reconciled
## to the live/persisted state. payload is WorldObjectSync.encode_snapshot() output.
@rpc("any_peer", "reliable", "call_remote")
func recv_world_snapshot(payload: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_world_snapshot_received"):
		world_scene._on_world_snapshot_received(payload)


## Authority → clients: a low-Hz batch of enemy positions for any *moving* enemy.
## payload is EnemySync.encode_batch() output. Unreliable_ordered (like avatars) —
## a dropped packet is corrected by the next one. Static enemies make this inert.
@rpc("any_peer", "unreliable_ordered", "call_remote")
func recv_enemy_positions(payload: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_enemy_positions_received"):
		world_scene._on_enemy_positions_received(payload)


## PvP challenge (GID-091): A → B "challenge to battle", carrying A's deck.
## Reliable — must not drop. Routed to WorldScene._on_battle_requested.
@rpc("any_peer", "reliable", "call_remote")
func request_battle(challenger_deck: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_battle_requested"):
		world_scene._on_battle_requested(sender, challenger_deck)


## PvP challenge response: B → A accept/decline, carrying B's deck on accept.
@rpc("any_peer", "reliable", "call_remote")
func respond_battle(accepted: bool, responder_deck: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_battle_responded"):
		world_scene._on_battle_responded(sender, accepted, responder_deck)


# ── Dedicated-server PvP routing (GID-097 / TID-353) ──────────────────────────
# In a dedicated-server session neither connected peer is the host, so the server
# arbitrates challenges and acts as the headless referee.  Three-message flow:
#   1. Challenger  → server: relay_pvp_request(target, my_deck)
#   2. Target      → server: relay_pvp_response(challenger_id, accepted, my_deck)
#   3. Server      → each client: notify_pvp_start(my_player_idx, opponent_deck)
# The server also sends set_session_flags to tell clients they are in a dedicated
# session so they know to use the relay path instead of the direct P2P path.

## Host → client: session metadata (e.g. {"dedicated": true}). Sent when the
## host delivers the session character in dedicated-server mode.
@rpc("any_peer", "reliable", "call_remote")
func set_session_flags(flags: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_session_flags"):
		world_scene._on_session_flags(flags)


## Client → server: "I want to challenge peer target_peer_id." Dedicated mode only.
@rpc("any_peer", "reliable", "call_remote")
func relay_pvp_request(target_peer_id: int, challenger_deck: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_relay_pvp_request"):
		world_scene._on_relay_pvp_request(sender, target_peer_id, challenger_deck)


## Client → server: "I accept/decline the challenge from challenger_id." Dedicated mode only.
@rpc("any_peer", "reliable", "call_remote")
func relay_pvp_response(challenger_id: int, accepted: bool, responder_deck: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_relay_pvp_response"):
		world_scene._on_relay_pvp_response(sender, challenger_id, accepted, responder_deck)


## Server → client: "You are player my_player_idx; here is your opponent's deck."
## Triggers SceneManager.enter_pvp_battle on the client.
@rpc("any_peer", "reliable", "call_remote")
func notify_pvp_start(my_player_idx: int, opponent_deck: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_notify_pvp_start"):
		world_scene._on_notify_pvp_start(my_player_idx, opponent_deck)


# ── Co-op story mode (GID-098) ────────────────────────────────────────────────

## Any peer → all others: follow me to this map (door or exit). Reliable —
## a dropped packet would leave one player stranded on the wrong map.
## target_map == "" means exit_map() (pop the stack). Routed to
## WorldScene._on_map_transition_received on each receiver.
@rpc("any_peer", "reliable", "call_remote")
func recv_map_transition(target_map: String, door_id: String) -> void:
	if world_scene != null and world_scene.has_method("_on_map_transition_received"):
		world_scene._on_map_transition_received(target_map, door_id)


## Authority → all: a story flag was set by any peer. Reliable — flag state must
## be consistent across the party. Routed to WorldScene._on_story_flag_received.
@rpc("any_peer", "reliable", "call_remote")
func recv_story_flag(key: String, value: bool) -> void:
	if world_scene != null and world_scene.has_method("_on_story_flag_received"):
		world_scene._on_story_flag_received(key, value)


## Client → authority: I want to set a story flag. Only the authority mutates
## the session state and broadcasts to everyone (including the submitter).
@rpc("any_peer", "reliable", "call_remote")
func submit_story_flag(key: String, value: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_story_flag_submitted"):
		world_scene._on_story_flag_submitted(sender, key, value)


## Authority → joining client: the current shared story flags so the late-joiner
## starts with the same story state as the rest of the party.
@rpc("any_peer", "reliable", "call_remote")
func recv_story_flags_snapshot(flags: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_story_flags_snapshot_received"):
		world_scene._on_story_flags_snapshot_received(flags)


# ── Emotes & map pings (GID-101 / TID-365) ───────────────────────────────────

## Any peer → all peers: a preset emote expression. Unreliable_ordered — a dropped
## emote is acceptable; the continuous 15 Hz avatar stream makes resilience cheap.
## payload is SocialSync.encode_emote() output: [emote_id, map_name].
@rpc("any_peer", "unreliable_ordered", "call_remote")
func recv_emote(payload: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_emote_received"):
		world_scene._on_emote_received(sender, payload)


## Any peer → all peers: a world-space tap-to-ping. Unreliable_ordered — a dropped
## ping is fine; the marker auto-expires anyway.
## payload is SocialSync.encode_ping() output: [x, z, kind, color_hex, map_name].
@rpc("any_peer", "unreliable_ordered", "call_remote")
func recv_ping(payload: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_ping_received"):
		world_scene._on_ping_received(sender, payload)


# ── Card trading & gifting (GID-101 / TID-366) ───────────────────────────────

## Client (initiator) → authority: propose a trade or gift. payload is
## TradeSync.encode_offer(). Reliable — must not drop.
@rpc("any_peer", "reliable", "call_remote")
func submit_trade_offer(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_trade_offer_submitted"):
		world_scene._on_trade_offer_submitted(sender, payload)


## Target peer → authority: accept or decline the pending offer. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_trade_confirm(trade_id: String, confirmed: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_trade_confirm_submitted"):
		world_scene._on_trade_confirm_submitted(sender, trade_id, confirmed)


## Authority → both trade parties: outcome (proposed / completed / cancelled).
## payload is TradeSync.encode_update(). Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_trade_update(payload: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_trade_update_received"):
		world_scene._on_trade_update_received(payload)


# ── PvP spectating (GID-101 / TID-367) ───────────────────────────────────────

## Host → all non-participants: a PvP duel started/ended among party members.
## Receivers show/hide the "Spectate" HUD affordance accordingly. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_pvp_active(in_battle: bool, peer_a: int, peer_b: int) -> void:
	if world_scene != null and world_scene.has_method("_on_pvp_active_received"):
		world_scene._on_pvp_active_received(in_battle, peer_a, peer_b)


## Non-participant → host: "I want to spectate the active duel." Reliable.
@rpc("any_peer", "reliable", "call_remote")
func request_spectate_pvp() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_spectate_pvp_requested"):
		world_scene._on_spectate_pvp_requested(sender)


## Host → requesting spectator: "you may enter the battle scene as a spectator."
## Reliable. The receiver calls SceneManager.enter_pvp_spectator().
@rpc("any_peer", "reliable", "call_remote")
func recv_spectate_approved() -> void:
	if world_scene != null and world_scene.has_method("_on_spectate_approved"):
		world_scene._on_spectate_approved()


# ── Wagered duels (GID-101 / TID-368) ────────────────────────────────────────

## Alternative challenge that carries a coin ante. Like request_battle but the
## challenger also proposes ante_coins staked by each player. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func request_battle_wager(challenger_deck: Array, ante_coins: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_battle_wager_requested"):
		world_scene._on_battle_wager_requested(sender, challenger_deck, ante_coins)


## Response to a wagered challenge: accepted carries the responder's deck +
## confirms the agreed ante. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func respond_battle_wager(accepted: bool, responder_deck: Array, ante_coins: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_battle_wager_responded"):
		world_scene._on_battle_wager_responded(sender, accepted, responder_deck, ante_coins)


# ── Shared party bounties (GID-101 / TID-369) ────────────────────────────────

## Authority → all clients: a party bounty's shared progress changed.
## payload: {"bounty_id": String, "progress": int, "count": int, "completed": bool}. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_party_bounty_update(payload: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_party_bounty_update_received"):
		world_scene._on_party_bounty_update_received(payload)


## Client → authority: I contributed a party bounty progress event.
## bounty_type / match_data mirror SaveManager.increment_bounty_progress. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_party_bounty_progress(bounty_type: String, match_data: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_party_bounty_progress_submitted"):
		world_scene._on_party_bounty_progress_submitted(sender, bounty_type, match_data)


## Authority → joining client: the full party bounty list (with progress) so a
## late-joiner starts with the same shared state. payload: Array[Dictionary]. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_party_bounties_snapshot(bounties: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_party_bounties_snapshot_received"):
		world_scene._on_party_bounties_snapshot_received(bounties)
