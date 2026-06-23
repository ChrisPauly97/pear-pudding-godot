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

# LAN discovery (separate UDP channel from the ENet game connection).
const DISCOVERY_PORT: int = 24566
const _DISCOVERY_QUERY: String = "PPTCG_DISCOVER"
const _DISCOVERY_REPLY_TAG: String = "PPTCG_HOST"
const _DISCOVERY_SCAN_SECONDS: float = 1.2

# Re-broadcast of native multiplayer signals.
# Rest of the game only connects to these — never to `multiplayer` directly.
signal server_started
signal connection_succeeded
signal connection_failed
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal session_ended

## Emitted ~1.2 s after start_discovery(); payload is an Array of host dicts
## {name, ip, game_port, map, players}.
signal hosts_discovered(hosts: Array)

## Shown to other players in their found-games list.
var host_label: String = "Pear Pudding Host"

var _host_listener: PacketPeerUDP = null  # host: answers discovery queries
var _scan_socket: PacketPeerUDP = null    # client: broadcasts query, collects replies
var _scan_time_left: float = 0.0
var _last_host_port: int = DEFAULT_PORT
var _discovered: Dictionary = {}          # ip -> host dict (dedupe)


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
	_last_host_port = port
	_start_discovery_listener()
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
	_stop_discovery_listener()
	stop_discovery()
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
# LAN discovery (ENet-transport-only — Steam matchmaking replaces this).
#
# Model: the client BROADCASTS a query, the host REPLIES by unicast. Only the
# host's *receipt* of a broadcast needs Android's WifiManager.MulticastLock, so
# the common mobile path (Android client -> desktop host) works lock-free. An
# Android *host* will not hear queries without a MulticastLock plugin (TODO).
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_serve_discovery()
	_tick_scan(delta)

## Host: begin answering discovery queries on DISCOVERY_PORT.
func _start_discovery_listener() -> void:
	_stop_discovery_listener()
	_host_listener = PacketPeerUDP.new()
	var err: Error = _host_listener.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("NetworkManager: could not bind discovery listener (error %d)." % err)
		_host_listener = null

func _stop_discovery_listener() -> void:
	if _host_listener != null:
		_host_listener.close()
		_host_listener = null

## Host: reply to any pending discovery queries (called each frame).
func _serve_discovery() -> void:
	if _host_listener == null:
		return
	while _host_listener.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _host_listener.get_packet()
		if not is_discovery_query(pkt):
			continue
		var sender_ip: String = _host_listener.get_packet_ip()
		var sender_port: int = _host_listener.get_packet_port()
		var players: int = multiplayer.get_peers().size() + 1
		var reply: PackedByteArray = build_discovery_reply(
			host_label, _last_host_port, "madrian", players)
		_host_listener.set_dest_address(sender_ip, sender_port)
		_host_listener.put_packet(reply)

## Client: broadcast a discovery query and collect replies for ~1.2 s.
func start_discovery() -> void:
	stop_discovery()
	_discovered.clear()
	_scan_socket = PacketPeerUDP.new()
	var berr: Error = _scan_socket.bind(0)  # ephemeral local port to receive replies
	if berr != OK:
		push_warning("NetworkManager: could not bind discovery scanner (error %d)." % berr)
		_scan_socket = null
		hosts_discovered.emit([])
		return
	_scan_socket.set_broadcast_enabled(true)
	_scan_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_scan_socket.put_packet(build_discovery_query())
	_scan_time_left = _DISCOVERY_SCAN_SECONDS

func stop_discovery() -> void:
	if _scan_socket != null:
		_scan_socket.close()
		_scan_socket = null
	_scan_time_left = 0.0

## Client: drain replies and emit hosts_discovered when the scan window closes.
func _tick_scan(delta: float) -> void:
	if _scan_socket == null:
		return
	while _scan_socket.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _scan_socket.get_packet()
		var ip: String = _scan_socket.get_packet_ip()
		var host: Dictionary = parse_discovery_reply(pkt, ip)
		if not host.is_empty():
			_discovered[ip] = host
	_scan_time_left -= delta
	if _scan_time_left <= 0.0:
		var found: Array = _discovered.values()
		stop_discovery()
		hosts_discovered.emit(found)


# ---------------------------------------------------------------------------
# Discovery wire format — pure helpers (unit-testable, no sockets).
# ---------------------------------------------------------------------------

static func build_discovery_query() -> PackedByteArray:
	return _DISCOVERY_QUERY.to_utf8_buffer()

static func is_discovery_query(pkt: PackedByteArray) -> bool:
	return pkt.get_string_from_utf8() == _DISCOVERY_QUERY

static func build_discovery_reply(label: String, game_port: int, map: String, players: int) -> PackedByteArray:
	var d := {
		"tag": _DISCOVERY_REPLY_TAG,
		"name": label,
		"game_port": game_port,
		"map": map,
		"players": players,
	}
	return JSON.stringify(d).to_utf8_buffer()

## Parse a reply packet into a host dict, or {} if invalid. `ip` is the source
## address observed on the socket (authoritative — not trusted from the payload).
static func parse_discovery_reply(pkt: PackedByteArray, ip: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(pkt.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {}
	var d: Dictionary = parsed
	if str(d.get("tag", "")) != _DISCOVERY_REPLY_TAG:
		return {}
	return {
		"name": str(d.get("name", "Host")),
		"ip": ip,
		"game_port": int(d.get("game_port", DEFAULT_PORT)),
		"map": str(d.get("map", "")),
		"players": int(d.get("players", 1)),
	}


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
