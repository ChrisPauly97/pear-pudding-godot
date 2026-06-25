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
