## RPC relay node for PvP card battles (GID-091).
##
## The battle-layer analogue of scenes/world/NetSync.gd. Lives as a fixed-name
## child "BattleNetSync" of BattleScene so the RPC path
## (/root/BattleScene/BattleNetSync) resolves identically on both peers and dies
## with the scene.
##
## RPCs are RELIABLE (turn-based — must never drop), unlike the avatar sync which
## was unreliable_ordered. The simulation authority is always the co-op host
## (NetworkManager.is_host()); the host owns the canonical GameState, the client
## sends intents and renders the broadcast mirror.
extends Node

## Back-reference set by BattleScene after this node is created.
var battle_scene: Node = null


## Client -> host: a single relayed human action (BattleNetProtocol intent dict).
@rpc("any_peer", "reliable", "call_remote")
func send_intent(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if battle_scene != null and battle_scene.has_method("_on_pvp_intent"):
		battle_scene._on_pvp_intent(sender, payload)


## Host -> client: full-state mirror (BattleNetProtocol.encode_state output).
@rpc("any_peer", "reliable", "call_remote")
func sync_state(payload: Dictionary) -> void:
	if battle_scene != null and battle_scene.has_method("_on_pvp_state"):
		battle_scene._on_pvp_state(payload)


## Host -> client: end-of-battle notification {"winner_idx": int, "forfeit": bool}.
@rpc("any_peer", "reliable", "call_remote")
func pvp_ended(payload: Dictionary) -> void:
	if battle_scene != null and battle_scene.has_method("_on_pvp_ended"):
		battle_scene._on_pvp_ended(payload)


## Client -> host: "my BattleScene is up, send me the current state." Resolves the
## startup race where the host's initial broadcast can precede the client's scene.
@rpc("any_peer", "reliable", "call_remote")
func request_sync() -> void:
	if battle_scene != null and battle_scene.has_method("_on_pvp_sync_request"):
		battle_scene._on_pvp_sync_request()


# ── Co-op PvE battle RPCs (GID-099) ──────────────────────────────────────────
# Mirror of the PvP RPCs above, extended to N acting peers (all allies).
# The boss is always AI-controlled by the authority; only allies send intents.

## Ally client → host: a single relayed ally action (BattleNetProtocol intent dict).
## Identical to send_intent but named distinctly so PvP and co-op paths don't share
## the same RPC handler (avoids cross-mode confusion on the host).
@rpc("any_peer", "reliable", "call_remote")
func send_coop_intent(payload: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if battle_scene != null and battle_scene.has_method("_on_coop_intent"):
		battle_scene._on_coop_intent(sender, payload)


## Host → all ally clients: full-state mirror (BattleNetProtocol.encode_state output).
@rpc("any_peer", "reliable", "call_remote")
func sync_coop_state(payload: Dictionary) -> void:
	if battle_scene != null and battle_scene.has_method("_on_coop_state"):
		battle_scene._on_coop_state(payload)


## Host → all ally clients: battle ended.
## payload: {"winner_ally": bool, "card_id": String, "rarity": String,
##           "stats": Dictionary, "coins": int, "xp": int}
@rpc("any_peer", "reliable", "call_remote")
func coop_battle_ended(payload: Dictionary) -> void:
	if battle_scene != null and battle_scene.has_method("_on_coop_battle_ended"):
		battle_scene._on_coop_battle_ended(payload)


## Ally client → host: "my co-op BattleScene is ready, send me the current state."
@rpc("any_peer", "reliable", "call_remote")
func request_coop_sync() -> void:
	if battle_scene != null and battle_scene.has_method("_on_coop_sync_request"):
		battle_scene._on_coop_sync_request()


# ── Duel spectating (GID-101 / TID-367) ──────────────────────────────────────

## Spectator → host: "register me as a spectator and send the current state."
## The host adds the sender to _spectators and fans the next sync_state to them.
@rpc("any_peer", "reliable", "call_remote")
func request_spectate() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if battle_scene != null and battle_scene.has_method("_on_spectate_request"):
		battle_scene._on_spectate_request(sender)


## Spectator → host: "I'm leaving the spectator view."
@rpc("any_peer", "reliable", "call_remote")
func stop_spectate() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if battle_scene != null and battle_scene.has_method("_on_stop_spectate"):
		battle_scene._on_stop_spectate(sender)
