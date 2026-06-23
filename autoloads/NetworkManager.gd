## Thin transport wrapper for co-op multiplayer.
##
## Owns the MultiplayerAPI peer lifecycle and re-broadcasts the native
## multiplayer signals as its own, so no other system touches `multiplayer`
## directly.
##
## Transport swap point: to add Steam, replace the ENET branch in
## _create_peer() with SteamMultiplayerPeer.new() (GodotSteam plugin).
## Everything else — signals, host/join API, WorldScene hooks — stays the same.
extends Node

enum Transport { ENET, STEAM }

const DEFAULT_PORT: int = 24565
const MAX_PEERS: int = 1  # 2-player slice: host + 1 client

# Re-broadcast of native multiplayer signals.
# Rest of the game only connects to these — never to `multiplayer` directly.
signal server_started
signal connection_succeeded
signal connection_failed
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal session_ended


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Start hosting on the given port. Returns OK or an Error code.
func host(port: int = DEFAULT_PORT) -> Error:
	var peer: MultiplayerPeer = _create_peer(Transport.ENET)
	if peer == null:
		return ERR_UNAVAILABLE
	var enet: ENetMultiplayerPeer = peer as ENetMultiplayerPeer
	if enet == null:
		return ERR_UNAVAILABLE
	var err: Error = enet.create_server(port, MAX_PEERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	server_started.emit()
	return OK


## Connect to a host. Returns OK or an Error code.
func join(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer: MultiplayerPeer = _create_peer(Transport.ENET)
	if peer == null:
		return ERR_UNAVAILABLE
	var enet: ENetMultiplayerPeer = peer as ENetMultiplayerPeer
	if enet == null:
		return ERR_UNAVAILABLE
	var err: Error = enet.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Disconnect and clean up. Safe to call when not connected.
func leave() -> void:
	multiplayer.multiplayer_peer = null
	session_ended.emit()


## True when a peer is assigned and not in the DISCONNECTED state.
func is_active() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


## True if this instance is the host (server).
func is_host() -> bool:
	return multiplayer.is_server()


## This peer's unique network ID (1 = host, >1 = clients).
func local_id() -> int:
	return multiplayer.get_unique_id()


# ---------------------------------------------------------------------------
# Transport factory — the only ENet-specific code.
# To swap to Steam: add `Transport.STEAM: return SteamMultiplayerPeer.new()`
# ---------------------------------------------------------------------------

func _create_peer(transport: Transport) -> MultiplayerPeer:
	match transport:
		Transport.ENET:
			return ENetMultiplayerPeer.new()
		Transport.STEAM:
			push_warning("NetworkManager: Steam transport not yet implemented. Install GodotSteam and return SteamMultiplayerPeer.new() here.")
			return null
	return null


# ---------------------------------------------------------------------------
# Native signal relays
# ---------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)


func _on_connected_to_server() -> void:
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	connection_failed.emit()


func _on_server_disconnected() -> void:
	session_ended.emit()
