## Headless smoke test for the dedicated-server NetSync relay handshake (GID-097 / TID-353).
##
## Not part of the auto-discovered unit suite (needs real sockets + 3-peer ENet).
## Run on demand:
##
##   godot --headless --path . -s tests/net_dedicated_server_smoke.gd
##
## Exit code 0 = pass, 1 = fail.
##
## Proves the full dedicated-server PvP relay round-trip over real ENet loopback:
##   1. Server sends set_session_flags → client receives {"dedicated": true}.
##   2. Client A relays a challenge (relay_pvp_request) to the server.
##   3. Server forwards the challenge to client B via request_battle.
##   4. Client B accepts via relay_pvp_response.
##   5. Server sends notify_pvp_start to both clients with the correct player indices.
extends SceneTree

const _NetSync = preload("res://scenes/world/NetSync.gd")
const _Harness = preload("res://tests/net_harness.gd")

const _PORT: int = 24574


# Server-side stub: implements the WorldScene authority handlers for relay routing.
class _ServerStub:
	extends Node
	var net_sync: Node = null
	var relay_challenger_id: int = -1
	var relay_challenger_deck: Array = []
	var relay_target_id: int = -1

	func _on_relay_pvp_request(sender_id: int, target_peer_id: int, challenger_deck: Array) -> void:
		relay_challenger_id = sender_id
		relay_challenger_deck = challenger_deck
		relay_target_id = target_peer_id
		if net_sync != null:
			net_sync.rpc_id(target_peer_id, "request_battle", challenger_deck)

	func _on_relay_pvp_response(sender_id: int, challenger_id: int, accepted: bool, responder_deck: Array) -> void:
		if relay_challenger_id != challenger_id or relay_target_id != sender_id:
			return
		var challenger: int = relay_challenger_id
		var target: int = relay_target_id
		var deck_a: Array = relay_challenger_deck.duplicate()
		relay_challenger_id = -1
		relay_challenger_deck = []
		relay_target_id = -1
		if not accepted:
			return
		if net_sync != null:
			net_sync.rpc_id(challenger, "notify_pvp_start", 0, responder_deck)
			net_sync.rpc_id(target, "notify_pvp_start", 1, deck_a)


# Client A stub: sends the relay challenge, records notify_pvp_start.
class _ClientAStub:
	extends Node
	var session_flags: Dictionary = {}
	var got_request_battle: bool = false
	var notify_player_idx: int = -1
	var notify_opponent_deck: Array = []

	func _on_session_flags(flags: Dictionary) -> void:
		session_flags = flags

	func _on_battle_requested(_sender: int, _deck: Array, _ranked: bool = false) -> void:
		got_request_battle = true

	func _on_notify_pvp_start(my_player_idx: int, opponent_deck: Array) -> void:
		notify_player_idx = my_player_idx
		notify_opponent_deck = opponent_deck


# Client B stub: receives the forwarded request_battle, responds via relay.
class _ClientBStub:
	extends Node
	var challenger_id_seen: int = -1
	var challenge_deck_seen: Array = []
	var notify_player_idx: int = -1
	var notify_opponent_deck: Array = []

	func _on_battle_requested(sender: int, deck: Array, _ranked: bool = false) -> void:
		challenger_id_seen = sender
		challenge_deck_seen = deck

	func _on_notify_pvp_start(my_player_idx: int, opponent_deck: Array) -> void:
		notify_player_idx = my_player_idx
		notify_opponent_deck = opponent_deck


func _initialize() -> void:
	_go()

