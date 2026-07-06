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
## `ranked` (GID-102 / TID-373): A's "Ranked" toggle state — both peers must agree, so
## the responder's accept always echoes back the challenger's value (see respond_battle).
## Reliable — must not drop. Routed to WorldScene._on_battle_requested.
@rpc("any_peer", "reliable", "call_remote")
func request_battle(challenger_deck: Array, ranked: bool = false) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_battle_requested"):
		world_scene._on_battle_requested(sender, challenger_deck, ranked)


## PvP challenge response: B → A accept/decline, carrying B's deck on accept.
## `ranked` echoes the challenger's request_battle value so both peers enter the duel
## with the same flag (defaulted for backward-compat with any stale caller).
@rpc("any_peer", "reliable", "call_remote")
func respond_battle(accepted: bool, responder_deck: Array, ranked: bool = false) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_battle_responded"):
		world_scene._on_battle_responded(sender, accepted, responder_deck, ranked)


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


## Authority → all: a chapter-ending/cliffhanger narration overlay should show now,
## with an optional story flag to set when it's closed. Reliable — a one-shot
## cinematic beat, not worth losing to an unreliable channel.
@rpc("any_peer", "reliable", "call_remote")
func recv_narration_overlay(pages: Array, title: String, completion_flag: String) -> void:
	if world_scene != null and world_scene.has_method("_on_narration_overlay_received"):
		world_scene._on_narration_overlay_received(pages, title, completion_flag)


