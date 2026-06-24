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
