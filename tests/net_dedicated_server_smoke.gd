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

	func _on_battle_requested(_sender: int, _deck: Array) -> void:
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

	func _on_battle_requested(sender: int, deck: Array) -> void:
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
	var server_peer := ENetMultiplayerPeer.new()
	var serr: Error = server_peer.create_server(_PORT, 4)
	if serr != OK:
		print("  [FAIL] create_server returned %d (loopback sockets may be blocked)" % serr)
		return false
	var mp_server := SceneMultiplayer.new()
	var server_root := Node.new()
	server_root.name = "SrvRoot"
	root.add_child(server_root)
	set_multiplayer(mp_server, server_root.get_path())
	mp_server.multiplayer_peer = server_peer

	var server_world := Node.new()
	server_world.name = "WorldScene"
	server_root.add_child(server_world)
	var server_netsync: Node = _NetSync.new()
	server_netsync.name = "NetSync"
	server_world.add_child(server_netsync)
	var server_stub := _ServerStub.new()
	server_stub.name = "Stub"
	server_stub.net_sync = server_netsync
	server_world.add_child(server_stub)
	server_netsync.set("world_scene", server_stub)

	# Track connected peers by signal so we know the moment they are RPC-ready.
	var server_connected_peers: Array[int] = []
	mp_server.peer_connected.connect(func(id: int) -> void: server_connected_peers.append(id))

	# --- Client A ---
	var peer_a := ENetMultiplayerPeer.new()
	if peer_a.create_client("127.0.0.1", _PORT) != OK:
		print("  [FAIL] create_client A failed")
		return false
	var mp_a := SceneMultiplayer.new()
	var root_a := Node.new()
	root_a.name = "CliA"
	root.add_child(root_a)
	set_multiplayer(mp_a, root_a.get_path())
	mp_a.multiplayer_peer = peer_a

	var world_a := Node.new()
	world_a.name = "WorldScene"
	root_a.add_child(world_a)
	var netsync_a: Node = _NetSync.new()
	netsync_a.name = "NetSync"
	world_a.add_child(netsync_a)
	var stub_a := _ClientAStub.new()
	stub_a.name = "StubA"
	world_a.add_child(stub_a)
	netsync_a.set("world_scene", stub_a)

	# --- Client B ---
	var peer_b := ENetMultiplayerPeer.new()
	if peer_b.create_client("127.0.0.1", _PORT) != OK:
		print("  [FAIL] create_client B failed")
		return false
	var mp_b := SceneMultiplayer.new()
	var root_b := Node.new()
	root_b.name = "CliB"
	root.add_child(root_b)
	set_multiplayer(mp_b, root_b.get_path())
	mp_b.multiplayer_peer = peer_b

	var world_b := Node.new()
	world_b.name = "WorldScene"
	root_b.add_child(world_b)
	var netsync_b: Node = _NetSync.new()
	netsync_b.name = "NetSync"
	world_b.add_child(netsync_b)
	var stub_b := _ClientBStub.new()
	stub_b.name = "StubB"
	world_b.add_child(stub_b)
	netsync_b.set("world_scene", stub_b)

	# Poll until the server has seen peer_connected for both clients and both
	# clients know their own unique IDs (> 0 means the handshake completed).
	var fully_connected := false
	for _i in range(800):
		mp_server.poll()
		mp_a.poll()
		mp_b.poll()
		if server_connected_peers.size() >= 2 and mp_a.get_unique_id() > 0 and mp_b.get_unique_id() > 0:
			fully_connected = true
			break
		OS.delay_msec(10)
	if not fully_connected:
		print("  [FAIL] not fully connected within timeout (server_peers=%d, a_id=%d, b_id=%d)"
			% [server_connected_peers.size(), mp_a.get_unique_id(), mp_b.get_unique_id()])
		return false

	var peer_a_id: int = mp_a.get_unique_id()
	var peer_b_id: int = mp_b.get_unique_id()
	print("  [PASS] all peers connected (a_id=%d, b_id=%d)" % [peer_a_id, peer_b_id])

	# --- Step 1: server sends set_session_flags to client A ---
	server_netsync.rpc_id(peer_a_id, "set_session_flags", {"dedicated": true})
	for _j in range(300):
		mp_server.poll()
		mp_a.poll()
		mp_b.poll()
		if not stub_a.session_flags.is_empty():
			break
		OS.delay_msec(10)
	if not bool(stub_a.session_flags.get("dedicated", false)):
		print("  [FAIL] client A did not receive set_session_flags with dedicated=true (got %s)" % str(stub_a.session_flags))
		return false
	print("  [PASS] client A received set_session_flags {dedicated: true}")

	# --- Step 2: client A relays a challenge to the server ---
	var deck_a: Array = ["ghost", "skeleton"]
	netsync_a.rpc_id(1, "relay_pvp_request", peer_b_id, deck_a)

	for _k in range(300):
		mp_server.poll()
		mp_a.poll()
		mp_b.poll()
		if stub_b.challenger_id_seen >= 0:
			break
		OS.delay_msec(10)
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

	for _l in range(300):
		mp_server.poll()
		mp_a.poll()
		mp_b.poll()
		if stub_a.notify_player_idx >= 0 and stub_b.notify_player_idx >= 0:
			break
		OS.delay_msec(10)

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

	peer_a.close()
	peer_b.close()
	server_peer.close()
	return true