## Authority → client: Maiteln's follower position, low-Hz (mirrors recv_avatar).
## payload is [x: float, z: float, map_name: String] — the map is carried so
## receivers can apply the CLAUDE.md cross-map-ghost filter (GID-096/TID-352).
@rpc("any_peer", "unreliable_ordered", "call_remote")
func recv_maiteln_state(payload: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_maiteln_state_received"):
		world_scene._on_maiteln_state_received(payload)


# ── Rally waystones (GID-105 / TID-388) ──────────────────────────────────────

## Rallying peer → target peer: "I'm rallying to you" hero-moment notice. Reliable —
## a one-shot toast, not worth losing to an unreliable channel.
@rpc("any_peer", "reliable", "call_remote")
func recv_rally_notice(rallier_name: String) -> void:
	if world_scene != null and world_scene.has_method("_on_rally_notice_received"):
		world_scene._on_rally_notice_received(rallier_name)


# ── Downed & rescue in shared dungeons (GID-105 / TID-389) ───────────────────

## Client → authority: "please revive peer_id" (an interact against a downed
## teammate). Reliable. The host validates against its authoritative downed-peers
## view (mirrored from the AvatarSync stream) before applying.
@rpc("any_peer", "reliable", "call_remote")
func submit_revive_request(peer_id: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_revive_request_submitted"):
		world_scene._on_revive_request_submitted(sender, peer_id)


## Authority → all: peer_id has been revived. Reliable — a dropped revive would
## leave a peer stuck frozen even though the host considers them rescued.
@rpc("any_peer", "reliable", "call_remote")
func recv_revive(peer_id: int) -> void:
	if world_scene != null and world_scene.has_method("_on_revive_received"):
		world_scene._on_revive_received(peer_id)


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


# ── Party chat (GID-102 / TID-374) ───────────────────────────────────────────

## Any peer → all peers: a quick-chat preset or free-text chat line. Reliable —
## unlike avatars/emotes/pings, chat messages must not be silently dropped, and
## chat is low-rate enough that reliable's extra overhead doesn't matter.
## payload is ChatSync.encode_quick()/encode_text() output: [text, kind, map].
@rpc("any_peer", "reliable", "call_remote")
func recv_chat(payload: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_chat_received"):
		world_scene._on_chat_received(sender, payload)


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


# ── Shared party stash (GID-102 / TID-376) ───────────────────────────────────
# Unlike trading, the stash is global to the session — no proximity gate needed.

## Client → authority: deposit a card or coins into the shared stash.
## payload: {"kind": "card"|"coins", "card_uid": String, "amount": int}. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_stash_deposit(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_stash_deposit_submitted"):
		world_scene._on_stash_deposit_submitted(sender, payload)


## Client → authority: withdraw a card or coins from the shared stash. Same payload
## shape as submit_stash_deposit (card_uid here refers to the stash-namespaced uid).
@rpc("any_peer", "reliable", "call_remote")
func submit_stash_withdraw(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_stash_withdraw_submitted"):
		world_scene._on_stash_withdraw_submitted(sender, payload)


## Authority → all (or one, on late-join): the current stash snapshot.
## payload: {"cards": Array, "coins": int}. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_stash_update(snapshot: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_stash_update_received"):
		world_scene._on_stash_update_received(snapshot)


# ── Async card auction house (GID-102 / TID-378) ─────────────────────────────
# Global to the session, same as the stash — no proximity gate.

## Client → authority: list a card for sale. payload: AuctionSync.encode_list_intent
## output ({"card_uid": String, "buyout": int}). Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_auction_list(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_auction_list_submitted"):
		world_scene._on_auction_list_submitted(sender, payload)


## Client → authority: bid on an active listing. payload: AuctionSync.encode_bid_intent
## output ({"auction_id": String, "amount": int}). Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_auction_bid(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_auction_bid_submitted"):
		world_scene._on_auction_bid_submitted(sender, payload)


## Client → authority: buy a listing outright. payload: AuctionSync.encode_id_intent
## output ({"auction_id": String}). Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_auction_buyout(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_auction_buyout_submitted"):
		world_scene._on_auction_buyout_submitted(sender, payload)


## Client → authority: cancel your own active listing. payload: AuctionSync.encode_id_intent
## output ({"auction_id": String}). Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_auction_cancel(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_auction_cancel_submitted"):
		world_scene._on_auction_cancel_submitted(sender, payload)


## Authority → all (or one, on late-join): the full listings snapshot.
## payload is AuctionSync.decode_snapshot-compatible Array of listing dicts. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_auction_update(snapshot: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_auction_update_received"):
		world_scene._on_auction_update_received(snapshot)


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


# ── Team PvP duels (GID-102 / TID-371) ───────────────────────────────────────

## Host → each participant: "the team duel is starting; you are absolute index
## my_idx." team_assignments[i] is the team (0/1) for absolute index i; all_decks[i]
## is that index's deck instances. No accept/decline — the host assigns teams from
## the connected 4-peer session (keeps team-formation UI minimal, per design).
## Triggers SceneManager.enter_team_battle on the recipient. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func notify_team_duel_start(my_idx: int, team_assignments: Array, all_decks: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_notify_team_duel_start"):
		world_scene._on_notify_team_duel_start(my_idx, team_assignments, all_decks)


# ── Ranked UI & leaderboard (GID-102 / TID-373) ──────────────────────────────

## Authority → one or all peers: the current session leaderboard. payload is
## SessionState.get_leaderboard() output: Array[Dictionary] of
## {token, name, rating, games, wins, losses} — already JSON-primitive, sent as-is
## (same pattern as recv_party_bounties_snapshot). Reliable — must not drop so the
## client's cached rows stay consistent with the authority.
@rpc("any_peer", "reliable", "call_remote")
func recv_leaderboard(rows: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_leaderboard_received"):
		world_scene._on_leaderboard_received(rows)


## Client → authority: on-demand refresh request (e.g. opening the leaderboard panel).
## Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_leaderboard_request() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_leaderboard_request_submitted"):
		world_scene._on_leaderboard_request_submitted(sender)


## Host → the opponent of a just-finished ranked duel: their rating delta, shown as a
## toast once they're back in the world (see WorldScene._update_pvp_ratings doc comment
## for why this can't be shown on the same-screen result UI). Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_rating_delta(delta: int) -> void:
	if world_scene != null and world_scene.has_method("_on_rating_delta_received"):
		world_scene._on_rating_delta_received(delta)


# ── PvE leaderboards: Spire + co-op clears (GID-102 / TID-379) ──────────────
# Distinct RPC/symbol names from the TID-373 PvP ranked-rating pair above
# (recv_leaderboard / submit_leaderboard_request) — this is the PvE counterpart,
# never touches rating. All names carry a "pve" marker to avoid any collision.

## Client → authority: "I finished a Spire run / co-op boss clear, here's my score."
## board is "spire" or "coop_clears"; value is floors_cleared (Spire) or the co-op
## clear's recorded value (see WorldScene._submit_pve_score for the value choice).
## Reliable — a dropped submission would silently lose a player's best result.
@rpc("any_peer", "reliable", "call_remote")
func submit_pve_leaderboard_score(board: String, value: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_pve_leaderboard_score_submitted"):
		world_scene._on_pve_leaderboard_score_submitted(sender, board, value)


## Authority → one or all peers: the current {spire, coop_clears} PvE leaderboard
## snapshot. payload is SessionState.get_pve_leaderboards_snapshot() output —
## already JSON-primitive, sent as-is (same pattern as recv_leaderboard /
## recv_party_bounties_snapshot). Reliable — must not drop so cached rows stay
## consistent with the authority. Fired on late-join and after every score update.
@rpc("any_peer", "reliable", "call_remote")
func recv_pve_leaderboards(snapshot: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_pve_leaderboards_received"):
		world_scene._on_pve_leaderboards_received(snapshot)


## Client → authority: on-demand refresh request (e.g. switching to the Spire/Co-op
## tab in the leaderboard overlay). Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_pve_leaderboard_request() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_pve_leaderboard_request_submitted"):
		world_scene._on_pve_leaderboard_request_submitted(sender)


## Guildhall garden (GID-106 / TID-393). SessionStore is authority-only, so
## clients need this pushed to them exactly like the PvE leaderboard snapshot
## above — same request/broadcast shape.

## Client → authority: request a fresh guildhall garden snapshot (sent on
## entering the guildhall map). Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_guildhall_garden_request() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_guildhall_garden_request_submitted"):
		world_scene._on_guildhall_garden_request_submitted(sender)


## Authority → one or all peers: the current {plots, plants} guildhall garden
## snapshot. Reliable — fired on request and after every plant/harvest.
@rpc("any_peer", "reliable", "call_remote")
func recv_guildhall_garden_update(payload: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_guildhall_garden_update_received"):
		world_scene._on_guildhall_garden_update_received(payload)


## Client → authority: plant a seed in an empty guildhall garden plot (free —
## no session seed economy is modeled). Plain params, mirrors
## submit_spire_draft_choice's precedent. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_session_plant(plot_idx: int, seed_id: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_session_plant_submitted"):
		world_scene._on_session_plant_submitted(sender, plot_idx, seed_id)


## Client → authority: harvest a mature guildhall garden plot. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_session_harvest(plot_idx: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_session_harvest_submitted"):
		world_scene._on_session_harvest_submitted(sender, plot_idx)


# ── Party loot rolls (GID-102 / TID-381) ─────────────────────────────────────

## Authority → all same-session members: open a Need/Greed/Pass prompt for a chest's
## resolved drop. payload is LootRoll.encode_start() output. Reliable — a dropped
## roll-start would leave a peer stuck unable to claim loot they're entitled to roll on.
@rpc("any_peer", "reliable", "call_remote")
func recv_loot_roll_start(payload: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_loot_roll_start_received"):
		world_scene._on_loot_roll_start_received(payload)


## Client → authority: "I opened a chest (cid), and need/greed mode is on — please
## start a roll." The chest-open flip itself already syncs via the existing
## EV_CHEST_OPENED world event; this only carries the tier so the authority can
## re-derive card_ids/position from its own deterministic chest data. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_loot_roll_request(cid: String, chest_tier: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_loot_roll_request_submitted"):
		world_scene._on_loot_roll_request_submitted(sender, cid, chest_tier)


## Client → authority: my Need/Greed/Pass choice for an active roll. payload fields are
## sent positionally (roll_id, choice) rather than as one Array so both ends stay
## simple RPC parameters like the other submit_* calls. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_loot_roll_choice(roll_id: String, choice: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_loot_roll_choice_submitted"):
		world_scene._on_loot_roll_choice_submitted(sender, roll_id, choice)


## Authority → all: the resolved outcome (winner + rolled values) so every peer can
## show a toast. payload is LootRoll.encode_result() output. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_loot_roll_result(payload: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_loot_roll_result_received"):
		world_scene._on_loot_roll_result_received(payload)


# ── Co-op Endless Spire alternating draft (GID-106 / TID-390) ────────────────

## Authority → all: open a draft prompt for a floor. payload is
## SpireDraftSync.encode_draft_start() output. Reliable — a dropped draft-start
## would leave the whole party stuck (nobody can pick, the run can't progress).
@rpc("any_peer", "reliable", "call_remote")
func recv_spire_draft_start(payload: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_spire_draft_start_received"):
		world_scene._on_spire_draft_start_received(payload)


## Client → authority: the active picker's chosen card index (0..2 into the
## broadcast options). Sent as a plain int, mirroring submit_loot_roll_choice's
## plain-RPC-params precedent. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_spire_draft_choice(card_idx: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_spire_draft_choice_submitted"):
		world_scene._on_spire_draft_choice_submitted(sender, card_idx)


## Authority → all: the resolved pick + next picker's turn. payload is
## SpireDraftSync.encode_draft_choice() output. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_spire_draft_choice(payload: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_spire_draft_choice_received"):
		world_scene._on_spire_draft_choice_received(payload)


## Client → host: a client engaged the co-op Spire floor boss. edata is the raw
## EnemyNPC.engage() payload. Mirrors submit_siege_boss_engaged. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_spire_boss_engaged(edata: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_spire_boss_engaged_submitted"):
		world_scene._on_spire_boss_engaged_submitted(sender, edata)


## Authority → all: the co-op Spire run has ended (defeat). Carries final stats
## + party roster (WorldScene._on_coop_spire_battle_ended's payload shape).
## Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_coop_spire_run_ended(payload: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_coop_spire_run_ended_received"):
		world_scene._on_coop_spire_run_ended_received(payload)


# ── Draft duels — sealed-deck PvP (GID-104 / TID-385) ────────────────────────
# Deterministic shared-seed model: the challenger generates one integer seed;
# both peers derive the IDENTICAL sequence of 1-of-3 pick rounds locally via
# DraftDuelGen.generate_rounds, so no per-pick relay/arbitration is needed. Only
# the two finished (transient, never-persisted) decks cross the wire, once each.

## Challenger → target: "draft duel?" payload is DraftDuelGen.encode_seed() output
## carrying the shared seed. Reliable — a dropped challenge must not silently vanish.
@rpc("any_peer", "reliable", "call_remote")
func request_draft_duel(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_draft_duel_requested"):
		world_scene._on_draft_duel_requested(sender, payload)


## Target → challenger: accept/decline. On accept, payload echoes the challenger's
## seed payload back so both peers provably draft from the same seed. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func respond_draft_duel(accepted: bool, payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_draft_duel_responded"):
		world_scene._on_draft_duel_responded(sender, accepted, payload)


## Either drafting peer → the other: my finished drafted deck (Array of transient
## instance dicts built by DraftDuelGen.make_drafted_instance — never persisted).
## Symmetric like request_battle/respond_battle: whichever peer finishes first
## simply waits until the opponent's deck arrives. Reliable — must not drop.
@rpc("any_peer", "reliable", "call_remote")
func submit_draft_duel_deck(deck: Array) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_draft_duel_deck_submitted"):
		world_scene._on_draft_duel_deck_submitted(sender, deck)
# ── Session tournaments (GID-104 / TID-386) ──────────────────────────────────

## Host → each entrant: the tournament is starting. payload is
## TournamentSync.encode_bracket() output; `ante` is deducted locally by the
## receiver (mirrors the existing ante-wager flow). Reliable.
@rpc("any_peer", "reliable", "call_remote")
func notify_tournament_start(bracket: Dictionary, ante: int) -> void:
	if world_scene != null and world_scene.has_method("_on_tournament_started"):
		world_scene._on_tournament_started(bracket, ante)


## Host → all: the bracket changed (a match started/finished, or the whole
## tournament finished). payload is TournamentSync.encode_bracket() output.
## Reliable — a dropped update would leave a peer's bracket panel stale.
@rpc("any_peer", "reliable", "call_remote")
func recv_tournament_update(bracket: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_tournament_update_received"):
		world_scene._on_tournament_update_received(bracket)


## Host → a non-combatant for the current match: auto-enter as a spectator
## (no manual "Spectate" button press needed, unlike the general TID-367 flow).
## Reliable.
@rpc("any_peer", "reliable", "call_remote")
func notify_tournament_spectate() -> void:
	if world_scene != null and world_scene.has_method("_on_tournament_spectate_notified"):
		world_scene._on_tournament_spectate_notified()


# ── Synced world clock & weather (GID-103 / TID-382) ──────────────────────────

## Authority → peers: the current shared clock/weather. payload is
## EnvSync.encode() output: [time_of_day, days_elapsed, weather_id]. Reliable —
## a dropped update just means the next low-Hz tick (or the next weather change)
## corrects it; there is no continuous stream to fall back on.
@rpc("any_peer", "reliable", "call_remote")
func recv_env_state(payload: Array) -> void:
	if world_scene != null and world_scene.has_method("_on_env_state_received"):
		world_scene._on_env_state_received(payload)


# ── Co-op Town Siege (GID-103 / TID-384) ──────────────────────────────────────

## Host → all: a siege has started with this deterministic id. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_siege_started(siege_id: int) -> void:
	if world_scene != null and world_scene.has_method("_on_siege_started_received"):
		world_scene._on_siege_started_received(siege_id)


## Host → all: the previous wave cleared — advance to this wave index. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_siege_wave(siege_id: int, wave: int) -> void:
	if world_scene != null and world_scene.has_method("_on_siege_wave_received"):
		world_scene._on_siege_wave_received(siege_id, wave)


## Host → all: every raider wave is cleared — spawn the finale boss. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func recv_siege_boss_phase(siege_id: int) -> void:
	if world_scene != null and world_scene.has_method("_on_siege_boss_phase_received"):
		world_scene._on_siege_boss_phase_received(siege_id)


## Client → host: I engaged the siege boss — start the joint battle for the
## whole party. edata is the raw EnemyNPC.engage() payload. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func submit_siege_boss_engaged(edata: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if world_scene != null and world_scene.has_method("_on_siege_boss_engaged_submitted"):
		world_scene._on_siege_boss_engaged_submitted(sender, edata)


## Host → each ally client: the joint siege-boss battle is starting. Mirrors
## notify_team_duel_start's per-recipient absolute-index pattern. Reliable.
@rpc("any_peer", "reliable", "call_remote")
func notify_coop_pve_start(my_idx: int, all_ally_decks: Array, enemy_data: Dictionary) -> void:
	if world_scene != null and world_scene.has_method("_on_notify_coop_pve_start"):
		world_scene._on_notify_coop_pve_start(my_idx, all_ally_decks, enemy_data)