func _go() -> void:
	await process_frame
	var ok: bool = _run()
	print("\nnet_dedicated_server_smoke: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	# --- Server (peer 1) ---
	var srv: Dictionary = _Harness.start_server(self, _PORT, 4)
	if srv.is_empty():
		return false
	var server_peer: ENetMultiplayerPeer = srv["peer"]
	var mp_server: SceneMultiplayer = srv["mp"]
	var server_root: Node = srv["root"]

	var server_stub := _ServerStub.new()
	var server_netsync: Node = _build_world(server_root, server_stub, "Stub")
	server_stub.net_sync = server_netsync

	# Track connected peers by signal so we know the moment they are RPC-ready.
	var server_connected_peers: Array[int] = []
	mp_server.peer_connected.connect(func(id: int) -> void: server_connected_peers.append(id))

	# --- Client A ---
	var cli_a: Dictionary = _Harness.start_client(self, _PORT, "CliA", "  [FAIL] create_client A failed")
	if cli_a.is_empty():
		return false
	var peer_a: ENetMultiplayerPeer = cli_a["peer"]
	var mp_a: SceneMultiplayer = cli_a["mp"]
	var root_a: Node = cli_a["root"]

	var stub_a := _ClientAStub.new()
	var netsync_a: Node = _build_world(root_a, stub_a, "StubA")

	# --- Client B ---
	var cli_b: Dictionary = _Harness.start_client(self, _PORT, "CliB", "  [FAIL] create_client B failed")
	if cli_b.is_empty():
		return false
	var peer_b: ENetMultiplayerPeer = cli_b["peer"]
	var mp_b: SceneMultiplayer = cli_b["mp"]
	var root_b: Node = cli_b["root"]

	var stub_b := _ClientBStub.new()
	var netsync_b: Node = _build_world(root_b, stub_b, "StubB")

	# Poll until the server has seen peer_connected for both clients and both
	# clients know their own unique IDs (> 0 means the handshake completed).
	var fully_connected: bool = _Harness.pump([mp_server, mp_a, mp_b], 800, 10, func() -> bool:
		return server_connected_peers.size() >= 2 and mp_a.get_unique_id() > 0 and mp_b.get_unique_id() > 0)
	if not fully_connected:
		print("  [FAIL] not fully connected within timeout (server_peers=%d, a_id=%d, b_id=%d)"
			% [server_connected_peers.size(), mp_a.get_unique_id(), mp_b.get_unique_id()])
		return false

	var peer_a_id: int = mp_a.get_unique_id()
	var peer_b_id: int = mp_b.get_unique_id()
	print("  [PASS] all peers connected (a_id=%d, b_id=%d)" % [peer_a_id, peer_b_id])

	# --- Step 1: server sends set_session_flags to client A ---
	server_netsync.rpc_id(peer_a_id, "set_session_flags", {"dedicated": true})
	_Harness.pump([mp_server, mp_a, mp_b], 300, 10, func() -> bool: return not stub_a.session_flags.is_empty())
	if not bool(stub_a.session_flags.get("dedicated", false)):
		print("  [FAIL] client A did not receive set_session_flags with dedicated=true (got %s)" % str(stub_a.session_flags))
		return false
	print("  [PASS] client A received set_session_flags {dedicated: true}")

	# --- Step 2: client A relays a challenge to the server ---
	var deck_a: Array = ["ghost", "skeleton"]
	netsync_a.rpc_id(1, "relay_pvp_request", peer_b_id, deck_a)

	_Harness.pump([mp_server, mp_a, mp_b], 300, 10, func() -> bool: return stub_b.challenger_id_seen >= 0)
	if stub_b.challenger_id_seen < 0:
		print("  [FAIL] client B did not receive request_battle from relay")
		return false
	if stub_b.challenge_deck_seen != deck_a:
		print("  [FAIL] forwarded deck mismatch: got %s, want %s" % [str(stub_b.challenge_deck_seen), str(deck_a)])
		return false
	print("  [PASS] server relayed request_battle to client B with challenger deck")

	# --- Step 3: client B accepts via relay_pvp_response → server ---
	var deck_b: Array = ["wraith", "zombie"]
	netsync_b.rpc_id(1, "relay_pvp_response", peer_a_id, true, deck_b)

	_Harness.pump([mp_server, mp_a, mp_b], 300, 10, func() -> bool:
		return stub_a.notify_player_idx >= 0 and stub_b.notify_player_idx >= 0)

	if stub_a.notify_player_idx < 0:
		print("  [FAIL] client A did not receive notify_pvp_start")
		return false
	if stub_b.notify_player_idx < 0:
		print("  [FAIL] client B did not receive notify_pvp_start")
		return false
	if stub_a.notify_player_idx != 0:
		print("  [FAIL] client A (challenger) should be player 0, got %d" % stub_a.notify_player_idx)
		return false
	if stub_b.notify_player_idx != 1:
		print("  [FAIL] client B (challenged) should be player 1, got %d" % stub_b.notify_player_idx)
		return false
	if stub_a.notify_opponent_deck != deck_b:
		print("  [FAIL] client A got wrong opponent deck: %s" % str(stub_a.notify_opponent_deck))
		return false
	if stub_b.notify_opponent_deck != deck_a:
		print("  [FAIL] client B got wrong opponent deck: %s" % str(stub_b.notify_opponent_deck))
		return false
	if stub_a.got_request_battle:
		print("  [FAIL] client A (challenger) incorrectly received request_battle")
		return false

	print("  [PASS] notify_pvp_start delivered to both clients with correct idx + opponent decks")

	_Harness.teardown([peer_a, peer_b, server_peer], [])
	return true


# Builds WorldScene/NetSync under `parent`, wires `stub` (named `stub_name`) as
# the NetSync's world_scene, and returns the NetSync node.
func _build_world(parent: Node, stub: Node, stub_name: String) -> Node:
	var world := Node.new()
	world.name = "WorldScene"
	parent.add_child(world)
	var netsync: Node = _NetSync.new()
	netsync.name = "NetSync"
	world.add_child(netsync)
	stub.name = stub_name
	world.add_child(stub)
	netsync.set("world_scene", stub)
	return netsync
