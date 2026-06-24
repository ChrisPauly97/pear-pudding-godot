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
